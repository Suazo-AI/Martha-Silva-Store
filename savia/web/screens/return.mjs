import * as api from '../api.mjs';
import { h, replace, showError, openModal } from '../ui.mjs';
import { formatMoney, parseMoney } from '../money.mjs';
import { garmentLine } from './sale-view.mjs';
import { routeSaleId } from './receipt.mjs';
import { remainingQuantity, selectedReturnLines } from './return-logic.mjs';
import { syncTill } from './till-open.mjs';

/** A second real login. The cashier's session and token stay in place. */
export function supervisorApproval(action = 'devolución', lines = []) {
  return openModal((body, close) => {
    const user = h('input', { id: 'approval-user', autocomplete: 'username', required: true });
    const pass = h('input', { id: 'approval-pass', type: 'password', autocomplete: 'current-password', required: true });
    document.getElementById('modal').addEventListener('close', () => { pass.value = ''; }, { once: true });
    const error = h('p', { role: 'alert' });
    const reason = h('input', { id: 'approval-reason', maxlength: 250, required: true });
    const discounts = lines.map((line, index) => ({ line, input: h('input', {
      id: `approval-discount-${index}`, inputmode: 'decimal', value: ((line.discountMinor ?? 0) / 100).toFixed(2) }) }));
    const submit = h('button', { type: 'submit', class: 'primary' }, `Autorizar ${action}`);
    const form = h('form', { class: 'form', onsubmit: async event => {
      event.preventDefault();
      submit.disabled = true;
      try {
        if (action === 'descuento' && (!reason.value.trim() || discounts.some(({ line, input }) =>
          parseMoney(input.value) == null || parseMoney(input.value) > line.unitPriceMinor * line.quantity))) {
          throw new Error('Indique el motivo y un descuento válido para cada prenda.');
        }
        const approval = await api.login(user.value.trim(), pass.value);
        pass.value = '';
        if (!approval.roles.some(role => ['MANAGER','OWNER'].includes(role))) {
          await api.endApproval(approval.token);
          throw new Error('Use una cuenta de supervisión o de la dueña para autorizar.');
        }
        if (!document.getElementById('modal').open) { await api.endApproval(approval.token); return; }
        close(action === 'descuento' ? { token: approval.token, reason: reason.value.trim(),
          lines: discounts.map(({ line, input }) => ({ ...line, discountMinor: parseMoney(input.value) })) } : approval.token);
      } catch (failure) { pass.value = ''; showError(error, failure); submit.disabled = false; }
    } }, h('label', {}, 'Usuario de supervisión', user), h('label', {}, 'Contraseña de supervisión', pass),
    action === 'descuento' ? discounts.map(({ line, input }) => h('label', {}, `Descuento en C$ · ${line.name}`, input)) : null,
    action === 'descuento' ? h('label', {}, 'Motivo del descuento', reason) : null, error,
    h('div', { class: 'actions' }, h('button', { type: 'button', onclick: () => { pass.value = ''; close(); } }, 'Cancelar'), submit));
    replace(body, h('h2', { id: 'modal-title' }, 'Aprobación de supervisión'),
      h('p', {}, `${action === 'descuento' ? 'El descuento' : 'La devolución'} necesita autorización. Ingrese la cuenta de supervisión o de la dueña.`), form);
  });
}

export default {
  title: 'Devolución',
  async mount(root, ctx) {
    const status = h('p', { role: 'alert', id: 'return-status' });
    const panel = h('section', { class: 'panel' });
    replace(root, h('div', { class: 'page' }, panel, status));
    try {
      const id = routeSaleId();
      if (!id) throw new Error('Elija una venta desde Historial.');
      const sale = await api.saleReceipt(id);
      if (!sale.customerId) throw new Error('Esta venta no tiene cliente. El reembolso disponible requiere el cliente registrado en la venta.');
      const { till } = await syncTill(ctx);
      if (!till) throw new Error('Abra una caja desde Venta antes de registrar la devolución.');
      const quantities = {};
      const reason = h('textarea', { id: 'return-reason', required: true, maxlength: '500', rows: '1' });
      const method = h('select', { id: 'refund-method' }, h('option', { value: 'credit' }, 'Anticipo / crédito al cliente'));
      const restock = h('input', { id: 'return-restock', type: 'checkbox', checked: true });
      const total = h('strong', { id: 'return-preview' }, formatMoney(0));
      const submit = h('button', { id: 'return-submit', class: 'primary big', type: 'submit' }, 'Confirmar devolución');
      let attempt = null;
      const drawPreview = () => {
        attempt = null;
        // Undiscounted preview only; the result and stock/cash read-backs come from the server.
        const minor = sale.lines.reduce((sum, line) => sum + (Number(quantities[line.lineNumber]) || 0) * line.unitPriceMinor, 0);
        total.textContent = formatMoney(minor);
      };
      const lineRows = sale.lines.map(line => {
        const max = remainingQuantity(line);
        return h('div', { class: 'return-item' }, garmentLine(line), h('label', {}, `A devolver · ${line.sku} · Máximo ${max}`,
          h('input', { id: `return-qty-${line.lineNumber}`, type: 'number', min: '0', max, step: '1', value: '0', disabled: max === 0,
            oninput: e => { quantities[line.lineNumber] = e.target.value; drawPreview(); } })));
      });
      const result = h('section', { class: 'panel', id: 'return-result', hidden: true });
      const form = h('form', { class: 'form', oninput: () => { attempt = null; }, onsubmit: async event => {
        event.preventDefault();
        submit.disabled = true;
        status.textContent = '';
        try {
          const lines = selectedReturnLines(sale.lines, quantities);
          if (!reason.value.trim()) throw new Error('Indique el motivo de la devolución.');
          if (!attempt) attempt = { reversalId: api.uuid(), creditId: api.uuid(), tillId: till.tillId,
            customerId: sale.customerId, reason: reason.value.trim(),
            lines: lines.map(selected => ({ saleLineId: sale.lines.find(row => row.lineNumber === selected.saleLineNumber).saleLineId,
              quantity: selected.quantity, restockPool: restock.checked ? 'store' : 'quarantine' })) };
          let response;
          if (!ctx.isApprover) {
            const token = await supervisorApproval();
            if (!token) return;
            try { response = await api.postCreditReturn(id, attempt, token); }
            finally { await api.endApproval(token).catch(() => {}); }
          } else response = await api.postCreditReturn(id, attempt);
          form.hidden = true;
          result.hidden = false;
          replace(result, h('h2', {}, 'Devolución registrada'),
            h('p', { id: 'return-id' }, response.reversalId), h('p', {}, 'Reembolso como anticipo del cliente'),
            h('p', {}, `Anticipo ${response.creditId}`),
            h('div', { class: 'total' }, 'Total devuelto', h('strong', { id: 'return-total' }, formatMoney(response.creditMinor))));
          const stock = await api.stock();
          const summary = await api.tillSummary(response.tillId);
          result.append(h('p', { id: 'return-cash' }, `Efectivo esperado: ${formatMoney(summary.expectedCashMinor)}`));
          for (const selected of lines) {
            const line = sale.lines.find(row => row.lineNumber === selected.saleLineNumber);
            const count = stock.filter(row => row.itemId === line.itemId).reduce((sum, row) => sum + row.onHand, 0);
            result.append(h('p', { dataset: { item: line.itemId } }, `${line.sku} · Existencias: ${count}`));
          }
        } catch (error) { showError(status, error); }
        finally { submit.disabled = false; }
      } }, ...lineRows,
      h('div', { class: 'return-options' }, h('div', { class: 'form' },
        h('label', {}, 'Motivo de la devolución', reason), h('label', {}, 'Método de reembolso', method),
        h('label', { class: 'check' }, restock, 'Reingresar al stock disponible'),
        h('p', { class: 'muted' }, 'Sin marcar: las unidades quedan en cuarentena. El reembolso se guarda como anticipo; no sale efectivo de caja.')),
        h('div', { class: 'total' }, 'Importe estimado', total)),
      h('div', { class: 'actions return-actions' }, h('button', { type: 'button', onclick: () => ctx.go('historial') }, 'Volver'), submit));
      replace(panel, h('h2', {}, `Devolución · ${id}`), form, result);
    } catch (error) { showError(status, error); }
    return { handleScan: () => ctx.notify('Indique las cantidades de la venta que va a devolver.') };
  },
};

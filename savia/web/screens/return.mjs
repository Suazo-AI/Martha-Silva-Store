import { confirmAction } from '../confirm.mjs';
import * as api from '../api.mjs';
import { h, replace, showError, openModal } from '../ui.mjs';
import { formatMoney, parseMoney } from '../money.mjs';
import { garmentLine, tenderName } from './sale-view.mjs';
import { routeSaleId } from './receipt.mjs';
import { remainingQuantity, selectedReturnLines, returnValue, exchangeBalance, outcomeRequest, OUTCOMES } from './return-logic.mjs';
import { syncTill } from './till-open.mjs';
import { itemFromLookup } from './sale-logic.mjs';

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
      const [policy, sellers] = await Promise.all([api.returnPolicy().catch(() => null), api.sellers().catch(() => [])]);
      let creditCustomerId=sale.customerId;
      const creditCustomer=h('input',{id:'return-credit-customer',type:'search',placeholder:'Nombre para emitir el anticipo'});
      const customerChoices=h('div',{class:'actions'});
      const chooseCustomer=h('div',{class:'form'},h('label',{},'Destinataria del anticipo',creditCustomer),h('button',{type:'button',onclick:async()=>{
        try { const customers=await api.searchCustomers(creditCustomer.value);replace(customerChoices,customers.map(customer=>h('button',{type:'button',onclick:()=>{creditCustomerId=customer.customerId;creditCustomer.value=customer.displayName;replace(customerChoices);}},customer.displayName))); }
        catch(error){showError(status,error);}
      }},'Buscar destinataria'),customerChoices);
      const { till } = await syncTill(ctx);
      if (!till) throw new Error('Abra una caja desde Venta antes de registrar la devolución.');
      const quantities = {};
      let outcome = 'credit';
      let newLines = [];
      let attempt = null;
      const reason = h('textarea', { id: 'return-reason', required: true, maxlength: '500', rows: '1' });
      const restock = h('input', { id: 'return-restock', type: 'checkbox', checked: true });
      const total = h('strong', { id: 'return-preview' }, formatMoney(0));
      const submit = h('button', { id: 'return-submit', class: 'primary big', type: 'submit' }, 'Confirmar devolución');
      const reference = h('input', { id: 'return-reference', maxlength: 120, placeholder: 'Número de la transferencia' });
      const exchangeCode = h('input', { id: 'exchange-code', type: 'search', autocomplete: 'off', placeholder: 'Código o SKU' });
      const exchangeLines = h('div', { id: 'exchange-lines' });
      const firstSeller = sale.lines.find(l => sellers.some(s => s.sellerId === l.sellerId))?.sellerId ?? sellers[0]?.sellerId;
      const exchangeSeller = h('select', { id: 'exchange-seller' }, sellers.map(s => h('option', { value: s.sellerId, selected: s.sellerId === firstSeller }, s.name)));
      const tenderKind = h('select', { id: 'exchange-tender' }, ['cash', 'card', 'transfer'].map(kind => h('option', { value: kind }, tenderName(kind))));
      const tenderReference = h('input', { id: 'exchange-tender-reference', maxlength: 120 });
      const differenceKind = h('select', { id: 'exchange-difference' }, h('option', { value: 'cash' }, 'Efectivo de caja'), h('option', { value: 'transfer' }, 'Transferencia bancaria'));
      const differenceReference = h('input', { id: 'exchange-difference-reference', maxlength: 120 });
      const balance = h('div', { id: 'exchange-balance', class: 'form' });
      const outcomePanel = h('div', { id: 'outcome-panel', class: 'form' });
      const returnMinor = () => returnValue(sale, quantities);
      const drawBalance = () => {
        const { newMinor, dueMinor, backMinor } = exchangeBalance(returnMinor(), newLines);
        replace(balance, h('div', { class: 'total' }, 'Prendas nuevas', h('strong', { id: 'exchange-new-total' }, formatMoney(newMinor))),
          dueMinor ? [h('div', { class: 'total' }, 'La clienta paga', h('strong', { id: 'exchange-due' }, formatMoney(dueMinor))),
            h('label', {}, 'Forma de pago', tenderKind), h('label', {}, 'Referencia del pago', tenderReference)] : null,
          backMinor ? [h('div', { class: 'total' }, 'Se devuelve a la clienta', h('strong', { id: 'exchange-back' }, formatMoney(backMinor))),
            h('label', {}, 'Devolver la diferencia en', differenceKind), h('label', {}, 'Referencia de la transferencia', differenceReference)] : null);
      };
      const drawExchange = () => {
        replace(exchangeLines, newLines.map((line, index) => h('div', { class: 'row', dataset: { item: line.itemId } },
          h('span', {}, `${line.name} · ${line.quantity} × ${formatMoney(line.unitPriceMinor)}`),
          h('button', { type: 'button', 'aria-label': `Quitar ${line.name} del cambio`, onclick: () => { newLines = newLines.filter((_, i) => i !== index); attempt = null; drawExchange(); } }, 'Quitar'))));
        drawBalance();
      };
      const addExchange = async () => {
        try {
          const code = exchangeCode.value.trim();
          if (!code) return;
          const found = await api.lookup(code);
          if (found.length !== 1) throw new Error(found.length ? 'Hay varias prendas con ese código. Use el SKU.' : `No se encontró «${code}».`);
          const row = found[0];
          if (row.unitPriceMinor == null) throw new Error('La prenda no tiene precio de venta.');
          const item = itemFromLookup(row);
          const existing = newLines.findIndex(l => l.itemId === item.itemId);
          newLines = existing === -1 ? [...newLines, { ...item, quantity: 1 }] : newLines.map((l, i) => i === existing ? { ...l, quantity: l.quantity + 1 } : l);
          exchangeCode.value = ''; attempt = null; status.textContent = ''; drawExchange();
        } catch (error) { showError(status, error); }
      };
      exchangeCode.addEventListener('keydown', event => { if (event.key === 'Enter') { event.preventDefault(); addExchange(); } });
      const drawOutcome = () => replace(outcomePanel,
        outcome === 'credit' ? [h('p', {}, 'Se emite un anticipo a nombre de la clienta. No sale efectivo de caja.'), sale.customerId ? null : chooseCustomer] : null,
        outcome === 'cash' ? h('p', {}, 'Sale efectivo de la caja abierta. Si la caja no alcanza, se rechaza.') : null,
        outcome === 'transfer' ? [h('p', {}, 'La caja no cambia.'), h('label', {}, 'Referencia de la transferencia', reference)] : null,
        outcome === 'exchange' ? [h('div', { class: 'row' }, h('label', {}, 'Prenda nueva', exchangeCode), h('button', { type: 'button', id: 'exchange-add', onclick: addExchange }, 'Agregar')),
          exchangeLines, h('label', {}, 'Vendedor del cambio', exchangeSeller), balance] : null);
      const outcomes = h('fieldset', { class: 'outcomes', id: 'refund-outcomes' }, h('legend', {}, 'Cómo se resuelve'),
        OUTCOMES.map(([value, label]) => h('label', {}, h('input', { type: 'radio', name: 'outcome', value, id: `outcome-${value}`, checked: value === outcome,
          onchange: () => { outcome = value; attempt = null; status.textContent = ''; drawOutcome(); } }), label)));
      const drawPreview = () => {
        attempt = null;
        total.textContent = formatMoney(returnMinor());
        drawBalance();
      };
      const lineRows = sale.lines.map(line => {
        const max = remainingQuantity(line);
        return h('div', { class: 'return-item' }, garmentLine(line), h('label', {}, `A devolver · ${line.sku} · Máximo ${max}`,
          h('input', { id: `return-qty-${line.lineNumber}`, type: 'number', min: '0', max, step: '1', value: '0', disabled: max === 0,
            oninput: e => { quantities[line.lineNumber] = e.target.value; drawPreview(); } })));
      });
      const sentence = () => {
        const amount = formatMoney(returnMinor());
        if (outcome === 'credit') return `Se devolverán prendas por ${amount}. Se emitirá un anticipo y se revertirá la comisión.`;
        if (outcome === 'cash') return `Se devolverán prendas por ${amount}. Saldrán ${amount} en efectivo de la caja y se revertirá la comisión.`;
        if (outcome === 'transfer') return `Se devolverán prendas por ${amount} por transferencia ${reference.value.trim()}. La caja no cambia y se revertirá la comisión.`;
        const { newMinor, dueMinor, backMinor } = exchangeBalance(returnMinor(), newLines);
        const difference = dueMinor ? `La clienta paga ${formatMoney(dueMinor)} con ${tenderName(tenderKind.value).toLowerCase()}.`
          : backMinor ? `Se devuelven ${formatMoney(backMinor)} por ${differenceKind.value === 'cash' ? 'efectivo de caja' : 'transferencia'}.` : 'Sin diferencia.';
        return `Cambio: entra ${amount} en prendas devueltas y salen ${formatMoney(newMinor)} en prendas nuevas. ${difference} Se revertirá la comisión de lo devuelto.`;
      };
      const result = h('section', { class: 'panel', id: 'return-result', hidden: true });
      const form = h('form', { class: 'form', oninput: () => { attempt = null; }, onsubmit: async event => {
        event.preventDefault();
        submit.disabled = true;
        status.textContent = '';
        try {
          const lines = selectedReturnLines(sale.lines, quantities);
          if (!reason.value.trim()) throw new Error('Indique el motivo de la devolución.');
          if (outcome === 'credit' && !creditCustomerId) throw new Error('Elija la destinataria del anticipo. La venta original no requiere cliente.');
          const returned = lines.map(selected => ({ saleLineId: sale.lines.find(row => row.lineNumber === selected.saleLineNumber).saleLineId,
            quantity: selected.quantity, restockPool: restock.checked ? 'store' : 'quarantine' }));
          if (!attempt) attempt = outcome === 'credit'
            ? { reversalId: api.uuid(), creditId: api.uuid(), tillId: till.tillId, customerId: creditCustomerId, reason: reason.value.trim(), lines: returned }
            : outcomeRequest({ reversalId: api.uuid(), outcome, tillId: till.tillId, reason: reason.value.trim(), lines: returned, reference: reference.value,
              exchangeSaleId: api.uuid(), newLines, sellerId: exchangeSeller.value || null, tenderKind: tenderKind.value, tenderReference: tenderReference.value,
              differenceKind: differenceKind.value, differenceReference: differenceReference.value, returnMinor: returnMinor() });
          if (!await confirmAction(sentence())) return;
          const post = token => outcome === 'credit' ? api.postCreditReturn(id, attempt, token) : api.postReturnOutcome(id, attempt, token);
          let response;
          if (!ctx.isApprover) {
            const token = await supervisorApproval();
            if (!token) return;
            try { response = await post(token); }
            finally { await api.endApproval(token).catch(() => {}); }
          } else response = await post();
          form.hidden = true;
          result.hidden = false;
          const kind = response.settlementKind ?? outcome;
          replace(result, h('h2', {}, 'Devolución registrada'),
            h('p', { id: 'return-id' }, response.reversalId), h('p', { id: 'return-outcome', dataset: { kind } }, Object.fromEntries(OUTCOMES)[kind] ?? kind),
            response.creditId ? h('p', {}, `Anticipo ${response.creditId}`) : null,
            attempt.reference ? h('p', { id: 'return-reference-result' }, `Referencia ${attempt.reference}`) : null,
            h('div', { class: 'total' }, 'Total devuelto', h('strong', { id: 'return-total' }, formatMoney(response.creditMinor))),
            attempt.exchangeSaleId ? h('button', { type: 'button', id: 'exchange-receipt', onclick: () => ctx.go(`recibo?sale=${encodeURIComponent(attempt.exchangeSaleId)}`) }, 'Ver recibo del cambio') : null);
          const stock = await api.stock();
          const summary = await api.tillSummary(response.tillId ?? till.tillId);
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
        policy ? h('p', { id: 'return-window', class: 'muted' }, `Plazo: ${policy.windowDays} días desde la venta.`) : null,
        h('label', {}, 'Motivo de la devolución', reason), outcomes, outcomePanel,
        h('label', { class: 'check' }, restock, 'Reingresar al stock disponible')),
        h('div', { class: 'total' }, 'Importe a devolver', total)),
      h('div', { class: 'actions return-actions' }, h('button', { type: 'button', onclick: () => ctx.go('historial') }, 'Volver'), submit));
      drawOutcome(); drawExchange();
      replace(panel, h('h2', {}, `Devolución · ${id}`), form, result);
    } catch (error) { showError(status, error); }
    return { handleScan: code => ctx.notify(`Para un cambio, escriba ${code} en Prenda nueva.`) };
  },
};

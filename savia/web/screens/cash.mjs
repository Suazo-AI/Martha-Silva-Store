// Caja · Cierre: count cash by denomination, show expected vs counted, close once.
import * as api from '../api.mjs';
import { h, replace, showError, showOk, clearMessage, device } from '../ui.mjs';
import { formatMoney, countTotal, NIO_DENOMINATIONS } from '../money.mjs';
import { openTillPanel, syncTill } from './till-open.mjs';
import { differenceView } from './cash-logic.mjs';

export default {
  title: 'Caja',
  async mount(root, ctx) {
    const handle = { handleScan: () => ctx.notify('En Caja no se escanea. Vaya a Venta.') };

    const renderNoTill = async (closure) => {
      replace(root, h('div', { class: 'page' }, h('div', { class: 'split' },
        closure ? closurePanel(closure) : h('section', { class: 'panel' }, h('h2', {}, 'No hay caja abierta en este equipo')),
        await openTillPanel(ctx, () => ctx.go('venta')))));
    };

    const renderTill = (till, summary) => {
      const quantities = new Map(NIO_DENOMINATIONS.map(d => [d, 0]));
      const counted = h('strong', { class: 'num', id: 'counted' });
      const message = h('p', { class: 'error', role: 'alert' });
      const expected = summary.expectedCashMinor;
      const saved = device.get('count.' + till.tillId);
      const pending = saved?.pending ?? { cashCountId: null, closureId: null, key: null };
      for (const line of saved?.lines ?? []) quantities.set(line.denominationMinor, line.quantity);

      const lines = () => [...quantities].filter(([, q]) => q > 0).map(([denominationMinor, quantity]) => ({ denominationMinor, quantity }));
      const drawCounted = () => { counted.textContent = formatMoney(countTotal(lines())); };

      const inputs = NIO_DENOMINATIONS.map(d => {
        const id = `den-${d}`;
        const input = h('input', { id, inputmode: 'numeric', autocomplete: 'off', value: String(quantities.get(d)) });
        input.addEventListener('input', () => {
          const q = Number(input.value.trim() || '0');
          input.setAttribute('aria-invalid', String(!Number.isInteger(q) || q < 0));
          if (Number.isInteger(q) && q >= 0) quantities.set(d, q);
          drawCounted();
        });
        input.addEventListener('focus', () => input.select());
        return h('label', { for: id }, h('span', { class: 'num' }, formatMoney(d)), input);
      });

      const saveCount = async () => {
        const countLines = lines();
        if (countLines.length === 0) throw Object.assign(new Error('Escriba cuántos billetes y monedas hay.'), { local: true });
        const key = JSON.stringify(countLines);
        if (pending.key !== key) Object.assign(pending, { cashCountId: api.uuid(), closureId: api.uuid(), key });
        await api.recordCashCount(till.tillId, { cashCountId: pending.cashCountId, lines: countLines });
        device.set('count.' + till.tillId, { pending, lines: countLines });
        return pending;
      };

      const save = h('button', { type: 'button', id: 'save-count', onclick: async () => {
        clearMessage(message);
        try { await saveCount(); showOk(message, 'Conteo guardado. Una supervisora puede cerrar la caja.'); }
        catch (error) { showError(message, error, error.local ? '' : 'Revise el conteo y vuelva a intentar.'); }
      } }, 'Guardar conteo');

      const close = h('button', { type: 'button', class: 'primary big', id: 'close-till', onclick: async () => {
        clearMessage(message);
        close.disabled = true;
        try {
          const ids = await saveCount();
          const closure = await api.closeTill(till.tillId, { closureId: ids.closureId, cashCountId: ids.cashCountId });
          ctx.till.set(null);
          device.set('count.' + till.tillId, null);
          await renderNoTill(closure);
          document.getElementById('closure-title')?.focus();
        } catch (error) {
          showError(message, error, error.local ? '' : error.code === 'cash.already_closed' ? 'La caja ya estaba cerrada.' : 'Revise el conteo y vuelva a intentar.');
          close.disabled = false;
        }
      } }, 'Cerrar caja');

      replace(root, h('div', { class: 'page' }, h('div', { class: 'split' },
        h('section', { class: 'panel ledger', 'aria-labelledby': 'ledger-title' },
          h('h2', { id: 'ledger-title' }, 'Caja del turno'),
          h('div', { class: 'row' }, h('span', {}, 'Fondo inicial'), h('strong', {}, formatMoney(summary.openingMinor))),
          summary ? h('div', { class: 'row' }, h('span', {}, 'Ventas en efectivo'), h('strong', {}, formatMoney(summary.cashSalesMinor))) : null,
          summary?.cashRefundsMinor ? h('div', { class: 'row' }, h('span', {}, 'Devoluciones'), h('strong', {}, formatMoney(summary.cashRefundsMinor))) : null,
          h('div', { class: 'row expected' }, h('span', {}, 'Efectivo esperado'),
            h('strong', { id: 'expected' }, formatMoney(expected))),
          h('p', { class: 'muted' }, `${summary.registerName} · ${summary.cashierName}`)),
        h('section', { class: 'panel', 'aria-labelledby': 'count-title' },
          h('h2', { id: 'count-title' }, 'Efectivo contado'),
          h('div', { class: 'denoms' }, inputs),
          h('div', { class: 'row total' }, h('span', {}, 'Su conteo'), counted),
          message,
          h('div', { class: 'actions' }, save),
          ctx.isApprover ? close : h('p', { class: 'muted' }, 'Guarde el conteo. Una supervisora cierra la caja.')))));
      drawCounted();
    };

    const { till, summary } = await syncTill(ctx);
    let liveSummary = summary ?? null;
    if (till?.tillId && !liveSummary) {
      try { liveSummary = await api.tillSummary(till.tillId); } catch { liveSummary = null; }
    }
    if (till?.tillId) renderTill(till, liveSummary); else await renderNoTill(null);
    return handle;
  },
};

function closurePanel(closure) {
  const diff = differenceView(closure.differenceMinor);
  return h('section', { class: 'panel ledger', 'aria-labelledby': 'closure-title', id: 'closure' },
    h('h2', { id: 'closure-title', tabindex: '-1' }, 'Caja cerrada'),
    h('div', { class: 'row' }, h('span', {}, 'Efectivo esperado'), h('strong', { id: 'closure-expected' }, formatMoney(closure.expectedMinor))),
    h('div', { class: 'row' }, h('span', {}, 'Efectivo contado'), h('strong', { id: 'closure-counted' }, formatMoney(closure.countedMinor))),
    h('p', {}, 'Diferencia'),
    h('div', { class: `diff ${diff.tone}`, id: 'closure-difference' }, `${diff.label}: ${formatMoney(closure.differenceMinor)}`));
}

// "Abrir caja": used by Venta and Caja when this device has no open till.
import * as api from '../api.mjs';
import { countTotal } from '../money.mjs';
import { clearMessage, device, GUID_RE, h, showError } from '../ui.mjs';
import { denominationCount } from './denominations.mjs';

export async function openTillPanel(ctx, onOpened) {
  const message = h('p', { class: 'error', role: 'alert' });
  const registerControl = h('select', { id: 'till-register', required: true });
  try {
    const list = await api.registers();
    const available = list.filter(r => !r.openTillId);
    registerControl.append(
      ...available.map(r =>
        h('option', { value: r.registerId, selected: r.registerId === device.get('registerId') }, `${r.code} · ${r.name}`),
      ),
    );
    if (!available.length) message.textContent = 'Todas las cajas tienen un turno abierto. Pida a la gerente que revise o cierre el turno.';
  } catch (error) {
    showError(message, error);
  }
  const count = await denominationCount({ prefix: 'open-den' });
  const submit = h('button', { class: 'primary big', type: 'submit' }, 'Abrir caja');
  const ids = api.retryIds('tillId');
  return h(
    'form',
    {
      class: 'panel form',
      'aria-labelledby': 'open-title',
      novalidate: true,
      onsubmit: async event => {
        event.preventDefault();
        clearMessage(message);
        const registerId = registerControl.value.trim();
        let lines;
        try {
          lines = count.lines();
        } catch (error) {
          showError(message, error);
          return;
        }
        const openingMinor = countTotal(lines);
        if (!GUID_RE.test(registerId)) {
          message.textContent = 'Elija una caja disponible.';
          registerControl.focus();
          return;
        }
        const { tillId } = ids([registerId, lines]);
        submit.disabled = true;
        try {
          await api.openTill({ tillId, registerId, currencyCode: 'NIO', openingMinor, lines });
          device.set('registerId', registerId);
          ctx.till.set(await api.tillSummary(tillId));
          await onOpened();
        } catch (error) {
          showError(message, error, 'Revise los datos y vuelva a intentar.');
        } finally {
          submit.disabled = false;
        }
      },
    },
    h('h2', { id: 'open-title' }, 'Abrir caja'),
    h('p', {}, 'No hay caja abierta en este equipo. Cuente el efectivo inicial y ábrala para vender.'),
    h('label', { for: 'till-register' }, 'Caja'),
    registerControl,
    count.node,
    h('div', { class: 'row total' }, 'Fondo inicial', count.total),
    message,
    submit,
  );
}

/** Registers identify an accessible open till without an expected 404 request. */
export async function syncTill(ctx) {
  const registers = await api.registers();
  const allowed = registers.filter(r => r.openTillId && (r.openTillCashierId === ctx.me.staffId || ctx.isApprover));
  const local = ctx.till.get();
  const register =
    allowed.find(r => r.openTillId === local?.tillId) ?? allowed.find(r => r.openTillCashierId === ctx.me.staffId) ?? allowed[0];
  if (!register) {
    device.set('parkedTickets', null);
    ctx.till.set(null);
    return { till: null, known: true };
  }
  const saved = device.get('parkedTickets');
  if (saved && saved.tillId !== register.openTillId) device.set('parkedTickets', null);
  const summary = await api.tillSummary(register.openTillId);
  ctx.till.set(summary);
  return { till: summary, summary, known: true };
}

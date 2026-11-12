// "Abrir caja": used by Venta and Caja when this device has no open till.
import * as api from '../api.mjs';
import { h, showError, clearMessage, device, GUID_RE } from '../ui.mjs';
import { parseMoney } from '../money.mjs';

export async function openTillPanel(ctx, onOpened) {
  const message = h('p', { class: 'error', role: 'alert' });
  const registerControl = h('select', { id: 'till-register', required: true });
  try {
    const list = await api.registers();
    const available = list.filter(r => !r.openTillId);
    registerControl.append(...available.map(r => h('option', { value: r.registerId,
      selected: r.registerId === device.get('registerId') }, `${r.code} · ${r.name}`)));
    if (!available.length) message.textContent = 'Todas las cajas tienen un turno abierto.';
  } catch (error) { showError(message, error); }
  const opening = h('input', { id: 'till-opening', inputmode: 'decimal', autocomplete: 'off', placeholder: '0.00' });
  const submit = h('button', { class: 'primary big', type: 'submit' }, 'Abrir caja');
  let pending = null;   // same TillId on a retry
  return h('form', { class: 'panel form', 'aria-labelledby': 'open-title', novalidate: true, onsubmit: async event => {
    event.preventDefault();
    clearMessage(message);
    const registerId = registerControl.value.trim();
    const openingMinor = parseMoney(opening.value);
    if (!GUID_RE.test(registerId)) { message.textContent = 'Elija una caja disponible.'; registerControl.focus(); return; }
    if (openingMinor == null) { message.textContent = 'Escriba el efectivo inicial, por ejemplo 1000.00.'; opening.focus(); return; }
    if (!pending || pending.registerId !== registerId || pending.openingMinor !== openingMinor) pending = { tillId: api.uuid(), registerId, openingMinor };
    submit.disabled = true;
    try {
      await api.openTill({ tillId: pending.tillId, registerId, currencyCode: 'NIO', openingMinor });
      device.set('registerId', registerId);
      ctx.till.set(await api.tillSummary(pending.tillId));
      await onOpened();
    } catch (error) {
      showError(message, error, 'Revise los datos y vuelva a intentar.');
    } finally {
      submit.disabled = false;
    }
  } },
    h('h2', { id: 'open-title' }, 'Abrir caja'),
    h('p', {}, 'No hay caja abierta en este equipo. Cuente el efectivo inicial y ábrala para vender.'),
    h('label', { for: 'till-register' }, 'Caja'), registerControl,
    h('label', { for: 'till-opening' }, 'Efectivo inicial (C$)'), opening,
    message, submit);
}

/** Registers identify an accessible open till without an expected 404 request. */
export async function syncTill(ctx) {
  const registers = await api.registers();
  const allowed = registers.filter(r => r.openTillId &&
    (r.openTillCashierId === ctx.me.staffId || ctx.isApprover));
  const local = ctx.till.get();
  const register = allowed.find(r => r.openTillId === local?.tillId) ??
    allowed.find(r => r.openTillCashierId === ctx.me.staffId) ?? allowed[0];
  if (!register) { ctx.till.set(null); return { till: null, known: true }; }
  const summary = await api.tillSummary(register.openTillId);
  ctx.till.set(summary);
  return { till: summary, summary, known: true };
}

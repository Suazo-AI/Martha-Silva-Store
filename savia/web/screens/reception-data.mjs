// Shared by Recepción (scan) and Recepción (revisar): the current session on this device and its server state.
import * as api from '../api.mjs';
import { h, photo, device } from '../ui.mjs';
import { linesFromServer, totalsText } from './reception-logic.mjs';

export const current = {
  get: () => device.get('reception'),
  set: value => device.set('reception', value),
};

/**
 * Reads the session from the server. Quantities come only from the server:
 * per line from GET .../lines when it exists, the session total from GET .../{id} always.
 */
export async function loadState(session) {
  const progress = await api.receptionProgress(session.sessionId);
  const lines = linesFromServer(await api.receptionLines(session.sessionId));
  return { progress, lines, totals: totalsText(lines.length, progress) };
}

export function lineView(line, { onRegister, onReject } = {}) {
  const isNew = ['unknown', 'ambiguous'].includes(line.matchStatus);
  return h('div', { class: 'rline', dataset: { code: line.code, scan: line.scanId, status: line.matchStatus } },
    photo(line.sku),
    h('div', {},
      h('strong', {}, isNew ? 'Código nuevo' : line.matchStatus === 'rejected' ? 'Lectura rechazada' : (line.name ?? 'Producto')),
      h('p', {}, line.size ? `Talla ${line.size} · ` : '', h('span', { class: 'num' }, line.code), line.sku && line.sku !== line.code ? ` · SKU ${line.sku}` : ''),
      isNew ? h('div', { class: 'actions' },
        h('span', { class: 'tag new' }, 'Sin registrar'),
        onRegister ? h('button', { type: 'button', onclick: () => onRegister(line) }, 'Registrar producto') : null,
        onReject ? h('button', { type: 'button', onclick: () => onReject(line) }, 'Rechazar') : null) : null),
    h('span', { class: 'qty', 'aria-label': line.quantity == null ? 'Cantidad no disponible' : `Cantidad ${line.quantity}` },
      line.quantity == null ? '—' : String(line.quantity)));
}

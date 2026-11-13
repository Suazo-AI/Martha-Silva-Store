// Recepción · Escanear. Each reading posts to the session; the screen shows only what the server answers.
import * as api from '../api.mjs';
import { h, replace, showError, clearMessage, flash, device, openModal, GUID_RE } from '../ui.mjs';
import { attachScanField, serialQueue } from '../scan.mjs';
import { parseMoney } from '../money.mjs';
import { current, loadState, lineView } from './reception-data.mjs';
import { defaultReference } from './reception-logic.mjs';

export default {
  title: 'Recepción',
  async mount(root, ctx) {
    let detach = () => {};
    let handle = { handleScan: () => {} };

    const renderStart = async () => {
      detach();
      const message = h('p', { class: 'error', role: 'alert' });
      const reference = h('input', { id: 'rec-reference', value: defaultReference(), required: true, maxlength: 100 });
      const supplierControl = h('select', { id: 'rec-supplier', required: true });
      try {
        const list = await api.suppliers();
        replace(supplierControl, list.map(s => h('option', { value: s.supplierId, selected: s.supplierId === device.get('supplierId') }, s.name)));
      } catch (error) { showError(message, error); }
      const submit = h('button', { class: 'primary big', type: 'submit' }, 'Empezar recepción');
      let pending = null;
      const form = h('form', { class: 'panel form', novalidate: true, onsubmit: async event => {
        event.preventDefault();
        clearMessage(message);
        const supplierId = supplierControl.value.trim();
        if (!reference.value.trim()) { message.textContent = 'Escriba una referencia para la recepción.'; reference.focus(); return; }
        if (!GUID_RE.test(supplierId)) { message.textContent = 'Elija el proveedor.'; supplierControl.focus(); return; }
        submit.disabled = true;
        const key = JSON.stringify([reference.value.trim(), supplierId]);
        if (!pending || pending.key !== key) pending = {
          key, sessionId: api.uuid(), containerId: api.uuid(), reference: reference.value.trim(), supplierId,
        };
        const session = pending;
        try {
          await api.openReception({ containerId: session.containerId, scanSessionId: session.sessionId, reference: session.reference, supplierId, deviceCode: 'WEB' });
          device.set('supplierId', supplierId);
          current.set(session);
          await renderScanning();
        } catch (error) {
          showError(message, error, 'Corrija los datos y vuelva a intentar.');
        } finally {
          submit.disabled = false;
        }
      } },
        h('h2', {}, 'Nueva recepción'),
        h('label', { for: 'rec-reference' }, 'Referencia'), reference,
        h('label', { for: 'rec-supplier' }, 'Proveedor'), supplierControl,
        message, submit);
      const resume = h('section', { class: 'panel' }, h('h2', {}, 'Recepciones pendientes'));
      try {
        const sessions = await api.listReceptions();
        resume.append(...sessions.map(s => h('button', { type: 'button', onclick: async () => {
          current.set({ sessionId: s.scanSessionId, containerId: s.containerId, reference: s.reference, supplierId: s.supplierId });
          if (s.status === 'counting') await renderScanning(); else ctx.go('recepcion/revisar');
        } }, `${s.reference} · ${s.supplierName}`)));
        if (!sessions.length) resume.append(h('p', { class: 'muted' }, 'No hay recepciones pendientes.'));
      } catch (error) { showError(message, error); }
      replace(root, h('div', { class: 'page' }, form, resume));
      handle.handleScan = () => ctx.notify('Primero empiece la recepción.');
      reference.focus();
    };

    const renderScanning = async () => {
      detach();
      const session = current.get();
      const scanInput = h('input', { id: 'scan-input', autocomplete: 'off', spellcheck: 'false', 'aria-describedby': 'scan-help' });
      const status = h('p', { class: 'error', role: 'alert' });
      const lastScan = h('section', { class: 'panel', 'aria-labelledby': 'last-title', 'aria-live': 'polite' });
      const linesBox = h('div', { class: 'lines', id: 'rec-lines' });
      const totals = h('p', { class: 'totals', id: 'rec-totals', 'aria-live': 'polite' });

      const retry = h('div', { class: 'actions' });
      const failed = [];   // scans the server did not confirm; retried with the same ScanId

      const draw = (state, lastCode) => {
        replace(linesBox, state.lines.map(line => lineView(line, ctx.isApprover ? {
          onRegister: async line => { if (await registerProduct(line, session.sessionId)) await refresh(line.code); },
          onReject: async line => { if (await rejectReading(line, session.sessionId)) await refresh(line.code); },
        } : {})));
        totals.textContent = state.totals;
        if (!lastCode) {
          replace(lastScan, h('h2', { id: 'last-title' }, 'Último escaneo'), h('p', { class: 'muted' }, 'Escanee la primera prenda.'));
          return;
        }
        const line = state.lines.find(l => l.code === lastCode);
        const known = line?.matchStatus === 'matched';
        const rejected = line?.matchStatus === 'rejected';
        const count = line?.quantity ?? null;
        const pieces = state.progress.matchedUnits + state.progress.unitsPendingReview;
        replace(lastScan,
          h('h2', { id: 'last-title' }, 'Último escaneo'),
          h('div', { class: 'last-scan' },
            h('div', {},
              h('strong', {}, rejected ? 'Lectura rechazada' : known ? (line.name ?? 'Producto') : 'Código nuevo'),
              h('p', { class: 'num' }, lastCode, line?.size ? ` · Talla ${line.size}` : ''),
              known || rejected ? null : h('p', { class: 'warning' }, 'Registre el producto o rechace la lectura antes de aprobar.')),
            h('div', { class: 'count', id: 'last-count' },
              count != null ? String(count) : String(pieces),
              h('small', {}, count != null ? (count === 1 ? 'pieza de este código' : 'piezas de este código') : 'piezas en total'))));
        flash(lastScan);
      };

      const refresh = async lastCode => {
        const state = await loadState(current.get());
        draw(state, lastCode);
        return state;
      };

      const sendScan = async ({ code, scanId }) => {
        try {
          await api.recordScan(session.sessionId, { scanId, rawCode: code, deviceCode: 'WEB' });
          clearMessage(status);
          await refresh(code);
        } catch (error) {
          if (error.network || error.status >= 500) {
            failed.push({ code, scanId });
            drawRetry();
          }
          showError(status, error, error.network ? 'La lectura quedó pendiente; use «Reintentar lecturas».' : 'Vuelva a escanear o revise el código.');
        }
      };
      const queue = serialQueue(sendScan);
      const drawRetry = () => replace(retry, failed.length ? h('button', { type: 'button', onclick: () => {
        const again = failed.splice(0);
        drawRetry();
        again.forEach(item => queue.push(item));
      } }, `Reintentar lecturas (${failed.length})`) : null);

      handle.handleScan = code => queue.push({ code, scanId: api.uuid() });

      const layout = h('div', { class: 'page' },
        h('div', { class: 'split' },
          h('div', { style: 'display:grid;gap:14px;min-width:0' },
            h('section', { class: 'panel scan-field' },
              h('label', { for: 'scan-input' }, 'Escanear código'),
              scanInput,
              h('p', { id: 'scan-help', class: 'muted' }, 'El lector escribe el código y pulsa Enter. También puede escribirlo a mano.'),
              status, retry),
            lastScan),
          h('section', { class: 'panel', 'aria-labelledby': 'lines-title' },
            h('div', { class: 'row' }, h('h2', { id: 'lines-title' }, 'Prendas escaneadas'), h('span', { class: 'muted' }, session.reference)),
            h('p', { class: 'notice', style: 'margin:0' }, 'El inventario cambia al registrar la recepción aprobada.'),
            totals, linesBox,
            h('a', { class: 'primary', href: '#/recepcion/revisar', style: 'display:flex;align-items:center;justify-content:center;min-height:56px;border-radius:8px;text-decoration:none;font-weight:700' },
              ctx.isApprover ? 'Revisar y aprobar' : 'Revisar recepción'))));
      replace(root, layout);
      detach = attachScanField(scanInput, code => handle.handleScan(code));
      try {
        const state = await refresh(null);
        if (state.progress.status !== 'counting') { detach(); ctx.go('recepcion/revisar'); }
      } catch (error) {
        if (error.code === 'receiving.session_not_found') {
          current.set(null);
          ctx.notify('La recepción guardada en este equipo ya no existe en el servidor. Empiece otra.');
          await renderStart();
          return;
        }
        showError(status, error);
      }
    };

    if (current.get()) await renderScanning(); else await renderStart();
    handle.unmount = () => detach();
    return handle;
  },
};

async function registerProduct(line, sessionId) {
  const code = line.code;
  // Keep identifiers across retries, including a lost 204 response.
  const productId = api.uuid(), itemId = api.uuid();
  return openModal((body, close) => {
    const message = h('p', { class: 'error', role: 'alert' });
    const name = h('input', { id: 'reg-name', required: true, maxlength: 200 });
    const price = h('input', { id: 'reg-price', inputmode: 'decimal', autocomplete: 'off' });
    const cost = h('input', { id: 'reg-cost', inputmode: 'decimal', autocomplete: 'off' });
    const submit = h('button', { class: 'primary', type: 'submit' }, 'Registrar');
    body.append(h('form', { class: 'form', onsubmit: async event => {
      event.preventDefault();
      clearMessage(message);
      const unitPriceMinor = parseMoney(price.value), unitCostMinor = parseMoney(cost.value);
      if (!name.value.trim() || unitPriceMinor == null || unitPriceMinor <= 0 || unitCostMinor == null) {
        message.textContent = 'Escriba nombre, precio y costo válidos.'; return;
      }
      submit.disabled = true;
      try {
        await api.registerProduct(productId, name.value.trim());
        await api.registerItem({ itemId, productId, sku: code, variantName: name.value.trim(),
          currencyCode: 'NIO', unitPriceMinor, unitCostMinor, barcode: code });
        await api.resolveScan(sessionId, line.scanId, itemId, 'Código registrado en el piloto');
        close(true);
      } catch (error) { showError(message, error, 'Revise los datos y vuelva a intentar.'); }
      finally { submit.disabled = false; }
    } },
      h('h2', { id: 'modal-title' }, 'Registrar producto'), h('p', { class: 'num' }, `Código ${code}`),
      h('label', { for: 'reg-name' }, 'Nombre'), name,
      h('label', { for: 'reg-price' }, 'Precio (C$)'), price,
      h('label', { for: 'reg-cost' }, 'Costo aprobado (C$)'), cost,
      message, h('div', { class: 'actions' }, h('button', { type: 'button', onclick: () => close(false) }, 'Cancelar'), submit)));
  });
}

async function rejectReading(line, sessionId) {
  return openModal((body, close) => {
    const reason = h('input', { id: 'reject-reason', required: true, maxlength: 250 });
    const message = h('p', { role: 'alert' });
    const submit = h('button', { type: 'submit', class: 'primary' }, 'Rechazar lectura');
    body.append(h('form', { class: 'form', onsubmit: async event => {
      event.preventDefault();
      if (!reason.value.trim()) return;
      submit.disabled = true;
      try { await api.rejectScan(sessionId, line.scanId, reason.value.trim()); close(true); }
      catch (error) { showError(message, error); submit.disabled = false; }
    } }, h('h2', { id: 'modal-title' }, 'Rechazar lectura'), h('p', {}, line.code),
      h('label', { for: 'reject-reason' }, 'Motivo'), reason, message,
      h('div', { class: 'actions' }, h('button', { type: 'button', onclick: () => close(false) }, 'Cancelar'), submit)));
  });
}

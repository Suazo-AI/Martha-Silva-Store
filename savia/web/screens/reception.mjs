import { confirmAction } from '../confirm.mjs';
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
      const expectedQuantity=h('input',{id:'scan-quantity',type:'number',min:1,max:10000,step:1,value:1});
      const status = h('p', { class: 'error', role: 'alert' });
      const lastScan = h('section', { class: 'panel', 'aria-labelledby': 'last-title', 'aria-live': 'polite' });
      const linesBox = h('div', { class: 'lines', id: 'rec-lines' });
      const totals = h('p', { class: 'totals', id: 'rec-totals', 'aria-live': 'polite' });

      const retry = h('div', { class: 'actions' });
      const failed = [];   // scans the server did not confirm; retried with the same ScanId

      const draw = (state, lastCode) => {
        replace(linesBox, state.lines.map(line => lineView(line, ctx.isApprover ? {
          onRegister: ctx.roles.includes('OWNER') ? async line => { if (await registerProduct(line, session.sessionId)) await refresh(line.code); } : null,
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

      const sendScan = async ({ code, scanId, quantity=1 }) => {
        try {
          await api.recordScan(session.sessionId, { scanId, rawCode: code, quantity, deviceCode: 'WEB' });
          clearMessage(status);
          await refresh(code);
        } catch (error) {
          if (error.network || error.status >= 500) {
            failed.push({ code, scanId, quantity });
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

      handle.handleScan = code => {
        const quantity=Number(expectedQuantity.value);
        if(!Number.isInteger(quantity)||quantity<1||quantity>10000){status.textContent='Indique de 1 a 10,000 unidades esperadas.';return;}
        return queue.push({code,scanId:api.uuid(),quantity});
      };

      const layout = h('div', { class: 'page' },
        h('div', { class: 'split' },
          h('div', { style: 'display:grid;gap:14px;min-width:0' },
            h('section', { class: 'panel scan-field' },
              h('label', { for: 'scan-input' }, 'Escanear código'),
              scanInput,
              h('label',{for:'scan-quantity'},'Unidades esperadas por esta lectura'),expectedQuantity,
              h('small',{},'Use la cantidad de la entrega. En Calidad indique cuáles llegaron buenas, con defectos o faltantes.'),
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

const registrationAttempts=new Map();
async function registerProduct(line, sessionId) {
  const code=line.code;
  const draft=await openModal((body,close)=>{
    const name=h('input',{id:'reg-name',required:true,maxlength:200});
    const price=h('input',{id:'reg-price',inputmode:'decimal'}),cost=h('input',{id:'reg-cost',inputmode:'decimal'});
    const message=h('p',{role:'alert'});
    body.append(h('form',{class:'form',onsubmit:event=>{
      event.preventDefault();
      const unitPriceMinor=parseMoney(price.value),unitCostMinor=parseMoney(cost.value);
      if(!name.value.trim() || unitPriceMinor==null || unitPriceMinor<=0 || unitCostMinor==null){message.textContent='Revise nombre, precio y costo.';return;}
      close({name:name.value.trim(),unitPriceMinor,unitCostMinor});
    }},h('h2',{id:'modal-title'},'Registrar producto'),h('p',{},`Código ${code}`),h('label',{},'Nombre',name),h('label',{},'Precio (C$)',price),h('label',{},'Costo aprobado (C$)',cost),message,
      h('button',{type:'button',onclick:()=>close()},'Volver'),h('button',{type:'submit',class:'primary'},'Registrar')));
  });
  if(!draft || !await confirmAction(`Se registrará ${draft.name} con precio C$ ${(draft.unitPriceMinor/100).toFixed(2)} y costo C$ ${(draft.unitCostMinor/100).toFixed(2)} para aceptar la prenda en esta recepción.`)) return false;
  const key=JSON.stringify([sessionId,line.scanId,draft]);
  if(!registrationAttempts.has(key)) registrationAttempts.set(key,{productId:api.uuid(),itemId:api.uuid()});
  const {productId,itemId}=registrationAttempts.get(key);
  try {
    await api.registerProduct(productId,draft.name);
    await api.registerItem({itemId,productId,sku:code,variantName:draft.name,currencyCode:'NIO',unitPriceMinor:draft.unitPriceMinor,unitCostMinor:draft.unitCostMinor,barcode:code});
    await api.resolveScan(sessionId,line.scanId,itemId,'Código registrado en el piloto');registrationAttempts.delete(key);return true;
  }catch(error){await openModal((body,close)=>replace(body,h('h2',{id:'modal-title'},'No se pudo registrar'),h('p',{},error.message),h('button',{type:'button',onclick:()=>close()},'Volver')));return false;}
}

async function rejectReading(line,sessionId) {
  const reason=await openModal((body,close)=>{
    const field=h('input',{id:'reject-reason',required:true,maxlength:250});
    body.append(h('form',{class:'form',onsubmit:event=>{event.preventDefault();if(field.value.trim()) close(field.value.trim());}},h('h2',{id:'modal-title'},'Rechazar lectura'),h('p',{},line.code),h('label',{},'Motivo',field),
      h('button',{type:'button',onclick:()=>close()},'Volver'),h('button',{type:'submit',class:'primary'},'Rechazar lectura')));
  });
  if(!reason || !await confirmAction(`Se rechazará la lectura ${line.code} (${line.quantity} unidades). No entrará al inventario. Motivo: ${reason}`)) return false;
  await api.rejectScan(sessionId,line.scanId,reason);return true;
}

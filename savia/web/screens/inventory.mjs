// Inventario: stock of this branch as the server reports it, with search by SKU or name.
import * as api from '../api.mjs';
import { h, replace, showError, clearMessage } from '../ui.mjs';
import { attachScanField } from '../scan.mjs';
import { filterStock } from './inventory-logic.mjs';
import { formatMoney } from '../money.mjs';

const POOL = { store: 'Tienda', web: 'Web', reserved: 'Reservado', quarantine:'Cuarentena' };

export default {
  title: 'Inventario',
  async mount(root, ctx) {
    let rows = [];
    let values=[];
    const search = h('input', { id: 'inv-search', type: 'search', autocomplete: 'off', spellcheck: 'false', placeholder: 'Buscar por SKU o nombre' });
    const status = h('p', { class: 'error', role: 'alert' });
    const count = h('p', { class: 'muted', id: 'inv-count', 'aria-live': 'polite' });
    const body = h('tbody', { id: 'stock-body' });
    const refresh = h('button', { type: 'button', id: 'inv-refresh' }, 'Actualizar');

    const draw = () => {
      const shown = filterStock(rows, search.value);
      count.textContent = `${shown.length} de ${rows.length} filas del servidor`;
      replace(body, shown.length === 0
        ? h('tr', {}, h('td', { colspan: '5' }, rows.length === 0 ? 'El servidor no reporta existencias en esta sucursal. Registre una recepción para ingresar prendas.' : 'Sin resultados. Cambie el nombre o SKU de la búsqueda.'))
        : shown.map(r => h('tr', { dataset: { item: r.itemId } },
          h('td', {}, h('div', { class: 'stock-name' }, h('div', {},
            h('strong', {}, r.variantName), h('br'), h('small', {}, `SKU ${r.sku}`),
            ctx.isApprover ? h('p',{},values.find(v=>v.itemId===r.itemId)?.costMinor!=null ? `Costo ${formatMoney(values.find(v=>v.itemId===r.itemId).costMinor)}` : 'Costo sin aprobar') : null))),
          h('td', {}, POOL[r.pool] ?? r.pool),
          h('td', { class: 'n onhand' }, String(r.onHand)),
          h('td', { class: 'n' }, String(r.reserved)),
          h('td', { class: 'n available' }, r.available > 0 ? String(r.available) : h('span', { class: 'out' }, '0 · Agotado')))));
    };

    const load = async () => {
      clearMessage(status);
      refresh.disabled = true;
      try { rows = await api.stock(); if(ctx.isApprover) values=await api.itemValues(''); draw(); }
      catch (error) { showError(status, error, 'Pulse Actualizar para reintentar.'); }
      finally { refresh.disabled = false; }
    };
    refresh.addEventListener('click', load);
    search.addEventListener('input', draw);

    replace(root, h('div', { class: 'page' }, h('section', { class: 'panel' },
      h('div', { class: 'row' },
        h('label', { for: 'inv-search', class: 'sr' }, 'Buscar por SKU o nombre'),
        h('div', { style: 'flex:1;min-width:220px' }, search), refresh),
      status, count,
      h('div', { class: 'table-wrap' }, h('table', { id: 'stock' },
        h('caption', { class: 'sr' }, 'Existencias de la sucursal'),
        h('thead', {}, h('tr', {}, h('th', {}, 'Prenda'), h('th', {}, 'Ubicación'), h('th', { class: 'n' }, 'Físico'), h('th', { class: 'n' }, 'Reservado'), h('th', { class: 'n' }, 'Disponible'))),
        body)))));

    const handle = {
      handleScan: async code => {
        try {
          const found = await api.lookup(code);
          search.value = found[0]?.sku ?? code;
        } catch { search.value = code; }
        draw();
      },
    };
    const detach = attachScanField(search, code => handle.handleScan(code), { keepFocus: false });
    handle.unmount = detach;
    await load();
    return handle;
  },
};

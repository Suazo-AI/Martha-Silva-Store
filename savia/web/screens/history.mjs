import * as api from '../api.mjs';
import { h, replace, showError } from '../ui.mjs';
import { attachScanField, serialQueue } from '../scan.mjs';
import { formatMoney } from '../money.mjs';
import { garmentLine, saleDate, saleStatusName } from './sale-view.mjs';

export default {
  title: 'Historial',
  async mount(root, ctx) {
    let active = true;
    let revision = 0;
    let page = 1;
    const field = h('input', { id: 'history-search', type: 'search', placeholder: 'Buscar SKU, nombre o recibo', autocomplete: 'off' });
    const date = h('input', { id: 'history-date', type: 'date' });
    const status = h('p', { role: 'status' });
    const rows = h('div', { id: 'history-rows', class: 'lines' });
    const previous = h('button', { type: 'button', onclick: () => { page--; load(); } }, 'Página anterior');
    const next = h('button', { type: 'button', onclick: () => { page++; load(); } }, 'Página siguiente');
    const load = async () => {
      const current = ++revision;
      status.textContent = 'Buscando ventas…';
      replace(rows);
      try {
        const result = await api.searchSales({ q: field.value.trim(), date: date.value, page });
        const sales = await Promise.all(result.items.map(row => api.saleReceipt(row.saleId)));
        if (!active || current !== revision) return;
        status.textContent = `${sales.length} de ${result.total} ${result.total === 1 ? 'venta' : 'ventas'} · Página ${result.page}`;
        previous.disabled = page <= 1;
        next.disabled = page * result.pageSize >= result.total;
        replace(rows, sales.length ? sales.map(sale => h('article', { class: 'history-sale', dataset: { sale: sale.saleId } },
          h('div', { class: 'row' }, h('div', {}, h('h2', {}, sale.saleId), h('p', { class: 'muted' }, `${saleDate(sale.createdAt)} · ${saleStatusName(sale.status)}`)),
            h('strong', { class: 'num' }, formatMoney(sale.totalMinor))),
          ...sale.lines.map(garmentLine),
          h('div', { class: 'actions' },
            h('button', { type: 'button', class: 'primary', onclick: () => ctx.go(`recibo?sale=${encodeURIComponent(sale.saleId)}`) }, 'Ver recibo'),
            h('button', { type: 'button', onclick: () => ctx.go(`devolucion?sale=${encodeURIComponent(sale.saleId)}`) }, 'Devolver')))) :
          h('p', { class: 'muted' }, 'Sin coincidencias. Busque otro SKU, nombre o recibo.'));
      } catch (error) { if (active && current === revision) showError(status, error); }
    };
    const queue = serialQueue(async value => { field.value = value; page = 1; await load(); });
    const search = h('form', { class: 'row', onsubmit: event => { event.preventDefault(); page = 1; load(); } },
      h('label', {}, 'Buscar venta', field), h('label', {}, 'Fecha', date), h('button', { type: 'submit' }, 'Buscar ventas'));
    replace(root, h('div', { class: 'page' }, h('section', { class: 'panel' }, search, status, rows, h('div', { class: 'actions' }, previous, next))));
    const detach = attachScanField(field, code => queue.push(code));
    await load();
    return { handleScan: code => queue.push(code), unmount() { active = false; detach(); } };
  },
};

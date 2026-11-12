import * as api from '../api.mjs';
import { h, replace, showError } from '../ui.mjs';
import { formatMoney } from '../money.mjs';
import { businessDate, tenderName } from './sale-view.mjs';

const metric = (name, value, id) => h('div', { class: 'panel' }, h('span', {}, name), h('strong', { id }, value));
const amount = (value, currency) => value == null ? '—' : formatMoney(value, currency);

// All money figures come directly from SQL's day-report response, grouped by currency.
export function reportContent(report) {
  return [h('h2', {}, 'Reporte del día'), h('p', {}, report.date),
    h('div', { class: 'report-totals' }, metric('Ventas registradas', String(report.salesCount), 'report-sale-count'),
      metric('Unidades vendidas', String(report.unitsSold), 'report-unit-count'),
      ...report.totals.map(row => metric(`Venta bruta · ${row.currencyCode}`, formatMoney(row.totalMinor, row.currencyCode), `report-total-${row.currencyCode}`))),
    h('h3', {}, 'Cobros por método'),
    h('div', { class: 'table-wrap' }, h('table', {}, h('thead', {}, h('tr', {},
      ...['Método', 'Ventas', 'Total'].map(label => h('th', { scope: 'col' }, label)))),
    h('tbody', { id: 'report-tenders' }, report.tenders.map(row => h('tr', { dataset: { kind: row.tenderKind, currency: row.currencyCode } },
      h('td', {}, tenderName(row.tenderKind)), h('td', { class: 'n' }, row.saleCount), h('td', { class: 'n' }, formatMoney(row.totalMinor, row.currencyCode))))))),
    h('h3', {}, 'Devoluciones del día'),
    h('div', { id: 'report-returns', class: 'lines' }, report.returns.length ? report.returns.map(row => h('div', { class: 'row', dataset: { reversal: row.reversalId } },
      h('span', {}, `${row.saleId} · ${tenderName(row.settlementKind)} · ${row.unitsReturned} ${row.unitsReturned === 1 ? 'unidad' : 'unidades'}`), h('strong', {}, formatMoney(row.creditMinor, row.currencyCode)))) : h('p', {}, 'Sin devoluciones.')),
    h('h3', {}, 'Caja y cierre contable'),
    ...report.tills.map(till => h('section', { class: 'panel', dataset: { till: till.tillId } },
      h('h3', {}, `${till.registerName} · ${till.cashierName}`),
      h('p', {}, till.status === 'closed' ? 'Cerrada' : 'Abierta'),
      ...[['Efectivo esperado', 'expectedMinor'], ['Efectivo contado', 'countedMinor'], ['Diferencia', 'differenceMinor'],
        ['Venta bruta al cierre', 'saleGrossMinor'], ['Devuelto al cierre', 'returnGrossMinor'], ['Venta neta al cierre', 'netSalesMinor']].map(([label, key]) =>
        h('div', { class: 'row' }, label, h('strong', { dataset: { field: key } }, amount(till[key], till.currencyCode)))),
      till.documentNumber ? h('p', {}, `Documento ${till.documentNumber}`) : null)),
  ];
}

export default {
  title: 'Reporte del día',
  async mount(root, ctx) {
    const date = h('input', { id: 'report-date', type: 'date', value: businessDate() });
    const status = h('p', { role: 'alert' });
    const paper = h('section', { class: 'panel report-paper', id: 'day-report' });
    let revision = 0;
    const load = async () => {
      const current = ++revision;
      try {
        const report = await api.dayReport(date.value);
        if (current !== revision) return;
        replace(paper, ...reportContent(report));
        status.textContent = '';
      } catch (error) { if (current === revision) showError(status, error); }
    };
    replace(root, h('div', { class: 'page' },
      h('form', { class: 'row no-print', onsubmit: e => { e.preventDefault(); load(); } }, h('label', {}, 'Fecha del reporte', date),
        h('div', { class: 'actions' }, h('button', { type: 'submit' }, 'Consultar reporte'),
          h('button', { type: 'button', id: 'print-report', onclick: () => window.print() }, 'Imprimir reporte'))), status, paper));
    await load();
    return { handleScan: () => ctx.notify('El reporte muestra los totales del servidor.'), unmount() { revision++; } };
  },
};

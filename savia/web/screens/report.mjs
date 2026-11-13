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
  title: 'Reportes',
  async mount(root, ctx) {
    const period = h('select', { id:'report-period', onchange:() => load() }, [['day','Día'],['week','Semana'],['month','Mes'],['year','Año']].map(([value,label])=>h('option',{value},label)));
    const date = h('input', { id: 'report-date', type: 'date', value: businessDate() });
    const status = h('p', { role: 'alert' });
    const paper = h('section', { class: 'panel report-paper', id: 'day-report' });
    let revision = 0;
    const load = async () => {
      const current = ++revision;
      try {
        const summary = await api.summaryReport(period.value, date.value);
        const report = period.value === 'day' ? await api.dayReport(date.value) : null;
        if (current !== revision) return;
        replace(paper, ...summaryContent(summary), ...(report ? reportContent(report) : []));
        status.textContent = '';
      } catch (error) { if (current === revision) showError(status, error); }
    };
    replace(root, h('div', { class: 'page' },
      h('form', { class: 'row no-print', onsubmit: e => { e.preventDefault(); load(); } }, h('label', {}, 'Período', period), h('label', {}, 'Fecha del reporte', date),
        h('div', { class: 'actions' }, h('button', { type: 'submit' }, 'Consultar reporte'),
          h('button', { type:'button', id:'export-report', onclick:async () => { try { await api.exportSummary(period.value,date.value); } catch(error) { showError(status,error); } } }, 'Exportar CSV'),
          h('button', { type: 'button', id: 'print-report', onclick: () => window.print() }, 'Imprimir reporte'))), status, paper));
    await load();
    return { handleScan: () => ctx.notify('El reporte muestra los totales del servidor.'), unmount() { revision++; } };
  },
};

export function summaryContent(report) {
  const moneyKeys = new Set(['grossMinor','discountsMinor','netMinor','returnsMinor','averageTicketMinor']);
  const labels = [['salesCount','Ventas'],['unitsSold','Prendas vendidas'],['grossMinor','Venta bruta'],
    ['discountsMinor','Descuentos'],['netMinor','Venta neta después de devoluciones'],['returnsMinor','Devoluciones'],
    ['averageTicketMinor','Ticket promedio'],['customersServed','Clientes atendidos'],['newCustomers','Clientes nuevos'],['stockExceptionsCount','Excepciones de inventario']];
  const table = (title, rows, columns) => h('section', {}, h('h3',{},title),
    rows.length ? h('div',{class:'table-wrap'},h('table',{},h('thead',{},h('tr',{},columns.map(([key,label])=>h('th',{},label)))),
      h('tbody',{},rows.map(row=>h('tr',{},columns.map(([key])=>h('td',{},key.endsWith('Minor') ? formatMoney(row[key]) : key==='tenderKind' ? tenderName(row[key]) : row[key]))))))) : h('p',{},'Sin movimientos en este período.'));
  return [h('h2',{},`Reportes · ${report.startDate} al ${report.endDate}`),
    h('div',{class:'report-totals',id:'summary-totals',dataset:{period:report.period}},labels.map(([key,label])=>metric(label,
      moneyKeys.has(key) ? formatMoney(report[key]) : String(report[key]),`summary-${key}`))),
    table('Cobros por método',report.tenders,[['tenderKind','Método'],['saleCount','Ventas'],['totalMinor','Total']]),
    table('Ventas por día',report.salesByDay,[['date','Día'],['salesCount','Ventas'],['totalMinor','Total']]),
    table('Ventas por cajera',report.cashiers,[['name','Cajera'],['salesCount','Ventas'],['totalMinor','Total']]),
    table('Prendas más vendidas',report.topItems,[['sku','SKU'],['name','Prenda'],['unitsSold','Unidades'],['totalMinor','Total']])];
}

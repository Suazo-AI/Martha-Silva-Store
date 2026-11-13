import * as api from '../api.mjs';
import { formatMoney } from '../money.mjs';
import { h, replace, showError } from '../ui.mjs';
import { formatBps, formatX100, kpiTabs, refundKindName } from './report-logic.mjs';
import { businessDate, tenderName } from './sale-view.mjs';

const metric = (name, value, id) => h('div', { class: 'panel' }, h('span', {}, name), h('strong', { id }, value));
const amount = (value, currency) => (value == null ? '—' : formatMoney(value, currency));
const table = (title, rows, columns, id, key) =>
  h(
    'section',
    {},
    h('h3', {}, title),
    rows.length
      ? h(
          'div',
          { class: 'table-wrap' },
          h(
            'table',
            { id },
            h(
              'thead',
              {},
              h(
                'tr',
                {},
                columns.map(([, label]) => h('th', { scope: 'col' }, label)),
              ),
            ),
            h(
              'tbody',
              {},
              rows.map(row =>
                h(
                  'tr',
                  { dataset: key ? { [key]: row[key === 'seller' ? 'sellerId' : key === 'staff' ? 'staffId' : key] } : {} },
                  columns.map(([field, , format]) =>
                    h('td', { dataset: { field } }, format ? format(row[field], row) : String(row[field] ?? '—')),
                  ),
                ),
              ),
            ),
          ),
        )
      : h('p', {}, 'Sin movimientos en este período.'),
  );
const money = value => amount(value);

// All money figures come directly from SQL's day-report response, grouped by currency.
export function reportContent(report) {
  return [
    h('h2', {}, 'Reporte del día'),
    h('p', {}, report.date),
    h(
      'div',
      { class: 'report-totals' },
      metric('Ventas registradas', String(report.salesCount), 'report-sale-count'),
      metric('Unidades vendidas', String(report.unitsSold), 'report-unit-count'),
      ...report.totals.map(row =>
        metric(`Venta bruta · ${row.currencyCode}`, formatMoney(row.totalMinor, row.currencyCode), `report-total-${row.currencyCode}`),
      ),
    ),
    h('h3', {}, 'Cobros por método'),
    h(
      'div',
      { class: 'table-wrap' },
      h(
        'table',
        {},
        h('thead', {}, h('tr', {}, ...['Método', 'Ventas', 'Total'].map(label => h('th', { scope: 'col' }, label)))),
        h(
          'tbody',
          { id: 'report-tenders' },
          report.tenders.map(row =>
            h(
              'tr',
              { dataset: { kind: row.tenderKind, currency: row.currencyCode } },
              h('td', {}, tenderName(row.tenderKind)),
              h('td', { class: 'n' }, row.saleCount),
              h('td', { class: 'n' }, formatMoney(row.totalMinor, row.currencyCode)),
            ),
          ),
        ),
      ),
    ),
    h('h3', {}, 'Devoluciones del día'),
    h(
      'div',
      { id: 'report-returns', class: 'lines' },
      report.returns.length
        ? report.returns.map(row =>
            h(
              'div',
              { class: 'row', dataset: { reversal: row.reversalId } },
              h(
                'span',
                {},
                `${row.saleId} · ${refundKindName(row.settlementKind)} · ${row.unitsReturned} ${row.unitsReturned === 1 ? 'unidad' : 'unidades'}`,
              ),
              h('strong', {}, formatMoney(row.creditMinor, row.currencyCode)),
            ),
          )
        : h('p', {}, 'Sin devoluciones.'),
    ),
    table(
      'Devoluciones por tipo',
      report.refundsByKind ?? [],
      [
        ['kind', 'Tipo', refundKindName],
        ['returnsCount', 'Devoluciones'],
        ['amountMinor', 'Importe', money],
        ['cashOutMinor', 'Salió de caja', money],
      ],
      'report-refunds-by-kind',
    ),
    h('h3', {}, 'Caja y cierre contable'),
    ...report.tills.map(till =>
      h(
        'section',
        { class: 'panel', dataset: { till: till.tillId } },
        h('h3', {}, `${till.registerName} · ${till.cashierName}`),
        h('p', {}, till.status === 'closed' ? 'Cerrada' : 'Abierta'),
        ...[
          ['Efectivo esperado', 'expectedMinor'],
          ['Efectivo contado', 'countedMinor'],
          ['Diferencia', 'differenceMinor'],
          ['Venta bruta al cierre', 'saleGrossMinor'],
          ['Devuelto al cierre', 'returnGrossMinor'],
          ['Venta neta al cierre', 'netSalesMinor'],
        ].map(([label, key]) =>
          h('div', { class: 'row' }, label, h('strong', { dataset: { field: key } }, amount(till[key], till.currencyCode))),
        ),
        ...(report.refundsByKind ?? [])
          .filter(row => row.tillId === till.tillId)
          .map(row =>
            h(
              'div',
              { class: 'row', dataset: { refund: row.kind } },
              `Devoluciones: ${refundKindName(row.kind).toLowerCase()}`,
              h('strong', {}, formatMoney(row.amountMinor)),
            ),
          ),
        till.documentNumber ? h('p', {}, `Documento ${till.documentNumber}`) : null,
      ),
    ),
  ];
}

/** "Negocio": SQL-computed KPIs for the period. */
export function businessContent(kpi) {
  const cards = [
    ['netSalesMinor', 'Venta neta', money],
    ['salesCount', 'Ventas', String],
    ['averageTicketMinor', 'Ticket promedio', money],
    ['unitsPerTicketX100', 'Prendas por ticket', formatX100],
    ['grossMarginMinor', 'Margen bruto', money],
    ['grossMarginBps', 'Margen bruto %', formatBps],
    ['discountsBps', 'Descuentos %', formatBps],
    ['returnsBps', 'Devoluciones %', formatBps],
    ['stockValueAtCostMinor', 'Inventario al costo', money],
    ['daysOfInventory', 'Días de inventario', v => (v == null ? '—' : String(v))],
    ['stockExceptionsCount', 'Excepciones de inventario', String],
    ['qualityRejects', 'Rechazos de calidad', String],
    ['tillClosuresWithDifference', 'Cierres con diferencia', String],
    ['tillDifferenceMinor', 'Diferencia de caja', money],
  ];
  return [
    h('h2', {}, `Negocio · ${kpi.startDate} al ${kpi.endDate}`),
    h(
      'div',
      { class: 'report-totals', id: 'kpi-business', dataset: { period: kpi.period } },
      cards.map(([key, label, format]) => metric(label, format(kpi[key]), `kpi-${key}`)),
    ),
    table(
      'Devoluciones por tipo',
      kpi.refundsByKind,
      [
        ['kind', 'Tipo', refundKindName],
        ['returnsCount', 'Devoluciones'],
        ['amountMinor', 'Importe', money],
      ],
      'kpi-refunds',
      'kind',
    ),
    table(
      'Ventas por hora',
      kpi.salesByHour,
      [
        ['hour', 'Hora', v => `${String(v).padStart(2, '0')}:00`],
        ['salesCount', 'Ventas'],
        ['totalMinor', 'Total', money],
      ],
      'kpi-hours',
    ),
    table(
      'Rotación por producto',
      kpi.sellThrough,
      [
        ['name', 'Producto'],
        ['unitsReceived', 'Recibidas'],
        ['unitsSold', 'Vendidas'],
        ['sellThroughBps', 'Vendido %', formatBps],
      ],
      'kpi-sell-through',
    ),
    table(
      'Sin movimiento en 60 días o más',
      kpi.staleItems,
      [
        ['sku', 'SKU'],
        ['name', 'Prenda'],
        ['onHand', 'Existencias'],
        ['lastMovementAt', 'Último movimiento', v => (v ? v.slice(0, 10) : '—')],
      ],
      'kpi-stale',
    ),
  ];
}

/** "Equipo": a seller only receives her own row from SQL. */
export function teamContent(team) {
  return [
    h('h2', {}, `Equipo · ${team.startDate} al ${team.endDate}`),
    table(
      'Vendedores',
      team.sellers,
      [
        ['name', 'Vendedor'],
        ['netSalesMinor', 'Venta neta', money],
        ['units', 'Prendas'],
        ['tickets', 'Tickets'],
        ['averageTicketMinor', 'Ticket promedio', money],
        ['unitsPerTicketX100', 'Prendas por ticket', formatX100],
        ['returnsBps', 'Devoluciones %', formatBps],
        ['discountsMinor', 'Descuentos', money],
        ['commissionPayableMinor', 'Comisión', money],
      ],
      'kpi-sellers',
      'seller',
    ),
    team.managers.length
      ? table(
          'Gerencia',
          team.managers,
          [
            ['name', 'Nombre'],
            ['tillClosures', 'Cierres'],
            ['tillDifferenceMinor', 'Diferencia de caja', money],
            ['approvalsCount', 'Aprobaciones'],
            ['approvalsMinor', 'Monto aprobado', money],
          ],
          'kpi-managers',
          'staff',
        )
      : null,
    team.stockWorkers.length
      ? table(
          'Bodega',
          team.stockWorkers,
          [
            ['name', 'Nombre'],
            ['garmentsReceived', 'Prendas recibidas'],
            ['qualityRejects', 'Rechazos'],
            ['receptionMinutesAverage', 'Minutos por recepción', v => (v == null ? '—' : String(v))],
          ],
          'kpi-stock',
          'staff',
        )
      : null,
  ];
}

export default {
  title: 'Reportes',
  async mount(root, ctx) {
    const tabs = kpiTabs(ctx.roles ?? []);
    let tab = tabs[0][0];
    const period = h(
      'select',
      { id: 'report-period', onchange: () => load() },
      [
        ['day', 'Día'],
        ['week', 'Semana'],
        ['month', 'Mes'],
        ['year', 'Año'],
      ].map(([value, label]) => h('option', { value }, label)),
    );
    const date = h('input', { id: 'report-date', type: 'date', value: businessDate() });
    const status = h('p', { role: 'alert' });
    const paper = h('section', { class: 'panel report-paper', id: 'day-report', role: 'tabpanel' });
    const tabBar = h('div', { class: 'tabs no-print', role: 'tablist' });
    const drawTabs = () =>
      replace(
        tabBar,
        tabs.map(([value, label]) =>
          h(
            'button',
            {
              type: 'button',
              role: 'tab',
              id: `tab-${value}`,
              'aria-selected': String(tab === value),
              onclick: () => {
                tab = value;
                drawTabs();
                load();
              },
            },
            label,
          ),
        ),
      );
    const exportSummary = h(
      'button',
      {
        type: 'button',
        id: 'export-report',
        onclick: async () => {
          try {
            await api.exportSummary(period.value, date.value);
          } catch (error) {
            showError(status, error);
          }
        },
      },
      'Exportar reporte',
    );
    let revision = 0;
    const load = async () => {
      const current = ++revision;
      exportSummary.hidden = tab !== 'negocio';
      try {
        if (tab === 'equipo') {
          const team = await api.kpiTeam(period.value, date.value);
          if (current !== revision) return;
          replace(paper, ...teamContent(team));
        } else {
          const [kpi, summary, report] = await Promise.all([
            api.kpiBusiness(period.value, date.value),
            api.summaryReport(period.value, date.value),
            period.value === 'day' ? api.dayReport(date.value) : null,
          ]);
          if (current !== revision) return;
          replace(paper, ...businessContent(kpi), ...summaryContent(summary), ...(report ? reportContent(report) : []));
        }
        status.textContent = '';
      } catch (error) {
        if (current === revision) showError(status, error);
      }
    };
    drawTabs();
    replace(
      root,
      h(
        'div',
        { class: 'page' },
        tabBar,
        h(
          'form',
          {
            class: 'row no-print',
            onsubmit: e => {
              e.preventDefault();
              load();
            },
          },
          h('label', {}, 'Período', period),
          h('label', {}, 'Fecha del reporte', date),
          h(
            'div',
            { class: 'actions' },
            h('button', { type: 'submit' }, 'Consultar reporte'),
            h(
              'button',
              {
                type: 'button',
                id: 'export-kpi',
                onclick: async () => {
                  try {
                    await (tab === 'equipo' ? api.exportKpiTeam : api.exportKpiBusiness)(period.value, date.value);
                  } catch (error) {
                    showError(status, error);
                  }
                },
              },
              'Exportar CSV',
            ),
            exportSummary,
            h('button', { type: 'button', id: 'print-report', onclick: () => window.print() }, 'Imprimir reporte'),
          ),
        ),
        status,
        paper,
      ),
    );
    await load();
    return {
      handleScan: () => ctx.notify('El reporte muestra los totales del servidor.'),
      unmount() {
        revision++;
      },
    };
  },
};

export function summaryContent(report) {
  const moneyKeys = new Set([
    'grossMinor',
    'discountsMinor',
    'netMinor',
    'returnsMinor',
    'averageTicketMinor',
    'grossMarginMinor',
    'costOfGoodsMinor',
  ]);
  const labels = [
    ['salesCount', 'Ventas'],
    ['unitsSold', 'Prendas vendidas'],
    ['grossMinor', 'Venta bruta'],
    ['discountsMinor', 'Descuentos'],
    ['netMinor', 'Venta neta después de devoluciones'],
    ['returnsMinor', 'Devoluciones'],
    ['grossMarginMinor', 'Margen bruto'],
    ['costOfGoodsMinor', 'Costo de lo vendido'],
    ['averageTicketMinor', 'Ticket promedio'],
    ['stockExceptionsCount', 'Excepciones de inventario'],
  ];
  const summaryTable = (title, rows, columns) =>
    h(
      'section',
      {},
      h('h3', {}, title),
      rows.length
        ? h(
            'div',
            { class: 'table-wrap' },
            h(
              'table',
              {},
              h(
                'thead',
                {},
                h(
                  'tr',
                  {},
                  columns.map(([key, label]) => h('th', {}, label)),
                ),
              ),
              h(
                'tbody',
                {},
                rows.map(row =>
                  h(
                    'tr',
                    {},
                    columns.map(([key]) =>
                      h('td', {}, key.endsWith('Minor') ? formatMoney(row[key]) : key === 'tenderKind' ? tenderName(row[key]) : row[key]),
                    ),
                  ),
                ),
              ),
            ),
          )
        : h('p', {}, 'Sin movimientos en este período.'),
    );
  return [
    h('h2', {}, `Reportes · ${report.startDate} al ${report.endDate}`),
    h(
      'div',
      { class: 'report-totals', id: 'summary-totals', dataset: { period: report.period } },
      labels.map(([key, label]) => metric(label, moneyKeys.has(key) ? formatMoney(report[key]) : String(report[key]), `summary-${key}`)),
    ),
    summaryTable('Cobros por método', report.tenders, [
      ['tenderKind', 'Método'],
      ['saleCount', 'Ventas'],
      ['totalMinor', 'Total'],
    ]),
    summaryTable('Ventas por día', report.salesByDay, [
      ['date', 'Día'],
      ['salesCount', 'Ventas'],
      ['totalMinor', 'Total'],
    ]),
    summaryTable('Ventas por quien cobró', report.cashiers, [
      ['name', 'Cobró'],
      ['salesCount', 'Ventas'],
      ['totalMinor', 'Total'],
    ]),
    summaryTable('Prendas más vendidas', report.topItems, [
      ['sku', 'SKU'],
      ['name', 'Prenda'],
      ['unitsSold', 'Unidades'],
      ['totalMinor', 'Total'],
    ]),
  ];
}

// Shared receipt/history garment rows, following the recorded names, quantities and amounts.
import { h } from '../ui.mjs';
import { formatMoney } from '../money.mjs';

export const tenderName = kind => ({ cash: 'Efectivo', card: 'Tarjeta', transfer: 'Transferencia', credit: 'Anticipo / crédito', other: 'Otro' }[kind] ?? kind);
export const saleStatusName = status => ({ posted: 'Confirmada', paid: 'Pagada', returned: 'Devuelta', partially_returned: 'Devolución parcial', voided: 'Anulada' }[status] ?? 'Registrada');
export const saleDate = value => value ? new Intl.DateTimeFormat('es-NI', { timeZone: 'America/Managua', dateStyle: 'medium', timeStyle: 'short' }).format(new Date(/(?:Z|[+-]\d\d:\d\d)$/.test(value) ? value : value + 'Z')) : '';
export function businessDate(value = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Managua', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(value);
  const get = kind => parts.find(part => part.type === kind).value;
  return `${get('year')}-${get('month')}-${get('day')}`;
}

export function receiptCashTotals(tenders) {
  return tenders.filter(t => t.tenderKind === 'cash').reduce((sum, tender) => ({
    receivedMinor: sum.receivedMinor + (tender.receivedMinor ?? 0),
    changeMinor: sum.changeMinor + (tender.changeMinor ?? 0),
  }), { receivedMinor: 0, changeMinor: 0 });
}

export function garmentLine(line) {
  return h('div', { class: 'sale-item', dataset: { line: line.lineNumber } }, h('div', {}, h('strong', {}, line.name),
      h('p', { class: 'muted' }, `SKU ${line.sku} · Talla ${line.sizeCode ?? '—'}`),
      h('p', {}, `${line.quantity} × ${formatMoney(line.unitPriceMinor)}`),
      line.returnedQuantity ? h('small', {}, `Devueltas: ${line.returnedQuantity}`) : null),
    h('strong', { class: 'num' }, formatMoney(line.totalMinor)));
}

export function receiptContent(sale) {
  const cash = receiptCashTotals(sale.tenders);
  return [
    h('h2', {}, `Recibo ${sale.receiptNumber ?? sale.saleId}`),
    h('p', { class: 'tag' }, saleStatusName(sale.status)),
    h('p', { class: 'muted' }, `${sale.branchName ?? ''} · ${saleDate(sale.createdAt)}`),
    ...sale.lines.map(garmentLine),
    h('div', { class: 'row' }, 'Subtotal', h('strong', {}, formatMoney(sale.subtotalMinor))),
    h('div', { class: 'row' }, 'Descuento', h('strong', {}, formatMoney(sale.discountMinor))),
    h('div', { class: 'total' }, 'Total', h('strong', { id: 'receipt-total' }, formatMoney(sale.totalMinor))),
    ...sale.tenders.map(tender => h('div', { class: 'row' }, tenderName(tender.tenderKind),
      h('strong', {}, formatMoney(tender.amountMinor)), tender.reference ? h('small', {}, `Referencia ${tender.reference}`) : null)),
    sale.tenders.some(t => t.tenderKind === 'cash') ? h('div', { class: 'row' }, 'Efectivo recibido',
      h('strong', { id: 'receipt-received' }, formatMoney(cash.receivedMinor))) : null,
    h('div', { class: 'row' }, 'Cambio', h('strong', { id: 'receipt-change' }, formatMoney(cash.changeMinor))),
    h('p', { class: 'muted' }, `Venta ${sale.saleId}`),
  ];
}

// Pure ticket logic for Venta. Integer minor units only.
import { lineTotal } from '../money.mjs';

export function addToTicket(lines, item, quantity = 1) {
  const index = lines.findIndex(l => l.itemId === item.itemId && l.sellerId === item.sellerId);
  if (index === -1) return [...lines, { ...item, ...(item.sellerId ? {ticketKey:crypto.randomUUID()} : {}), quantity }];
  return lines.map((l, i) => i === index ? { ...l, quantity: l.quantity + quantity } : l);
}

/** Sets a quantity typed by the person. Below 1 or not a whole number leaves the line unchanged. */
export function setQuantity(lines, itemId, value) {
  const quantity = Number(value);
  if (!Number.isInteger(quantity) || quantity < 1 || quantity > 9999) return lines;
  return lines.map(l => (l.ticketKey ?? l.itemId) === itemId ? { ...l, quantity } : l);
}

export const removeLine = (lines, itemId) => lines.filter(l => (l.ticketKey ?? l.itemId) !== itemId);

export const ticketTotal = lines => lines.reduce((sum, l) => sum + lineTotal(l.unitPriceMinor, l.quantity) - (l.discountMinor ?? 0), 0);

/** Body of POST /sales. Tenders are prepared from pending input, never stored balances. */
export function saleRequest({ saleId, tillId, lines, receivedMinor, tenders, customerId }) {
  const total = ticketTotal(lines);
  return {
    saleId, tillId, currencyCode: 'NIO', ...(customerId ? { customerId } : {}),
    lines: lines.map((l, i) => ({ lineNumber: i + 1, itemId: l.itemId, quantity: l.quantity, unitPriceMinor: l.unitPriceMinor, discountMinor: l.discountMinor ?? 0, ...(l.sellerId ? {sellerId:l.sellerId} : {}) })),
    tenders: tenders ?? [{ tenderNumber: 1, tenderKind: 'cash', amountMinor: total, receivedMinor, changeMinor: receivedMinor - total }],
  };
}

/** ItemLookup (or a search row) -> ticket item. */
export function itemFromLookup(row) {
  return {
    itemId: row.itemId,
    name: row.productName && row.variantName && row.variantName !== row.productName ? `${row.productName} · ${row.variantName}` : (row.variantName ?? row.productName),
    size: row.sizeCode ?? null,
    sku: row.sku,
    unitPriceMinor: row.unitPriceMinor,
    currencyCode: row.currencyCode ?? 'NIO',
    isSample: row.isSample ?? null,
  };
}

/** Pending-input preview. SQL validates the combined discount and records final totals. */
export function discountedLines(lines, ticketPercent = 0) {
  return lines.map(line => {
    const percent = Number(line.discountPercent ?? 0) + Number(ticketPercent);
    if (!Number.isFinite(percent) || percent < 0 || percent > 100) throw new Error('El descuento combinado debe estar entre 0 y 100 %.');
    return { ...line, discountMinor: line.discountAmountMinor ?? Math.floor(line.unitPriceMinor * line.quantity * percent / 100) };
  });
}
export const MAX_SELLERS = 3;
/** Lines whose seller left the ticket go to the first ticket seller; a replaced seller hands her lines to the new one. */
export function alignSellers(lines, ticketSellers, replaced = null) {
  return lines.map(line => {
    const sellerId = replaced && line.sellerId === replaced.from ? replaced.to : line.sellerId;
    return { ...line, sellerId: ticketSellers.includes(sellerId) ? sellerId : ticketSellers[0] };
  });
}
/** Sellers still free for another "Venta compartida" slot. */
export const freeSellers = (sellers, ticketSellers, current = null) => sellers.filter(s => s.sellerId === current || !ticketSellers.includes(s.sellerId));
export const needsDiscountApproval = lines => lines.some(l => (l.discountMinor ?? 0) > 0);
export const catalogMatches = (product, { type = '', size = '', query = '' } = {}) =>
  (!type || product.type === type) && product.variants.some(v => (!size || v.sizeCode === size) &&
    (!query || [product.name, v.sku, v.variantName].join(' ').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().includes(query.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase())));

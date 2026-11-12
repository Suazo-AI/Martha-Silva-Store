// Pure ticket logic for Venta. Integer minor units only.
import { lineTotal } from '../money.mjs';

export function addToTicket(lines, item, quantity = 1) {
  const index = lines.findIndex(l => l.itemId === item.itemId);
  if (index === -1) return [...lines, { ...item, quantity }];
  return lines.map((l, i) => i === index ? { ...l, quantity: l.quantity + quantity } : l);
}

/** Sets a quantity typed by the person. Below 1 or not a whole number leaves the line unchanged. */
export function setQuantity(lines, itemId, value) {
  const quantity = Number(value);
  if (!Number.isInteger(quantity) || quantity < 1 || quantity > 9999) return lines;
  return lines.map(l => l.itemId === itemId ? { ...l, quantity } : l);
}

export const removeLine = (lines, itemId) => lines.filter(l => l.itemId !== itemId);

export const ticketTotal = lines => lines.reduce((sum, l) => sum + lineTotal(l.unitPriceMinor, l.quantity), 0);

/** Body of POST /sales for a cash sale. */
export function saleRequest({ saleId, tillId, lines, receivedMinor }) {
  const total = ticketTotal(lines);
  return {
    saleId, tillId, currencyCode: 'NIO',
    lines: lines.map((l, i) => ({ lineNumber: i + 1, itemId: l.itemId, quantity: l.quantity, unitPriceMinor: l.unitPriceMinor, discountMinor: 0 })),
    tenders: [{ tenderNumber: 1, tenderKind: 'cash', amountMinor: total, receivedMinor, changeMinor: receivedMinor - total }],
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

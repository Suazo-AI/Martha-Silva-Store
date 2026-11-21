import assert from 'node:assert/strict';
import test from 'node:test';
import { addToTicket, itemFromLookup, saleRequest, ticketTotal } from '../screens/sale-logic.mjs';

test('two sellers of the same garment keep separate sale lines and attribution', () => {
  let lines = addToTicket([], { itemId: 'item', sellerId: 'seller1', unitPriceMinor: 59900 });
  lines = addToTicket(lines, { itemId: 'item', sellerId: 'seller2', unitPriceMinor: 59900 });
  lines = addToTicket(lines, { itemId: 'item', sellerId: 'seller1', unitPriceMinor: 59900 });
  assert.equal(lines.length, 2);
  assert.deepEqual(
    lines.map(l => l.quantity),
    [2, 1],
  );
  assert.deepEqual(
    saleRequest({ saleId: 's', tillId: 't', lines, receivedMinor: 179700 }).lines.map(l => l.sellerId),
    ['seller1', 'seller2'],
  );
});
test('line discounts reach SQL and lower the tender total', () => {
  const lines = [{ itemId: 'item', quantity: 2, unitPriceMinor: 59900, discountMinor: 11980 }];
  assert.equal(ticketTotal(lines), 107820);
  assert.equal(saleRequest({ saleId: 's', tillId: 't', lines, receivedMinor: 107820 }).lines[0].discountMinor, 11980);
});

import { catalogMatches, discountedLines, needsDiscountApproval } from '../screens/sale-logic.mjs';

test('tax rounds once per full line after discounts, with zero-tax and exempted totals preserved', () => {
  const taxed = itemFromLookup({ itemId: 'taxed', unitPriceMinor: 1, taxRateBps: 5000 });
  const lines = addToTicket([], taxed, 3);
  assert.equal(ticketTotal(lines), 5);
  assert.equal(ticketTotal(discountedLines(lines, 34)), 3);
  assert.equal(ticketTotal(discountedLines(lines, 100)), 0);
  assert.equal(ticketTotal([{ ...lines[0], taxRateBps: 0 }]), 3);
  assert.equal(ticketTotal([{ itemId: 'old', unitPriceMinor: 1, quantity: 3 }]), 3);
  assert.equal(ticketTotal([lines[0], { ...lines[0], quantity: 1 }]), 7);
  const request = saleRequest({ saleId: 's', tillId: 't', lines, receivedMinor: 10 });
  assert.deepEqual(request.tenders, [{ tenderNumber: 1, tenderKind: 'cash', amountMinor: 5, receivedMinor: 10, changeMinor: 5 }]);
  assert.deepEqual(request.lines, [{ lineNumber: 1, itemId: 'taxed', quantity: 3, unitPriceMinor: 1, discountMinor: 0 }]);
});

test('ticket and line percentages combine without bypassing manager approval', () => {
  const base = [{ itemId: 'a', quantity: 2, unitPriceMinor: 59900, discountPercent: 5 }];
  const ten = discountedLines(base, 5);
  assert.equal(ten[0].discountMinor, 11980);
  assert.equal(needsDiscountApproval(ten), true);
  assert.equal(needsDiscountApproval(discountedLines(base, 15)), true);
  assert.throws(() => discountedLines(base, 96));
  assert.throws(() => discountedLines(base, NaN));
});
test('catalog filters intersect type, size, name and SKU without accents', () => {
  const p = { name: 'Blusa de lino', type: 'Blusas', variants: [{ sku: 'MAS-BLU-LIN-BLA-S', sizeCode: 'S', variantName: 'Blusa blanca' }] };
  assert.equal(catalogMatches(p, { type: 'Blusas', size: 'S', query: 'blusa' }), true);
  assert.equal(catalogMatches(p, { type: 'Vestidos' }), false);
  assert.equal(catalogMatches(p, { size: 'M' }), false);
  assert.equal(catalogMatches(p, { query: 'MAS-BLU' }), true);
});

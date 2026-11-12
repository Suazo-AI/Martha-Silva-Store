import test from 'node:test';
import assert from 'node:assert/strict';
import { addToTicket, setQuantity, removeLine, ticketTotal, saleRequest, itemFromLookup } from '../screens/sale-logic.mjs';
import { linesFromServer, totalsText } from '../screens/reception-logic.mjs';
import { differenceView } from '../screens/cash-logic.mjs';
import { filterStock } from '../screens/inventory-logic.mjs';
import { toError, request, ApiError } from '../api.mjs';

const lookupRow = { itemId: 'i1', sku: 'T-SKU-0001', variantName: 'Blusa Negra M', unitPriceMinor: 120000, currencyCode: 'NIO', status: 'active', productName: 'Blusa Test', sizeCode: 'M' };

test('ticket: same item twice is one line with quantity 2; total and change in minor units', () => {
  let lines = addToTicket([], itemFromLookup(lookupRow));
  lines = addToTicket(lines, itemFromLookup(lookupRow));
  assert.equal(lines.length, 1);
  assert.equal(lines[0].quantity, 2);
  assert.equal(ticketTotal(lines), 240000);
  const body = saleRequest({ saleId: 's', tillId: 't', lines, receivedMinor: 300000 });
  assert.deepEqual(body.lines, [{ lineNumber: 1, itemId: 'i1', quantity: 2, unitPriceMinor: 120000, discountMinor: 0 }]);
  assert.deepEqual(body.tenders, [{ tenderNumber: 1, tenderKind: 'cash', amountMinor: 240000, receivedMinor: 300000, changeMinor: 60000 }]);
});

test('ticket: editable quantity rejects 0, negatives and decimals', () => {
  const lines = addToTicket([], itemFromLookup(lookupRow));
  assert.equal(setQuantity(lines, 'i1', '0'), lines);
  assert.equal(setQuantity(lines, 'i1', '-1'), lines);
  assert.equal(setQuantity(lines, 'i1', '1.5'), lines);
  assert.equal(setQuantity(lines, 'i1', '3')[0].quantity, 3);
  assert.deepEqual(removeLine(lines, 'i1'), []);
});

test('reception: server lines preserve quantity, scan id and rejection status', () => {
  const rows = linesFromServer([{ rawCode: '7500001000014', quantity: 5, matchStatus: 'matched', scanId: null },
    { rawCode: 'unknown', quantity: 1, matchStatus: 'rejected', scanId: 'scan-1' }]);
  assert.equal(rows[0].quantity, 5);
  assert.equal(rows[1].scanId, 'scan-1');
  assert.equal(rows[1].matchStatus, 'rejected');
});

test('reception totals text uses the server progress', () => {
  assert.equal(totalsText(1, { matchedUnits: 5, unitsPendingReview: 0 }), '1 código · 5 piezas');
  assert.equal(totalsText(2, { matchedUnits: 3, unitsPendingReview: 2 }), '2 códigos · 5 piezas');
  assert.equal(totalsText(0, { matchedUnits: 1, unitsPendingReview: 0 }), '0 códigos · 1 pieza');
});

test('cash difference has words, not only color', () => {
  assert.deepEqual(differenceView(-10000), { tone: 'neg', label: 'Faltante' });
  assert.deepEqual(differenceView(0), { tone: 'zero', label: 'Cuadra' });
  assert.deepEqual(differenceView(5), { tone: 'pos', label: 'Sobrante' });
});

test('inventory filter matches SKU or name without accents', () => {
  const rows = [{ sku: 'T-SKU-0001', variantName: 'Blusa Negra M' }, { sku: 'X-2', variantName: 'Pantalón' }];
  assert.equal(filterStock(rows, '').length, 2);
  assert.deepEqual(filterStock(rows, 'sku-0001').map(r => r.sku), ['T-SKU-0001']);
  assert.deepEqual(filterStock(rows, 'pantalon').map(r => r.sku), ['X-2']);
});

const response = (status, body) => ({ ok: status < 400, status, text: async () => body });

test('api: business rejection keeps the server code and Spanish message', async () => {
  const error = await toError(response(409, JSON.stringify({ code: 'stock.insufficient', message: 'No hay existencia.', traceId: 't1' })));
  assert.ok(error instanceof ApiError);
  assert.equal(error.code, 'stock.insufficient');
  assert.equal(error.message, 'No hay existencia.');
  assert.equal(error.missing, false);
});

test('api: an unmapped route keeps its HTTP status', async () => {
  const error = await toError(response(404, ''));
  assert.equal(error.missing, false);
  assert.equal(error.code, 'http.404');
});

test('api: a network failure becomes a retryable error', async () => {
  await assert.rejects(request('GET', '/me', undefined, { fetchImpl: async () => { throw new TypeError('fetch failed'); } }),
    e => e.network === true && e.code === 'network');
});

test('api: 204 gives null and JSON is parsed', async () => {
  assert.equal(await request('POST', '/x', {}, { fetchImpl: async () => response(204, '') }), null);
  assert.deepEqual(await request('GET', '/x', undefined, { fetchImpl: async () => response(200, '{"a":1}') }), { a: 1 });
});

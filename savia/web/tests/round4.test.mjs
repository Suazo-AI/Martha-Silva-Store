import test from 'node:test';
import assert from 'node:assert/strict';
import { alignSellers, freeSellers, MAX_SELLERS } from '../screens/sale-logic.mjs';
import { returnValue, exchangeBalance, outcomeRequest } from '../screens/return-logic.mjs';
import { guessMapping, mapRows, toBase64, mappingKey } from '../screens/import-logic.mjs';
import { formatBps, formatX100, kpiTabs } from '../screens/report-logic.mjs';

test('shared sale: lines follow the ticket sellers', () => {
  assert.equal(MAX_SELLERS, 3);
  const lines = [{ itemId: 'a', sellerId: 's1' }, { itemId: 'b', sellerId: 's2' }];
  assert.deepEqual(alignSellers(lines, ['s1']).map(l => l.sellerId), ['s1', 's1']);
  assert.deepEqual(alignSellers(lines, ['s1', 's2']).map(l => l.sellerId), ['s1', 's2']);
  assert.deepEqual(alignSellers(lines, ['s3', 's2'], { from: 's1', to: 's3' }).map(l => l.sellerId), ['s3', 's2']);
  const sellers = [{ sellerId: 's1' }, { sellerId: 's2' }, { sellerId: 's3' }];
  assert.deepEqual(freeSellers(sellers, ['s1', 's2']).map(s => s.sellerId), ['s3']);
  assert.deepEqual(freeSellers(sellers, ['s1', 's2'], 's2').map(s => s.sellerId), ['s2', 's3']);
});

test('return value mirrors SQL proportional credit and remainder', () => {
  const sale = { lines: [{ lineNumber: 1, saleLineId: 'L1', quantity: 3, returnedQuantity: 1, totalMinor: 100000 }],
    reversals: [{ status: 'approved', lines: [{ saleLineId: 'L1', creditMinor: 33333 }] }] };
  assert.equal(returnValue(sale, { 1: 1 }), 33333);
  assert.equal(returnValue(sale, { 1: 2 }), 66667);
  assert.equal(returnValue(sale, {}), 0);
});

test('exchange balance and outcome bodies', () => {
  const newLines = [{ itemId: 'n', quantity: 2, unitPriceMinor: 50000 }];
  assert.deepEqual(exchangeBalance(80000, newLines), { newMinor: 100000, dueMinor: 20000, backMinor: 0 });
  assert.deepEqual(exchangeBalance(130000, newLines), { newMinor: 100000, dueMinor: 0, backMinor: 30000 });
  const base = { reversalId: 'r', tillId: 't', reason: 'Talla', lines: [{ saleLineId: 'L1', quantity: 1, restockPool: 'store' }] };
  assert.throws(() => outcomeRequest({ ...base, outcome: 'transfer', reference: ' ' }), /referencia/);
  assert.equal(outcomeRequest({ ...base, outcome: 'transfer', reference: ' TRF-1 ' }).reference, 'TRF-1');
  assert.equal(outcomeRequest({ ...base, outcome: 'cash' }).newLines, undefined);
  assert.throws(() => outcomeRequest({ ...base, outcome: 'credit' }));
  assert.throws(() => outcomeRequest({ ...base, outcome: 'exchange', newLines: [] }), /prenda/);
  const due = outcomeRequest({ ...base, outcome: 'exchange', exchangeSaleId: 'x', newLines, sellerId: 's1', tenderKind: 'cash', returnMinor: 80000 });
  assert.deepEqual(due.newLines[0], { lineNumber: 1, itemId: 'n', quantity: 2, unitPriceMinor: 50000, discountMinor: 0, sellerId: 's1' });
  assert.deepEqual(due.newTenders, [{ tenderNumber: 1, tenderKind: 'cash', amountMinor: 20000, receivedMinor: 20000, changeMinor: 0 }]);
  assert.equal(due.differenceKind, undefined);
  assert.throws(() => outcomeRequest({ ...base, outcome: 'exchange', exchangeSaleId: 'x', newLines, differenceKind: 'transfer', returnMinor: 130000 }), /referencia/);
  const back = outcomeRequest({ ...base, outcome: 'exchange', exchangeSaleId: 'x', newLines, differenceKind: 'cash', returnMinor: 130000 });
  assert.deepEqual([back.newTenders, back.differenceKind], [[], 'cash']);
});

test('import mapping guesses Spanish headers in any order', () => {
  assert.deepEqual(guessMapping(['Codigo de barras', 'Referencia', 'Descripcion', 'Tipo de prenda', 'Talla', 'Color', 'Costo', 'Precio', 'Existencia']),
    { code: 0, sku: 1, name: 2, type: 3, size: 4, color: 5, cost: 6, price: 7, stock: 8 });
  assert.deepEqual(guessMapping(['Descripcion', 'Precio venta', 'Talla', 'Color', 'Existencias', 'Codigo', 'Costo unitario', 'Categoria', 'Referencia']),
    { code: 5, sku: 8, name: 0, type: 7, size: 2, color: 3, cost: 6, price: 1, stock: 4 });
  assert.equal(guessMapping(['Nada']).price, -1);
  assert.equal(mappingKey(['Código', 'Precio']), mappingKey(['codigo', 'precio']));
  const rows = mapRows([['7459990001017', '', 'Vestido', '', '', '', '', '980', '3']], guessMapping(['Codigo', 'SKU', 'Nombre', 'Tipo', 'Talla', 'Color', 'Costo', 'Precio', 'Stock']));
  assert.deepEqual(rows[0], { row: 2, code: '7459990001017', sku: null, name: 'Vestido', type: null, size: null, color: null, cost: null, price: '980', stock: '3' });
  assert.equal(toBase64(new TextEncoder().encode('ñ;1')), Buffer.from('ñ;1').toString('base64'));
});

test('KPI formatting and tabs by role', () => {
  assert.equal(formatBps(1234), '12.34 %');
  assert.equal(formatX100(150), '1.50');
  assert.deepEqual(kpiTabs(['SELLER']).map(([k]) => k), ['equipo']);
  assert.deepEqual(kpiTabs(['MANAGER']).map(([k]) => k), ['negocio', 'equipo']);
});

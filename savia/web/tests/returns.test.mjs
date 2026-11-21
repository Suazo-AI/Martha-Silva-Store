import assert from 'node:assert/strict';
import test from 'node:test';
import { remainingQuantity, selectedReturnLines } from '../screens/return-logic.mjs';

const lines = [
  { lineNumber: 1, quantity: 3, returnedQuantity: 2 },
  { lineNumber: 2, quantity: 2, returnedQuantity: 0 },
];
test('return selection respects sold minus returned and excludes zero lines', () => {
  assert.equal(remainingQuantity(lines[0]), 1);
  assert.deepEqual(selectedReturnLines(lines, { 1: '1', 2: '0' }), [{ saleLineNumber: 1, quantity: 1 }]);
  assert.deepEqual(selectedReturnLines(lines, { 2: 2 }), [{ saleLineNumber: 2, quantity: 2 }]);
});
test('return selection rejects excessive, fractional, negative and empty quantities', () => {
  for (const quantities of [{ 1: 2 }, { 2: 2.1 }, { 2: -1 }, { 2: 'abc' }, {}, { 1: Infinity }]) {
    assert.throws(() => selectedReturnLines(lines, quantities));
  }
});

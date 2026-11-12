import test from 'node:test';
import assert from 'node:assert/strict';
import { formatMoney, parseMoney, cashChange, lineTotal, countTotal } from '../money.mjs';

test('formatMoney: minor units to "C$ 1,200.00"', () => {
  assert.equal(formatMoney(120000), 'C$ 1,200.00');
  assert.equal(formatMoney(0), 'C$ 0.00');
  assert.equal(formatMoney(5), 'C$ 0.05');
  assert.equal(formatMoney(123456789), 'C$ 1,234,567.89');
  assert.equal(formatMoney(-10050), '-C$ 100.50');
  assert.equal(formatMoney(100, 'USD'), 'US$ 1.00');
});

test('formatMoney refuses floats', () => {
  assert.throws(() => formatMoney(12.5), TypeError);
  assert.throws(() => formatMoney(NaN), TypeError);
});

test('parseMoney reads text without float math', () => {
  assert.equal(parseMoney('1200'), 120000);
  assert.equal(parseMoney('1,200.5'), 120050);
  assert.equal(parseMoney('C$ 1,200.50'), 120050);
  assert.equal(parseMoney('0.1'), 10);
  assert.equal(parseMoney('0.29'), 29);      // 0.29*100 is 28.999… in floating point
  assert.equal(parseMoney('4000.07'), 400007);
  assert.equal(parseMoney(''), null);
  assert.equal(parseMoney('abc'), null);
  assert.equal(parseMoney('1.234'), null);
  assert.equal(parseMoney('-5'), null);
});

test('cashChange: empty, invalid, short, change', () => {
  assert.deepEqual(cashChange(240000, ''), { kind: 'empty' });
  assert.deepEqual(cashChange(240000, 'x'), { kind: 'invalid' });
  assert.deepEqual(cashChange(240000, '2000'), { kind: 'short', receivedMinor: 200000, missingMinor: 40000 });
  assert.deepEqual(cashChange(240000, '3000'), { kind: 'change', receivedMinor: 300000, changeMinor: 60000 });
  assert.deepEqual(cashChange(240000, '2400'), { kind: 'change', receivedMinor: 240000, changeMinor: 0 });
});

test('lineTotal and countTotal stay integers', () => {
  assert.equal(lineTotal(120000, 2), 240000);
  assert.throws(() => lineTotal(1.5, 2), TypeError);
  assert.equal(countTotal([{ denominationMinor: 100000, quantity: 3 }, { denominationMinor: 10000, quantity: 4 }]), 340000);
});

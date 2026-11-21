import assert from 'node:assert/strict';
import test from 'node:test';
import { businessDate, receiptCashTotals, saleDate } from '../screens/sale-view.mjs';

test('receipt uses recorded cash received/change; card and transfer create no cash change', () => {
  assert.deepEqual(
    receiptCashTotals([
      { tenderKind: 'cash', amountMinor: 59800, receivedMinor: 100000, changeMinor: 40200 },
      { tenderKind: 'card', amountMinor: 30000, receivedMinor: null, changeMinor: null },
      { tenderKind: 'transfer', amountMinor: 30000, receivedMinor: null, changeMinor: null },
    ]),
    { receivedMinor: 100000, changeMinor: 40200 },
  );
  assert.deepEqual(receiptCashTotals([{ tenderKind: 'card', amountMinor: 119800 }]), { receivedMinor: 0, changeMinor: 0 });
});

test('SQL dates without offsets are UTC; business-date filters use Nicaragua midnight', () => {
  assert.equal(saleDate('2026-11-12T02:00:00'), saleDate('2026-11-12T02:00:00Z'));
  assert.equal(businessDate(new Date('2026-11-12T05:59:59Z')), '2026-11-11');
  assert.equal(businessDate(new Date('2026-11-12T06:00:00Z')), '2026-11-12');
});

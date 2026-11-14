import assert from 'node:assert/strict';
import test from 'node:test';
import { paymentDraft } from '../screens/payment-logic.mjs';
import { usdCash } from '../screens/usd-logic.mjs';

const rate = { id: 'rate', rate: 36.6243 };
test('USD conversion, whole córdoba change and both rounding signs', () => {
  const a = usdCash(216100, '60', rate);
  assert.deepEqual([a.receivedMinor, a.changeMinor, a.roundingMinor], [219746, 3600, 46]);
  const b = usdCash(216100, '59', rate);
  assert.deepEqual([b.receivedMinor, b.changeMinor, b.roundingMinor], [216083, 0, -17]);
  assert.throws(() => usdCash(216100, '58', rate));
  assert.throws(() => usdCash(216100, '60', null));
});
test('USD draft keeps integer server fields and rejects duplicate USD payments', () => {
  const rows = [
    { kind: 'cash_usd', received: '20', amount: '732.49' },
    { kind: 'cash', received: '1428.51', amount: '1428.51' },
  ];
  const draft = paymentDraft(216100, rows, { supportedKinds: ['cash_usd', 'cash'], rate });
  assert.equal(draft.tenders[0].tenderKind, 'cash');
  assert.equal(draft.tenders[0].foreignReceivedMinor, 2000);
  assert.equal(draft.tenders[0].exchangeRateId, rate.id);
  assert.throws(() => paymentDraft(216100, [rows[0], rows[0]], { supportedKinds: ['cash_usd'], rate }));
});

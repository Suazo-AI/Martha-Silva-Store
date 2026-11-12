import test from 'node:test';
import assert from 'node:assert/strict';
import { saleRequest } from '../screens/sale-logic.mjs';
import { paymentDraft } from '../screens/payment-logic.mjs';

const lines = [{ itemId: 'i', quantity: 2, unitPriceMinor: 59900 }];
test('card sale preserves its tender and never creates cash change', () => {
  const tenders = [{ tenderNumber: 1, tenderKind: 'card', amountMinor: 119800, receivedMinor: null, changeMinor: null, reference: 'AUTH-MUESTRA' }];
  assert.deepEqual(saleRequest({ saleId: 's', tillId: 't', lines, tenders }).tenders, tenders);
});

const options = { supportedKinds: ['cash', 'card', 'transfer', 'credit'], customerId: 'customer' };
test('pending split cash and card: only cash has received and change', () => {
  assert.deepEqual(paymentDraft(119800, [{ kind: 'cash', amount: '598', received: '1000' }, { kind: 'card', amount: '600', received: '9000', reference: 'AUTH-MUESTRA' }], options), {
    tenders: [
      { tenderNumber: 1, tenderKind: 'cash', amountMinor: 59800, receivedMinor: 100000, changeMinor: 40200 },
      { tenderNumber: 2, tenderKind: 'card', amountMinor: 60000, receivedMinor: null, changeMinor: null, reference: 'AUTH-MUESTRA' },
    ], changeMinor: 40200,
  });
});
test('pending input rejects short/overallocated split, absent reference or customer, and unsupported kind', () => {
  for (const rows of [[], [{ kind: 'cash', received: '1197.99' }], [{ kind: 'transfer', reference: ' ' }],
    [{ kind: 'card' }], [{ kind: 'card', amount: '600', reference: 'AUTH-1' }, { kind: 'card', amount: '599', reference: 'AUTH-2' }], [{ kind: 'bitcoin' }]]) {
    assert.throws(() => paymentDraft(119800, rows, options));
  }
  assert.throws(() => paymentDraft(119800, [{ kind: 'credit' }], { supportedKinds: options.supportedKinds }));
});
test('transfer reference and customer credit pass as pending input without inventing a balance', () => {
  assert.equal(paymentDraft(119800, [{ kind: 'transfer', reference: ' MUESTRA ' }], options).tenders[0].reference, 'MUESTRA');
  const credit = paymentDraft(119800, [{ kind: 'credit', creditId: 'credit' }], options);
  assert.equal(credit.changeMinor, 0);
  assert.equal(credit.tenders[0].creditId, 'credit');
});

test('split sale preserves cash change and transfer reference', () => {
  const tenders = [
    { tenderNumber: 1, tenderKind: 'cash', amountMinor: 59800, receivedMinor: 100000, changeMinor: 40200 },
    { tenderNumber: 2, tenderKind: 'transfer', amountMinor: 60000, receivedMinor: null, changeMinor: null, reference: 'MUESTRA-1' },
  ];
  assert.deepEqual(saleRequest({ saleId: 's', tillId: 't', lines, tenders }).tenders, tenders);
});

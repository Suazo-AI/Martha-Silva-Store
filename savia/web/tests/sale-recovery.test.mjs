import assert from 'node:assert/strict';
import test from 'node:test';
import {
  actorScope,
  clearPending,
  matchesReceipt,
  persistPending,
  RECOVERY_KEY,
  readPending,
  sameGuid,
  sameScope,
} from '../sale-recovery.mjs';
import { paymentDraft } from '../screens/payment-logic.mjs';
import { saleRequest } from '../screens/sale-logic.mjs';

const id = n => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const scope = actorScope({ staffId: id(1), nodeId: id(2), branchId: id(3), locationId: id(4) }, 'http://localhost:123');
const store = () => {
  const map = new Map();
  return { getItem: k => map.get(k) ?? null, setItem: (k, v) => map.set(k, v), removeItem: k => map.delete(k) };
};
const record = () => ({
  version: 1,
  scope: { ...scope },
  changeMinor: 0,
  body: saleRequest({
    saleId: id(5),
    tillId: id(6),
    lines: [{ itemId: id(7), quantity: 1, unitPriceMinor: 10000, sellerId: id(1) }],
    tenders: [{ tenderNumber: 1, tenderKind: 'card', amountMinor: 10000, reference: 'DEMO' }],
  }),
});
test('real payment bodies survive durable readback including USD, split tenders, credit and 100% discount', () => {
  const supportedKinds = ['cash', 'card', 'transfer', 'credit', 'cash_usd'];
  for (const rows of [
    [{ kind: 'cash', received: '110' }],
    [{ kind: 'card', reference: 'Demo voucher' }],
    [{ kind: 'transfer', reference: 'Demo transfer' }],
    [{ kind: 'credit', creditId: id(8) }],
    [
      { kind: 'cash', amount: '20', received: '30' },
      { kind: 'card', amount: '20' },
      { kind: 'transfer', amount: '30', reference: 'DEMO' },
      { kind: 'credit', amount: '30', creditId: id(8) },
    ],
    [{ kind: 'cash_usd', received: '3', foreignChange: '0' }],
  ]) {
    const draft = paymentDraft(10000, rows, { supportedKinds, customerId: id(9), rate: { id: id(10), rate: 36.5 } });
    const r = record();
    r.changeMinor = draft.changeMinor;
    r.body.tenders = draft.tenders;
    r.body.customerId = id(9);
    r.body.discountReason = 'Demo';
    r.body.stockExceptionNote = 'Demo stock';
    const db = store();
    persistPending(r, db);
    assert.deepEqual(readPending(db), r);
  }
  const r = record();
  r.body.lines[0].discountMinor = 10000;
  r.body.tenders = [];
  persistPending(r, store());
});
test('write/readback failure blocks and an existing marker cannot be overwritten', () => {
  const r = record(),
    db = store();
  persistPending(r, db);
  assert.throws(() => persistPending(r, db));
  assert.throws(() => persistPending(r, { getItem: () => null, setItem: () => {} }));
  assert.throws(() =>
    persistPending(r, {
      getItem: () => null,
      setItem: () => {
        throw Error('denied');
      },
    }),
  );
  assert.deepEqual(readPending(db), r);
});
test('corruption, extra credentials and monetary tampering are rejected', () => {
  for (const mutate of [
    r => (r.token = 'SECRET'),
    r => (r.body.approvalToken = 'SECRET'),
    r => (r.body.lines[0].unitPriceMinor = 1.5),
    r => (r.body.tenders[0].amountMinor = 9999),
    r => (r.scope.staffId = 'owner'),
  ]) {
    const r = record();
    mutate(r);
    assert.throws(() => persistPending(r, store()));
  }
  assert.throws(() => readPending({ getItem: () => '{' }));
});
test('receipt match binds cashier and original till, account/node/location changes quarantine', () => {
  const r = record(),
    sale = {
      saleId: id(5),
      cashierId: id(1),
      tillId: id(6),
      subtotalMinor: 10000,
      discountMinor: 0,
      taxMinor: 0,
      totalMinor: 10000,
      status: 'posted',
    };
  assert.equal(matchesReceipt(sale, r), true);
  for (const k of ['saleId', 'cashierId', 'tillId']) assert.equal(matchesReceipt({ ...sale, [k]: id(99) }, r), false);
  for (const k of ['staffId', 'nodeId', 'branchId', 'locationId', 'origin'])
    assert.equal(sameScope(scope, { ...scope, [k]: 'other' }), false);
  assert.equal(sameGuid('AAAAAAAA-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000001'), true);
  assert.equal(sameGuid('Ana', 'ana'), false);
});
test('clear fails closed on changed marker or failed deletion', () => {
  const db = store(),
    r = record();
  persistPending(r, db);
  assert.throws(() => clearPending({ ...r, body: { ...r.body, saleId: id(99) } }, db));
  assert.throws(() => clearPending(r, { ...db, removeItem: () => {} }));
  assert.ok(db.getItem(RECOVERY_KEY));
  clearPending(r, db);
  assert.equal(readPending(db), null);
});

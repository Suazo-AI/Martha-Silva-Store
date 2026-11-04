import test from 'node:test';
import assert from 'node:assert/strict';
import {catalog, createDemoStore} from './model.mjs';

const PINK = 'demo-gala-rosa';
const LINEN = 'demo-moda-lino';
const available = (store, productId, size) => store.getCatalog()
  .find(product => product.id === productId).sizes.find(variant => variant.size === size).available;

test('six synthetic products expose the exact UI catalog shape and limited sample stock', () => {
  const store = createDemoStore();
  const products = store.getCatalog();
  assert.equal(products.length, 6);
  assert.equal(new Set(products.map(product => product.id)).size, 6);
  const skus = [];
  for (const product of products) {
    assert.deepEqual(Object.keys(product).sort(), ['category', 'color', 'id', 'name', 'priceCents', 'sizes']);
    assert.ok(product.priceCents > 0 && Number.isSafeInteger(product.priceCents));
    assert.match(product.name, /muestra/);
    assert.deepEqual(product.sizes.map(variant => variant.size), ['S', 'M', 'L']);
    for (const variant of product.sizes) {
      assert.deepEqual(Object.keys(variant).sort(), ['available', 'size', 'sku']);
      assert.ok(Number.isSafeInteger(variant.available) && variant.available >= 0 && variant.available <= 3);
      skus.push(variant.sku);
    }
  }
  assert.equal(new Set(skus).size, 18);
  assert.ok(products.some(product => product.sizes.some(variant => variant.available === 0)));
  assert.deepEqual(store.getState(), {cart: [], totalCents: 0, itemCount: 0, sales: [], lastResult: null});
});

test('the same product and size aggregate into one stable line without reserving stock', () => {
  const store = createDemoStore();
  const original = store.getCatalog();
  const first = store.addItem(PINK, 'S');
  const second = store.addItem(PINK, 'S');
  assert.equal(second.cart.length, 1);
  assert.equal(second.cart[0].id, first.cart[0].id);
  assert.equal(second.cart[0].quantity, 2);
  assert.equal(second.cart[0].lineTotalCents, 25800);
  store.addItem(PINK, 'M');
  store.addItem(LINEN, 'S', 3);
  const state = store.getState();
  assert.equal(state.cart.length, 3);
  assert.equal(state.itemCount, 6);
  assert.equal(state.totalCents, 59400);
  assert.equal(new Set(state.cart.map(line => line.id)).size, 3);
  assert.deepEqual(store.getCatalog(), original);
});

test('aggregate stock bounds reject a repeated add atomically; sizes keep separate limits', () => {
  const store = createDemoStore();
  store.addItem(PINK, 'S', 2);
  const before = store.getState();
  const stock = store.getCatalog();
  assert.throws(() => store.addItem(PINK, 'S'), /Quedan 2 unidades/);
  assert.deepEqual(store.getState(), before);
  assert.deepEqual(store.getCatalog(), stock);
  assert.throws(() => store.addItem(PINK, 'L'), /agotada/);
  assert.deepEqual(store.getState(), before);
  assert.equal(store.addItem(PINK, 'M').cart.length, 2);
});

test('only positive safe integer numbers are accepted; rejected edits never change state', () => {
  const store = createDemoStore();
  const id = store.addItem(PINK, 'S').cart[0].id;
  const before = store.getState();
  for (const quantity of [0, -1, 1.5, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1, '1', null, undefined, true]) {
    // Explicit undefined on add means its documented default of one, so test it
    // through setQuantity only; every other invalid input is rejected by both.
    if (quantity !== undefined) assert.throws(() => store.addItem(PINK, 'S', quantity), /cantidad entera/);
    assert.throws(() => store.setQuantity(id, quantity), /cantidad entera/);
    assert.deepEqual(store.getState(), before);
  }
  assert.throws(() => store.setQuantity(id, 3), /Quedan 2 unidades/);
  assert.deepEqual(store.getState(), before);
  const changed = store.setQuantity(id, 2);
  assert.equal(changed.cart[0].id, id);
  assert.equal(changed.itemCount, 2);
  assert.equal(changed.totalCents, 25800);
});

test('unknown products, sizes, lines, sales and outcomes give errors without mutations', () => {
  const store = createDemoStore();
  store.addItem(PINK, 'S');
  const before = store.getState();
  for (const action of [
    () => store.addItem('__proto__', 'S'),
    () => store.addItem(PINK, 'XL'),
    () => store.setQuantity('missing-line', 1),
    () => store.removeItem('missing-line'),
    () => store.cancelSale('missing-sale'),
    () => store.checkout('paid'),
    () => store.checkout(),
  ]) {
    assert.throws(action, error => error instanceof Error && error.message.length > 15);
    assert.deepEqual(store.getState(), before);
  }
});

test('decline preserves the complete bag and stock; a deliberate approval retry succeeds once', () => {
  const store = createDemoStore();
  store.addItem(PINK, 'S', 2);
  store.addItem(LINEN, 'M');
  const before = store.getState();
  const stock = store.getCatalog();
  const declined = store.checkout('declined');
  assert.deepEqual(declined.cart, before.cart);
  assert.equal(declined.totalCents, before.totalCents);
  assert.equal(declined.itemCount, before.itemCount);
  assert.deepEqual(declined.sales, []);
  assert.deepEqual(declined.lastResult, {outcome: 'declined'});
  assert.deepEqual(store.getCatalog(), stock);
  assert.deepEqual(store.checkout('declined'), declined);
  const approved = store.checkout('approved');
  assert.equal(approved.sales.length, 1);
  assert.deepEqual(approved.sales[0].lines, before.cart);
  assert.equal(approved.sales[0].totalCents, before.totalCents);
  assert.equal(approved.sales[0].status, 'completed');
  assert.ok(Number.isFinite(Date.parse(approved.sales[0].createdAt)));
  assert.match(approved.sales[0].createdAt, /Z$/);
  assert.deepEqual(approved.lastResult, {outcome: 'approved', saleId: approved.sales[0].id});
  assert.deepEqual(approved.cart, []);
  assert.equal(approved.totalCents, 0);
  assert.equal(approved.itemCount, 0);
  assert.equal(available(store, PINK, 'S'), 0);
  assert.equal(available(store, LINEN, 'M'), 1);
});

test('double-submit on the now-empty bag cannot create another receipt or stock decrement', () => {
  const store = createDemoStore();
  store.addItem(PINK, 'S');
  const approved = store.checkout('approved');
  const stock = store.getCatalog();
  assert.throws(() => store.checkout('approved'), /Agregá al menos una prenda/);
  assert.throws(() => store.checkout('declined'), /Agregá al menos una prenda/);
  assert.deepEqual(store.getState(), approved);
  assert.deepEqual(store.getCatalog(), stock);
});

test('cancelling two distinct sales restores only each sale once and preserves its receipt data', () => {
  const store = createDemoStore();
  store.addItem(PINK, 'S');
  const first = store.checkout('approved').sales[0];
  store.addItem(PINK, 'S');
  const second = store.checkout('approved').sales[1];
  assert.notEqual(first.id, second.id);
  assert.equal(available(store, PINK, 'S'), 0);
  const cancelled = store.cancelSale(first.id);
  assert.equal(available(store, PINK, 'S'), 1);
  assert.deepEqual(cancelled.sales[0], {...first, status: 'cancelled'});
  assert.deepEqual(cancelled.sales[1], second);
  assert.equal(cancelled.lastResult, null);
  const beforeRepeat = store.getState();
  assert.throws(() => store.cancelSale(first.id), /ya está cancelado/);
  assert.deepEqual(store.getState(), beforeRepeat);
  assert.equal(available(store, PINK, 'S'), 1);
  store.cancelSale(second.id);
  assert.equal(available(store, PINK, 'S'), 2);
});

test('remove and clear affect only the bag, clear checkout feedback, and do not replenish stock', () => {
  const store = createDemoStore();
  store.addItem(PINK, 'S');
  store.checkout('approved');
  const stock = store.getCatalog();
  const line = store.addItem(LINEN, 'S').cart[0];
  store.checkout('declined');
  assert.equal(store.removeItem(line.id).lastResult, null);
  assert.deepEqual(store.getCatalog(), stock);
  assert.equal(store.getState().sales.length, 1);
  store.addItem(LINEN, 'S');
  store.checkout('declined');
  assert.equal(store.clearCart().lastResult, null);
  assert.deepEqual(store.getCatalog(), stock);
  assert.equal(store.getState().sales.length, 1);
  assert.deepEqual(store.clearCart().cart, []);
});

test('catalog, mutation returns, cart, sale lines and checkout results expose no mutable internal references', () => {
  const store = createDemoStore();
  const external = store.getCatalog();
  external[0].priceCents = -100;
  external[0].sizes[0].available = 999;
  external.push({id: 'outside'});
  const returned = store.addItem(PINK, 'S');
  returned.cart[0].quantity = 99;
  returned.cart[0].unitPriceCents = 0;
  returned.cart.push({id: 'outside'});
  assert.equal(store.getState().itemCount, 1);
  assert.equal(store.getState().totalCents, 12900);
  const result = store.checkout('approved');
  const id = result.lastResult.saleId;
  result.sales[0].status = 'cancelled';
  result.sales[0].lines[0].quantity = 100;
  result.sales[0].lines[0].name = 'changed';
  result.lastResult.outcome = 'declined';
  result.sales.splice(0);
  const actual = store.getState();
  assert.equal(actual.sales.length, 1);
  assert.equal(actual.sales[0].status, 'completed');
  assert.equal(actual.sales[0].lines[0].quantity, 1);
  assert.match(actual.sales[0].lines[0].name, /muestra/);
  assert.deepEqual(actual.lastResult, {outcome: 'approved', saleId: id});
  store.cancelSale(id);
  assert.equal(available(store, PINK, 'S'), 2);
});

test('reset restores fixture, removes receipts and bag, and never aliases a stale sale ID', () => {
  const store = createDemoStore();
  const initial = store.getCatalog();
  store.addItem(PINK, 'S');
  const oldId = store.checkout('approved').lastResult.saleId;
  store.addItem(LINEN, 'S');
  store.checkout('declined');
  const reset = store.resetDemo();
  assert.deepEqual(reset, {cart: [], totalCents: 0, itemCount: 0, sales: [], lastResult: null});
  assert.deepEqual(store.getCatalog(), initial);
  store.addItem(PINK, 'S');
  const currentId = store.checkout('approved').lastResult.saleId;
  assert.notEqual(currentId, oldId);
  const before = store.getState();
  assert.throws(() => store.cancelSale(oldId), /No encontramos ese comprobante/);
  assert.deepEqual(store.getState(), before);
});

test('store instances are independent and the exported reference fixture is deeply frozen', () => {
  const a = createDemoStore(), b = createDemoStore();
  assert.ok(Object.isFrozen(catalog));
  assert.ok(Object.isFrozen(catalog[0]));
  assert.ok(Object.isFrozen(catalog[0].sizes));
  assert.ok(Object.isFrozen(catalog[0].sizes[0]));
  assert.throws(() => { catalog[0].sizes[0].available = 500; }, TypeError);
  a.addItem(PINK, 'S', 2);
  a.checkout('approved');
  assert.equal(available(a, PINK, 'S'), 0);
  assert.equal(available(b, PINK, 'S'), 2);
  assert.deepEqual(b.getState(), {cart: [], totalCents: 0, itemCount: 0, sales: [], lastResult: null});
  b.addItem(LINEN, 'L');
  a.resetDemo();
  assert.equal(b.getState().cart.length, 1);
});

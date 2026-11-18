// Exercise the normal Venta screen through its serialized POST, with synthetic data and no server.
import assert from 'node:assert/strict';
import test from 'node:test';
import { setToken } from '../api.mjs';
import sale from '../screens/sale.mjs';

// Minimal DOM, following sale-lifecycle.test.mjs, for the controls used by this flow.
class Element {
  constructor(tag, text = '') {
    this.tag = tag;
    this.text = text;
    this.value = '';
    this.children = [];
    this.dataset = {};
    this.handlers = new Map();
    this.classList = { add() {}, remove() {} };
  }
  append(...children) {
    for (const child of children) child.parentNode = this;
    this.children.push(...children);
  }
  replaceChildren() {
    for (const child of this.children) child.parentNode = null;
    this.children = [];
    this.text = '';
  }
  remove() {
    if (this.parentNode) this.parentNode.children = this.parentNode.children.filter(child => child !== this);
    this.parentNode = null;
  }
  set textContent(value) {
    this.replaceChildren();
    this.text = String(value);
  }
  get textContent() {
    return this.text + this.children.map(child => child.textContent).join('');
  }
  setAttribute(key, value) {
    this[key] = ['disabled', 'hidden'].includes(key) ? true : value;
  }
  addEventListener(type, fn) {
    this.handlers.set(type, [...(this.handlers.get(type) ?? []), fn]);
  }
  removeEventListener(type, fn) {
    this.handlers.set(type, (this.handlers.get(type) ?? []).filter(handler => handler !== fn));
  }
  async fire(type) {
    for (const fn of this.handlers.get(type) ?? []) await fn({ target: this, stopPropagation() {} });
  }
  querySelectorAll(query) {
    const selectors = query.split(',');
    return this.children.flatMap(child => {
      const matches = selectors.some(selector => {
        if (selector.startsWith('#')) return child.id === selector.slice(1);
        if (selector.startsWith('.')) return child.className?.split(' ').includes(selector.slice(1));
        return child.tag === selector;
      });
      return [...(matches ? [child] : []), ...child.querySelectorAll(query)];
    });
  }
  querySelector(query) {
    return this.querySelectorAll(query)[0] ?? null;
  }
  focus() {}
}

function storage() {
  const values = new Map();
  return {
    getItem: key => values.get(key) ?? null,
    setItem: (key, value) => values.set(key, String(value)),
    removeItem: key => values.delete(key),
  };
}

const id = n => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const actor = { staffId: id(1), nodeId: id(2), branchId: id(3), locationId: id(4), roles: ['CASHIER'] };
const tillId = id(5);
const customer = { customerId: id(6), displayName: 'Ana', customerCode: 'C-1' };
const credit = { customerId: customer.customerId, creditId: id(7), branchId: actor.branchId, currencyCode: 'NIO', availableMinor: 10000 };
const item = { itemId: id(8), sku: 'TEST', sizeCode: 'M', available: 1, unitPriceMinor: 10000 };
const settle = () => new Promise(resolve => setImmediate(resolve));

for (const scenario of ['keep credit', 'switch to cash after selection', 'switch to cash during lookup']) {
  test(`Venta customer contract: ${scenario}`, async t => {
    const root = new Element('main');
    const document = new Element('document');
    document.createElement = tag => new Element(tag);
    document.createTextNode = text => new Element('#text', text);
    document.append(root);
    Object.assign(globalThis, {
      Node: Element,
      document,
      location: { origin: 'https://fixture.invalid', hash: '#/venta' },
      localStorage: storage(),
      sessionStorage: storage(),
    });
    setToken('synthetic-cashier-session');
    let till = null;
    const ctx = {
      me: actor,
      branchName: 'Fixture',
      till: { get: () => till, set: value => { till = value; } },
    };
    const posts = [];
    let creditLookups = 0;
    const { promise: creditLookup, resolve: finishLookup } = Promise.withResolvers();
    t.mock.method(globalThis, 'fetch', async (url, options) => {
      const { pathname } = new URL(url, 'https://fixture.invalid');
      if (pathname === '/api/v1/exchange-rate') return Response.json({}, { status: 404 });
      if (pathname === '/api/v1/cash/registers') return Response.json([{ openTillId: tillId, openTillCashierId: actor.staffId }]);
      if (pathname === `/api/v1/cash/tills/${tillId}/summary`) return Response.json({ tillId });
      if (pathname === '/api/v1/sellers') return Response.json([{ sellerId: actor.staffId, name: 'Seller' }]);
      if (pathname === '/api/v1/catalog/items') return Response.json([{ productId: id(9), name: 'Fixture', type: 'Dress', variants: [item] }]);
      if (pathname === '/api/v1/customers') return Response.json([customer]);
      if (pathname === '/api/v1/credits/search') {
        creditLookups++;
        await creditLookup;
        return Response.json([credit]);
      }
      if (pathname === '/api/v1/sales' && options.method === 'POST') {
        const body = JSON.parse(options.body);
        posts.push(body);
        return Response.json({ saleId: body.saleId, status: 'posted', subtotalMinor: 10000, discountMinor: 0, taxMinor: 0, totalMinor: 10000 });
      }
      if (pathname === `/api/v1/sales/${posts[0]?.saleId}` && options.method === 'GET') return Response.json({}, { status: 404 });
      assert.fail(`Unexpected fixture request ${options.method} ${pathname}`);
    });

    const handle = await sale.mount(root, ctx);
    t.after(() => handle.unmount());
    const find = selector => {
      const element = root.querySelector(selector);
      assert.ok(element, `missing ${selector}`);
      return element;
    };
    const change = async (selector, value, type = 'change') => {
      const element = find(selector);
      element.value = value;
      await element.fire(type);
    };

    await settle();
    await find('.product').fire('click');
    await change('#payment-0-kind', 'credit');
    await change('#sale-customer-search', customer.displayName, 'input');
    const search = find('#sale-customer-panel').querySelector('button');
    await search.fire('click');
    const picking = find('#sale-customers').querySelector('button').fire('click');
    assert.equal(creditLookups, 1);
    if (scenario === 'switch to cash during lookup') await change('#payment-0-kind', 'cash');
    finishLookup();
    await picking;
    if (scenario !== 'switch to cash during lookup') {
      assert.match(find('#sale-customer-panel').textContent, /Cliente: Ana/);
      await change('#payment-0-credit', credit.creditId);
    }
    if (scenario === 'switch to cash after selection') await change('#payment-0-kind', 'cash');
    if (scenario !== 'keep credit') await change('#received', '100', 'input');
    assert.equal(find('#pay').disabled, false);
    await find('#pay').fire('click');

    assert.equal(posts.length, 1, 'Cobrar sends exactly one sale');
    const [body] = posts;
    assert.equal(body.lines[0].itemId, item.itemId);
    assert.equal(body.tenders.length, 1);
    const [tender] = body.tenders;
    if (scenario === 'keep credit') {
      assert.equal(tender.tenderKind, 'credit');
      assert.equal(tender.creditId, credit.creditId);
      assert.equal(body.customerId, customer.customerId);
    } else {
      assert.equal(tender.tenderKind, 'cash');
      assert.equal(Object.hasOwn(tender, 'creditId'), false);
      assert.equal(Object.hasOwn(body, 'customerId'), false, 'POST /sales omits customerId for cash');
    }
  });
}

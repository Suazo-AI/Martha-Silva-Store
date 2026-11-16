// Actual sale and shared modal modules; fictional HTTP and a minimal offline DOM.
import assert from 'node:assert/strict';
import { resolve } from 'node:path';
import test from 'node:test';
import { pathToFileURL } from 'node:url';

class Element {
  constructor(tag = 'div', text = '') {
    this.tagName = tag.toUpperCase();
    this.children = [];
    this.parentNode = null;
    this.dataset = {};
    this.attrs = {};
    this.value = '';
    this.listeners = new Map();
    this._text = text;
    this.open = false;
    this.classList = { add() {}, remove() {} };
  }
  append(...xs) {
    for (let x of xs.flat(Infinity)) {
      if (!(x instanceof Element)) x = new Element('#text', String(x));
      x.parentNode = this;
      this.children.push(x);
    }
  }
  replaceChildren(...xs) {
    for (const x of this.children) x.parentNode = null;
    this.children = [];
    this._text = '';
    this.append(...xs);
  }
  set textContent(x) {
    this.replaceChildren();
    this._text = String(x);
  }
  get textContent() {
    return this._text + this.children.map(x => x.textContent).join('');
  }
  setAttribute(k, v) {
    this.attrs[k] = String(v);
    if (k === 'id' || k === 'value' || k === 'type') this[k] = String(v);
    if (k === 'class') this.className = String(v);
    if (k === 'hidden' || k === 'disabled' || k === 'open') this[k] = true;
  }
  getAttribute(k) {
    return this.attrs[k] ?? null;
  }
  addEventListener(k, f) {
    if (!this.listeners.has(k)) this.listeners.set(k, []);
    this.listeners.get(k).push(f);
  }
  removeEventListener(k, f) {
    this.listeners.set(
      k,
      (this.listeners.get(k) || []).filter(x => x !== f),
    );
  }
  async fire(k) {
    for (const f of [...(this.listeners.get(k) || [])]) await f({ target: this, preventDefault() {}, stopPropagation() {} });
  }
  matches(s) {
    if (s.startsWith('#')) return this.id === s.slice(1);
    if (s.startsWith('.')) return (this.className || '').split(' ').includes(s.slice(1));
    if (s === 'dialog[open]') return this.tagName === 'DIALOG' && this.open;
    return this.tagName === s.toUpperCase();
  }
  querySelectorAll(s) {
    const selectors = s.split(',').map(x => x.trim());
    return this.children.flatMap(x => [...(selectors.some(s => x.matches(s)) ? [x] : []), ...x.querySelectorAll(s)]);
  }
  querySelector(s) {
    return this.querySelectorAll(s)[0] ?? null;
  }
  closest(s) {
    return s.split(',').some(x => this.matches(x)) ? this : (this.parentNode?.closest(s) ?? null);
  }
  remove() {
    if (this.parentNode) this.parentNode.children = this.parentNode.children.filter(x => x !== this);
    this.parentNode = null;
  }
  focus() {
    document.activeElement = this;
  }
  showModal() {
    this.open = true;
    this.shown = (this.shown || 0) + 1;
  }
  close() {
    this.open = false;
    void this.fire('close');
  }
  get isConnected() {
    return this === document.body || !!this.parentNode?.isConnected;
  }
}
class Storage extends Map {
  getItem(k) {
    return this.get(k) ?? null;
  }
  setItem(k, v) {
    this.set(k, String(v));
  }
  removeItem(k) {
    this.delete(k);
  }
}
globalThis.Node = Element;
globalThis.localStorage = new Storage();
globalThis.sessionStorage = new Storage();
globalThis.location = { origin: 'http://fixture.invalid', hash: '#/venta' };
const document = new Element('document');
globalThis.document = document;
document.body = new Element('body');
document.append(document.body);
document.createElement = t => new Element(t);
document.createTextNode = t => new Element('#text', t);
document.getElementById = id => document.body.querySelector(`#${id}`);
globalThis.window = globalThis;
const load = p => import(pathToFileURL(resolve(p)).href);
const api = await load('savia/web/api.mjs');
const { default: sale } = await load('savia/web/screens/sale.mjs');
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const actor = { staffId: id(1), nodeId: id(2), branchId: id(3), locationId: id(4), roles: ['MANAGER'] };
const variants = [
  { itemId: id(8), sku: 'A', sizeCode: 'S', available: 5, unitPriceMinor: 100 },
  { itemId: id(9), sku: 'A', sizeCode: 'M', available: 5, unitPriceMinor: 100 },
];
const tick = () => new Promise(r => setImmediate(r));
for (const action of ['active-control', 'navigation', 'logout', 'account', 'navigation-click', 'logout-click', 'account-click']) {
  test(`catalog lookup/modal respects lifecycle: ${action}`, async () => {
    localStorage.clear();
    sessionStorage.clear();
    api.setToken('session-A');
    location.hash = '#/venta';
    const root = new Element('main');
    root.id = 'screen';
    const modal = new Element('dialog');
    modal.id = 'modal';
    const modalBody = new Element('div');
    modalBody.id = 'modal-body';
    modal.append(modalBody);
    document.body.replaceChildren(root, modal);
    let release;
    const calls = [];
    globalThis.fetch = async (url, opts = {}) => {
      const p = String(url).replace('/api/v1', '');
      calls.push({ path: p, method: opts.method });
      let data;
      if (p === '/exchange-rate') return new Response('{}', { status: 404 });
      if (p === '/cash/registers') data = [{ registerId: id(7), openTillId: id(5), openTillCashierId: id(1) }];
      else if (p.endsWith('/summary')) data = { tillId: id(5) };
      else if (p === '/sellers') data = [{ sellerId: id(1), name: 'A' }];
      else if (p === '/catalog/items') data = [{ name: 'Fixture', productId: id(6), type: 'Dress', variants }];
      else if (p.startsWith('/catalog/lookup'))
        return new Promise(r => {
          release = () => r(new Response(JSON.stringify(variants)));
        });
      else throw Error(`Unexpected request ${p}`);
      return new Response(JSON.stringify(data));
    };
    let active = true;
    const ctx = {
      me: { ...actor },
      isApprover: true,
      branchName: 'Fixture',
      isCurrent: () => active,
      till: { get: () => null, set() {} },
      notify() {},
      go() {},
      refreshTill() {},
    };
    // syncTill sets the local till; retain it for the actual sale screen.
    let till = null;
    ctx.till = {
      get: () => till,
      set: v => {
        till = v;
      },
    };
    const handle = await sale.mount(root, ctx);
    await tick();
    assert.ok(root.querySelector('#sale-search'), 'actual sale mounted');
    const oldCard = root.querySelector('.product');
    const pending = action.endsWith('-click') ? Promise.resolve() : handle.handleScan('AMBIGUOUS');
    await tick();
    if (!action.endsWith('-click')) assert.equal(typeof release, 'function', 'lookup held');
    if (action !== 'active-control') {
      handle.unmount();
      active = false;
      location.hash = '#/historial';
      if (action.startsWith('logout')) {
        api.setToken(null);
        ctx.me = null;
      }
      if (action.startsWith('account')) {
        api.setToken('session-B');
        ctx.me = { ...actor, staffId: id(10) };
      }
      root.textContent = 'CURRENT SCREEN';
      modalBody.textContent = 'CURRENT ACCOUNT DIALOG';
    }
    const focusTarget = action === 'active-control' ? root.querySelector('#sale-search') : new Element('button', 'CURRENT ACCOUNT FOCUS');
    if (action !== 'active-control') document.body.append(focusTarget);
    focusTarget.focus();
    if (action.endsWith('-click')) void oldCard.fire('click');
    else release();
    await pending;
    await tick();
    try {
      if (action === 'active-control') {
        assert.ok(modal.open, 'active lookup opens the actual size picker');
        assert.ok(modalBody.querySelector('#sale-sizes'), 'actual size controls present');
        assert.equal(document.activeElement, modalBody.querySelector('button'), 'active picker receives focus');
      } else {
        assert.equal(modal.open, false, 'retired lookup must not open the shared modal');
        assert.equal(modalBody.textContent, 'CURRENT ACCOUNT DIALOG', 'replacement dialog stays intact');
        assert.equal(root.textContent, 'CURRENT SCREEN', 'replacement screen stays intact');
        assert.equal(document.activeElement, focusTarget, 'replacement focus stays intact');
      }
      assert.equal(calls.filter(c => c.method === 'POST').length, 0, 'lookup never submits a sale');
    } finally {
      modal.close();
      handle.unmount();
    }
  });
}

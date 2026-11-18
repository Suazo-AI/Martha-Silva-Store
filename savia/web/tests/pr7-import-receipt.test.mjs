// Receipt and import regressions extracted from the shared PR7 findings fixture.
import assert from 'node:assert/strict';
import test from 'node:test';
import * as api from '../api.mjs';
import receipt from '../screens/receipt.mjs';
import importScreen from '../screens/import.mjs';

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
globalThis.location = { origin: 'http://fixture.invalid', hash: '#/' };
const document = new Element('document');
globalThis.document = document;
document.body = new Element('body');
document.append(document.body);
document.createElement = t => new Element(t);
document.createTextNode = t => new Element('#text', t);
document.getElementById = id => document.body.querySelector(`#${id}`);
globalThis.window = globalThis;
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const tick = async (n = 5) => {
  for (let i = 0; i < n; i++) await new Promise(r => setImmediate(r));
};
const held = () => {
  let release;
  const promise = new Promise(r => {
    release = (data, status = 200) => r(new Response(JSON.stringify(data), { status }));
  });
  return { promise, release };
};
const page = () => {
  const root = new Element('main');
  root.id = 'screen';
  const modal = new Element('dialog');
  modal.id = 'modal';
  const modalBody = new Element('div');
  modalBody.id = 'modal-body';
  modal.append(modalBody);
  document.body.replaceChildren(root, modal);
  api.setToken('session-A');
  return { root, modal, modalBody };
};
const sale = {
  saleId: id(20),
  receiptNumber: 'R-0001',
  status: 'posted',
  branchName: 'Fixture',
  createdAt: '2026-11-12T02:00:00Z',
  lines: [],
  subtotalMinor: 100,
  discountMinor: 0,
  totalMinor: 100,
  tenders: [{ tenderKind: 'card', amountMinor: 100 }],
};

// Codex PR7 receipt.mjs:15-17.
for (const action of ['active-control', 'navigation']) {
  test(`receipt response respects the screen lifecycle: ${action}`, async () => {
    const { root } = page();
    location.hash = `#/recibo?sale=${sale.saleId}`;
    const pending = held();
    globalThis.fetch = async url => {
      const p = String(url).replace('/api/v1', '');
      if (p === `/sales/${sale.saleId}`) return pending.promise;
      throw Error(`Unexpected request ${p}`);
    };
    let active = true;
    const mounted = receipt.mount(root, { isCurrent: () => active, go() {}, notify() {} });
    await tick();
    if (action !== 'active-control') {
      active = false;
      location.hash = '#/comisiones';
      root.textContent = 'CURRENT SCREEN';
    }
    pending.release(sale);
    await mounted;
    await tick();
    if (action === 'active-control') assert.match(root.textContent, /R-0001/, 'active receipt renders');
    else assert.equal(root.textContent, 'CURRENT SCREEN', 'late receipt must not replace the current screen');
  });
}

const summary = rowsCount => ({ rowsCount, validCount: rowsCount, errorCount: 0, unitsCount: 0, errors: [], sample: [] });

async function importFixture() {
  const { root, modalBody } = page();
  const previews = [];
  const posted = [];
  globalThis.fetch = async (url, opts = {}) => {
    const p = String(url).replace('/api/v1', '');
    const body = opts.body ? JSON.parse(opts.body) : null;
    if (p === '/catalog/import/file')
      return new Response(
        JSON.stringify({ fileName: 'f.csv', headers: ['Código de barras', 'Referencia (SKU)', 'Descripción'], rows: [['1', 'A', 'Blusa']] }),
      );
    if (p === '/catalog/import/preview') {
      const h = held();
      previews.push({ body, release: h.release });
      return h.promise;
    }
    if (p === '/catalog/import') {
      posted.push(body);
      return new Response(JSON.stringify({ batchId: body.batchId, itemsCreated: 1, unitsAdded: 0 }));
    }
    throw Error(`Unexpected request ${p}`);
  };
  await importScreen.mount(root, { isCurrent: () => true, go() {}, notify() {} });
  const input = root.querySelector('#import-file');
  input.files = [{ name: 'f.csv', arrayBuffer: async () => new Uint8Array([49]).buffer }];
  await input.fire('change');
  await tick();
  return { root, modalBody, previews, posted };
}

// Codex PR7 import.mjs:93-95.
test('import confirmation submits the request that produced the displayed preview', async () => {
  const { root, modalBody, previews, posted } = await importFixture();
  const first = root.querySelector('#import-preview-button').fire('click');
  const select = root.querySelector('select');
  select.value = '-1';
  await select.fire('change');
  const second = root.querySelector('#import-preview-button').fire('click');
  assert.equal(previews.length, 2, 'two previews in flight');
  previews[1].release(summary(222));
  await second;
  previews[0].release(summary(111));
  await first;
  const shown = root.querySelector('#import-rowsCount')?.textContent;
  const confirm = root.querySelector('#import-confirm');
  assert.ok(confirm, 'the displayed preview can be confirmed');
  const confirming = confirm.fire('click');
  await modalBody.querySelector('#confirm-yes').fire('click');
  await confirming;
  assert.equal(shown, '222', 'the stale older preview must not replace the newer one');
  assert.deepEqual(posted, [previews[1].body], 'confirmation sends the full request for the visible preview');
});

test('changing the mapping invalidates a pending preview without starting another request', async () => {
  const { root, previews } = await importFixture();
  const pending = root.querySelector('#import-preview-button').fire('click');
  const select = root.querySelector('select');
  select.value = '-1';
  await select.fire('change');
  previews[0].release(summary(111));
  await pending;
  assert.equal(root.querySelector('#import-preview').hidden, true);
});

test('a stale preview failure leaves the current preview and status alone', async () => {
  const { root, previews } = await importFixture();
  const button = root.querySelector('#import-preview-button');
  const first = button.fire('click');
  const second = button.fire('click');
  previews[1].release(summary(222));
  await second;
  previews[0].release({ title: 'Stale failure' }, 500);
  await first;
  assert.equal(root.querySelector('#import-rowsCount').textContent, '222');
  assert.equal(root.querySelector('#import-status').textContent, '');
});

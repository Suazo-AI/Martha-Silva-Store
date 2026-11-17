// Actual sale and shared modal modules; fictional HTTP and a minimal offline DOM.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import nodeTest from 'node:test';

const test = (name, fn) => nodeTest(name, { timeout: 3000 }, fn);

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
    if (k === 'checked') this.checked = true;
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
const intent = await load('savia/web/screens/return-intent.mjs');
const { default: returns } = await load('savia/web/screens/return.mjs');
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const actor = { staffId: id(1), nodeId: id(2), branchId: id(3), locationId: id(4), roles: ['MANAGER'] };
const tick = () => new Promise(r => setImmediate(r));
const key = 'savia.return.pending.v1';
const locks = new Set();
Object.defineProperty(globalThis, 'navigator', {
  configurable: true,
  value: {
    locks: {
      async request(name, options, fn) {
        if (locks.has(name)) return fn(null);
        locks.add(name);
        try {
          return await fn({ name });
        } finally {
          locks.delete(name);
        }
      },
    },
  },
});
// Exercise the actual shell context declarations without starting the whole router.
const shell = readFileSync('savia/web/app.mjs', 'utf8');
const rootStart = shell.indexOf('const ctx = {');
const rootEnd = shell.indexOf('\nlet current =', rootStart);
const routeStart = shell.indexOf('  const screenCtx = Object.create(ctx);');
const routeEnd = shell.indexOf("  $('access').hidden = true;", routeStart);
assert.ok(rootStart >= 0 && rootEnd > rootStart && routeStart >= 0 && routeEnd > routeStart);
const shellContext = new Function(
  'api',
  'device',
  'renderTillState',
  '$',
  'isApprover',
  'isOwner',
  `${shell.slice(rootStart, rootEnd)}\nreturn ctx;`,
);
const routeContext = new Function('ctx', 'isCurrent', `${shell.slice(routeStart, routeEnd)}\nreturn screenCtx;`);
async function fixture({ routed = false } = {}) {
  localStorage.clear();
  sessionStorage.clear();
  api.setToken('session-A');
  location.hash = `#/devolucion?sale=${id(5)}`;
  const root = new Element('main'),
    modal = new Element('dialog'),
    body = new Element('div');
  root.id = 'screen';
  modal.id = 'modal';
  body.id = 'modal-body';
  modal.append(body);
  document.body.replaceChildren(root, modal);
  const sale = {
    saleId: id(5),
    tillId: id(6),
    customerId: id(7),
    currencyCode: 'NIO',
    lines: [
      {
        saleLineId: id(8),
        lineNumber: 1,
        quantity: 3,
        returnedQuantity: 0,
        totalMinor: 300,
        unitPriceMinor: 100,
        sku: 'Fixture',
        itemId: id(9),
      },
    ],
    reversals: [],
  };
  const posts = [],
    calls = [],
    revoked = [],
    notices = [],
    cleanupNotices = [];
  let mode = 'loss',
    active = true,
    release;
  let sessionCtx;
  const ctx = routed
    ? (() => {
        const notice = {
          set textContent(text) {
            notices.push(text);
          },
        };
        const cleanupNotice = {
          set textContent(text) {
            cleanupNotices.push(text);
          },
        };
        sessionCtx = shellContext(
          api,
          { get: () => ({ tillId: id(6) }), set() {} },
          () => {},
          name => (name === 'approval-cleanup-notice' ? cleanupNotice : notice),
          roles => roles.includes('MANAGER'),
          roles => roles.includes('OWNER'),
        );
        sessionCtx.me = { ...actor, roles: [...actor.roles] };
        return routeContext(sessionCtx, () => active);
      })()
    : {
        me: { ...actor },
        isApprover: true,
        isCurrent: () => active,
        till: { get: () => ({ tillId: id(6) }), set() {} },
        notify(message) {
          notices.push(message);
        },
        go() {},
        refreshTill() {},
      };
  globalThis.fetch = async (url, opts = {}) => {
    const p = String(url).replace('/api/v1', '');
    calls.push(p);
    if (opts.method === 'POST' && p.includes('/returns/')) {
      posts.push(JSON.parse(opts.body));
      if (mode === 'hold') await new Promise(r => (release = r));
      if (mode === 'loss') throw Error('lost');
      if (mode === 'ok' || mode === 'wrongStatus') {
        const r = JSON.parse(localStorage.getItem(key));
        receipt({ sale }, r);
        return new Response(JSON.stringify(sale.reversals[0]), { status: mode === 'wrongStatus' ? 201 : 200 });
      }
      return new Response('{}');
    }
    let data;
    if (p === `/sales/${id(5)}`) {
      if (mode === 'holdLookup') await new Promise(r => (release = r));
      if (mode === '404') return new Response('{}', { status: 404 });
      data = sale;
    } else if (p === '/returns/policy') data = { windowDays: 30 };
    else if (p === '/sellers') data = [{ sellerId: id(1), name: 'Fixture' }];
    else if (p === '/cash/registers') data = [{ registerId: id(10), openTillId: id(6), openTillCashierId: id(1) }];
    else if (p.endsWith('/summary')) data = { tillId: id(6) };
    else if (p === '/cash/tills/current') data = { tillId: id(6) };
    else if (p === '/auth/login') {
      if (mode === 'holdApproval') await new Promise(r => (release = r));
      return new Response(JSON.stringify({ token: 'approval-fixture', roles: ['MANAGER'] }));
    } else if (p.startsWith('/catalog/lookup')) data = [{ itemId: id(12), sku: 'NEW', name: 'New fixture', unitPriceMinor: 100 }];
    else if (p === '/auth/logout') {
      revoked.push(opts.headers.Authorization);
      if (mode === 'logoutfail') return new Response('{}', { status: 500 });
      return new Response(null, { status: 204 });
    } else throw Error(`Unexpected ${p}`);
    return new Response(JSON.stringify(data), { status: mode === 'wrongGetStatus' && p.startsWith('/sales/') ? 201 : 200 });
  };
  let handle;
  const mount = async () => {
    handle?.unmount?.();
    handle = await returns.mount(root, ctx);
  };
  await mount();
  const input = async (s, v) => {
    const el = root.querySelector(s);
    assert.ok(el, s);
    el.value = v;
    await el.fire('input');
  };
  const prepare = async () => {
    await input('#return-qty-1', '1');
    await input('#return-reason', 'Fixture reason');
  };
  const submit = () => root.querySelector('form').fire('submit');
  const confirm = async () => {
    await tick();
    assert.ok(body.querySelector('#confirm-yes'));
    await body.querySelector('#confirm-yes').fire('click');
    await tick();
  };
  return {
    root,
    modal,
    body,
    ctx,
    sessionCtx,
    sale,
    posts,
    calls,
    revoked,
    notices,
    cleanupNotices,
    mount,
    input,
    prepare,
    submit,
    confirm,
    retire() {
      active = false;
      handle?.unmount?.();
    },
    release() {
      release();
    },
    mode(v) {
      mode = v;
    },
  };
}
test('lost response freezes immutable intent through edit and remount; 404 never unlocks', async () => {
  const f = await fixture();
  await f.prepare();
  const oldReason = f.root.querySelector('#return-reason'),
    oldForm = f.root.querySelector('form');
  const p = f.submit();
  await f.confirm();
  await p;
  const saved = localStorage.getItem(key);
  assert.ok(saved, 'durable intent exists after lost response');
  oldReason.value = 'Changed';
  await oldReason.fire('input');
  const p2 = oldForm.fire('submit');
  await tick();
  if (f.body.querySelector('#confirm-yes') && f.modal.open) await f.confirm();
  await p2;
  assert.equal(f.posts.length, 1, 'edits cannot create another return');
  f.calls.length = 0;
  await f.mount();
  assert.equal(f.calls.length, 0, 'recovery precedes dependencies');
  f.mode('404');
  await f.root.querySelector('#return-lookup').fire('click');
  assert.ok(localStorage.getItem(key), '404 preserves intent');
  assert.equal(f.posts.length, 1);
  assert.equal(JSON.parse(saved).body.reversalId, f.posts[0].reversalId);
});
test('account switch while confirmation is held cannot POST', async () => {
  const f = await fixture();
  await f.prepare();
  const p = f.submit();
  await tick();
  api.setToken('session-B');
  f.ctx.me = { ...actor, staffId: id(99) };
  await f.confirm();
  await p;
  assert.equal(f.posts.length, 0, 'retired confirmation must not POST');
});

async function lost(f) {
  await f.prepare();
  const p = f.submit();
  await f.confirm();
  await p;
  return JSON.parse(localStorage.getItem(key));
}
function receipt(f, r) {
  f.sale.reversals = [
    {
      creditId: null,
      ...r.body,
      kind: 'return',
      currencyCode: 'NIO',
      actorId: id(20),
      createdAt: '2026-11-16T12:00:00Z',
      status: 'approved',
      approvedBy: id(21),
      settlementKind: r.body.outcome ?? 'credit',
      creditMinor: 100,
      lines: r.expected,
    },
  ];
}
test('explicit replay after 404 keeps exact body; malformed 200 stays unresolved', async () => {
  const f = await fixture(),
    r = await lost(f);
  f.mode('404');
  await f.root.querySelector('#return-lookup').fire('click');
  f.mode('bad');
  const p = f.root.querySelector('#return-replay').fire('click');
  await f.confirm();
  await p;
  assert.equal(f.posts.length, 2);
  assert.deepEqual(f.posts[1], f.posts[0]);
  assert.equal(JSON.parse(localStorage.getItem(key)).state, 'unresolved');
  const retiredReplay = f.root.querySelector('#return-replay');
  receipt(f, r);
  await f.root.querySelector('#return-lookup').fire('click');
  assert.equal(JSON.parse(localStorage.getItem(key)).state, 'confirmed');
  await retiredReplay.fire('click');
  assert.equal(f.posts.length, 2, 'confirmed intent cannot replay');
});
test('wrong IDs, lines, credit, till and malformed receipt cannot confirm', async () => {
  const f = await fixture(),
    r = await lost(f);
  for (const change of [
    x => (x.reversalId = id(90)),
    x => (x.tillId = id(90)),
    x => (x.creditId = id(90)),
    x => (x.lines = []),
    x => (x.creditMinor = 999),
    x => (x.status = 'rejected'),
    x => (x.reason = 'other'),
    x => (x.approvedBy = null),
  ]) {
    receipt(f, r);
    change(f.sale.reversals[0]);
    await f.root.querySelector('#return-lookup').fire('click');
    assert.notEqual(JSON.parse(localStorage.getItem(key)).state, 'confirmed');
  }
});
test('storage denied, corrupt, and missing Web Locks block sending', async () => {
  for (const kind of ['denied', 'corrupt', 'no-lock']) {
    const f = await fixture();
    await f.prepare();
    const original = localStorage.setItem,
      nav = navigator.locks;
    if (kind === 'denied')
      localStorage.setItem = () => {
        throw Error('denied');
      };
    if (kind === 'corrupt') localStorage.setItem(key, '{');
    if (kind === 'no-lock') navigator.locks = null;
    try {
      await f.submit();
      assert.equal(f.posts.length, 0);
      assert.equal(f.modal.open, false);
    } finally {
      localStorage.setItem = original;
      navigator.locks = nav;
    }
  }
});
test('double submit while confirmation held sends zero; cancel removes never sent draft', async () => {
  const f = await fixture();
  await f.prepare();
  const p = f.submit();
  await tick();
  await f.submit();
  await f.body.querySelector('#confirm-no').fire('click');
  await p;
  assert.equal(f.posts.length, 0);
  assert.equal(localStorage.getItem(key), null);
  assert.ok(f.root.querySelector('form'));
});
test('foreign actor recovery is generic and loads no dependencies', async () => {
  const f = await fixture(),
    r = await lost(f);
  f.ctx.me = { ...actor, staffId: id(99) };
  api.setToken('session-B');
  f.calls.length = 0;
  await f.mount();
  assert.equal(f.calls.length, 0);
  assert.equal(f.root.textContent.includes(r.body.reversalId), false);
  assert.equal(f.root.querySelector('#return-replay'), null);
});
test('late POST and lookup cannot render or clear after retirement', async () => {
  for (const phase of ['post', 'lookup']) {
    const f = await fixture();
    let p;
    if (phase === 'post') {
      await f.prepare();
      f.mode('hold');
      p = f.submit();
      await f.confirm();
    } else {
      await lost(f);
      f.mode('holdLookup');
      p = f.root.querySelector('#return-lookup').fire('click');
      await tick();
    }
    f.retire();
    f.root.textContent = 'CURRENT SCREEN';
    f.release();
    await p;
    assert.equal(f.root.textContent, 'CURRENT SCREEN');
    assert.ok(localStorage.getItem(key));
  }
});
test('competing mounts cannot replace durable reservation; readback failure and tamper fail closed', async () => {
  const f = await fixture(),
    r = await lost(f);
  await assert.rejects(() => intent.withIntentLock(() => intent.reserveIntent(r)));
  const raw = localStorage.getItem(key);
  assert.equal(raw, JSON.stringify(r));
  const fake = { getItem: () => null, setItem() {} };
  assert.throws(() => intent.reserveIntent(r, fake));
  for (const mutate of [x => (x.body.token = 'SECRET'), x => (x.scope.staffId = 'bad'), x => (x.expected[0].creditMinor = -1)]) {
    const c = structuredClone(r);
    mutate(c);
    assert.throws(() => intent.validateIntent(c));
  }
});

test('all supported outcomes reserve complete bodies and preserve exact replay', async () => {
  for (const outcome of ['cash', 'transfer', 'exchange', 'credit']) {
    const f = await fixture();
    await f.prepare();
    await f.root.querySelector(`#outcome-${outcome}`).fire('change');
    if (outcome === 'transfer') await f.input('#return-reference', 'DEMO REF');
    if (outcome === 'exchange') {
      f.root.querySelector('#exchange-seller').value = id(1);
      await f.input('#exchange-code', 'NEW');
      await f.root.querySelector('#exchange-add').fire('click');
    }
    const p = f.submit();
    await f.confirm();
    await p;
    assert.equal(f.posts.length, 1, f.root.textContent);
    const r = JSON.parse(localStorage.getItem(key));
    assert.deepEqual(r.body, f.posts[0]);
    assert.equal(r.body.outcome ?? 'credit', outcome);
    f.calls.length = 0;
    await f.mount();
    assert.equal(f.calls.length, 0);
    const replay = f.root.querySelector('#return-replay').fire('click');
    await f.confirm();
    await replay;
    assert.deepEqual(f.posts[1], f.posts[0]);
    if (outcome === 'exchange') {
      receipt(f, r);
      await f.root.querySelector('#return-lookup').fire('click');
      assert.notEqual(JSON.parse(localStorage.getItem(key)).state, 'confirmed');
    }
  }
});
test('temporary approval revoked on failed POST and late approval; cashier session retained', async () => {
  for (const retire of [false, true]) {
    const f = await fixture();
    f.ctx.isApprover = false;
    await f.prepare();
    const p = f.submit();
    await f.confirm();
    assert.ok(f.body.querySelector('#approval-user'));
    f.body.querySelector('#approval-user').value = 'Fixture';
    f.body.querySelector('#approval-pass').value = 'Fixture';
    if (retire) f.mode('holdApproval');
    const login = f.body.querySelector('form').fire('submit');
    await tick();
    if (retire) {
      f.retire();
      f.body.textContent = 'CURRENT DIALOG';
      f.release();
    }
    await login;
    await p;
    assert.ok(f.revoked.includes('Bearer approval-fixture'));
    assert.equal(api.getToken(), 'session-A');
    assert.equal(f.posts.length, retire ? 0 : 1);
    if (retire) assert.equal(f.body.textContent, 'CURRENT DIALOG');
    assert.equal(localStorage.getItem(key).includes('approval-fixture'), false);
  }
});

test('cancelled approval cannot close or authorize a replacement dialog', async () => {
  const f = await fixture();
  f.ctx.isApprover = false;
  await f.prepare();
  const p = f.submit();
  await f.confirm();
  f.mode('holdApproval');
  const login = f.body.querySelector('form').fire('submit');
  await tick();
  const cancel = f.body.querySelectorAll('button').find(b => b.textContent === 'Cancelar');
  await cancel.fire('click');
  await p;
  f.body.textContent = 'REPLACEMENT DIALOG';
  f.modal.showModal();
  f.release();
  await login;
  assert.equal(f.body.textContent, 'REPLACEMENT DIALOG');
  assert.equal(f.modal.open, true);
  assert.equal(f.posts.length, 0);
  assert.equal(f.revoked.length, 1);
});
test('held origin lock rejects a competing mount submit without allocating or sending', async () => {
  const f = await fixture();
  await f.prepare();
  const p = f.submit();
  await tick();
  const raw = localStorage.getItem(key);
  const otherRoot = new Element('main');
  document.body.append(otherRoot);
  const h = await returns.mount(otherRoot, f.ctx);
  assert.ok(otherRoot.querySelector('#return-replay'));
  await otherRoot.querySelector('#return-replay').fire('click');
  assert.equal(localStorage.getItem(key), raw);
  assert.equal(f.posts.length, 0);
  await f.body.querySelector('#confirm-no').fire('click');
  await p;
  h.unmount();
  assert.equal(f.posts.length, 0);
});

test('F2 rejects malformed reversal fields independently', async () => {
  for (const mutate of [
    x => (x.kind = 'cancel'),
    x => (x.currencyCode = 'USD'),
    x => (x.actorId = 'bad'),
    x => (x.createdAt = 'invalid'),
    x => (x.creditMinor = Number.MAX_SAFE_INTEGER + 1),
    x => x.lines.push({ ...x.lines[0] }),
  ]) {
    const f = await fixture(),
      r = await lost(f);
    receipt(f, r);
    mutate(f.sale.reversals[0]);
    await f.root.querySelector('#return-lookup').fire('click');
    assert.notEqual(JSON.parse(localStorage.getItem(key)).state, 'confirmed');
  }
});
test('F1 exact successful exchange POST and explicit replay confirm durably', async () => {
  for (const replay of [false, true]) {
    const f = await fixture();
    await f.prepare();
    await f.root.querySelector('#outcome-exchange').fire('change');
    f.root.querySelector('#exchange-seller').value = id(1);
    await f.input('#exchange-code', 'NEW');
    await f.root.querySelector('#exchange-add').fire('click');
    f.mode(replay ? 'loss' : 'ok');
    const p = f.submit();
    await f.confirm();
    await p;
    if (replay) {
      f.mode('ok');
      const p2 = f.root.querySelector('#return-replay').fire('click');
      await f.confirm();
      await p2;
      assert.deepEqual(f.posts[1], f.posts[0]);
    }
    assert.equal(JSON.parse(localStorage.getItem(key)).state, 'confirmed');
    assert.ok(f.root.querySelector('#return-finish'));
    await f.mount();
    assert.ok(f.root.querySelector('#return-finish'));
    assert.match(f.root.textContent, /100|1.00/);
  }
});

test('F1 wrong POST status stays unresolved; API default return shape preserved', async () => {
  const f = await fixture();
  await f.prepare();
  f.mode('wrongStatus');
  const p = f.submit();
  await f.confirm();
  await p;
  assert.equal(JSON.parse(localStorage.getItem(key)).state, 'unresolved');
  assert.equal(f.root.querySelector('#return-cancel'), null);
  assert.equal((await api.getSale(id(5))).saleId, id(5));
});
test('F3 remounted draft cancellation verifies removal and restores editable form', async () => {
  const f = await fixture();
  await f.prepare();
  const p = f.submit();
  await tick();
  f.retire();
  await p;
  // Same session remount with fresh current ownership.
  f.ctx.isCurrent = () => true;
  await f.mount();
  assert.ok(f.root.querySelector('#return-cancel'));
  await f.root.querySelector('#return-cancel').fire('click');
  assert.equal(localStorage.getItem(key), null);
  assert.ok(f.root.querySelector('#return-reason'));
  assert.equal(f.posts.length, 0);
});
test('F3 cancellation cannot clear a competitor or sending record; removal failure retains editing lock', async () => {
  const f = await fixture(),
    r = await lost(f);
  assert.throws(() => intent.cancelDraft(r));
  const draft = { ...r, state: 'draft' };
  localStorage.setItem(key, JSON.stringify(draft));
  const other = { ...draft, body: { ...draft.body, reason: 'competitor' } };
  localStorage.setItem(key, JSON.stringify(other));
  assert.throws(() => intent.cancelDraft(draft));
  assert.equal(localStorage.getItem(key), JSON.stringify(other));
  localStorage.setItem(key, JSON.stringify(draft));
  const remove = localStorage.removeItem;
  localStorage.removeItem = () => {};
  try {
    assert.throws(() => intent.cancelDraft(draft));
    assert.ok(localStorage.getItem(key));
  } finally {
    localStorage.removeItem = remove;
  }
});
test('F5 retirement revokes immediately during held POST, single shot even on failed logout', async () => {
  for (const fail of [false, true]) {
    const f = await fixture();
    f.ctx.isApprover = false;
    await f.prepare();
    const p = f.submit();
    await f.confirm();
    f.mode('hold');
    const login = f.body.querySelector('form').fire('submit');
    await tick();
    await login;
    assert.equal(f.posts.length, 1);
    if (fail) f.mode('logoutfail');
    f.retire();
    await tick();
    assert.equal(f.revoked.length, 1);
    if (fail) assert.match(f.notices.join(' '), /temporal/);
    f.release();
    await p;
    assert.equal(f.revoked.length, 1);
    assert.ok(localStorage.getItem(key));
    assert.equal(localStorage.getItem(key).includes('approval-fixture'), false);
  }
});
test('F4 ordinary outcomes preserve monetary result and receipts through reload without refresh', async () => {
  for (const outcome of ['credit', 'cash', 'transfer']) {
    const f = await fixture();
    await f.prepare();
    await f.root.querySelector(`#outcome-${outcome}`).fire('change');
    if (outcome === 'transfer') await f.input('#return-reference', 'REF-123');
    f.mode('ok');
    const p = f.submit();
    await tick();
    assert.match(f.body.textContent, /1.00/);
    await f.confirm();
    await p;
    assert.equal(JSON.parse(localStorage.getItem(key)).state, 'confirmed');
    const result = f.root.querySelector('#return-result').textContent;
    assert.match(result, /1.00/);
    if (outcome === 'transfer') assert.match(result, /REF-123/);
    f.calls.length = 0;
    await f.mount();
    assert.equal(f.root.querySelector('#return-result').textContent, result);
    assert.equal(f.calls.length, 0);
    assert.ok(f.root.querySelector('a'));
  }
});
test('F2 legacy missing currency remains recoverable but cannot confirm or fabricate expectations', async () => {
  const f = await fixture(),
    r = await lost(f);
  delete r.currencyCode;
  localStorage.setItem(key, JSON.stringify(r));
  await f.mount();
  receipt(f, r);
  await f.root.querySelector('#return-lookup').fire('click');
  assert.notEqual(JSON.parse(localStorage.getItem(key)).state, 'confirmed');
  assert.equal(JSON.parse(localStorage.getItem(key)).currencyCode, undefined);
});
test('F2 validator accepts unordered exact lines and different supervisor; rejects malformed fields', async () => {
  const f = await fixture(),
    r = await lost(f);
  r.body.lines.push({ ...r.body.lines[0], saleLineId: id(30) });
  r.expected.push({ ...r.expected[0], saleLineId: id(30) });
  receipt(f, r);
  const x = f.sale.reversals[0];
  x.creditMinor = 200;
  x.lines = [...r.expected].reverse();
  assert.ok(intent.validReversal(x, r));
  for (const mutate of [
    v => (v.kind = null),
    v => (v.currencyCode = null),
    v => (v.actorId = null),
    v => (v.createdAt = null),
    v => (v.approvedBy = 'bad'),
    v => (v.creditMinor = 0),
    v => (v.creditMinor = 1.5),
    v => v.lines[0].quantity++,
    v => (v.lines[0].restockPool = 'bad'),
    v => v.lines[0].creditMinor++,
    v => (v.lines[0].saleLineId = id(88)),
    v => v.lines.pop(),
    v => (v.creditId = null),
    v => (v.tillId = id(88)),
    v => (v.reversalId = id(88)),
  ]) {
    const y = structuredClone(x);
    mutate(y);
    assert.equal(intent.validReversal(y, r), false);
  }
  assert.equal(intent.validReversal([], r), false);
  assert.equal(intent.validReversal(null, r), false);
});

test('GET wrong HTTP status cannot confirm a matching ordinary reversal', async () => {
  const f = await fixture(),
    r = await lost(f);
  receipt(f, r);
  f.mode('wrongGetStatus');
  await f.root.querySelector('#return-lookup').fire('click');
  assert.notEqual(JSON.parse(localStorage.getItem(key)).state, 'confirmed');
});
test('ack cannot confirm after durable ownership changes during held POST', async () => {
  const f = await fixture();
  await f.prepare();
  f.mode('hold');
  const p = f.submit();
  await f.confirm();
  const r = JSON.parse(localStorage.getItem(key));
  assert.equal(r.state, 'sending');
  r.body.reason = 'competing operation';
  localStorage.setItem(key, JSON.stringify(r));
  const raw = localStorage.getItem(key);
  f.mode('ok');
  f.release();
  await p;
  assert.equal(localStorage.getItem(key), raw);
  assert.equal(f.root.querySelector('#return-finish'), null);
});
test('F4 exchange due/back and tender references come from captured body', async () => {
  for (const price of [50, 150]) {
    const f = await fixture(),
      r = await lost(f);
    r.endpoint = 'outcome';
    delete r.body.creditId;
    delete r.body.customerId;
    r.body.outcome = 'exchange';
    r.body.exchangeSaleId = id(44);
    r.body.newLines = [{ lineNumber: 1, itemId: id(45), quantity: 1, unitPriceMinor: price, discountMinor: 0, sellerId: id(1) }];
    r.body.newTenders = price > 100 ? [{ tenderNumber: 1, tenderKind: 'transfer', amountMinor: 50, reference: 'PAY-REF' }] : [];
    if (price < 100) {
      r.body.differenceKind = 'transfer';
      r.body.differenceReference = 'BACK-REF';
    }
    localStorage.setItem(key, JSON.stringify(r));
    await f.mount();
    const result = f.root.querySelector('#return-result').textContent;
    assert.match(result, /0.50/);
    assert.ok(result.includes(price > 100 ? 'PAY-REF' : 'BACK-REF'));
    assert.match(result, /La clienta paga/);
    assert.match(result, /Se devuelve/);
  }
});
test('invalid calendar date cannot confirm', async () => {
  const f = await fixture(),
    r = await lost(f);
  receipt(f, r);
  f.sale.reversals[0].createdAt = '2026-02-31T12:00:00Z';
  assert.equal(intent.validReversal(f.sale.reversals[0], r), false);
});

test('F5 approval cleanup precedes a held lookup and retirement', async () => {
  const f = await fixture();
  f.ctx.isApprover = false;
  await f.prepare();
  const p = f.submit();
  await f.confirm();
  const login = f.body.querySelector('form').fire('submit');
  await login;
  await p;
  assert.equal(f.revoked.length, 1);
  f.mode('holdLookup');
  const lookup = f.root.querySelector('#return-lookup').fire('click');
  await tick();
  f.retire();
  assert.equal(f.revoked.length, 1);
  f.release();
  await lookup;
  assert.equal(f.revoked.length, 1);
  assert.ok(localStorage.getItem(key));
});

test('CF1 routed initial return uses inherited actor and role getters', async () => {
  const f = await fixture({ routed: true });
  assert.equal(Object.hasOwn(f.ctx, 'me'), false);
  assert.ok(f.root.querySelector('#return-reason'), 'open till must render an editable return');
  await f.prepare();
  f.mode('ok');
  const p = f.submit();
  await f.confirm();
  await p;
  assert.equal(f.posts.length, 1);
  assert.equal(JSON.parse(localStorage.getItem(key)).state, 'confirmed');
});
for (const action of ['draft-cancel', 'replay-confirm-cancel'])
  test(`CF1 routed ${action} restores editable form without POST`, async () => {
    // Mount with a durable draft first so initial-mount failure cannot hide cancellation.
    const f = await fixture();
    await f.prepare();
    const oldForm = f.root.querySelector('form');
    const p = f.submit();
    await tick();
    await f.mount();
    await p;
    const parent = {
      me: f.ctx.me,
      get isApprover() {
        return true;
      },
    };
    delete f.ctx.me;
    delete f.ctx.isApprover;
    Object.setPrototypeOf(f.ctx, parent);
    await f.mount();
    if (action === 'draft-cancel') await f.root.querySelector('#return-cancel').fire('click');
    else {
      const retry = f.root.querySelector('#return-replay').fire('click');
      await tick();
      await f.body.querySelector('#confirm-no').fire('click');
      await retry;
    }
    assert.equal(localStorage.getItem(key), null);
    assert.equal(f.posts.length, 0);
    assert.ok(f.root.querySelector('#return-reason'), 'draft cancellation must restore inherited context');
    await oldForm.fire('submit');
    assert.equal(f.posts.length, 0, 'cancelled form cannot submit late');
  });

test('CF2 routed retirement reports generic cleanup failure while suppressing stale notices', async () => {
  const f = await fixture({ routed: true });
  // Own enumerable actor fields isolate CF2 from the separately reproduced CF1.
  if (!f.root.querySelector('#return-reason')) {
    Object.defineProperty(f.ctx, 'me', { value: f.sessionCtx.me, enumerable: true, configurable: true });
    Object.defineProperty(f.ctx, 'isApprover', { value: true, writable: true, enumerable: true, configurable: true });
    await f.mount();
  }
  f.sessionCtx.me.roles = ['CASHIER'];
  if (Object.hasOwn(f.ctx, 'isApprover')) f.ctx.isApprover = false;
  await f.prepare();
  const p = f.submit();
  await f.confirm();
  f.mode('hold');
  await f.body.querySelector('form').fire('submit');
  await tick();
  assert.equal(f.posts.length, 1);
  f.mode('logoutfail');
  f.retire();
  f.ctx.notify('STALE PRIVATE DETAILS');
  await tick();
  f.release();
  await p;
  assert.equal(f.revoked.length, 1);
  assert.match(f.cleanupNotices.join(' '), /temporal/);
  assert.equal(
    f.notices.some(x => x.includes('STALE PRIVATE DETAILS')),
    false,
  );
  assert.equal(
    f.cleanupNotices.some(x => x.includes('approval-fixture') || x.includes(id(5))),
    false,
  );
  assert.equal(
    f.notices.some(x => x.includes('temporal')),
    false,
    'cleanup warning must not use the private route notice',
  );
  assert.equal(JSON.parse(localStorage.getItem(key)).state, 'sending');
});

test('CF2-R1 clearing private route notices preserves only the fixed cleanup warning', () => {
  const privateNotice = { textContent: '' },
    cleanupNotice = { textContent: '' };
  const ctx = shellContext(
    api,
    { get: () => ({}), set() {} },
    () => {},
    name => {
      assert.ok(['notice', 'approval-cleanup-notice'].includes(name));
      return name === 'notice' ? privateNotice : cleanupNotice;
    },
    () => false,
    () => false,
  );
  ctx.notify('PRIVATE OLD ACTOR');
  ctx.reportApprovalCleanupFailure('PRIVATE APPROVAL TOKEN');
  ctx.notify('');
  assert.equal(privateNotice.textContent, '');
  assert.equal(cleanupNotice.textContent, 'No se pudo cerrar la autorización temporal. Pida revisión a la gerente.');
  assert.equal(cleanupNotice.textContent.includes('PRIVATE'), false);
  ctx.reportApprovalCleanupFailure();
  assert.equal(cleanupNotice.textContent, 'No se pudo cerrar la autorización temporal. Pida revisión a la gerente.');
});

for (const outcome of ['credit', 'exchange'])
  test(`PRIMARY-BROWSER-01 verified ${outcome} replay clears an earlier unresolved lookup warning`, async () => {
    const f = await fixture(),
      r = await lost(f);
    if (outcome === 'exchange') {
      r.endpoint = 'outcome';
      delete r.body.creditId;
      delete r.body.customerId;
      r.body.outcome = 'exchange';
      r.body.exchangeSaleId = id(44);
      r.body.newLines = [{ lineNumber: 1, itemId: id(45), quantity: 1, unitPriceMinor: 100, discountMinor: 0, sellerId: id(1) }];
      r.body.newTenders = [];
      localStorage.setItem(key, JSON.stringify(r));
      await f.mount();
    }
    f.mode('404');
    await f.root.querySelector('#return-lookup').fire('click');
    assert.ok(f.root.querySelector('#return-status').textContent);
    f.mode('bad');
    const bad = f.root.querySelector('#return-replay').fire('click');
    await f.confirm();
    await bad;
    assert.ok(f.root.querySelector('#return-status').textContent, 'failed replay must retain uncertainty');
    f.mode('ok');
    const good = f.root.querySelector('#return-replay').fire('click');
    await f.confirm();
    await good;
    assert.equal(JSON.parse(localStorage.getItem(key)).state, 'confirmed');
    assert.equal(f.root.querySelector('#return-status').textContent, '');
  });

test('PRIMARY-BROWSER-01 exact ordinary receipt lookup clears uncertainty without POST', async () => {
  const f = await fixture(),
    r = await lost(f);
  f.mode('404');
  await f.root.querySelector('#return-lookup').fire('click');
  assert.ok(f.root.querySelector('#return-status').textContent);
  receipt(f, r);
  f.mode('ok');
  await f.root.querySelector('#return-lookup').fire('click');
  assert.equal(JSON.parse(localStorage.getItem(key)).state, 'confirmed');
  assert.equal(f.root.querySelector('#return-status').textContent, '');
  assert.equal(f.posts.length, 1);
});

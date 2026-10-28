import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {mountStaffApp} from './app.mjs';
import {createStaffClient} from './client.mjs';
import {StaffRequestError} from './login.mjs';
const {JSDOM} = createRequire(import.meta.url)('jsdom');

// Written compatibility tests with DOM/transport doubles; no server, SQL or browser.
const html = await readFile(new URL('./index.html', import.meta.url), 'utf8');
const identity = role => ({id: 'b5af9f41-78b6-4a21-9b6a-d07c29a67076',
  loginName: 'test.staff', displayName: 'Synthetic staff', role, enabled: true,
  version: '31f2bab2-9872-4b5f-bb24-09d7c2b57a30'});
const emptyPage = () => ({items: [], total: 0, skip: 0, take: 50});
const json = (value, status = 200) => new Response(JSON.stringify(value),
  {status, headers: {'Content-Type': 'application/json; charset=utf-8'}});
function setup(t, role, overrides = {}) {
  const dom = new JSDOM(html, {url: 'https://staff.example.invalid/internal/', runScripts: 'outside-only'});
  const counts = {customers: 0, items: 0};
  const client = {getSession: async () => identity(role),
    listCustomers: async () => { counts.customers++; return emptyPage(); },
    listItems: async () => { counts.items++; return emptyPage(); },
    logout: async () => {}, ...overrides};
  const app = mountStaffApp({document: dom.window.document, client, redirect: () => {}});
  t.after(() => { app.destroy(); dom.window.close(); });
  return {app, document: dom.window.document, window: dom.window, counts};
}
for (const role of ['Manager', 'Cashier', 'Inventory']) {
  test(`${role} opens items and cannot trigger a customer read through hidden controls`, async t => {
    const {app, document, window, counts} = setup(t, role);
    await app.ready;
    assert.equal(app.getState().authenticated, true);
    assert.equal(app.getState().view, 'inventario');
    assert.equal(counts.customers, 0);
    assert.equal(counts.items, 1);
    const nav = document.querySelector('[data-action="nav"][data-target="clientes"]');
    assert.equal(nav.hidden, true);
    assert.equal(nav.disabled, true);
    assert.equal(document.querySelector('[data-view="clientes"]').hidden, true);
    assert.equal(document.querySelector('#clients-search').disabled, true);
    assert.equal(app.navigate('clientes'), false);
    assert.equal(app.getState().view, 'inventario');
    // Synthetic events can reach listeners even on hidden forms: the read guard
    // must hold independently from the disabled navigation control.
    document.querySelector('#clients-search-form').dispatchEvent(
      new window.Event('submit', {bubbles: true, cancelable: true}));
    document.querySelector('[data-page-next="clientes"]').click();
    await app.refresh();
    assert.equal(counts.customers, 0);
    assert.equal(counts.items, 2);
    assert.equal(document.querySelector('[data-action="logout"]').disabled, false);
  });
  test(`${role} client refuses both Party feeds before transport but retains catalog reads`, async () => {
    const reads = [];
    const client = createStaffClient({fetchImpl: async path => {
      reads.push(path);
      if (path === '/internal/api/security/me') return json(identity(role));
      assert.match(path, /^\/internal\/api\/directory\/items\?/);
      return json(emptyPage());
    }});
    await client.getSession();
    await assert.rejects(client.listCustomers(), error => error.status === 403);
    await assert.rejects(client.listSuppliers(), error => error.status === 403);
    assert.equal(reads.length, 1);
    assert.deepEqual(await client.listItems(), emptyPage());
    assert.equal(reads.length, 2);
    assert.equal(reads.some(path => path.includes('/parties')), false);
  });
}
test('Owner opens customers and a later server denial is an error, not empty success', async t => {
  let calls = 0;
  const {app, document, counts} = setup(t, 'Owner', {listCustomers: async () => {
    if (++calls > 1) throw new StaffRequestError('forbidden', 403);
    return emptyPage();
  }});
  await app.ready;
  assert.equal(app.getState().view, 'clientes');
  assert.equal(calls, 1);
  assert.equal(counts.items, 0);
  assert.equal(document.querySelector('[data-action="nav"][data-target="clientes"]').hidden, false);
  await app.refresh();
  assert.equal(calls, 2);
  assert.equal(document.querySelector('#clients-error').hidden, false);
  assert.equal(document.querySelector('#clients-empty').hidden, true);
  assert.equal(app.getState().authenticated, true);
});
test('missing verified session keeps 401 and makes no Party request', async () => {
  let calls = 0;
  const client = createStaffClient({fetchImpl: async () => { calls++; throw new Error('No transport expected'); }});
  await assert.rejects(client.listCustomers(), error => error.status === 401);
  await assert.rejects(client.listSuppliers(), error => error.status === 401);
  assert.equal(calls, 0);
});
test('Owner client still uses the existing authenticated Party contracts', async () => {
  const reads = [];
  const client = createStaffClient({fetchImpl: async path => {
    reads.push(path);
    return json(path === '/internal/api/security/me' ? identity('Owner') : emptyPage());
  }});
  await client.getSession();
  await client.listCustomers();
  await client.listSuppliers();
  const partyReads = reads.slice(1).map(path => new URL(path, 'https://staff.example.invalid'));
  assert.equal(partyReads.length, 2);
  assert.ok(partyReads.every(url => url.pathname === '/internal/api/directory/parties'));
  assert.deepEqual(partyReads.map(url => url.searchParams.get('kind')), ['customer', 'supplier']);
});

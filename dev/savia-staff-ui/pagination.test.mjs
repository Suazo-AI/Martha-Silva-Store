import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {createStaffClient} from './client.mjs';
import {mountStaffApp} from './app.mjs';
import {StaffRequestError} from './login.mjs';
const {JSDOM} = createRequire(import.meta.url)('jsdom');

// Synthetic transport and DOM doubles only; no server, SQL or browser is used.
const staff = {id: 'b5af9f41-78b6-4a21-9b6a-d07c29a67076', loginName: 'test.staff',
  displayName: 'Personal de prueba', role: 'Owner', enabled: true,
  version: '31f2bab2-9872-4b5f-bb24-09d7c2b57a30'};
const customer = index => ({id: `18b9320a-2075-41cd-88a0-${String(index + 1).padStart(12, '0')}`,
  name: `Cliente de prueba ${index + 1}`, kind: 'customer', email: null, phone: null, active: true});
const json = (value, status = 200) => new Response(JSON.stringify(value),
  {status, headers: {'Content-Type': 'application/json; charset=utf-8'}});
const html = await readFile(new URL('./index.html', import.meta.url), 'utf8');
function page({skip = 0, take = 50, total = 132} = {}) {
  return {items: Array.from({length: Math.max(0, Math.min(take, total - skip))}, (_, i) => customer(skip + i)),
    total, skip, take};
}
function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return {promise, resolve, reject};
}
async function until(predicate, message) {
  for (let turn = 0; turn < 40; turn++) {
    if (predicate()) return;
    await new Promise(resolve => setImmediate(resolve));
  }
  assert.fail(message);
}
function transportFor(reply) {
  const reads = [];
  return {reads, fetchImpl: async (path, options) => {
    assert.equal(options.method, 'GET', 'Pagination must never send a mutation');
    if (path === '/internal/api/security/me') return json(staff);
    const url = new URL(path, 'https://staff.example.invalid');
    assert.match(url.pathname, /^\/internal\/api\/directory\/(parties|items)$/);
    reads.push(url);
    return reply(url, reads.length);
  }};
}
function directoryPage(url, total = 132) {
  const result = page({skip: Number(url.searchParams.get('skip')), take: Number(url.searchParams.get('take')), total});
  if (url.pathname.endsWith('/items')) result.items = result.items.map((row, index) => ({
    id: row.id, name: `Articulo de prueba ${result.skip + index + 1}`, active: true,
    sku: `TEST-${result.skip + index + 1}`, unitPriceMinor: 1250, currency: 'USD',
  }));
  return result;
}
function setup(t, transport) {
  const dom = new JSDOM(html, {url: 'https://staff.example.invalid/internal/', runScripts: 'outside-only'});
  const document = dom.window.document;
  const client = createStaffClient(transport);
  const app = mountStaffApp({document, client, redirect: () => assert.fail('Pagination must not redirect')});
  t.after(() => { app.destroy(); dom.window.close(); });
  return {app, document, client};
}

test('Directory pagination sends the applied query, inactive flag and explicit skip/take', async () => {
  const transport = transportFor(url => json(page({skip: Number(url.searchParams.get('skip')),
    take: Number(url.searchParams.get('take'))})));
  const client = createStaffClient(transport);
  await client.getSession();
  const result = await client.listCustomers({q: '  Aguja & hilo  ', includeInactive: true, skip: 25, take: 25});
  assert.equal(result.skip, 25);
  assert.equal(result.take, 25);
  assert.equal(result.items.length, 25);
  assert.equal(result.items[0].name, 'Cliente de prueba 26');
  assert.deepEqual(Object.fromEntries(transport.reads[0].searchParams),
    {includeInactive: 'true', skip: '25', take: '25', q: 'Aguja & hilo', kind: 'customer'});
  await client.listItems({q: '   ', skip: 100000, take: 100});
  assert.equal(transport.reads[1].searchParams.has('q'), false);
  assert.equal(transport.reads[1].searchParams.get('skip'), '100000');
  assert.equal(transport.reads[1].searchParams.get('take'), '100');
});

test('invalid query bounds are rejected before Directory transport', async () => {
  let reads = 0;
  const client = createStaffClient({fetchImpl: async path => {
    if (path === '/internal/api/security/me') return json(staff);
    reads++; return json(page());
  }});
  await client.getSession();
  const invalid = [
    ...[-1, 100001, 1.5, '0'].map(skip => ({skip})),
    ...[0, 101, 1.5, '50'].map(take => ({take})),
    {q: 'x'.repeat(201)}, {q: null}, {includeInactive: 'true'},
  ];
  for (const options of invalid) {
    await assert.rejects(client.listCustomers(options), error => error instanceof StaffRequestError && error.code === 'invalid');
  }
  assert.equal(reads, 0);
});

test('inconsistent response pages are rejected, but an empty page beyond the total is valid', async () => {
  let response = page({skip: 50, take: 25});
  const client = createStaffClient({fetchImpl: async path => json(path === '/internal/api/security/me' ? staff : response)});
  await client.getSession();
  const options = {skip: 50, take: 25};
  const invalid = [
    {...response, skip: 0}, {...response, take: 50}, {...response, skip: 100001},
    {...response, take: 0}, {...response, take: 101}, {...response, total: 74},
    {...response, total: 1.5}, {...response, items: [...response.items, customer(75)]},
  ];
  for (const value of invalid) {
    response = value;
    await assert.rejects(client.listCustomers(options), error => error instanceof StaffRequestError && error.code === 'response');
  }
  response = page({skip: 50, take: 25, total: 12});
  const empty = await client.listCustomers(options);
  assert.deepEqual(empty.items, []);
  assert.equal(empty.total, 12);
});

test('next/previous, applied search and sizes 25/50/100 navigate real Directory pages without enabling writes', async t => {
  const transport = transportFor(url => json(directoryPage(url)));
  const {app, document} = setup(t, transport);
  const $ = selector => document.querySelector(selector);
  const control = (action, target = 'clientes') => $(`[data-action="${action}"][data-target="${target}"]`);
  const submit = selector => $(selector).dispatchEvent(new document.defaultView.Event('submit', {bubbles: true, cancelable: true}));
  async function act(action, prefix = 'clients') {
    const expectedReads = transport.reads.length + 1;
    action();
    await until(() => transport.reads.length === expectedReads && !$(`#${prefix}-page-size`).disabled,
      'The confirmed page must restore its page-size control');
  }
  const last = () => transport.reads.at(-1).searchParams;
  function changeSize(value, prefix = 'clients') {
    $(`#${prefix}-page-size`).value = String(value);
    $(`#${prefix}-page-size`).dispatchEvent(new document.defaultView.Event('change', {bubbles: true}));
  }
  await app.ready;
  assert.equal(last().get('skip'), '0');
  assert.equal(last().get('take'), '50');
  assert.equal($('#clients-rows').children.length, 50);
  assert.equal(control('page-prev').disabled, true);
  assert.equal(control('page-next').disabled, false);
  await act(() => control('page-next').click());
  assert.equal(last().get('skip'), '50');
  assert.match($('#clients-rows').firstElementChild.textContent, /Cliente de prueba 51/);
  $('#clients-search').value = 'borrador sin aplicar';
  $('#clients-search').dispatchEvent(new document.defaultView.Event('input', {bubbles: true}));
  const confirmedReads = transport.reads.length;
  assert.equal(control('page-next').disabled, true, 'An unapplied search must not be mixed with an old offset');
  control('page-next').click();
  assert.equal(transport.reads.length, confirmedReads);
  $('#clients-search').value = '';
  $('#clients-search').dispatchEvent(new document.defaultView.Event('input', {bubbles: true}));
  await act(() => control('page-next').click());
  assert.equal(last().get('skip'), '100');
  assert.equal(last().has('q'), false, 'Paging must retain the applied query');
  assert.equal($('#clients-rows').children.length, 32);
  assert.equal(control('page-next').disabled, true);
  await act(() => control('page-prev').click());
  assert.equal(last().get('skip'), '50');
  $('#clients-search').value = '  Loto & lino  ';
  await act(() => submit('#clients-search-form'));
  assert.equal(last().get('skip'), '0');
  assert.equal(last().get('q'), 'Loto & lino');
  assert.equal(control('page-prev').disabled, true);
  for (const take of [25, 50, 100]) {
    await act(() => changeSize(take));
    assert.equal(last().get('skip'), '0', 'A size change must restart the applied search');
    assert.equal(last().get('take'), String(take));
    assert.equal(last().get('q'), 'Loto & lino');
    assert.equal($('#clients-rows').children.length, take);
    assert.equal($('#clients-page-size').value, String(take));
    if (take !== 100) {
      await act(() => control('page-next').click());
      assert.equal(last().get('skip'), String(take));
    }
  }
  await act(() => $('[data-action="nav"][data-target="inventario"]').click(), 'inventory');
  assert.equal(last().get('skip'), '0');
  assert.equal(last().get('take'), '50');
  assert.equal(last().has('q'), false, 'Inventory has its own applied search');
  await act(() => changeSize(25, 'inventory'), 'inventory');
  await act(() => control('page-next', 'inventario').click(), 'inventory');
  assert.equal(last().get('skip'), '25');
  assert.match($('#inventory-rows').firstElementChild.textContent, /Articulo de prueba 26/);
  await act(() => $('[data-action="nav"][data-target="clientes"]').click());
  assert.equal(last().get('take'), '100');
  assert.equal(last().get('q'), 'Loto & lino');
  assert.equal($('[data-action="new-client"]').disabled, true);
  assert.equal($('#client-save').disabled, true);
});

test('a failed next page stays visibly unconfirmed and disables the pager until a successful search', async t => {
  const failure = deferred();
  const transport = transportFor((url, count) => count === 2 ? failure.promise : json(directoryPage(url, 75)));
  const {app, document} = setup(t, transport);
  const $ = selector => document.querySelector(selector);
  const previous = $('[data-action="page-prev"][data-target="clientes"]');
  const next = $('[data-action="page-next"][data-target="clientes"]');
  const size = $('#clients-page-size');
  await app.ready;
  next.click();
  assert.equal(next.disabled, true);
  assert.equal(previous.disabled, true);
  assert.equal(size.disabled, true);
  failure.reject(new Error('Synthetic connection loss'));
  await until(() => !$('#clients-error').hidden && !$('#clients-search').disabled,
    'A failed page must expose a retryable search and a visible error');
  assert.equal($('#clients-rows').children.length, 0);
  assert.equal($('#clients-empty').hidden, true, 'An unavailable page is not a confirmed empty directory');
  assert.match($('#clients-error').textContent, /servidor|respuesta|confirm/i);
  assert.equal(next.disabled, true);
  assert.equal(previous.disabled, true);
  assert.equal(size.disabled, true);
  assert.equal(app.getState().authenticated, true);
  $('#clients-search-form').dispatchEvent(new document.defaultView.Event('submit', {bubbles: true, cancelable: true}));
  await until(() => transport.reads.length === 3 && !size.disabled, 'A successful search must restore pagination');
  assert.equal(transport.reads[2].searchParams.get('skip'), '0');
  assert.equal($('#clients-error').hidden, true);
  assert.equal($('#clients-rows').children.length, 50);
  assert.equal(next.disabled, false);
});

test('an older page 401 revokes the workspace and prevents a newer page response from repopulating it', async t => {
  const older = deferred(), newer = deferred();
  const transport = transportFor((url, count) => count === 1 ? json(directoryPage(url))
    : count === 2 ? older.promise : newer.promise);
  const {app, document, client} = setup(t, transport);
  await app.ready;
  const firstRead = app.refresh();
  const secondRead = app.refresh();
  older.resolve(json({code: 'authentication_required'}, 401));
  await firstRead;
  assert.equal(client.getVerifiedSession(), null);
  assert.equal(app.getState().authenticated, false);
  assert.equal(document.querySelector('#staff-shell').hidden, true);
  assert.equal(document.querySelector('#clients-rows').children.length, 0);
  newer.resolve(json(page({total: 1})));
  await secondRead;
  assert.equal(document.querySelector('#clients-rows').children.length, 0);
  assert.equal(document.querySelector('[data-session-user]').textContent, '');
  assert.equal(document.querySelector('#clients-page-size').disabled, true);
});

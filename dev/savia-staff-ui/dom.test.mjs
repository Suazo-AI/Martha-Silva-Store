import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {mountStaffApp} from './app.mjs';
import {StaffRequestError} from './login.mjs';
const {JSDOM} = createRequire(import.meta.url)('jsdom');

// Explicit application-client doubles exercise DOM behavior, not .NET or SQL.
const staff = {id: 'b5af9f41-78b6-4a21-9b6a-d07c29a67076', loginName: 'test.staff',
  displayName: 'Personal de prueba', role: 'Manager', enabled: true,
  version: '31f2bab2-9872-4b5f-bb24-09d7c2b57a30'};
const customer = {id: '18b9320a-2075-41cd-88a0-24341e7b9e30', name: 'Cliente sintético',
  kind: 'customer', email: 'test@example.invalid', phone: '', active: true};
const page = (items = [customer]) => ({items, total: items.length, skip: 0, take: 50});
const html = await readFile(new URL('./index.html', import.meta.url), 'utf8');
function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return {promise, resolve, reject};
}
function setup(t, overrides = {}) {
  const dom = new JSDOM(html, {url: 'https://staff.example.invalid/internal/', runScripts: 'outside-only'});
  const document = dom.window.document;
  const client = {getSession: async () => staff, listCustomers: async () => page(),
    listItems: async () => page([]), logout: async () => {}, ...overrides};
  const redirects = [];
  const app = mountStaffApp({document, client, redirect: value => redirects.push(value)});
  t.after(() => { app.destroy(); dom.window.close(); });
  return {app, document, redirects};
}

test('denied bootstrap leaves the workspace closed and never reads business data', async t => {
  let reads = 0;
  const {app, document} = setup(t, {
    getSession: async () => { throw new StaffRequestError('unauthorized', 401); },
    listCustomers: async () => { reads++; return page(); },
  });
  await app.ready;
  assert.equal(app.getState().authenticated, false);
  assert.equal(document.querySelector('#staff-shell').hidden, true);
  assert.equal(document.querySelector('#staff-shell').hasAttribute('inert'), true);
  assert.equal(document.querySelector('#auth-required').hidden, false);
  assert.equal(reads, 0);
  assert.equal(document.querySelector('#clients-rows').children.length, 0);
});

test('401 from an older concurrent read invalidates the UI and drops a newer success', async t => {
  const older = deferred(), newer = deferred();
  let count = 0;
  const {app, document} = setup(t, {listCustomers: () => {
    count++;
    return count === 1 ? Promise.resolve(page()) : count === 2 ? older.promise : newer.promise;
  }});
  await app.ready;
  assert.equal(app.getState().authenticated, true);
  assert.match(document.querySelector('#clients-rows').textContent, /Cliente sintético/);
  const firstRead = app.refresh();
  const secondRead = app.refresh();
  older.reject(new StaffRequestError('unauthorized', 401));
  await firstRead;
  assert.equal(app.getState().authenticated, false, 'A stale read can still revoke the current session');
  assert.equal(document.querySelector('#staff-shell').hidden, true);
  assert.equal(document.querySelector('#clients-rows').children.length, 0);
  newer.resolve(page([{...customer, name: 'No debe aparecer'}]));
  await secondRead;
  assert.equal(document.querySelector('#clients-rows').children.length, 0);
  assert.equal(document.querySelector('[data-session-user]').textContent, '');
});

test('directory names are rendered as text, and an unavailable write stays disabled', async t => {
  const literalName = '<img src=x onerror="alert(1)">';
  const {app, document} = setup(t, {listCustomers: async () => page([{...customer, name: literalName}])});
  await app.ready;
  assert.equal(app.getState().authenticated, true);
  assert.match(document.querySelector('#clients-rows').textContent, /<img src=x/);
  assert.equal(document.querySelector('#clients-rows img'), null);
  assert.equal(document.querySelector('[data-action="new-client"]').disabled, true);
  assert.equal(document.querySelector('#client-save').disabled, true);
});

test('403 is shown as an error instead of a zero-result customer list', async t => {
  const {app, document} = setup(t, {listCustomers: async () => { throw new StaffRequestError('forbidden', 403); }});
  await app.ready;
  assert.equal(app.getState().authenticated, true);
  assert.equal(document.querySelector('#clients-error').hidden, false);
  assert.match(document.querySelector('#clients-error').textContent, /permiso/);
  assert.equal(document.querySelector('#clients-empty').hidden, true);
  assert.equal(document.querySelector('#clients-search').disabled, false);
});

test('logout hides and clears private data before the server response arrives', async t => {
  const completion = deferred();
  const {app, document} = setup(t, {logout: () => completion.promise});
  await app.ready;
  document.querySelector('[data-action="logout"]').click();
  assert.equal(app.getState().authenticated, false);
  assert.equal(document.querySelector('#staff-shell').hidden, true);
  assert.equal(document.querySelector('#clients-rows').children.length, 0);
  completion.reject(new StaffRequestError('unavailable'));
  await completion.promise.catch(() => {});
  await new Promise(resolve => setTimeout(resolve, 0));
  assert.equal(app.getState().authenticated, false);
  assert.equal(document.querySelector('#auth-required').hidden, false);
});

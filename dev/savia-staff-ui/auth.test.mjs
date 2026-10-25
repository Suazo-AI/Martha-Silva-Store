import test from 'node:test';
import assert from 'node:assert/strict';
import {createAuthClient, StaffRequestError} from './login.mjs';

// Contract tests with explicit transport doubles: no HTTP server or SQL is used.
const staff = Object.freeze({id: 'b5af9f41-78b6-4a21-9b6a-d07c29a67076',
  loginName: 'test.staff', displayName: 'Personal de prueba', role: 'Manager', enabled: true,
  version: '31f2bab2-9872-4b5f-bb24-09d7c2b57a30'});
const json = (value, status = 200) => new Response(JSON.stringify(value),
  {status, headers: {'Content-Type': 'application/json; charset=utf-8'}});
const csrf = token => json({token, headerName: 'X-CSRF-TOKEN'});
function scripted(steps) {
  const calls = [];
  return {calls, fetchImpl: async (path, options) => {
    calls.push({path, ...options});
    assert.ok(steps.length, 'Unexpected HTTP request');
    return steps.shift()(path, options);
  }, done() { assert.equal(steps.length, 0, 'Expected HTTP request was not sent'); }};
}

test('login renews CSRF after identity changes and verifies the server session before access', async () => {
  const transport = scripted([
    () => csrf('anonymous-token'),
    () => json({staff, expiresAt: new Date(Date.now() + 3600000).toISOString()}),
    () => csrf('authenticated-token'), () => json(staff),
  ]);
  const client = createAuthClient(transport);
  const result = await client.login({loginName: 'test.staff', password: 'test-only-password'});
  assert.equal(result.id, staff.id);
  assert.equal(client.getVerifiedSession().id, staff.id);
  assert.deepEqual(transport.calls.map(c => [c.method, c.path]), [
    ['GET', '/internal/api/security/csrf'], ['POST', '/internal/api/security/login'],
    ['GET', '/internal/api/security/csrf'], ['GET', '/internal/api/security/me'],
  ]);
  const sent = transport.calls[1];
  assert.deepEqual(JSON.parse(sent.body), {loginName: 'test.staff', password: 'test-only-password'});
  assert.equal(sent.headers['X-CSRF-TOKEN'], 'anonymous-token');
  for (const call of transport.calls) {
    assert.equal(call.credentials, 'same-origin');
    assert.equal(call.redirect, 'error');
    assert.equal(call.cache, 'no-store');
  }
  transport.done();
});

test('unverified clients cannot read directory data', async () => {
  let calls = 0;
  const client = createAuthClient({fetchImpl: async () => { calls++; return json({items: []}); }});
  await assert.rejects(client.requestAuthenticated('/internal/api/directory/parties'),
    error => error instanceof StaffRequestError && error.status === 401);
  assert.equal(calls, 0);
});

test('a login/session identity mismatch never grants directory access', async () => {
  const transport = scripted([() => csrf('a'),
    () => json({staff, expiresAt: new Date(Date.now() + 3600000).toISOString()}),
    () => csrf('b'), () => json({...staff, id: '9a46e709-3f52-4ed8-847d-5395143f3c63'}),
  ]);
  const client = createAuthClient(transport);
  await assert.rejects(client.login({loginName: 'test.staff', password: 'test-only-password'}), StaffRequestError);
  assert.equal(client.getVerifiedSession(), null);
  await assert.rejects(client.requestAuthenticated('/internal/api/directory/items'), StaffRequestError);
  transport.done();
});

test('an expired or revoked session clears client access on 401', async () => {
  let invalidations = 0;
  const transport = scripted([() => json(staff), () => json({code: 'authentication_required'}, 401)]);
  const client = createAuthClient({...transport, onUnauthorized: () => invalidations++});
  await client.getSession();
  await assert.rejects(client.requestAuthenticated('/internal/api/directory/items'),
    error => error.status === 401);
  assert.equal(client.getVerifiedSession(), null);
  assert.equal(invalidations, 1);
  transport.done();
});

test('failed revalidation cannot retain an earlier verified session', async () => {
  let reply;
  const pendingResponse = new Promise(resolve => { reply = resolve; });
  const transport = scripted([() => json(staff), () => pendingResponse]);
  const client = createAuthClient(transport);
  await client.getSession();
  assert.equal(client.getVerifiedSession().id, staff.id);
  const revalidation = client.getSession();
  assert.equal(client.getVerifiedSession(), null, 'Access must close while session verification is pending');
  await assert.rejects(client.requestAuthenticated('/internal/api/directory/parties'), StaffRequestError);
  reply(json({...staff, version: null}));
  await assert.rejects(revalidation, StaffRequestError);
  assert.equal(client.getVerifiedSession(), null);
  await assert.rejects(client.requestAuthenticated('/internal/api/directory/parties'), StaffRequestError);
  assert.equal(transport.calls.length, 2);
  transport.done();
});

test('403 stays a permission denial and cannot be presented as an empty directory', async () => {
  const transport = scripted([() => json(staff), () => json({code: 'forbidden'}, 403)]);
  const client = createAuthClient(transport);
  await client.getSession();
  await assert.rejects(client.requestAuthenticated('/internal/api/directory/items'),
    error => error.code === 'forbidden' && error.status === 403);
  assert.equal(client.getVerifiedSession().id, staff.id);
  transport.done();
});

test('the read client refuses external origins and undeclared operations before transport', async () => {
  const transport = scripted([() => json(staff)]);
  const client = createAuthClient(transport);
  await client.getSession();
  for (const path of ['https://example.invalid/internal/api/directory/items',
    '//example.invalid/internal/api/directory/items', '/internal/api/security/staff',
    '/api/v2/synthetic/catalog', '/internal/api/directory/items/../parties']) {
    await assert.rejects(client.requestAuthenticated(path), StaffRequestError);
  }
  assert.equal(transport.calls.length, 1);
  transport.done();
});

test('logout obtains identity-bound CSRF and accepts the documented empty 204', async () => {
  const transport = scripted([() => json(staff), () => csrf('signed-in-token'),
    () => new Response(null, {status: 204})]);
  const client = createAuthClient(transport);
  await client.getSession();
  await client.logout();
  assert.equal(client.getVerifiedSession(), null);
  assert.equal(transport.calls[2].path, '/internal/api/security/logout');
  assert.equal(transport.calls[2].method, 'POST');
  assert.equal(transport.calls[2].headers['X-CSRF-TOKEN'], 'signed-in-token');
  await assert.rejects(client.requestAuthenticated('/internal/api/directory/items'), StaffRequestError);
  transport.done();
});

test('a timeout does not manufacture a verified session', async () => {
  const client = createAuthClient({timeoutMs: 10, fetchImpl: () => new Promise(() => {})});
  await assert.rejects(client.getSession(), error => error.code === 'unavailable');
  assert.equal(client.getVerifiedSession(), null);
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { readBackendStatus, API_PATHS } from './api-client.mjs';

const authority = { mode: 'savia', instanceId: 'savia-synthetic-v2', epoch: 1 };
const fixture = { synthetic: true, authority, variantId: '11111111-1111-1111-1111-111111111111',
  locationId: '22222222-2222-2222-2222-222222222222', sku: 'SYNTHETIC-001', name: 'Prueba',
  currency: 'XXX', unitPriceMinor: 1250, onHand: 10, reserved: 2, available: 8 };
const flags = { catalog: true, reserve: true, getReservation: true, cancel: true, attemptLookup: true,
  movements: true, expiration: false, sale: false, shipment: false, return: false, payments: false };
const capabilities = { synthetic: true, authority, providers: [{ mode: 'savia', authority,
  implementationStatus: 'synthetic_code_implemented', sqlVerification: 'not_verified', capabilities: flags },
  { mode: 'cga', authority: null, implementationStatus: 'not_verified', sqlVerification: 'not_verified',
    capabilities: Object.fromEntries(Object.keys(flags).map(key => [key, false])) }] };
const json = (body, status = 200, contentType = 'application/json') => new Response(JSON.stringify(body),
  { status, headers: { 'content-type': contentType } });
const goodFetch = overrides => async path => path === API_PATHS.ready ? json({ status: 'ready' })
  : path === API_PATHS.capabilities ? json(capabilities) : json({ synthetic: true, authority, items: [{ ...fixture, ...overrides }] });

test('static 404 closes connection without manufacturing catalog or enabling transactions', async () => {
  const requests = [];
  const result = await readBackendStatus({ fetchImpl: async (path, options) => {
    requests.push({ path, options }); return json({}, 404);
  } });
  assert.equal(result.state, 'unavailable');
  assert.equal(result.catalog, null);
  assert.equal(result.transactionsEnabled, false);
  assert.deepEqual(requests.map(request => request.path), Object.values(API_PATHS));
  assert.ok(requests.every(request => request.options.method === 'GET' && request.options.credentials === 'omit'
    && request.options.redirect === 'error' && !request.options.body));
});
test('HTML returned by a static fallback cannot masquerade as an API', async () => {
  const result = await readBackendStatus({ fetchImpl: async () => new Response('<h1>Demo</h1>',
    { status: 200, headers: { 'content-type': 'text/html' } }) });
  assert.equal(result.state, 'unavailable');
  assert.equal(result.catalog, null);
});
test('real contract-shaped reads preserve XXX and unverified SQL; writes remain closed', async () => {
  const result = await readBackendStatus({ fetchImpl: goodFetch() });
  assert.equal(result.state, 'ready');
  assert.equal(result.catalog.items[0].currency, 'XXX');
  assert.equal(result.sqlVerification, 'not_verified');
  assert.equal(result.transactionsEnabled, false);
});
test('a capabilities response alone does not prove storage readiness', async () => {
  const result = await readBackendStatus({ fetchImpl: async path => path === API_PATHS.capabilities
    ? json(capabilities) : json({ code: 'storage_unavailable' }, 503) });
  assert.equal(result.state, 'partial');
  assert.equal(result.catalog, null);
});
test('capabilities reject unsupported SQL claims, missing flags, commerce and CGA operations', async () => {
  for (const alter of [value => { value.providers[0].sqlVerification = 'verified'; },
    value => { delete value.providers[0].capabilities.cancel; },
    value => { value.providers[0].capabilities.payments = true; },
    value => { value.providers[0].capabilities.sale = true; },
    value => { value.providers[1].capabilities.reserve = true; },
    value => { value.providers[1].authority = authority; },
    value => { value.providers.push(value.providers[0]); }]) {
    const body = structuredClone(capabilities); alter(body);
    const result = await readBackendStatus({ fetchImpl: path => path === API_PATHS.capabilities
      ? Promise.resolve(json(body)) : goodFetch()(path) });
    assert.equal(result.state, 'partial');
    assert.equal(result.capabilities, null);
    assert.equal(result.sqlVerification, 'not_verified');
    assert.equal(result.transactionsEnabled, false);
  }
});
test('invalid currency, balances, authority, quantities and IDs are rejected', async () => {
  for (const invalid of [{ currency: 'USD' }, { available: 100 }, { reserved: -1 },
    { authority: { ...authority, epoch: 2 } }, { unitPriceMinor: 1.5 },
    { onHand: Number.MAX_SAFE_INTEGER + 1 }, { variantId: 'not-a-guid' }, { synthetic: false }]) {
    const result = await readBackendStatus({ fetchImpl: goodFetch(invalid) });
    assert.equal(result.state, 'partial');
    assert.equal(result.catalog, null);
  }
});
test('transport errors expose useful generic errors without leaking exception text', async () => {
  const result = await readBackendStatus({ fetchImpl: async () => { throw new Error('secret-token-string'); } });
  assert.equal(result.state, 'unavailable');
  assert.ok(!JSON.stringify(result).includes('secret-token-string'));
});
test('timeouts finish each read and keep operations closed', async () => {
  const result = await readBackendStatus({ timeoutMs: 2, fetchImpl: (_path, { signal }) => new Promise((_, reject) =>
    signal.addEventListener('abort', () => reject(new DOMException('aborted', 'AbortError')), { once: true })) });
  assert.equal(result.state, 'unavailable');
  assert.ok(result.checks.every(check => check.message.includes('tardó')));
  assert.equal(result.transactionsEnabled, false);
});

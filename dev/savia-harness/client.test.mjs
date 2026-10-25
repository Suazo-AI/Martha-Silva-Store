import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { Harness, initialState, AUTHORITY, ROOT, loopbackOrigin } from './client.mjs';

// Contract-only fetch doubles: none of these tests connect to .NET or SQL Server.
const fixture = { variantId: '33333333-3333-3333-3333-333333333333', locationId: '44444444-4444-4444-4444-444444444444',
  sku: 'SYNTHETIC-V2-001', name: 'SYNTHETIC TEST PRODUCT - NOT FOR SALE', unitPriceMinor: 1250,
  currency: 'XXX', onHand: 5, reserved: 0, available: 5, authority: AUTHORITY, synthetic: true };
const catalog = { synthetic: true, authority: AUTHORITY, items: [fixture] };
const answer = (status, body) => ({ ok: status >= 200 && status < 300, status, json: async () => structuredClone(body) });
const reserveReceipt = body => ({ reservationId: '55555555-5555-5555-5555-555555555555', variantId: body.variantId,
  locationId: body.locationId, quantity: body.quantity, unitPriceMinor: 1250, currency: 'XXX', totalMinor: 1250 * body.quantity,
  status: 'active', attemptId: body.attemptId, authority: body.authority, createdAt: '2026-10-25T00:00:00Z', synthetic: true });
function setup(handler, state = initialState('http://127.0.0.1:5080')) {
  const calls = [], saved = [];
  let sequence = 0;
  const harness = new Harness({ state, uuid: () => `00000000-0000-0000-0000-${String(++sequence).padStart(12, '0')}`,
    save: async value => saved.push(structuredClone(value)), fetchImpl: async (url, options) => {
      calls.push({ url, ...options });
      if (url.endsWith('/catalog')) return answer(200, catalog);
      return handler(url, options, saved);
    } });
  return { harness, calls, saved };
}

test('only loopback HTTP origins; no remote, credentials, paths or redirects', async () => {
  for (const value of ['https://localhost:5080', 'http://example.org', 'http://user:pass@localhost',
    'http://localhost/path', 'http://localhost?x=1', 'http://localhost/#hash']) assert.throws(() => loopbackOrigin(value));
  assert.equal(loopbackOrigin('http://[::1]:5080'), 'http://[::1]:5080');
  const { harness, calls } = setup(() => answer(200, {}));
  await harness.capabilities();
  assert.equal(calls[0].redirect, 'error');
});

test('persist exact authority/key/payload before POST; server sets price', async () => {
  const { harness, calls } = setup((url, options, saved) => {
    const attempt = saved.at(-1).attempts[0];
    assert.equal(attempt.status, 'prepared');
    assert.equal(options.body, attempt.body);
    assert.equal(options.headers['Idempotency-Key'], attempt.key);
    const body = JSON.parse(options.body);
    assert.deepEqual(Object.keys(body), ['variantId', 'locationId', 'quantity', 'attemptId', 'authority']);
    return answer(201, reserveReceipt(body));
  });
  const result = await harness.reserve(2);
  assert.equal(result.status, 'succeeded');
  assert.equal(result.result.totalMinor, 2500);
  assert.equal(calls[1].url, 'http://127.0.0.1:5080' + ROOT + '/reservations');
});

test('state write failure prevents a POST', async () => {
  let posts = 0;
  const harness = new Harness({ state: initialState('http://localhost:5080'), save: async () => { throw new Error('disk failure'); },
    fetchImpl: async (url, options) => { if (options.method === 'POST') posts++; return answer(200, catalog); } });
  await assert.rejects(harness.reserve(), /disk failure/);
  assert.equal(posts, 0);
});

test('timeout stays unknown; reload + retry preserves authority/key/body without catalog read', async () => {
  const first = setup(() => { throw Object.assign(new Error('timeout'), { name: 'AbortError' }); });
  const unknown = await first.harness.reserve();
  assert.equal(unknown.status, 'unknown');
  assert.equal(unknown.error, 'timeout_outcome_unknown');
  const second = setup((url, options) => answer(201, reserveReceipt(JSON.parse(options.body))), first.saved.at(-1));
  const success = await second.harness.retry(unknown.attemptId);
  assert.equal(success.status, 'succeeded');
  assert.equal(second.calls.length, 1);
  assert.equal(second.calls[0].body, first.calls[1].body);
  assert.deepEqual(second.calls[0].headers, first.calls[1].headers);
  assert.equal(second.calls[0].url, first.calls[1].url);
});

test('pending/unknown prevents new reserve, cancellation authority, and provider switch', async () => {
  const { harness, calls } = setup(() => { throw new Error('lost connection'); });
  await harness.reserve();
  await assert.rejects(harness.reserve(), /pending\/unknown/);
  await assert.rejects(harness.mode('savia'), /original authority/);
  await assert.rejects(harness.mode('api-cga'), /original authority/);
  assert.equal(calls.length, 2);
});

test('missing lookup is unknown, distinct from persisted business rejection', async () => {
  let lookupFound = false;
  const { harness } = setup((url, options) => {
    if (options.method === 'POST') throw new Error('timeout');
    const attempt = harness.state.attempts[0];
    return lookupFound ? answer(200, { operation: 'reserve', attemptId: attempt.attemptId, authority: AUTHORITY,
      outcome: 'rejected', result: null, error: 'out_of_stock', createdAt: '2026-10-25T00:00:00Z' })
      : answer(404, { code: 'attempt_unknown' });
  });
  await harness.reserve();
  assert.equal((await harness.lookup()).status, 'unknown');
  lookupFound = true;
  const rejection = await harness.lookup();
  assert.equal(rejection.status, 'rejected');
  assert.equal(rejection.error, 'out_of_stock');
});

test('lookup recovers a committed creation after a lost response', async () => {
  let receipt;
  const { harness } = setup((url, options) => {
    if (options.method === 'POST') { receipt = reserveReceipt(JSON.parse(options.body)); throw new Error('response lost'); }
    return answer(200, { operation: 'reserve', attemptId: receipt.attemptId, authority: AUTHORITY,
      outcome: 'succeeded', result: receipt, error: null, createdAt: receipt.createdAt });
  });
  await harness.reserve();
  const recovered = await harness.lookup();
  assert.equal(recovered.status, 'succeeded');
  assert.deepEqual(harness.state.creation, receipt);
});

test('explicit HTTP rejection differs from 503 uncertainty; no local success or ERP fallback', async () => {
  for (const [status, expected] of [[409, 'rejected'], [503, 'unknown'], [408, 'unknown'], [429, 'unknown']]) {
    const { harness, calls } = setup(() => answer(status, { code: status === 409 ? 'out_of_stock' : 'storage_unavailable' }));
    assert.equal((await harness.reserve()).status, expected);
    assert.equal(harness.state.reservationId, null);
    assert.equal(calls.length, 2);
  }
});

test('cancel retry is exact; replayed create remains active while GET stays cancelled', async () => {
  let creation, cancellation;
  const { harness, calls } = setup((url, options) => {
    if (options.method !== 'POST') return answer(200, { creation, status: cancellation ? 'cancelled' : 'active', cancelledAt: cancellation?.cancelledAt ?? null });
    const body = JSON.parse(options.body);
    if (!url.endsWith('/cancel')) { creation ??= reserveReceipt(body); return answer(201, creation); }
    cancellation ??= { reservationId: creation.reservationId, attemptId: body.attemptId, status: 'cancelled', releasedQuantity: 1,
      authority: body.authority, cancelledAt: '2026-10-25T00:01:00Z', synthetic: true };
    return answer(200, cancellation);
  });
  const reserved = await harness.reserve();
  const cancelled = await harness.cancel();
  await harness.retry(cancelled.attemptId);
  assert.equal(calls[2].body, calls[3].body);
  assert.equal(calls[2].headers['Idempotency-Key'], calls[3].headers['Idempotency-Key']);
  await harness.status();
  await harness.retry(reserved.attemptId);
  assert.equal(harness.state.creation.status, 'active');
  assert.equal(harness.state.current.status, 'cancelled');
  assert.equal((await harness.status()).status, 'cancelled');
});

test('CGA capabilities closed without inventing an endpoint', async () => {
  const { harness, calls } = setup(() => assert.fail('No HTTP request expected'));
  await assert.rejects(harness.mode('api-cga'), /all capabilities closed/);
  assert.equal(calls.length, 0);
});

test('malformed successful response remains unknown, never invents a reservation', async () => {
  const { harness } = setup(() => answer(201, { status: 'active' }));
  assert.equal((await harness.reserve()).status, 'unknown');
  assert.equal(harness.state.creation, null);
});

test('harness sources remain outside the prepare/deploy source allowlists', async () => {
  const prepare = await readFile(new URL('../../prepare.py', import.meta.url), 'utf8');
  const wrangler = JSON.parse(await readFile(new URL('../../wrangler.jsonc', import.meta.url), 'utf8'));
  assert.match(prepare, /static = ROOT \/ 'build-inputs' \/ 'static'/);
  assert.match(prepare, /\('app\.js', 'demo-api\.js', 'integration-adapters\.js'\)/);
  assert.doesNotMatch(prepare, /savia-harness|ROOT \/ 'dev'/);
  assert.equal(wrangler.assets.directory, './dist');
});

test('corrupted saved authority or payload is blocked before HTTP', async () => {
  const { harness, saved } = setup(() => { throw new Error('timeout'); });
  await harness.reserve();
  const state = saved.at(-1);
  state.attempts[0].authority.epoch = 2;
  assert.throws(() => setup(() => assert.fail('No request expected'), state), /Corrupted saved attempt/);
});

test('GET cannot overwrite the immutable creation receipt', async () => {
  const { harness } = setup((url, options) => options.method === 'POST'
    ? answer(201, reserveReceipt(JSON.parse(options.body)))
    : answer(200, { creation: { ...harness.state.creation, status: 'cancelled' }, status: 'cancelled', cancelledAt: '2026-10-25T00:01:00Z' }));
  await harness.reserve();
  await assert.rejects(harness.status(), /immutable original creation/);
  assert.equal(harness.state.creation.status, 'active');
  assert.equal(harness.state.current, null);
});

import path from 'node:path';
import {pathToFileURL} from 'node:url';

const {test, expect} = await import(pathToFileURL(path.join(process.env.SAVIA_PLAYWRIGHT_PACKAGE, 'test.mjs')).href);
const origin = process.env.SAVIA_QA_ORIGIN;
const authority = {mode: 'savia', instanceId: 'savia-synthetic-v2', epoch: 1};
const command = {
  variantId: '33333333-3333-3333-3333-333333333333',
  locationId: '44444444-4444-4444-4444-444444444444',
  quantity: 1,
  attemptId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  authority,
};
const headers = {'Idempotency-Key': 'playwright-synthetic-guard-001'};

test('browser reaches only the synthetic capability descriptor; CGA stays closed', async ({page, context}) => {
  await context.route('**/*', route =>
    new URL(route.request().url()).origin === origin ? route.continue() : route.abort());
  const response = await page.goto('/api/v2/synthetic/capabilities');
  expect(response.status()).toBe(200);
  const body = await response.json();
  expect(body.synthetic).toBe(true);
  expect(body.authority).toEqual(authority);
  expect(body.providers.find(p => p.mode === 'savia').sqlVerification).toBe('not_verified');
  const cga = body.providers.find(p => p.mode === 'cga');
  expect(cga.implementationStatus).toBe('not_verified');
  expect(cga.authority).toBeNull();
  expect(Object.values(cga.capabilities).every(v => v === false)).toBe(true);
  expect(new URL(page.url()).origin).toBe(origin);
});

test('invalid and foreign authority commands are rejected before storage resolution', async ({request}) => {
  const invalid = await request.post('/api/v2/synthetic/reservations', {
    headers, maxRedirects: 0, data: {...command, quantity: 0},
  });
  expect(invalid.status()).toBe(400);
  expect((await invalid.json()).code).toBe('invalid_request');
  const foreign = await request.post('/api/v2/synthetic/reservations', {
    headers, maxRedirects: 0, data: {...command, authority: {...authority, mode: 'cga'}},
  });
  expect(foreign.status()).toBe(409);
  expect((await foreign.json()).code).toBe('authority_mismatch');
});

test('no SQL connection means readiness and data reads fail closed, without invented stock', async ({request}) => {
  expect((await request.get('/health/live', {maxRedirects: 0})).status()).toBe(200);
  for (const route of ['/health/ready', '/api/v2/synthetic/catalog', '/api/v2/synthetic/movements']) {
    const response = await request.get(route, {maxRedirects: 0});
    expect(response.status()).toBe(503);
    const body = await response.json();
    expect(body.code).toBe('storage_unavailable');
    expect(body).not.toHaveProperty('items');
  }
  const legacy = await request.get('/api/v1/catalog', {maxRedirects: 0});
  expect(legacy.status()).toBe(503);
  expect((await legacy.json()).code).toBe('storage_unavailable');
});

test('client-supplied price is rejected by the real HTTP request contract', async ({request}) => {
  const response = await request.post('/api/v2/synthetic/reservations', {
    headers, maxRedirects: 0, data: {...command, unitPriceMinor: 1},
  });
  expect(response.status()).toBe(400);
  expect((await response.json()).code).toBe('invalid_request');
});

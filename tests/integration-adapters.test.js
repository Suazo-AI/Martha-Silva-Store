'use strict';
const assert = require('node:assert/strict');
const test = require('node:test');
const fs = require('node:fs');
const vm = require('node:vm');
const http = require('node:http');
const {createStoreApi} = require('../src/store-api.js');
const {MODES, getDescriptor, createLocalAdapter} = require('../src/integration-adapters.js');
const {createSaviaSyntheticAdapter} = require('../src/savia-http-adapter.js');
const context = {window:{}};
vm.runInNewContext(fs.readFileSync(require.resolve('../build-inputs/static/catalog.js'), 'utf8'), context);
const catalog = JSON.parse(JSON.stringify(context.window.STORE_CATALOG));
const variant = catalog.products[0].variants[0].id;
const contact = {name:'Synthetic', email:'test@example.invalid', phone:'000'};
const address = {line1:'Fixture', city:'Fixture', department:'Fixture'};
const rejects = (call, code) => assert.rejects(call, error => error.code === code);
function demoSetup() {
  const saved = new Map();
  const storage = {getItem:key => saved.get(key) ?? null, setItem:(key, value) => saved.set(key, value)};
  const create = mode => createLocalAdapter({mode, catalog, storage, createStoreApi});
  return {saved, storage, create, savia:create('savia'), sisfain:create('sisfain')};
}
async function order(api, key = 'same-local-key') {
  await api('/api/cart/items', {variant_id:variant, quantity:1});
  const quote = await api('/api/quote', {delivery_zone:'managua'});
  return (await api('/api/orders', {quote_id:quote.id, idempotency_key:key, contact, address})).order;
}
const productId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const variantId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const orderId = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
const externalCatalog = () => ({synthetic:true, items:[{productId, name:'Synthetic fixture', variants:[{variantId, sku:'SYNTHETIC-1', unitPriceMinor:1250, currency:'XXX', availableQuantity:3}]}]});
const externalOrder = () => ({orderId, variantId, quantity:2, unitPriceMinor:1250, currency:'XXX', totalMinor:2500, status:'reserved', createdAt:'2026-10-24T23:00:00Z', synthetic:true});
const orderInput = () => ({integration_id:'savia', data_kind:'synthetic', variant_id:'savia-synthetic~' + variantId, quantity:2, idempotency_key:'synthetic-attempt-0001'});
const response = (status, value) => ({status, json:async () => value});
function httpSetup(handler) {
  const calls = [];
  const adapter = createSaviaSyntheticAdapter({allowSyntheticOrders:true, transport:async (path, options) => {
    calls.push({path, options});
    return handler ? handler(path, options) : response(options.method === 'POST' ? 201 : 200, path === '/api/v1/catalog' ? externalCatalog() : externalOrder());
  }});
  return {adapter, calls};
}

test('descriptors identify two disconnected demo models and cannot enable production', async () => {
  assert.deepEqual(MODES, ['savia', 'sisfain']);
  for (const mode of MODES) {
    const descriptor = getDescriptor(mode);
    assert.equal(descriptor.status, 'local');
    assert.equal(descriptor.connectionStatus, 'unconfigured');
    assert.equal(descriptor.capabilities.realOrders, false);
    assert.equal(descriptor.capabilities.payments, false);
    assert.throws(() => { descriptor.capabilities.realOrders = true; }, TypeError);
  }
  assert.equal(getDescriptor('savia').fullName, 'Sistema de Administración, Ventas, Inventarios y Abastecimiento');
  assert.equal(getDescriptor('sisfain').capabilities.httpAdapter, false);
  assert.throws(() => getDescriptor('cga-production'), error => error.code === 'unknown_integration');
  await rejects(() => demoSetup().sisfain.createRealOrder({}), 'real_orders_disabled');
});

test('demo cart, inventory, orders, retry keys and reset are isolated by mode', async () => {
  const setup = demoSetup();
  const saviaOrder = await order(setup.savia);
  assert.equal((await setup.sisfain('/api/cart')).lines.length, 0);
  assert.equal((await setup.sisfain('/api/admin/inventory')).variants[0].available, 3);
  const cgaOrder = await order(setup.sisfain);
  assert.ok(saviaOrder.id.startsWith('savia~'));
  assert.ok(cgaOrder.id.startsWith('sisfain~'));
  assert.notEqual(saviaOrder.id, cgaOrder.id);
  assert.equal(saviaOrder.integration_id, 'savia');
  assert.equal(cgaOrder.integration_id, 'sisfain');
  assert.equal(cgaOrder.lines[0].data_kind, 'local');
  assert.equal((await setup.savia('/api/orders', {idempotency_key:'same-local-key'})).order.id, saviaOrder.id);
  assert.equal((await setup.sisfain('/api/orders', {idempotency_key:'same-local-key'})).order.id, cgaOrder.id);
  await setup.savia(`/api/orders/${saviaOrder.id}/payment`, {outcome:'approved'});
  assert.equal((await setup.savia('/api/admin/inventory')).variants[0].stock, 2);
  assert.equal((await setup.sisfain('/api/admin/inventory')).variants[0].stock, 3);
  assert.equal((await setup.create('savia')('/api/orders/' + saviaOrder.id)).order.id, saviaOrder.id);
  setup.savia.reset();
  assert.equal((await setup.savia('/api/admin/orders')).orders.length, 0);
  assert.equal((await setup.sisfain('/api/admin/orders')).orders.length, 1);
  assert.ok([...setup.saved.keys()].every(key => /^martha-integration-v1:(savia|sisfain):/.test(key)));
});

test('local key replay rejects a new quote or changed customer data but allows exact and key-only recovery', async () => {
  const {savia} = demoSetup();
  const created = await order(savia);
  const exact = {quote_id:created.quote_id, idempotency_key:'same-local-key', contact, address, newsletter:false};
  assert.equal((await savia('/api/orders', exact)).order.id, created.id);
  assert.equal((await savia('/api/orders', {idempotency_key:'same-local-key'})).order.id, created.id);
  for (const change of [{contact:{...contact, name:'Different'}}, {address:{...address, city:'Different'}}, {newsletter:true}]) {
    await rejects(() => savia('/api/orders', {...exact, ...change}), 'idempotency_conflict');
  }
  await savia('/api/cart/items', {variant_id:variant, quantity:1});
  const quote = await savia('/api/quote', {delivery_zone:'resto'});
  await assert.rejects(() => savia('/api/orders', {...exact, quote_id:quote.id}), error => error.code === 'idempotency_conflict' && error.status === 409);
  assert.equal((await savia('/api/admin/orders')).orders.length, 1);
  assert.equal((await savia('/api/cart')).lines[0].quantity, 1);
});

test('missing local catalog fails explicitly instead of advertising an empty loaded integration', () => {
  for (const value of [undefined, null, {}, {products:null}]) {
    assert.throws(() => createLocalAdapter({mode:'savia', catalog:value, createStoreApi}), error => error.code === 'missing_catalog');
  }
  assert.equal(typeof createLocalAdapter({mode:'savia', catalog:[], createStoreApi}), 'function');
});

test('unscoped legacy state is not imported into either integration', async () => {
  const setup = demoSetup();
  const legacy = createStoreApi(catalog, setup.storage);
  await legacy('/api/cart/items', {variant_id:variant, quantity:2});
  const raw = setup.saved.get('martha-store-state-1');
  for (const api of [setup.savia, setup.sisfain]) assert.equal((await api('/api/cart')).lines.length, 0);
  assert.equal(setup.saved.get('martha-store-state-1'), raw);
});

test('cross-mode quote/order/return references and synthetic origins fail before mutation', async () => {
  const {savia, sisfain} = demoSetup();
  await savia('/api/cart/items', {variant_id:variant, quantity:1});
  const quote = await savia('/api/quote', {delivery_zone:'managua'});
  await rejects(() => sisfain('/api/orders', {quote_id:quote.id, idempotency_key:'foreign', contact, address}), 'integration_mismatch');
  const created = (await savia('/api/orders', {quote_id:quote.id, idempotency_key:'own', contact, address})).order;
  for (const path of [`/api/orders/${created.id}`, `/api/orders/${created.id}/payment`, `/api/admin/orders/${created.id}/fulfill`]) {
    await rejects(() => sisfain(path, path.endsWith(created.id) ? undefined : {}), 'integration_mismatch');
  }
  for (const reference of ['unscoped', 'savia-synthetic~' + orderId, 'savia~../wrong', 'savia~%2Fwrong']) {
    await rejects(() => savia('/api/orders/' + encodeURIComponent(reference)), reference === 'savia~%2Fwrong' ? 'order_not_found' : 'integration_mismatch');
  }
  await rejects(() => sisfain('/api/cart/items', {integration_id:'savia', variant_id:variant, quantity:1}), 'integration_mismatch');
  await rejects(() => savia('/api/cart/items', {data_kind:'synthetic', variant_id:variant, quantity:1}), 'integration_mismatch');
  await rejects(() => savia('/api/orders', {real_orders:true}), 'real_orders_disabled');
  await rejects(() => savia('/api/orders', {quote_id:quote.id, return_id:'sisfain~return'}), 'integration_mismatch');
  assert.equal((await sisfain('/api/admin/orders')).orders.length, 0);
});

test('return workflow keeps all outward references scoped including admin lists', async () => {
  const {sisfain} = demoSetup();
  const created = await order(sisfain);
  await sisfain(`/api/orders/${created.id}/payment`, {outcome:'approved'});
  for (const status of ['preparing', 'shipped', 'delivered']) await sisfain(`/api/admin/orders/${created.id}/fulfill`, {status, tracking:'DEMO'});
  const result = await sisfain(`/api/orders/${created.id}/returns`, {reason:'Demo', lines:[{variant_id:variant, quantity:1}]});
  assert.ok(result.return.id.startsWith('sisfain~'));
  assert.equal(result.order.returns[0].id, result.return.id);
  await sisfain(`/api/admin/orders/${created.id}/returns/${result.return.id}/receive`, {});
  const refunded = await sisfain(`/api/admin/orders/${created.id}/refund`, {return_id:result.return.id, restock:true});
  assert.equal(refunded.order.status, 'refunded');
  assert.equal((await sisfain('/api/admin/orders')).orders[0].id, created.id);
});

test('CGA route simulation never issues a vendor request and rejects invented external routes', async () => {
  const {sisfain} = demoSetup();
  assert.equal((await sisfain.readCatalog()).data_origin, 'browser');
  await rejects(() => sisfain('/api/v1/synthetic/orders', {}), 'unsupported_route');
  await rejects(() => sisfain('/cga/orders', {}), 'unsupported_route');
  assert.equal(typeof sisfain.createSyntheticOrder, 'undefined');
});

test('both model families expose the same canonical catalog fields without conflating currency or IDs', async () => {
  const local = await demoSetup().savia.readCatalog();
  const synthetic = await httpSetup().adapter.readCatalog();
  assert.deepEqual(Object.keys(local).sort(), Object.keys(synthetic).sort());
  assert.deepEqual(Object.keys(local.products[0]).sort(), Object.keys(synthetic.products[0]).sort());
  assert.deepEqual(Object.keys(local.products[0].variants[0]).sort(), Object.keys(synthetic.products[0].variants[0]).sort());
  assert.equal(local.products[0].variants[0].currency, 'USD');
  assert.equal(local.products[0].variants[0].sku, null);
  assert.equal(synthetic.products[0].variants[0].currency, 'XXX');
  assert.equal(synthetic.products[0].variants[0].id, 'savia-synthetic~' + variantId);
  assert.equal(synthetic.authoritative, false);
  assert.equal(synthetic.real_orders, false);
  assert.equal(synthetic.data_kind, 'synthetic');
  assert.equal(own(synthetic.products[0], 'images'), false);
});
function own(value, key) { return Object.prototype.hasOwnProperty.call(value, key); }

test('HTTP adapter is unconfigured by default; synthetic writes require explicit opt-in', async () => {
  const disabled = createSaviaSyntheticAdapter();
  assert.equal(disabled.descriptor.status, 'unconfigured');
  await rejects(() => disabled.readCatalog(), 'integration_unconfigured');
  await rejects(() => disabled.createSyntheticOrder(orderInput()), 'synthetic_writes_disabled');
  await rejects(() => disabled.createRealOrder(orderInput()), 'real_orders_disabled');
  let calls = 0;
  const readOnly = createSaviaSyntheticAdapter({transport:async () => { calls++; return response(200, externalCatalog()); }});
  await rejects(() => readOnly.createSyntheticOrder(orderInput()), 'synthetic_writes_disabled');
  assert.equal(calls, 0);
  assert.throws(() => createSaviaSyntheticAdapter({transport:'https://example.invalid'}), error => error.code === 'invalid_configuration');
  assert.throws(() => createSaviaSyntheticAdapter({allowSyntheticOrders:'true'}), error => error.code === 'invalid_configuration');
});

test('synthetic HTTP uses only documented paths, exact minimal body and credential-free options', async () => {
  const {adapter, calls} = httpSetup();
  await adapter.readCatalog();
  const created = await adapter.createSyntheticOrder(orderInput());
  assert.equal(created.status, 'reserved');
  assert.equal(created.currency, 'XXX');
  assert.equal(created.id, 'savia-synthetic~' + orderId);
  assert.equal(created.data_kind, 'synthetic');
  assert.equal(created.real_orders, false);
  assert.deepEqual(await adapter.readOrder(created.id), created);
  assert.deepEqual(calls.map(call => call.path), ['/api/v1/catalog', '/api/v1/synthetic/orders', '/api/v1/synthetic/orders/' + orderId]);
  const sent = calls[1].options;
  assert.deepEqual(JSON.parse(sent.body), {variantId, quantity:2});
  assert.equal(sent.headers['Idempotency-Key'], 'synthetic-attempt-0001');
  for (const {options} of calls) {
    assert.equal(options.credentials, 'omit');
    assert.equal(options.redirect, 'error');
    assert.equal(options.cache, 'no-store');
    assert.equal(own(options.headers, 'Authorization'), false);
  }
  const contract = JSON.parse(fs.readFileSync(require.resolve('../contracts/openapi-v1.json'), 'utf8'));
  assert.ok(contract.paths[calls[0].path].get);
  assert.ok(contract.paths[calls[1].path].post);
  assert.deepEqual(Object.keys(JSON.parse(sent.body)).sort(), contract.components.schemas.CreateSyntheticOrder.required.slice().sort());
});

test('synthetic input rejects mode mixing, local IDs, prices, contact, multi-lines and invalid keys before network', async () => {
  const {adapter, calls} = httpSetup();
  for (const changes of [{integration_id:'sisfain'}, {data_kind:'local'}, {variant_id:variant}, {variant_id:'savia~' + variantId}]) {
    await rejects(() => adapter.createSyntheticOrder({...orderInput(), ...changes}), 'integration_mismatch');
  }
  for (const changes of [{quantity:0}, {quantity:101}, {quantity:1.1}, {quantity:'2'}, {idempotency_key:'short'}, {idempotency_key:'has spaces'}, {idempotency_key:'x'.repeat(129)}, {unit_price_minor:1}, {contact}, {lines:[]}, {variant_id:'savia-synthetic~00000000-0000-0000-0000-000000000000'}]) {
    await rejects(() => adapter.createSyntheticOrder({...orderInput(), ...changes}), 'invalid_request');
  }
  await rejects(() => adapter.readOrder('sisfain~' + orderId), 'integration_mismatch');
  assert.equal(calls.length, 0);
});

test('synthetic catalog rejects commercial, malformed, unsafe and duplicate data', async () => {
  const corruptions = [
    value => { value.synthetic = false; }, value => { value.items[0].variants[0].currency = 'USD'; },
    value => { value.items[0].variants[0].unitPriceMinor = 9000000000001; },
    value => { value.items[0].variants[0].availableQuantity = -1; },
    value => { value.items[0].variants[0].unitPriceMinor = '1250'; },
    value => { value.items[0].productId = 'slug'; }, value => { value.items[0].images = []; },
    value => { value.items.push(structuredClone(value.items[0])); },
    value => { value.items[0].variants.push(structuredClone(value.items[0].variants[0])); }
  ];
  for (const corrupt of corruptions) {
    const value = externalCatalog(); corrupt(value);
    await rejects(() => httpSetup(() => response(200, value)).adapter.readCatalog(), 'invalid_response');
  }
});

test('synthetic order validates exact schema, amounts, lifecycle, UTC and request identity', async () => {
  const corruptions = [
    value => { value.synthetic = false; }, value => { value.currency = 'USD'; }, value => { value.status = 'paid'; },
    value => { value.totalMinor++; }, value => { value.quantity = 3; value.totalMinor = 3750; },
    value => { value.variantId = productId; }, value => { value.createdAt = '2026-10-24T23:00:00-06:00'; },
    value => { value.createdAt = 'not-a-dateZ'; }, value => { value.payment = 'approved'; },
    value => { value.orderId = '00000000-0000-0000-0000-000000000000'; }
  ];
  for (const corrupt of corruptions) {
    const value = externalOrder(); corrupt(value);
    await assert.rejects(() => httpSetup(() => response(201, value)).adapter.createSyntheticOrder(orderInput()), error => error.code === 'synthetic_outcome_unknown' && error.retryWithSameKey === true);
  }
  const otherOrder = {...externalOrder(), orderId:productId};
  await rejects(() => httpSetup(() => response(200, otherOrder)).adapter.readOrder('savia-synthetic~' + orderId), 'invalid_response');
});

test('problem codes are preserved without leaking arbitrary server message contents', async () => {
  for (const [status, code] of [[409, 'out_of_stock'], [409, 'idempotency_conflict'], [503, 'storage_unavailable'], [404, 'not_found']]) {
    const {adapter, calls} = httpSetup(() => response(status, {status, code, title:'sensitive server contents', traceId:'internal'}));
    await assert.rejects(() => adapter.createSyntheticOrder(orderInput()), error => error.code === code && error.status === status && !error.message.includes('sensitive') && error.retryWithSameKey === (status >= 500));
    assert.equal(calls.length, 1);
  }
});

test('unknown outcomes never auto-retry, mutate the caller or fallback; manual retry keeps the exact key', async () => {
  const calls = [], input = orderInput(), original = structuredClone(input);
  let attempt = 0;
  const adapter = createSaviaSyntheticAdapter({allowSyntheticOrders:true, transport:async (path, options) => {
    calls.push({path, options});
    if (attempt++ === 0) throw new Error('network lost after server commit');
    return response(201, externalOrder());
  }});
  await assert.rejects(() => adapter.createSyntheticOrder(input), error => error.code === 'synthetic_outcome_unknown' && error.retryWithSameKey);
  assert.equal(calls.length, 1);
  assert.deepEqual(input, original);
  const retried = await adapter.createSyntheticOrder(input);
  assert.equal(retried.id, 'savia-synthetic~' + orderId);
  assert.deepEqual(calls[0], calls[1]);
  assert.equal(calls.length, 2);
});

test('invalid JSON, missing response and unexpected success status remain fail-closed', async () => {
  for (const value of [undefined, response(202, externalOrder()), {status:201, json:async () => { throw new Error('invalid JSON'); }}]) {
    await rejects(() => httpSetup(() => value).adapter.createSyntheticOrder(orderInput()), 'synthetic_outcome_unknown');
  }
  await rejects(() => httpSetup(() => { throw new Error('offline'); }).adapter.readCatalog(), 'transport_unavailable');
  await rejects(() => httpSetup(() => response(200, {message:'fallback'})).adapter.readCatalog(), 'invalid_response');
});

test('browser export has no network bootstrap or CGA client', () => {
  let fetchCalls = 0;
  const window = {fetch:() => { fetchCalls++; throw new Error('must not run'); }};
  vm.runInNewContext(fs.readFileSync(require.resolve('../src/integration-adapters.js'), 'utf8'), {window});
  assert.equal(typeof window.MarthaIntegrations.createLocalAdapter, 'function');
  assert.equal(typeof window.MarthaIntegrations.createSaviaSyntheticAdapter, 'undefined');
  assert.equal(typeof window.MarthaIntegrations.createCgaHttpAdapter, 'undefined');
  assert.equal(fetchCalls, 0);
});

test('loopback HTTP fixture proves wire request and retry behavior, not .NET interoperability', async () => {
  const received = [], orders = new Map();
  const server = http.createServer((request, result) => {
    let raw = '';
    request.on('data', chunk => { raw += chunk; });
    request.on('end', () => {
      received.push({method:request.method, path:request.url, raw, key:request.headers['idempotency-key'], authorization:request.headers.authorization, cookie:request.headers.cookie});
      result.setHeader('Content-Type', 'application/json');
      if (request.method === 'GET' && request.url === '/api/v1/catalog') return result.end(JSON.stringify(externalCatalog()));
      if (request.method === 'POST' && request.url === '/api/v1/synthetic/orders') {
        const previous = orders.get(request.headers['idempotency-key']);
        if (previous && previous !== raw) { result.statusCode = 409; return result.end(JSON.stringify({status:409, code:'idempotency_conflict', title:'Conflict', traceId:'fixture'})); }
        orders.set(request.headers['idempotency-key'], raw); result.statusCode = 201; return result.end(JSON.stringify(externalOrder()));
      }
      result.statusCode = 404; result.end('{}');
    });
  });
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
  try {
    const origin = 'http://127.0.0.1:' + server.address().port;
    const adapter = createSaviaSyntheticAdapter({allowSyntheticOrders:true, transport:(path, options) => fetch(origin + path, options)});
    await adapter.readCatalog();
    const first = await adapter.createSyntheticOrder(orderInput());
    assert.deepEqual(await adapter.createSyntheticOrder(orderInput()), first);
    await rejects(() => adapter.createSyntheticOrder({...orderInput(), quantity:1}), 'idempotency_conflict');
    assert.equal(orders.size, 1);
    assert.equal(received[1].raw, JSON.stringify({variantId, quantity:2}));
    assert.equal(received[1].key, orderInput().idempotency_key);
    assert.ok(received.every(request => !request.authorization && !request.cookie));
  } finally {
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
  }
});

// Live model: the hub is a stubbed fetch here; tests/e2e evidence covers the real hub.
const {createLiveAdapter} = require('../src/integration-adapters.js');
const [rosa, gris] = catalog.products;
const liveConfig = {apiBase:'https://hub.example.test/', turnstileSiteKey:'', skus:{[rosa.variants[0].id]:'HUB-ROSA-S', [rosa.variants[1].id]:'HUB-ROSA-M'}};
const liveContact = {name:'Comprador Prueba', email:'buyer@example.test', phone:'0000-0000'};
const liveShipping = {zone:'managua', address:'Calle de prueba 1', city:'Managua, Managua'};
const json = (status, value) => ({ok:status >= 200 && status < 300, status, json:async () => value});
function liveSetup({items, onOrder} = {}) {
  const saved = new Map(), calls = [];
  const storage = {getItem:key => saved.get(key) ?? null, setItem:(key, value) => saved.set(key, value)};
  let hubItems = items || [
    {sku:'HUB-ROSA-S', productId:'p1', name:'Rosa', size:'S', color:'Rosa', unitPriceMinor:450000, currency:'NIO', available:2},
    {sku:'HUB-ROSA-M', productId:'p1', name:'Rosa', size:'M', color:'Rosa', unitPriceMinor:460000, currency:'NIO', available:0},
    {sku:'HUB-UNMAPPED', productId:'p9', name:'Otra', size:'S', color:'Azul', unitPriceMinor:100, currency:'NIO', available:9}];
  let keys = 0;
  const fetch = async (url, options) => {
    calls.push({url, options});
    const path = url.replace('https://hub.example.test', '');
    if (path === '/api/v1/public/catalog') return json(200, {items:hubItems});
    if (path === '/api/v1/public/orders') return onOrder ? onOrder(JSON.parse(options.body), options) : json(201, {orderId:orderId, code:'W-000123', accessToken:'token-secret', status:'reserved', totalMinor:500000, shippingMinor:50000, currency:'NIO', expiresAt:'2026-11-23T00:00:00Z', payment:{provider:'manual', label:'Pago manual (no es tarjeta)', kind:'instructions', url:null, method:'manual', instructions:'Le escribiremos.'}});
    if (path === `/api/v1/public/orders/${orderId}`) return options.headers['X-Order-Token'] === 'token-secret' ? json(200, {code:'W-000123', status:'paid', totalMinor:500000, currency:'NIO', expiresAt:'2026-11-23T00:00:00Z', lines:[{sku:'HUB-ROSA-S', qty:1}]}) : json(404, {code:'not_found'});
    return json(404, {code:'not_found'});
  };
  const api = createLiveAdapter({config:liveConfig, catalog, storage, fetch, uuid:() => `00000000-0000-4000-8000-${String(++keys).padStart(12, '0')}`});
  return {api, calls, saved, storage, setItems:value => { hubItems = value; }, orderCalls:() => calls.filter(call => call.url.endsWith('/api/v1/public/orders'))};
}
const liveInput = (prices = {[rosa.variants[0].id]:450000}, extra = {}) => ({contact:liveContact, shipping:liveShipping, provider:'manual', locale:'es', prices, ...extra});

test('live catalog shows only hub prices and stock; unmapped variants are not for sale', async () => {
  const {api} = liveSetup();
  const products = (await api('/api/catalog')).products;
  const first = products.find(p => p.id === rosa.id), second = products.find(p => p.id === gris.id);
  assert.equal(first.price_minor, 450000);
  assert.equal(first.currency, 'NIO');
  assert.deepEqual(first.variants.map(v => v.stock), [2, 0, 0]);
  assert.deepEqual(first.variants.map(v => v.sku), ['HUB-ROSA-S', 'HUB-ROSA-M', null]);
  assert.equal(second.price_minor, null);
  assert.ok(second.variants.every(v => v.stock === 0));
  await rejects(() => api('/api/cart/items', {variant_id:rosa.variants[1].id, quantity:1}), 'insufficient_stock');
  await rejects(() => api('/api/cart/items', {variant_id:gris.variants[0].id, quantity:1}), 'insufficient_stock');
  await rejects(() => api('/api/cart/items', {variant_id:rosa.variants[0].id, quantity:3}), 'insufficient_stock');
  const cart = await api('/api/cart/items', {variant_id:rosa.variants[0].id, quantity:1});
  assert.deepEqual([cart.subtotal_minor, cart.currency, cart.lines[0].sku], [450000, 'NIO', 'HUB-ROSA-S']);
  await rejects(() => api('/api/quote', {delivery_zone:'managua'}), 'unsupported_route');
});

test('live order sends the exact hub body with one key, credential-free, and keeps the token out of URLs', async () => {
  const {api, calls, saved, orderCalls} = liveSetup();
  await api('/api/cart/items', {variant_id:rosa.variants[0].id, quantity:1});
  const {order} = await api('/api/orders', liveInput());
  const [post] = orderCalls();
  assert.deepEqual(JSON.parse(post.options.body), {lines:[{sku:'HUB-ROSA-S', qty:1}], contact:liveContact, shipping:liveShipping, provider:'manual', locale:'es'});
  assert.match(post.options.headers['Idempotency-Key'], /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  assert.equal(post.options.credentials, 'omit');
  assert.equal(post.options.cache, 'no-store');
  assert.deepEqual([order.code, order.total_minor, order.shipping_minor, order.subtotal_minor, order.payment.label], ['W-000123', 500000, 50000, undefined, 'Pago manual (no es tarjeta)'], 'no subtotal is derived: the hub total can include tax');
  assert.equal((await api('/api/cart')).lines.length, 0);
  assert.equal(saved.get('martha-live-v1:pending'), 'null');
  const read = (await api(`/api/orders/${orderId}`)).order;
  assert.equal(read.status, 'paid');
  const get = calls.at(-1);
  assert.equal(get.options.headers['X-Order-Token'], 'token-secret');
  assert.ok(calls.every(call => !call.url.includes('token-secret')));
  await rejects(() => api('/api/orders/dddddddd-dddd-dddd-dddd-dddddddddddd'), 'not_found');
  assert.equal(calls.at(-1), get, 'an order unknown to this browser makes no request');
});

test('a retry after a lost response and a double submit reuse one Idempotency-Key; a new body gets a new key', async () => {
  let failNext = true;
  const keys = [];
  const {api, orderCalls} = liveSetup({onOrder:(body, options) => {
    keys.push(options.headers['Idempotency-Key']);
    if (failNext) { failNext = false; throw new TypeError('connection reset'); }
    return json(keys.length > 2 ? 200 : 201, {orderId, code:'W-000123', accessToken:'token-secret', status:'reserved', totalMinor:500000, shippingMinor:50000, currency:'NIO', expiresAt:'2026-11-23T00:00:00Z', payment:null});
  }});
  await api('/api/cart/items', {variant_id:rosa.variants[0].id, quantity:1});
  await assert.rejects(() => api('/api/orders', liveInput()), error => error.code === 'network' && error.ambiguous === true);
  const results = await Promise.all([api('/api/orders', liveInput()), api('/api/orders', liveInput())]);
  assert.deepEqual(results.map(result => result.order.id), [orderId, orderId]);
  assert.equal(new Set(keys).size, 1, keys.join());
  assert.equal(orderCalls().length, 3);
  await api('/api/cart/items', {variant_id:rosa.variants[0].id, quantity:1});
  await api('/api/orders', liveInput(undefined, {contact:{...liveContact, name:'Otra Persona'}}));
  assert.notEqual(keys.at(-1), keys[0]);
});

test('a changed hub price stops the order before it is placed', async () => {
  const {api, setItems, orderCalls} = liveSetup();
  await api('/api/cart/items', {variant_id:rosa.variants[0].id, quantity:1});
  setItems([{sku:'HUB-ROSA-S', productId:'p1', name:'Rosa', size:'S', color:'Rosa', unitPriceMinor:470000, currency:'NIO', available:2}]);
  await rejects(() => api('/api/orders', liveInput()), 'price_changed');
  assert.equal(orderCalls().length, 0);
  assert.equal((await api('/api/cart')).lines[0].unit_price_minor, 470000);
  setItems([]);
  await assert.rejects(() => api('/api/orders', liveInput({[rosa.variants[0].id]:470000})), error => error.code === 'out_of_stock' && error.message.includes(rosa.name) && error.message.includes('talla S'));
  assert.equal(orderCalls().length, 0);
});

test('hub problems map by code to authored messages; prose from the hub is never shown', async () => {
  const cases = [[409, {code:'out_of_stock', sku:'HUB-ROSA-S', message:'hub prose'}, 'out_of_stock', false],
    [429, {code:'rate_limited', message:'hub prose'}, 'rate_limited', false], [403, {code:'turnstile_failed'}, 'turnstile_failed', false],
    [400, {code:'validation', message:'hub prose'}, 'validation', false], [409, {code:'too_many_unpaid'}, 'too_many_unpaid', false],
    [503, {code:'unavailable'}, 'unavailable', true], [502, null, 'unavailable', true]];
  for (const [status, body, code, ambiguous] of cases) {
    const {api} = liveSetup({onOrder:() => json(status, body)});
    await api('/api/cart/items', {variant_id:rosa.variants[0].id, quantity:1});
    await assert.rejects(() => api('/api/orders', liveInput()), error => {
      assert.equal(error.code, code, status);
      assert.equal(!!error.ambiguous, ambiguous, code);
      assert.ok(!error.message.includes('hub prose'));
      if (code === 'out_of_stock') assert.ok(error.message.includes(`${rosa.name}, talla S`));
      return true;
    });
  }
});

test('a hub that cannot be read leaves nothing for sale', async () => {
  const api = createLiveAdapter({config:liveConfig, catalog, storage:null, fetch:async () => { throw new TypeError('offline'); }});
  await rejects(() => api('/api/catalog'), 'network');
  await rejects(() => api('/api/cart/items', {variant_id:rosa.variants[0].id, quantity:1}), 'network');
});

test('live contract: the manual label, zones and problem codes match the hub source', () => {
  const read = file => fs.readFileSync(require.resolve('../' + file), 'utf8');
  const label = read('savia/src/Savia.Api/Payments.cs').match(/public string Label => "([^"]+)";/)[1];
  const live = createLiveAdapter({config:liveConfig, catalog, storage:null, fetch:async () => json(200, {items:[]})});
  assert.deepEqual(live.providers.map(p => [p.code, p.label]), [['manual', label]]);
  const zones = [...read('savia/db/migrations/V049__web_order.sql').matchAll(/\('([a-z]+)',N'[^']+',\d+,'NIO'\)/g)].map(match => match[1]);
  assert.deepEqual(zones, ['managua', 'departamentos']);
  const app = read('src/app.js');
  for (const zone of zones) assert.ok(app.includes(`value="${zone}"`), zone);
  const hubCodes = new Set([...[read('savia/src/Savia.Api/PublicEndpoints.cs'), read('savia/src/Savia.Api/WebStoreHosting.cs')].join('').matchAll(/"([a-z]+(?:_[a-z]+)*)"/g)].map(match => match[1]));
  for (const code of ['out_of_stock', 'rate_limited', 'turnstile_failed', 'validation', 'too_many_unpaid', 'provider_unavailable', 'payload_too_large', 'unavailable']) assert.ok(hubCodes.has(code), code);
});

test('the default build stays in demo mode and the CONFIG line is the one prepare.py replaces', () => {
  const source = fs.readFileSync(require.resolve('../src/integration-adapters.js'), 'utf8');
  assert.equal(source.split('const CONFIG = {"apiBase":"","turnstileSiteKey":"","skus":{}};').length, 2);
  const window = {fetch:() => { throw new Error('must not run'); }};
  vm.runInNewContext(source, {window});
  assert.equal(window.MarthaIntegrations.live, false);
  assert.equal(typeof window.MarthaIntegrations.createLiveAdapter, 'function');
});

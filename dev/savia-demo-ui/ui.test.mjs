// DOM simulation only. This file does not start a browser, server, backend or SQL.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import {createDemoStore} from './model.mjs';
import {mountSaviaDemo} from './app.mjs';
import {API_PATHS, readBackendStatus} from './api-client.mjs';

const directory = path.dirname(fileURLToPath(import.meta.url));
const repository = path.resolve(directory, '../..');
const jsdomPackage = process.env.SAVIA_UI_JSDOM_PACKAGE
  ? path.resolve(process.env.SAVIA_UI_JSDOM_PACKAGE)
  : path.join(repository, 'tests/frontend-deps/node_modules/jsdom');
if (!fs.existsSync(path.join(jsdomPackage, 'package.json'))) {
  throw new Error('jsdom no está instalado en la ruta seleccionada. Definí SAVIA_UI_JSDOM_PACKAGE con una instalación existente; esta prueba no instala dependencias.');
}
const {JSDOM, VirtualConsole} = createRequire(import.meta.url)(jsdomPackage);
const html = fs.readFileSync(path.join(directory, 'index.html'), 'utf8');
const tick = () => new Promise(resolve => setImmediate(resolve));
const selectorValue = value => String(value).replace(/[\\"]/g, '\\$&');

async function boot() {
  const errors = [], requests = [];
  const console = new VirtualConsole();
  console.on('jsdomError', error => errors.push(error.message));
  const dom = new JSDOM(html, {
    url: 'http://127.0.0.1:8030/', runScripts: 'outside-only',
    pretendToBeVisual: true, virtualConsole: console,
  });
  const window = dom.window, document = window.document;
  window.HTMLElement.prototype.scrollIntoView = function () {};
  // jsdom has no native dialog interaction. This supplies only open/close/focus,
  // while production event handlers and the real model remain under test.
  window.HTMLDialogElement.prototype.showModal = function () {
    this.open = true;
    this.querySelector('button:not(:disabled),input:not(:disabled),select:not(:disabled)')?.focus();
  };
  window.HTMLDialogElement.prototype.close = function () {
    this.open = false;
    this.dispatchEvent(new window.Event('close'));
  };
  const fetchImpl = async (url, options = {}) => {
    requests.push({url, ...options});
    assert.equal(options.method, 'GET', 'connection diagnostics must not send mutations');
    throw new Error('Explicit offline test transport');
  };
  window.fetch = fetchImpl;
  const model = createDemoStore();
  const controller = await mountSaviaDemo({
    document, model, readStatus: () => readBackendStatus({fetchImpl, timeoutMs: 10}),
  });
  await tick();
  return {
    dom, window, document, model, controller, errors, requests,
    close() { controller?.destroy?.(); window.close(); },
  };
}

function element(ui, selector, root = ui.document) {
  const found = root.querySelector(selector);
  assert.ok(found, `Missing UI control: ${selector}`);
  return found;
}
async function click(ui, selector, root) {
  const button = element(ui, selector, root);
  assert.notEqual(button.disabled, true, `Control should be available: ${selector}`);
  button.focus(); button.click(); await tick();
}
async function navigate(ui, target) {
  await click(ui, `[data-action="nav"][data-target="${target}"]`);
}
function availableFixture(ui, minimum = 2) {
  const product = ui.model.getCatalog().find(item => item.sizes.some(size => size.available >= minimum));
  assert.ok(product, 'Fixture must support a meaningful quantity edit');
  return {product, variant: product.sizes.find(size => size.available >= minimum)};
}
function stock(ui, product, size) {
  return ui.model.getCatalog().find(item => item.id === product.id).sizes.find(item => item.size === size).available;
}
async function add(ui, product, size) {
  await navigate(ui, 'catalogo');
  const card = element(ui, `[data-product-id="${selectorValue(product.id)}"]`, element(ui, '[data-view="catalogo"]'));
  const select = element(ui, `[data-size-for="${selectorValue(product.id)}"]`, card);
  select.value = size;
  select.dispatchEvent(new ui.window.Event('change', {bubbles: true}));
  await click(ui, `[data-action="add"][data-product="${selectorValue(product.id)}"]`, card);
}
async function openPayment(ui) {
  await navigate(ui, 'caja');
  await click(ui, '[data-action="pay"]');
  assert.equal(element(ui, '#payment-dialog').open, true);
}
async function approve(ui) {
  await openPayment(ui);
  await click(ui, '[data-action="approve"]', element(ui, '#payment-dialog'));
}

test('mount is explicit about demo/memory and does not contact backend automatically', async () => {
  const ui = await boot();
  try {
    assert.equal(ui.model.getCatalog().length, 6);
    assert.equal(ui.model.getState().cart.length, 0);
    assert.equal(element(ui, '[data-action="pay"]').disabled, true);
    assert.match(ui.document.body.textContent, /demostraci[oó]n|\bdemo\b/i);
    assert.match(ui.document.body.textContent, /sin cobros|no se (?:cobra|realizan cobros)/i);
    assert.match(ui.document.body.textContent, /recarg|recarga/i);
    assert.match(ui.document.body.textContent, /no reserva/i);
    assert.equal(element(ui, '#ui-status').getAttribute('role'), 'status');
    assert.equal(element(ui, '#ui-error').getAttribute('role'), 'alert');
    assert.equal(ui.requests.length, 0);
    assert.deepEqual(ui.errors, []);
  } finally { ui.close(); }
});

test('search filters displayed catalog without changing the scenario', async () => {
  const ui = await boot();
  try {
    await navigate(ui, 'catalogo');
    const before = ui.model.getState(), catalog = ui.model.getCatalog();
    const search = element(ui, '#catalog-search');
    search.value = 'no-existing-synthetic-garment';
    search.dispatchEvent(new ui.window.Event('input', {bubbles: true})); await tick();
    assert.equal(element(ui, '[data-view="catalogo"]').querySelectorAll('[data-product-id]').length, 0);
    search.value = ''; search.dispatchEvent(new ui.window.Event('input', {bubbles: true})); await tick();
    assert.equal(element(ui, '[data-view="catalogo"]').querySelectorAll('[data-product-id]').length, 6);
    assert.deepEqual(ui.model.getState(), before);
    assert.deepEqual(ui.model.getCatalog(), catalog);
  } finally { ui.close(); }
});

test('size must be selected and exhausted sizes are unavailable', async () => {
  const ui = await boot();
  try {
    await navigate(ui, 'catalogo');
    const product = ui.model.getCatalog().find(item => item.sizes.some(size => size.available === 0));
    const card = element(ui, `[data-product-id="${product.id}"]`, element(ui, '[data-view="catalogo"]'));
    const select = element(ui, `[data-size-for="${product.id}"]`, card);
    const soldOut = product.sizes.find(size => size.available === 0);
    assert.equal(element(ui, `option[value="${soldOut.size}"]`, select).disabled, true);
    assert.equal(select.value, '', 'mount must not silently pick a size');
    const addButton = element(ui, '[data-action="add"]', card);
    if (!addButton.disabled) {
      addButton.click(); await tick();
      assert.match(element(ui, '#ui-error').textContent, /talla/i);
      assert.equal(ui.document.activeElement, select);
    }
    assert.equal(ui.model.getState().cart.length, 0);
  } finally { ui.close(); }
});

test('cart actions preserve useful focus and announce removal without reserving stock', async () => {
  const ui = await boot();
  try {
    const {product, variant} = availableFixture(ui, 3), originalStock = variant.available;
    await add(ui, product, variant.size); await navigate(ui, 'caja');
    const line = ui.model.getState().cart[0];
    const incrementSelector = `[data-action="increment"][data-line="${line.id}"]`;
    const removeSelector = `[data-action="remove"][data-line="${line.id}"]`;
    assert.match(element(ui, removeSelector).getAttribute('aria-label') || '', new RegExp(variant.size));
    assert.ok((element(ui, removeSelector).getAttribute('aria-label') || '').includes(product.name));
    await click(ui, incrementSelector);
    assert.equal(ui.model.getState().cart[0].quantity, 2);
    assert.equal(stock(ui, product, variant.size), originalStock, 'bag edits are not stock reservations');
    assert.equal(ui.document.activeElement, element(ui, incrementSelector));
    await click(ui, removeSelector);
    assert.equal(ui.model.getState().cart.length, 0);
    assert.equal(element(ui, '[data-action="pay"]').disabled, true);
    assert.notEqual(ui.document.activeElement, ui.document.body);
    assert.match(element(ui, '#ui-status').textContent, /retir|quitad|bolsa vac[ií]a/i);
  } finally { ui.close(); }
});

test('approval changes stock once and displays a clearly synthetic receipt', async () => {
  const ui = await boot();
  try {
    const {product, variant} = availableFixture(ui);
    await add(ui, product, variant.size); await openPayment(ui);
    const approveButton = element(ui, '[data-action="approve"]', element(ui, '#payment-dialog'));
    approveButton.click(); approveButton.click(); await tick();
    const state = ui.model.getState();
    assert.equal(state.sales.length, 1);
    assert.equal(state.cart.length, 0);
    assert.equal(stock(ui, product, variant.size), variant.available - 1);
    assert.equal(element(ui, '#receipt-dialog').open, true);
    const receipt = element(ui, '[data-receipt-content]').textContent;
    assert.match(receipt, /ficticio|sin validez fiscal|sin cobro real/i);
    assert.ok(receipt.includes(state.sales[0].id));
    assert.ok(receipt.includes(product.name));
    assert.equal(ui.requests.length, 0);
  } finally { ui.close(); }
});

test('decline is recoverable and preserves both cart and stock', async () => {
  const ui = await boot();
  try {
    const {product, variant} = availableFixture(ui);
    await add(ui, product, variant.size);
    const before = ui.model.getState(), catalog = ui.model.getCatalog();
    await openPayment(ui); await click(ui, '[data-action="decline"]', element(ui, '#payment-dialog'));
    assert.deepEqual(ui.model.getState().cart, before.cart);
    assert.equal(ui.model.getState().sales.length, 0);
    assert.deepEqual(ui.model.getCatalog(), catalog);
    assert.match(element(ui, '#ui-status').textContent + element(ui, '#ui-error').textContent, /rechaz|no aprobad/i);
    assert.notEqual(ui.document.activeElement, ui.document.body);
  } finally { ui.close(); }
});

test('cancelling a demo receipt restores units once and disables repeat cancellation', async () => {
  const ui = await boot();
  try {
    const {product, variant} = availableFixture(ui);
    await add(ui, product, variant.size); await approve(ui);
    await click(ui, '[data-action="close-dialog"]', element(ui, '#receipt-dialog'));
    assert.notEqual(ui.document.activeElement, ui.document.body, 'closing receipt must return usable focus');
    await navigate(ui, 'ventas');
    const sale = ui.model.getState().sales[0];
    const cancelSelector = `[data-action="cancel-sale"][data-sale="${sale.id}"]`;
    await click(ui, cancelSelector); assert.equal(element(ui, '#confirm-dialog').open, true);
    await click(ui, '[data-action="confirm"]', element(ui, '#confirm-dialog'));
    assert.equal(ui.model.getState().sales[0].status, 'cancelled');
    assert.equal(stock(ui, product, variant.size), variant.available);
    const repeated = ui.document.querySelector(cancelSelector);
    assert.ok(!repeated || repeated.disabled, 'cancelled receipt must not offer an enabled cancellation');
  } finally { ui.close(); }
});

test('reset requires confirmation and restores the independent sample scenario', async () => {
  const ui = await boot();
  try {
    const originalCatalog = ui.model.getCatalog(), {product, variant} = availableFixture(ui);
    await add(ui, product, variant.size); await approve(ui);
    await click(ui, '[data-action="close-dialog"]', element(ui, '#receipt-dialog'));
    await add(ui, product, variant.size);
    const before = ui.model.getState();
    await click(ui, '[data-action="reset-demo"]');
    await click(ui, '[data-action="close-dialog"]', element(ui, '#confirm-dialog'));
    assert.deepEqual(ui.model.getState(), before, 'dismissed confirmation must preserve the scenario');
    await click(ui, '[data-action="reset-demo"]');
    await click(ui, '[data-action="confirm"]', element(ui, '#confirm-dialog'));
    assert.equal(ui.model.getState().cart.length, 0);
    assert.equal(ui.model.getState().sales.length, 0);
    assert.deepEqual(ui.model.getCatalog(), originalCatalog);
    assert.notEqual(ui.document.activeElement, ui.document.body);
  } finally { ui.close(); }
});

test('Connection unavailable is explicit and uses only virtual same-origin GETs', async () => {
  const ui = await boot();
  try {
    const before = ui.model.getState(), catalog = ui.model.getCatalog();
    await navigate(ui, 'conexion');
    const previousRequests = ui.requests.length;
    await click(ui, '[data-action="check-backend"]');
    await tick();
    assert.match(element(ui, '[data-backend-status]').textContent, /no (?:est[aá] )?disponible|no se pudo/i);
    assert.equal(ui.requests.length - previousRequests, 3);
    assert.deepEqual(ui.requests.slice(previousRequests).map(item => item.url), Object.values(API_PATHS));
    assert.ok(ui.requests.every(item => item.method === 'GET' && item.credentials === 'omit' && item.redirect === 'error'));
    assert.deepEqual(ui.model.getState(), before);
    assert.deepEqual(ui.model.getCatalog(), catalog);
    assert.deepEqual(ui.errors, []);
  } finally { ui.close(); }
});

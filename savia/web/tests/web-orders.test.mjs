import assert from 'node:assert/strict';
import test from 'node:test';
import * as api from '../api.mjs';
import { canAccess, navigation } from '../roles.mjs';
import { linesText, manualPayment, orderActions, statusLabel } from '../screens/web-orders-logic.mjs';

const order = { id: 'o1', code: 'W-1', status: 'reserved', totalMinor: 170000, currency: 'NIO', lines: [{ sku: 'A', qty: 2 }, { sku: 'B', qty: 1 }] };

test('each status offers only the staff actions the hub accepts', () => {
  assert.deepEqual(orderActions({ status: 'reserved' }), ['pay', 'cancel']);
  assert.deepEqual(orderActions({ status: 'paid' }), ['fulfill']);
  for (const status of ['fulfilled', 'cancelled', 'expired', 'payment_review', 'refunded']) assert.deepEqual(orderActions({ status }), [], status);
});

test('status labels are Spanish and an unknown status shows as it came', () => {
  assert.equal(statusLabel('reserved'), 'Reservado, sin pagar');
  assert.equal(statusLabel('payment_review'), 'Pago tardío: revisar');
  assert.equal(statusLabel('nuevo'), 'nuevo');
});

test('a manual payment needs a reference and records the order total', () => {
  assert.deepEqual(manualPayment(order, '  '), { error: 'Indique la referencia del pago (número de transferencia o recibo).' });
  assert.deepEqual(manualPayment(order, 'x'.repeat(161)), { error: 'La referencia admite 160 caracteres.' });
  assert.deepEqual(manualPayment(order, ' TRF 123 '), { body: { amountMinor: 170000, currency: 'NIO', reference: 'TRF 123' } });
});

test('lines read as sku and quantity', () => {
  assert.equal(linesText(order), 'A × 2 · B × 1');
});

test('web-order calls use the hub routes', async () => {
  const original = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async (url, options) => {
    calls.push({ url, method: options.method, body: options.body && JSON.parse(options.body) });
    return { ok: true, status: 204, text: async () => '' };
  };
  try {
    await api.webOrders('reserved');
    await api.webOrders('');
    await api.recordManualPayment('o/1', { amountMinor: 1, currency: 'NIO', reference: 'r' });
    await api.fulfillWebOrder('o1');
    await api.cancelWebOrder('o1');
    assert.deepEqual(calls, [
      { url: '/api/v1/web-orders?status=reserved', method: 'GET', body: undefined },
      { url: '/api/v1/web-orders', method: 'GET', body: undefined },
      { url: '/api/v1/web-orders/o%2F1/manual-payment', method: 'POST', body: { amountMinor: 1, currency: 'NIO', reference: 'r' } },
      { url: '/api/v1/web-orders/o1/fulfill', method: 'POST', body: undefined },
      { url: '/api/v1/web-orders/o1/cancel', method: 'POST', body: undefined },
    ]);
  } finally {
    globalThis.fetch = original;
  }
});

test('the web-orders screen is for approvers and appears only on the hub', () => {
  assert.equal(canAccess('pedidos-web', ['MANAGER']), true);
  assert.equal(canAccess('pedidos-web', ['SELLER']), false);
  const routes = nodeKind => navigation(['OWNER'], nodeKind).flatMap(g => g.screens.map(s => s.route));
  assert.ok(routes('Cloud').includes('pedidos-web'));
  assert.ok(!routes('Branch').includes('pedidos-web'));
});

class Element {
  constructor(tag) {
    this.tag = tag;
    this.children = [];
    this.handlers = {};
    this.dataset = {};
    this.value = '';
  }
  setAttribute(key, value) {
    this[key] = value;
  }
  addEventListener(name, fn) {
    this.handlers[name] = fn;
  }
  focus() {}
  append(node) {
    this.children.push(node);
  }
  replaceChildren() {
    this.children = [];
  }
}
const nodes = root => [root, ...root.children.flatMap(nodes)];
const text = root => root.text ?? root.children.map(text).join('');

async function withDom(orders, run) {
  const old = { document: globalThis.document, Node: globalThis.Node, fetch: globalThis.fetch };
  const requests = [];
  globalThis.Node = Element;
  globalThis.document = { createElement: tag => new Element(tag), createTextNode: t => ({ text: t, children: [] }) };
  globalThis.fetch = async (url, options) => {
    requests.push(`${options.method} ${url}`);
    return new Response(JSON.stringify(orders), { status: 200 });
  };
  try {
    await run(requests);
  } finally {
    Object.assign(globalThis, old);
  }
}

const listed = [
  { ...order, id: 'r1', code: 'W-R', shippingMinor: 50000, provider: 'manual', name: 'Ana', phone: '8888', email: 'ana@example.test', address: 'Calle 1', city: 'Managua', zone: 'managua', createdAt: '2026-11-22T12:00:00Z', expiresAt: '2026-11-22T12:30:00Z', sourceStore: 'CENTRO' },
  { ...order, id: 'p1', code: 'W-P', status: 'paid', shippingMinor: 50000, provider: 'manual', name: 'Luis', createdAt: '2026-11-22T12:00:00Z', notes: null },
];

test('the hub screen lists each order with its contact and only the buttons its status allows', async () => {
  const { default: screen } = await import('../screens/web-orders.mjs');
  await withDom(listed, async requests => {
    const root = new Element('main');
    await screen.mount(root, { me: { nodeKind: 'Cloud' }, notify() {} });
    assert.deepEqual(requests, ['GET /api/v1/web-orders']);
    const cards = nodes(root).filter(n => n.tag === 'section');
    assert.deepEqual(cards.map(c => c.dataset.status), ['reserved', 'paid']);
    const buttons = card => nodes(card).filter(n => n.tag === 'button').map(text);
    assert.deepEqual(buttons(cards[0]), ['Registrar pago', 'Cancelar']);
    assert.deepEqual(buttons(cards[1]), ['Marcar enviado']);
    assert.ok(text(cards[0]).includes('Calle 1') && text(cards[0]).includes('ana@example.test') && text(cards[0]).includes('CENTRO'));
    assert.ok(text(cards[0]).includes('A × 2 · B × 1'));
    assert.ok(!nodes(cards[1]).some(n => n.tag === 'input'), 'a paid order asks for no payment reference');

    // An empty reference stops before the confirmation and before any request.
    nodes(cards[0]).find(n => n.tag === 'button' && text(n) === 'Registrar pago').handlers.click({ target: {} });
    assert.equal(nodes(root).find(n => n.role === 'alert').textContent, 'Indique la referencia del pago (número de transferencia o recibo).');
    assert.equal(requests.length, 1);
  });
});

test('on a store the screen explains that web orders are handled on the hub and calls nothing', async () => {
  const { default: screen } = await import('../screens/web-orders.mjs');
  await withDom([], async requests => {
    const root = new Element('main');
    await screen.mount(root, { me: { nodeKind: 'Branch' } });
    assert.equal(text(root), 'Los pedidos web se atienden en el servidor central.');
    assert.deepEqual(requests, []);
  });
});

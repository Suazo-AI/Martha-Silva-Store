import assert from 'node:assert/strict';
import test from 'node:test';
import * as api from '../api.mjs';
import { newCustomer, statusLabel, transferActions, transferRequest } from '../screens/credit-transfers-logic.mjs';

const row = { fromBranchId: 'A', toBranchId: 'B' };

test('each node offers only the transfer steps it owns', () => {
  const steps = (status, kind, branch) => transferActions({ ...row, status }, kind, branch);
  assert.deepEqual(steps('requested', 'Cloud'), ['approve', 'cancel']);
  assert.deepEqual(steps('approved', 'Cloud'), ['cancel']);
  assert.deepEqual(steps('in_transit', 'Cloud'), []);
  assert.deepEqual(steps('requested', 'Branch', 'A'), []);
  assert.deepEqual(steps('approved', 'Branch', 'A'), ['dispatch']);
  assert.deepEqual(steps('approved', 'Branch', 'B'), []);
  assert.deepEqual(steps('in_transit', 'Branch', 'B'), ['receive']);
  assert.deepEqual(steps('in_transit', 'Branch', 'A'), []);
  assert.deepEqual(steps('received', 'Branch', 'B'), []);
  assert.equal(statusLabel('in_transit'), 'En tránsito, por recibir');
});

test('a transfer request takes the amount in minor units, within the balance of that store', () => {
  const credit = { creditId: 'c1', branchId: 'A', availableMinor: 120000 };
  assert.deepEqual(transferRequest(credit, 'B', '500', ' Canje en B ', 't1'), {
    body: { transferId: 't1', creditId: 'c1', fromBranchId: 'A', toBranchId: 'B', amountMinor: 50000, reason: 'Canje en B' },
  });
  assert.equal(transferRequest(credit, 'B', '', 'x', 't1').error, 'Escriba el monto a traer.');
  assert.equal(transferRequest(credit, 'B', '1200.01', 'x', 't1').error, 'El monto supera el saldo de esa sucursal.');
  assert.equal(transferRequest(credit, 'B', '10', '  ', 't1').error, 'Escriba el motivo del traslado.');
});

test('a new customer needs a name; empty optional fields go as null', () => {
  const blank = { displayName: '', documentNumber: '', phone: '', email: '' };
  assert.equal(newCustomer(blank, 'k').error, 'Escriba el nombre de la clienta.');
  assert.deepEqual(newCustomer({ ...blank, displayName: ' Ana Prueba ', email: 'ana@example.test' }, 'k').body, {
    customerId: 'k',
    displayName: 'Ana Prueba',
    documentNumber: null,
    phone: null,
    email: 'ana@example.test',
  });
});

test('customer and transfer calls use the routes of the API', async () => {
  const original = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async (url, init) => {
    calls.push(`${init.method} ${url} ${init.body ?? ''}`.trim());
    return new Response(init.method === 'GET' ? '[]' : null, { status: init.method === 'GET' ? 200 : 204 });
  };
  try {
    await api.createCustomer({ customerId: 'k' });
    await api.creditTransfers();
    await api.requestCreditTransfer({ transferId: 't' });
    await api.approveCreditTransfer('t');
    await api.cancelCreditTransfer('t', 'r');
    await api.dispatchCreditTransfer('t');
    await api.receiveCreditTransfer('t');
  } finally {
    globalThis.fetch = original;
  }
  assert.deepEqual(calls, [
    'POST /api/v1/customers {"customerId":"k"}',
    'GET /api/v1/credit-transfers',
    'POST /api/v1/credit-transfers {"transferId":"t"}',
    'POST /api/v1/credit-transfers/t/approve',
    'POST /api/v1/credit-transfers/t/cancel {"reason":"r"}',
    'POST /api/v1/credit-transfers/t/dispatch',
    'POST /api/v1/credit-transfers/t/receive',
  ]);
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
const buttons = card =>
  nodes(card)
    .filter(n => n.tag === 'button')
    .map(text);

async function mounted(me, rows) {
  const old = { document: globalThis.document, Node: globalThis.Node, fetch: globalThis.fetch };
  const requests = [];
  globalThis.Node = Element;
  globalThis.document = { createElement: tag => new Element(tag), createTextNode: t => ({ text: t, children: [] }) };
  globalThis.fetch = async (url, options) => {
    requests.push(`${options.method} ${url}`);
    return new Response(JSON.stringify(rows), { status: 200 });
  };
  try {
    const { default: screen } = await import('../screens/credit-transfers.mjs');
    const root = new Element('main');
    await screen.mount(root, { me, notify() {} });
    return { root, requests, cards: nodes(root).filter(n => n.tag === 'section') };
  } finally {
    Object.assign(globalThis, old);
  }
}

const listed = ['requested', 'approved', 'in_transit'].map((status, i) => ({
  transferId: `t${i}`,
  creditId: 'c1',
  customerName: 'Clienta Prueba',
  fromBranchId: 'A',
  fromBranchName: 'Centro',
  toBranchId: 'B',
  toBranchName: 'Masaya',
  amountMinor: 50000,
  currencyCode: 'NIO',
  status,
  reason: 'Canje en Masaya',
  requestedAt: '2026-11-22T12:00:00Z',
}));

test('the hub lists every transfer and offers approve and cancel only while it is open', async () => {
  const { root, requests, cards } = await mounted({ nodeKind: 'Cloud' }, listed);
  assert.deepEqual(requests, ['GET /api/v1/credit-transfers']);
  assert.deepEqual(cards.map(buttons), [['Aprobar', 'Cancelar'], ['Cancelar'], []]);
  assert.ok(text(cards[0]).includes('Centro → Masaya · Solicitado, espera aprobación'));
  // A cancel without a reason stops before the confirmation and before any request.
  nodes(cards[0])
    .find(n => n.tag === 'button' && text(n) === 'Cancelar')
    .handlers.click({ target: {} });
  assert.equal(nodes(root).find(n => n.role === 'alert').textContent, 'Escriba el motivo de la cancelación.');
  assert.equal(requests.length, 1);
});

test('the origin store dispatches and the destination store receives', async () => {
  assert.deepEqual((await mounted({ nodeKind: 'Branch', branchId: 'A' }, listed)).cards.map(buttons), [[], ['Enviar'], []]);
  assert.deepEqual((await mounted({ nodeKind: 'Branch', branchId: 'B' }, listed)).cards.map(buttons), [[], [], ['Recibir']]);
});

import assert from 'node:assert/strict';
import test from 'node:test';
import { canAccess, navigation, SCREENS } from '../roles.mjs';
import history from '../screens/history.mjs';

test('work groups preserve every role combination, without duplicate or empty groups', () => {
  const roles = ['OWNER', 'MANAGER', 'SELLER', 'INVENTORY', 'CASHIER', 'UNKNOWN'];
  for (let mask = 0; mask < 2 ** roles.length; mask++) {
    const selected = roles.filter((_, i) => mask & (1 << i));
    const groups = navigation(selected);
    const routes = groups.flatMap(g => g.screens.map(s => s.route));
    assert.ok(groups.every(g => g.screens.length));
    assert.equal(new Set(routes).size, routes.length);
    assert.deepEqual(
      routes.toSorted(),
      SCREENS.filter(s => s.label && !s.node && canAccess(s.route, selected))
        .map(s => s.route)
        .toSorted(),
    );
  }
  const owner = navigation(['OWNER']);
  assert.deepEqual(
    owner[0].screens.map(s => s.route),
    ['venta', 'caja', 'inventario', 'historial'],
  );
  assert.equal(owner.length, 4);
  assert.equal(owner.flatMap(g => g.screens).length, 15);
  assert.deepEqual(
    navigation(['SELLER']).map(g => g.label),
    ['Consultas', 'Administración'],
  );
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
  removeEventListener() {}
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

test('history uses recorded receipt numbers, honest missing-number fallback, and original actions/search', async () => {
  const old = { document: globalThis.document, Node: globalThis.Node, fetch: globalThis.fetch };
  const requests = [],
    routes = [];
  const sales = ['CENTRO-42', null, '', '   '].map((receiptNumber, i) => ({
    saleId: `uuid-${i}`,
    receiptNumber,
    createdAt: '2026-11-16T12:00:00Z',
    totalMinor: 159900,
    status: 'posted',
    lines: [],
  }));
  globalThis.Node = Element;
  globalThis.document = {
    createElement: tag => new Element(tag),
    createTextNode: text => ({ text, children: [] }),
    addEventListener() {},
    removeEventListener() {},
  };
  globalThis.fetch = async url => {
    requests.push(String(url));
    const path = String(url).split('?')[0];
    const body = path.endsWith('/sales') ? { items: sales, total: 4, page: 1, pageSize: 25 } : sales.find(s => path.endsWith(s.saleId));
    return new Response(JSON.stringify(body), { status: 200 });
  };
  try {
    const root = new Element('main');
    const handle = await history.mount(root, { go: route => routes.push(route) });
    const all = nodes(root);
    const headings = all.filter(n => n.tag === 'h2').map(text);
    assert.deepEqual(headings, ['Recibo CENTRO-42', ...Array(3).fill('Venta sin número de recibo')]);
    const articles = all.filter(n => n.tag === 'article');
    assert.ok(text(articles[0]).includes('1,599'));
    const support = nodes(articles[0]).find(n => n.tag === 'details');
    assert.ok(text(support).includes('uuid-0'));
    assert.equal(support.open, undefined);
    for (const label of ['Ver recibo', 'Devolver']) all.find(n => n.tag === 'button' && text(n) === label).handlers.click();
    assert.deepEqual(routes, ['recibo?sale=uuid-0', 'devolucion?sale=uuid-0']);
    await handle.handleScan('CENTRO-42');
    assert.ok(requests.some(url => url.includes('q=CENTRO-42')));
    handle.unmount();
  } finally {
    Object.assign(globalThis, old);
  }
});

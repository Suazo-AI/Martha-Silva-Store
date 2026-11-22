// S9 (D-039): on a store with a hub the price and import screens say where the catalog is managed and call no API.
import assert from 'node:assert/strict';
import test from 'node:test';

class Element {
  constructor(tag, text = '') {
    this.tag = tag;
    this.attributes = {};
    this.dataset = {};
    this.children = [];
    this.text = text;
  }
  setAttribute(key, value) {
    this.attributes[key] = value;
  }
  addEventListener() {}
  append(...children) {
    this.children.push(...children);
  }
  replaceChildren(...children) {
    this.children = children;
  }
  get textContent() {
    return this.text + this.children.map(child => child.textContent).join('');
  }
  set textContent(value) {
    this.children = [];
    this.text = String(value);
  }
}
globalThis.Node = Element;
globalThis.document = { createElement: tag => new Element(tag), createTextNode: text => new Element('#text', text) };
globalThis.localStorage = { getItem: () => null, setItem() {} };
const calls = [];
globalThis.fetch = async url => {
  calls.push(String(url));
  return new Response('[]', { status: 200, headers: { 'content-type': 'application/json' } });
};

const { default: prices } = await import('../screens/prices.mjs');
const { default: importer } = await import('../screens/import.mjs');

const mount = async (screen, me) => {
  const root = new Element('main');
  await screen.mount(root, { me, isCurrent: () => true, notify() {}, go() {} });
  return root.textContent;
};

test('a store with a hub shows the central catalog on prices and import, and calls no API', async () => {
  calls.length = 0;
  const me = { nodeKind: 'Branch', catalogManagedByHub: true };
  assert.match(await mount(prices, me), /El catálogo se gestiona en la central\./);
  assert.match(await mount(importer, me), /El catálogo se gestiona en la central\./);
  assert.deepEqual(calls, []);
});

test('the hub and a store without a hub keep the forms', async () => {
  for (const me of [{ nodeKind: 'Cloud', catalogManagedByHub: false }, { nodeKind: 'Branch' }]) {
    assert.doesNotMatch(await mount(prices, me), /se gestiona en la central/);
    assert.doesNotMatch(await mount(importer, me), /se gestiona en la central/);
  }
});

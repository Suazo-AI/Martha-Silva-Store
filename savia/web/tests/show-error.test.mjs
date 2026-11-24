import assert from 'node:assert/strict';
import test from 'node:test';
import { showError } from '../ui.mjs';

class Element {
  constructor(tag) {
    this.tag = tag;
    this.attributes = {};
  }
  setAttribute(key, value) {
    this.attributes[key] = value;
  }
  addEventListener() {}
  append() {}
}

function shown(error, nextStep) {
  const oldDocument = globalThis.document,
    oldNode = globalThis.Node;
  globalThis.Node = Element;
  globalThis.document = { createElement: tag => new Element(tag), createTextNode: text => ({ text }) };
  try {
    const el = new Element('p');
    showError(el, error, nextStep);
    return el.textContent;
  } finally {
    globalThis.document = oldDocument;
    globalThis.Node = oldNode;
  }
}

test('a restored branch tells the cashier to wait, not to fix their input', () => {
  const lock = { code: 'sync.recovery_pending', message: 'Sucursal restaurada: no se puede vender.' };
  const text = shown(lock, 'Revise los datos y vuelva a intentar.');
  assert.match(text, /^Sucursal restaurada: no se puede vender\. Espere unos minutos/);
  assert.doesNotMatch(text, /Revise los datos/);
});

test('other errors keep the screen advice', () => {
  const text = shown({ code: 'cash.register_till_open', message: 'Esta caja ya tiene un turno abierto.' }, 'Revise.');
  assert.equal(text, 'Esta caja ya tiene un turno abierto. Revise.');
});

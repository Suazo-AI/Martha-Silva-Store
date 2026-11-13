import assert from 'node:assert/strict';
import test from 'node:test';
import { attachScanField, readScan, serialQueue, shouldReclaimFocus } from '../scan.mjs';

test('readScan keeps leading zeros and strips scanner noise', () => {
  assert.equal(readScan('0000123456789'), '0000123456789');
  assert.equal(readScan('  0000123456789\r\n'), '0000123456789');
  assert.equal(readScan('\t'), null);
  assert.equal(readScan(''), null);
  assert.equal(readScan('x'.repeat(129)), null);
});

const el = (tagName, extra = {}) => ({ tagName, closest: () => null, ...extra });

test('shouldReclaimFocus: buttons and body give focus back, text fields and dialogs keep it', () => {
  const field = el('INPUT', { type: 'text' });
  assert.equal(shouldReclaimFocus(null, field), true);
  assert.equal(shouldReclaimFocus(field, field), false);
  assert.equal(shouldReclaimFocus(el('BODY'), field), true);
  assert.equal(shouldReclaimFocus(el('BUTTON'), field), true);
  assert.equal(shouldReclaimFocus(el('INPUT', { type: 'text' }), field), false);
  assert.equal(shouldReclaimFocus(el('INPUT', { type: 'checkbox' }), field), true);
  assert.equal(shouldReclaimFocus(el('SELECT'), field), false);
  assert.equal(shouldReclaimFocus(el('BUTTON', { closest: s => (s === 'dialog[open]' ? {} : null) }), field), false);
});

/** Minimal fake DOM: enough for attachScanField. */
function fakeDom() {
  const listeners = {};
  const doc = {
    activeElement: null,
    addEventListener: (t, fn) => {
      listeners[`doc:${t}`] ??= [];
      listeners[`doc:${t}`].push(fn);
    },
    removeEventListener: (t, fn) => {
      listeners[`doc:${t}`] = (listeners[`doc:${t}`] || []).filter(f => f !== fn);
    },
  };
  const input = {
    tagName: 'INPUT',
    type: 'text',
    value: '',
    isConnected: true,
    disabled: false,
    closest: () => null,
    addEventListener: (t, fn) => {
      listeners[t] ??= [];
      listeners[t].push(fn);
    },
    removeEventListener: (t, fn) => {
      listeners[t] = (listeners[t] || []).filter(f => f !== fn);
    },
    focus() {
      doc.activeElement = input;
    },
  };
  const fire = (t, event = {}) => {
    for (const fn of listeners[t] || []) fn(event);
  };
  const fireDoc = (t, event = {}) => {
    for (const fn of listeners[`doc:${t}`] || []) fn(event);
  };
  return { doc, input, fire, fireDoc, listeners };
}

test('attachScanField: Enter sends the code and clears the field at once', () => {
  const { doc, input, fire } = fakeDom();
  const codes = [];
  attachScanField(input, code => codes.push(code), { doc });
  assert.equal(doc.activeElement, input);
  for (let i = 0; i < 5; i++) {
    input.value = '0000123456789';
    let prevented = false;
    fire('keydown', {
      key: 'Enter',
      preventDefault: () => {
        prevented = true;
      },
    });
    assert.equal(prevented, true);
    assert.equal(input.value, '');
  }
  input.value = '   ';
  fire('keydown', { key: 'Enter', preventDefault() {} });
  input.value = '123';
  fire('keydown', { key: '3', preventDefault() {} });
  assert.deepEqual(codes, Array(5).fill('0000123456789'));
});

test('attachScanField: takes focus back after a click on a button, not from another text field', async () => {
  const { doc, input, fireDoc } = fakeDom();
  attachScanField(input, () => {}, { doc });
  doc.activeElement = el('BUTTON');
  fireDoc('click');
  await new Promise(r => setTimeout(r, 5));
  assert.equal(doc.activeElement, input);
  const other = el('INPUT', { type: 'text' });
  doc.activeElement = other;
  fireDoc('click');
  await new Promise(r => setTimeout(r, 5));
  assert.equal(doc.activeElement, other);
});

test('attachScanField: detach removes every listener', () => {
  const { doc, input, listeners } = fakeDom();
  const detach = attachScanField(input, () => {}, { doc });
  detach();
  const left = Object.values(listeners).reduce((n, list) => n + list.length, 0);
  assert.equal(left, 0);
});

test('scanner burst without focus reports once; focused burst does not duplicate Enter', () => {
  const { doc, input, fireDoc, fire } = fakeDom();
  const codes = [];
  const detach = attachScanField(input, code => codes.push(code), { doc, keepFocus: false });
  const burst = target => {
    for (const key of '7500001000014') fireDoc('keydown', { key, target });
    const event = {
      key: 'Enter',
      target,
      defaultPrevented: false,
      preventDefault() {
        this.defaultPrevented = true;
      },
    };
    fireDoc('keydown', event);
    return event;
  };
  burst(el('BODY'));
  input.value = '';
  for (const key of '7500001000014') {
    fireDoc('keydown', { key, target: input });
    input.value += key;
  }
  const enter = {
    key: 'Enter',
    target: input,
    defaultPrevented: false,
    preventDefault() {
      this.defaultPrevented = true;
    },
  };
  fireDoc('keydown', enter);
  fire('keydown', enter);
  assert.deepEqual(codes, ['7500001000014', '7500001000014']);
  assert.equal(input.value, '');
  detach();
});

test('serialQueue keeps arrival order even when early work is slow', async () => {
  const done = [];
  const queue = serialQueue(async n => {
    await new Promise(r => setTimeout(r, n === 1 ? 20 : 1));
    done.push(n);
  });
  await Promise.all([1, 2, 3].map(n => queue.push(n)));
  assert.deepEqual(done, [1, 2, 3]);
});

test('serialQueue continues after a failure', async () => {
  const done = [];
  const queue = serialQueue(async n => {
    if (n === 1) throw new Error('x');
    done.push(n);
  });
  await assert.rejects(queue.push(1));
  await queue.push(2);
  assert.deepEqual(done, [2]);
  assert.equal(queue.pending, 0);
});

// Emulated tests: fake event target + fake clock. No physical scanner was used.
import { test, mock, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { createScanner, isValidEan13 } from './scanner.mjs';

const BODY = { tagName: 'BODY' };

function setup(extra = {}) {
  mock.timers.enable({ apis: ['setTimeout'] });
  const handlers = new Map();
  const target = {
    addEventListener(type, fn) { (handlers.get(type) || handlers.set(type, new Set()).get(type)).add(fn); },
    removeEventListener(type, fn) { handlers.get(type)?.delete(fn); },
    emit(type, evt) { for (const fn of [...(handlers.get(type) || [])]) fn(evt); return evt; },
    count() { let n = 0; for (const s of handlers.values()) n += s.size; return n; },
  };
  const clock = { t: 1000 };
  const scans = [];
  const rejects = [];
  const scanner = createScanner({
    target, now: () => clock.t,
    onScan: (s) => scans.push(s), onReject: (r) => rejects.push(r), ...extra,
  });
  const advance = (ms) => { clock.t += ms; mock.timers.tick(ms); };
  const key = (k, o = {}) => {
    const evt = { type: 'keydown', key: k, repeat: false, isComposing: false, target: BODY,
      defaultPrevented: false, preventDefault() { this.defaultPrevented = true; }, ...o };
    return target.emit('keydown', evt);
  };
  // Types text with `step` ms between keys; capitals send Shift first, like a real keyboard.
  const type = (text, { step = 5, suffix = 'Enter', ...o } = {}) => {
    let last = null;
    for (const ch of text) {
      if (ch !== ch.toLowerCase()) key('Shift', o);
      key(ch, o);
      advance(step);
    }
    if (suffix) last = key(suffix, o);
    return last;
  };
  return { target, clock, scans, rejects, scanner, advance, key, type };
}

afterEach(() => mock.timers.reset());

const input = (value = '') => ({ tagName: 'INPUT', type: 'text', value });

test('1 fast burst plus Enter is one scanner scan, no focus, suffix prevented', () => {
  const s = setup();
  const enter = s.type('7501234567890');
  assert.equal(s.scans.length, 1);
  assert.equal(s.scans[0].code, '7501234567890');
  assert.equal(s.scans[0].source, 'scanner');
  assert.equal(s.scans[0].suffixKey, 'Enter');
  assert.equal(s.scans[0].chars, 13);
  assert.equal(s.scans[0].durationMs, 65);
  assert.equal(s.scans[0].avgInterKeyMs, 5);
  assert.equal(enter.defaultPrevented, true);
});

test('1b Tab suffix also works and is prevented', () => {
  const s = setup();
  const tab = s.type('ABCD1234', { suffix: 'Tab' });
  assert.equal(s.scans[0].suffixKey, 'Tab');
  assert.equal(tab.defaultPrevented, true);
});

test('2 slow typing in focused input plus Enter is manual (not prevented)', () => {
  const s = setup();
  const inp = input();
  for (const ch of '12345') { inp.value += ch; s.key(ch, { target: inp }); s.advance(300); }
  const enter = s.key('Enter', { target: inp });
  assert.equal(s.scans.length, 1);
  assert.equal(s.scans[0].source, 'manual');
  assert.equal(s.scans[0].code, '12345');
  assert.equal(enter.defaultPrevented, false);
});

test('2b allowManual false ignores manual entry', () => {
  const s = setup({ allowManual: false });
  const inp = input('12345');
  s.key('Enter', { target: inp });
  assert.equal(s.scans.length, 0);
});

test('2c slow keys with no focused input are ignored and never accumulate', () => {
  const s = setup();
  for (const ch of 'abcdef') { s.key(ch); s.advance(300); }
  s.key('Enter');
  assert.equal(s.scans.length, 0);
  assert.equal(s.rejects.length, 0);
  s.type('9990001');
  assert.equal(s.scans.length, 1);
  assert.equal(s.scans[0].code, '9990001');
});

test('3 burst in a focused input: reported once, restoreValue is the value before the burst', () => {
  const s = setup();
  const inp = input('ab');
  // The browser types each char into the input; the module sees keydown before insertion.
  for (const ch of '4006381333931') { s.key(ch, { target: inp }); inp.value += ch; s.advance(5); }
  const enter = s.key('Enter', { target: inp });
  assert.equal(s.scans.length, 1);
  assert.equal(s.scans[0].code, '4006381333931');
  assert.equal(s.scans[0].source, 'scanner');
  assert.equal(s.scans[0].input, inp);
  assert.equal(s.scans[0].restoreValue, 'ab');
  assert.equal(enter.defaultPrevented, true);
  inp.value = s.scans[0].restoreValue;
  assert.equal(inp.value, 'ab');
});

test('4 Shift capitals, CapsLock, non-printables; leading zeros kept as string', () => {
  const s = setup();
  s.key('CapsLock'); s.advance(5);
  s.type('ABc0012');
  assert.equal(s.scans[0].code, 'ABc0012');
  assert.equal(typeof s.scans[0].code, 'string');
  s.type('000123');
  assert.equal(s.scans[1].code, '000123');
  // A non-printable key in the middle of a burst discards it, no crash, no partial scan.
  s.key('1'); s.advance(5); s.key('2'); s.advance(5); s.key('ArrowLeft'); s.advance(5);
  s.key('3'); s.advance(5); s.key('Enter');
  assert.equal(s.scans.length, 2);
});

test('4b Dead key inside a burst rejects invalid_chars', () => {
  const s = setup();
  s.key('1'); s.advance(5); s.key('Dead'); s.advance(5); s.key('2'); s.advance(5);
  s.key('3'); s.advance(5); s.key('4'); s.advance(5); s.key('Enter');
  assert.equal(s.scans.length, 0);
  assert.equal(s.rejects[0].reason, 'invalid_chars');
});

test('5 burst without suffix rejects timeout after 3 x maxInterKeyMs and clears the buffer', () => {
  const s = setup();
  s.type('123456', { suffix: null });
  s.advance(100);
  assert.equal(s.rejects.length, 0);
  s.advance(60); // 160 ms since last key >= 150
  assert.equal(s.rejects.length, 1);
  assert.equal(s.rejects[0].reason, 'timeout');
  assert.equal(s.rejects[0].raw, '123456');
  s.key('Enter');
  assert.equal(s.scans.length, 0);
});

test('5b too_short, invalid prefix strip, and ean13 checksum rejects', () => {
  const s = setup({ prefix: ']E0', validate: 'ean13' });
  s.type('123');
  assert.equal(s.rejects.at(-1).reason, 'too_short');
  s.type(']E04006381333931');
  assert.equal(s.scans.at(-1).code, '4006381333931');
  s.type('4006381333932');
  assert.equal(s.rejects.at(-1).reason, 'checksum');
  assert.equal(isValidEan13('4006381333931'), true);
  assert.equal(isValidEan13('4006381333932'), false);
});

test('6 two scans back to back in order', () => {
  const s = setup();
  s.type('AAAA1111', { step: 5 });
  s.type('BBBB2222', { step: 5 }); // starts immediately after the suffix, no pause
  assert.deepEqual(s.scans.map((x) => x.code), ['AAAA1111', 'BBBB2222']);
});

test('6b 100 identical emulated scans give exactly 100 onScan calls', () => {
  const s = setup();
  for (let i = 0; i < 100; i++) s.type('7501234567890', { step: 2 });
  assert.equal(s.scans.length, 100);
  assert.ok(s.scans.every((x) => x.code === '7501234567890' && x.source === 'scanner'));
  assert.equal(s.scanner.stats().scans, 100);
  assert.equal(s.rejects.length, 0);
});

test('6c slow keys then a fast burst yield only the burst as the code', () => {
  const s = setup();
  for (const ch of 'xyz') { s.key(ch); s.advance(400); }
  s.type('55512345');
  assert.equal(s.scans.length, 1);
  assert.equal(s.scans[0].code, '55512345');
});

test('7 composition events and key repeat do not corrupt the buffer', () => {
  const s = setup();
  for (const ch of '12') { s.key(ch); s.advance(5); }
  s.key('3', { repeat: true }); s.advance(5);
  s.key('Process', { keyCode: 229 }); s.advance(5);
  s.key('x', { isComposing: true }); s.advance(5);
  for (const ch of '34') { s.key(ch); s.advance(5); }
  s.key('Enter');
  assert.equal(s.scans.length, 1);
  assert.equal(s.scans[0].code, '1234');
  // composition resets the buffer; keys during composition are ignored
  s.key('9'); s.advance(5);
  s.target.emit('compositionstart', {});
  s.key('8', { isComposing: true }); s.advance(5);
  s.target.emit('compositionend', {});
  s.type('5678');
  assert.equal(s.scans.at(-1).code, '5678');
});

test('8 configure() changes options at runtime', () => {
  const s = setup();
  s.type('123');
  assert.equal(s.rejects.at(-1).reason, 'too_short');
  s.scanner.configure({ minLength: 3 });
  s.type('123');
  assert.equal(s.scans.at(-1).code, '123');
  s.scanner.configure({ suffixKeys: ['F2'] });
  s.type('77777', { suffix: 'F2' });
  assert.equal(s.scans.at(-1).code, '77777');
  s.scanner.configure({ maxInterKeyMs: 200 });
  s.type('88888', { step: 120, suffix: 'F2' });
  assert.equal(s.scans.at(-1).code, '88888');
});

test('8b stop() removes every listener', () => {
  const s = setup();
  assert.ok(s.target.count() > 0);
  s.scanner.stop();
  assert.equal(s.target.count(), 0);
  s.type('12345678');
  assert.equal(s.scans.length, 0);
  assert.deepEqual(s.scanner.stats().scans, 0);
});

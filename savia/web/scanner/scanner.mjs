// Keyboard-wedge barcode scanner reader. No dependencies.
//
// A wedge scanner types the code like a keyboard, very fast, and ends with a suffix key
// (Enter or Tab). A human types slower than `maxInterKeyMs` per key.
//
// Strategy when a text input is focused during a scanner burst:
//   The browser has already typed the burst characters into the input (we cannot know it is a
//   burst before the 2nd key). The module reports the code ONCE and does not touch the input.
//   `scan.input` is that input and `scan.restoreValue` is its value before the burst began.
//   The caller clears the duplicates with: scan.input.value = scan.restoreValue
//   For source 'manual', `scan.input` is the input and `scan.restoreValue` is null.
//
// Single-character codes are not supported: a burst needs at least 2 fast keys.
// Extra scan fields beyond the contract: `input`, `restoreValue`.

const MODIFIERS = new Set([
  'Shift', 'Control', 'Alt', 'AltGraph', 'Meta', 'CapsLock', 'NumLock', 'ScrollLock',
  'Fn', 'FnLock', 'Hyper', 'Super', 'Symbol', 'SymbolLock', 'OS',
]);
const TEXT_TYPES = new Set(['', 'text', 'search', 'tel', 'number', 'url', 'email', 'password']);
const CONTROL_CHARS = /[\u0000-\u001f\u007f-\u009f]/;

const DEFAULTS = {
  target: null,
  onScan: null,
  onReject: null,
  minLength: 4,
  maxInterKeyMs: 50,
  suffixKeys: ['Enter', 'Tab'],
  prefix: '',
  allowManual: true,
  validate: null,
  now: () => performance.now(),
};

export function isValidEan13(code) {
  if (typeof code !== 'string' || !/^\d{13}$/.test(code)) return false;
  let sum = 0;
  for (let i = 0; i < 12; i++) sum += Number(code[i]) * (i % 2 ? 3 : 1);
  return (10 - (sum % 10)) % 10 === Number(code[12]);
}

function isTextInput(el) {
  return !!el && el.tagName === 'INPUT' && typeof el.value === 'string'
    && TEXT_TYPES.has(String(el.type || '').toLowerCase());
}

export function createScanner(options = {}) {
  const opts = { ...DEFAULTS };
  const counters = { scans: 0, rejects: 0, lastScan: null };
  let buf = [];
  let times = [];
  let lastT = 0;
  let bad = false;
  let startInput = null;
  let startValue = null;
  let timer = null;
  let composing = false;
  let attached = null;

  function apply(partial) {
    for (const k of Object.keys(DEFAULTS)) {
      if (partial[k] !== undefined) opts[k] = partial[k];
    }
  }

  function clearTimer() {
    if (timer !== null) { globalThis.clearTimeout(timer); timer = null; }
  }

  function clearBuf() {
    clearTimer();
    buf = []; times = []; bad = false; startInput = null; startValue = null;
  }

  function arm() {
    clearTimer();
    timer = globalThis.setTimeout(() => { timer = null; abandon(); }, 3 * opts.maxInterKeyMs);
    if (timer && typeof timer.unref === 'function') timer.unref();
  }

  function reject(reason, raw) {
    counters.rejects++;
    if (opts.onReject) opts.onReject({ reason, raw });
  }

  // A burst of 2+ keys that never got its suffix key.
  function abandon() {
    const raw = buf.join('');
    const wasBurst = buf.length >= 2;
    clearBuf();
    if (wasBurst) reject('timeout', raw);
  }

  function finish(source, raw, meta) {
    let code = raw;
    if (source === 'scanner' && opts.prefix && code.startsWith(opts.prefix)) {
      code = code.slice(opts.prefix.length);
    }
    if (meta.bad || CONTROL_CHARS.test(code)) return reject('invalid_chars', raw);
    if (code.length < opts.minLength) return reject('too_short', raw);
    if (opts.validate === 'ean13' && !isValidEan13(code)) return reject('checksum', raw);
    const scan = {
      code,
      source,
      chars: code.length,
      durationMs: meta.durationMs,
      avgInterKeyMs: meta.avgInterKeyMs,
      suffixKey: meta.suffixKey,
      input: meta.input,
      restoreValue: meta.restoreValue,
    };
    counters.scans++;
    counters.lastScan = scan;
    if (opts.onScan) opts.onScan(scan);
  }

  function onSuffix(e, t) {
    const n = buf.length;
    if (n >= 2) {
      if (typeof e.preventDefault === 'function') e.preventDefault();
      const raw = buf.join('');
      const durationMs = t - times[0];
      const meta = {
        bad, durationMs, avgInterKeyMs: durationMs / n, suffixKey: e.key,
        input: startInput, restoreValue: startValue,
      };
      clearBuf();
      finish('scanner', raw, meta);
      return;
    }
    clearBuf();
    if (opts.allowManual && e.key === 'Enter' && isTextInput(e.target) && e.target.value) {
      finish('manual', e.target.value, {
        bad: false, durationMs: 0, avgInterKeyMs: 0, suffixKey: 'Enter',
        input: e.target, restoreValue: null,
      });
    }
  }

  function onKeyDown(e) {
    if (composing || e.isComposing || e.keyCode === 229 || e.key === 'Process') return;
    if (e.repeat) return;
    const key = e.key;
    if (typeof key !== 'string' || MODIFIERS.has(key)) return;
    const t = opts.now();
    if (buf.length && t - lastT > opts.maxInterKeyMs) abandon();
    if (e.ctrlKey || e.metaKey) { clearBuf(); return; }
    if (key === 'Dead' || key === 'Unidentified') {
      if (buf.length) { bad = true; lastT = t; arm(); }
      return;
    }
    if (opts.suffixKeys.includes(key)) { onSuffix(e, t); return; }
    if ([...key].length !== 1) { clearBuf(); return; }
    if (buf.length === 0) {
      const editable = isTextInput(e.target);
      startInput = editable ? e.target : null;
      startValue = editable ? e.target.value : null;
    }
    buf.push(key);
    times.push(t);
    lastT = t;
    arm();
  }

  function onCompositionStart() { composing = true; clearBuf(); }
  function onCompositionEnd() { composing = false; clearBuf(); }

  function attach() {
    const target = opts.target || (typeof document !== 'undefined' ? document : null);
    if (!target) throw new Error('createScanner: no target');
    target.addEventListener('keydown', onKeyDown, true);
    target.addEventListener('compositionstart', onCompositionStart, true);
    target.addEventListener('compositionend', onCompositionEnd, true);
    attached = target;
  }

  function detach() {
    if (!attached) return;
    attached.removeEventListener('keydown', onKeyDown, true);
    attached.removeEventListener('compositionstart', onCompositionStart, true);
    attached.removeEventListener('compositionend', onCompositionEnd, true);
    attached = null;
  }

  apply(options);
  attach();

  return {
    stop() { detach(); clearBuf(); composing = false; },
    configure(partial = {}) {
      const retarget = partial.target !== undefined && partial.target !== opts.target;
      apply(partial);
      if (retarget && attached) { detach(); clearBuf(); attach(); }
      if (buf.length) arm();
    },
    stats() { return { ...counters }; },
  };
}

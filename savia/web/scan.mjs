import { createScanner } from './scanner/scanner.mjs';
// Keyboard-wedge scanner support. The scanner types the code and presses Enter.
// A separate advanced scanner module may call each screen's handleScan(code) directly.

/** Normalizes what the field holds when Enter arrives. Returns the code, or null when there is nothing to send. */
export function readScan(raw) {
  if (raw == null) return null;
  // Scanners may add CR/LF/TAB or stray control characters; codes keep their leading zeros.
  const code = String(raw).replace(/[\u0000-\u001f\u007f]/g, '').trim();
  return code.length > 0 && code.length <= 128 ? code : null;
}

const TEXT_INPUT_TYPES = new Set(['text', 'search', 'number', 'password', 'email', 'tel', 'url', 'date', '']);

/**
 * True when the scan field should take focus back from `active`.
 * Another text field, a select, a textarea or anything inside an open dialog keeps its focus.
 */
export function shouldReclaimFocus(active, field) {
  if (!active || active === field) return active !== field;
  if (typeof active.closest === 'function' && active.closest('dialog[open]')) return false;
  const tag = (active.tagName || '').toUpperCase();
  if (tag === 'TEXTAREA' || tag === 'SELECT') return false;
  if (tag === 'INPUT') return !TEXT_INPUT_TYPES.has((active.type || '').toLowerCase());
  if (active.isContentEditable) return false;
  return true;
}

/**
 * Wires an <input> as a scan field. Enter sends the code to onCode and clears the field at once,
 * so the next reading never waits for the server. The field takes focus back after clicks elsewhere.
 * Returns a function that detaches everything.
 */
export function attachScanField(input, onCode, { keepFocus = true, doc = globalThis.document } = {}) {
  const onKey = event => {
    if (event.key !== 'Enter' || event.defaultPrevented) return;
    event.preventDefault();
    const code = readScan(input.value);
    input.value = '';
    if (code) onCode(code);
  };
  let timer = null;
  const reclaim = () => {
    if (!keepFocus || !input.isConnected) return;
    clearTimeout(timer);
    timer = setTimeout(() => {
      if (input.isConnected && !input.disabled && shouldReclaimFocus(doc.activeElement, input)) input.focus({ preventScroll: true });
    }, 0);
  };
  const listeners = new Map();
  const target = {
    addEventListener(type, fn, capture) {
      const wrapped = event => { if (!doc.querySelector?.('dialog[open]')) fn(event); };
      listeners.set(fn, wrapped);
      doc.addEventListener(type, wrapped, capture);
    },
    removeEventListener(type, fn, capture) {
      doc.removeEventListener(type, listeners.get(fn), capture);
      listeners.delete(fn);
    },
  };
  const scanner = createScanner({ target, allowManual: false, minLength: 2,
    onScan: scan => {
      // Dialog fields are ordinary form input. Keep their values and Enter behavior.
      if (doc.querySelector?.('dialog[open]')) return;
      if (scan.input) {
        scan.input.value = scan.input === input ? '' : scan.restoreValue;
        scan.input.dispatchEvent?.(new Event('input', { bubbles: true }));
      }
      const code = readScan(scan.code);
      if (code) onCode(code);
    },
  });
  input.addEventListener('keydown', onKey);
  input.addEventListener('blur', reclaim);
  doc.addEventListener('click', reclaim);
  doc.addEventListener('close', reclaim, true);   // a dialog closed
  if (keepFocus) input.focus({ preventScroll: true });
  return () => {
    clearTimeout(timer);
    scanner.stop();
    input.removeEventListener('keydown', onKey);
    input.removeEventListener('blur', reclaim);
    doc.removeEventListener('click', reclaim);
    doc.removeEventListener('close', reclaim, true);
  };
}

/**
 * Runs async work one item at a time, in arrival order. Scans arrive faster than the server answers;
 * the queue keeps their order and never drops one.
 */
export function serialQueue(worker) {
  let chain = Promise.resolve();
  let pending = 0;
  return {
    push(item) {
      pending += 1;
      const run = chain.then(() => worker(item)).finally(() => { pending -= 1; });
      chain = run.catch(() => {});
      return run;
    },
    get pending() { return pending; },
  };
}

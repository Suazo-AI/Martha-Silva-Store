// Small DOM helpers shared by the screens. No framework.

/** h('div', { class: 'x', onclick: fn }, 'text', child) */
export function h(tag, attrs = {}, ...children) {
  const el = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs ?? {})) {
    if (value === undefined || value === null || value === false) continue;
    if (key.startsWith('on') && typeof value === 'function') el.addEventListener(key.slice(2), value);
    else if (key === 'class') el.className = value;
    else if (key === 'dataset') Object.assign(el.dataset, value);
    else if (key === 'text') el.textContent = value;
    else if (value === true) el.setAttribute(key, '');
    else el.setAttribute(key, String(value));
  }
  append(el, children);
  return el;
}

function append(el, children) {
  for (const child of children.flat(Infinity)) {
    if (child === null || child === undefined || child === false) continue;
    el.append(child instanceof Node ? child : document.createTextNode(String(child)));
  }
}

export function replace(el, ...children) {
  el.replaceChildren();
  append(el, children);
  return el;
}

/** Sample photos shipped with the pilot, keyed by the first 11 characters of the SKU (MAS-XXX-YYY). */
const SAMPLE_PHOTOS = new Set(['MAS-BLU-LIN', 'MAS-VES-MID', 'MAS-FAL-PLI', 'MAS-PAN-PAL', 'MAS-JEA-SKI', 'MAS-TOP-BAS', 'MAS-CAR-TEJ']);

/** Photo slot beside each garment. Shows the sample photo of the SKU when one exists, else "Sin foto". */
export function photo(sku) {
  const key = typeof sku === 'string' ? sku.slice(0, 11).toUpperCase() : '';
  if (!SAMPLE_PHOTOS.has(key)) return h('span', { class: 'photo', 'aria-hidden': 'true' }, 'Sin foto');
  return h('span', { class: 'photo has-img', 'aria-hidden': 'true' },
    h('img', { src: `/img/products/${key}.webp`, alt: '', loading: 'lazy', width: '640', height: '640' }));
}

/** Shows an ApiError (or any error) in a live region. Input fields are never cleared here. */
export function showError(el, error, nextStep) {
  const message = error?.message || 'Ocurrió un error.';
  const parts = [message];
  if (nextStep) parts.push(nextStep);
  if (error?.code && !error.missing && !error.network) parts.push(`(${error.code})`);
  el.className = 'error';
  el.textContent = parts.join(' ');
}

export function showOk(el, text) {
  el.className = 'ok';
  el.textContent = text;
}

export function clearMessage(el) {
  el.className = 'error';
  el.textContent = '';
}

/** Short confirmation flash (<200 ms); skipped when the user prefers reduced motion (CSS handles it). */
export function flash(el) {
  el.classList.remove('flash');
  void el.offsetWidth;
  el.classList.add('flash');
}

/** Device-level settings (this tablet): register, supplier, current work. Never money or stock. */
export const device = {
  get(key) {
    try { const raw = localStorage.getItem('savia.device.' + key); return raw ? JSON.parse(raw) : null; } catch { return null; }
  },
  set(key, value) {
    try {
      if (value === null || value === undefined) localStorage.removeItem('savia.device.' + key);
      else localStorage.setItem('savia.device.' + key, JSON.stringify(value));
    } catch { /* private mode: work continues without remembering */ }
  },
};

export const GUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Opens the shared <dialog>. build(body, close) fills it. Resolves when it closes. */
export function openModal(build) {
  const dialog = document.getElementById('modal');
  const body = document.getElementById('modal-body');
  body.replaceChildren();
  return new Promise(resolve => {
    const close = value => { resolve(value); dialog.close(); };
    dialog.addEventListener('close', () => resolve(undefined), { once: true });
    build(body, close);
    dialog.showModal();
    const first = body.querySelector('input,select,textarea,button');
    first?.focus();
  });
}

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

// A restored branch refuses sales, till openings and receiving until its rebuild lands (D-036).
// The screen's own advice ("revise los datos") would send the cashier after a problem they cannot fix.
const NEXT_STEP_BY_CODE = {
  'sync.recovery_pending': 'Espere unos minutos y vuelva a intentar. Si sigue igual, avise a la gerente.',
  'sync.schema_mismatch': 'Las ventas siguen guardadas en esta sucursal. Avise a soporte para actualizar el sistema.',
};

// The store keeps selling while its rounds fail, so the till names the reason instead of failing silently (D-041).
const SYNC_REASON_BY_CODE = {
  'sync.schema_mismatch': 'La central rechaza esta sucursal: la versión de su base de datos no coincide.',
  'sync.unauthorized': 'La central rechaza la credencial de esta sucursal.',
  'sync.unreachable': 'No hay conexión con la central.',
};

/**
 * Banner text for GET /sync/status, or null when the last round worked or sync is off.
 * A restored store waits for its rebuild before it may sell, so the banner shows how far the rebuild got (D-036).
 */
export function syncNotice(status) {
  if (!status?.enabled) return null;
  const { rebuild } = status;
  const progress = rebuild
    ? `Se reconstruye esta sucursal desde la central: ${rebuild.done} de ${rebuild.total} tablas. Las ventas vuelven al terminar.`
    : null;
  if (!status.code) return progress;
  const reason = SYNC_REASON_BY_CODE[status.code] ?? 'La sincronización con la central falló.';
  const step = NEXT_STEP_BY_CODE[status.code] ?? 'Las ventas siguen guardadas en esta sucursal.';
  return [reason, progress ?? step].join(' ');
}

/**
 * D-039: a store with a hub only reads the catalog. Its price and import screens say so instead of offering a form the
 * server refuses (catalog.managed_by_hub). Returns true when it replaced the screen.
 */
export function showCatalogManagedCentrally(root, me) {
  if (!me?.catalogManagedByHub) return false;
  replace(root, h('div', { class: 'page' }, h('p', { role: 'status', id: 'catalog-central' }, 'El catálogo se gestiona en la central.')));
  return true;
}

/** Shows an ApiError (or any error) in a live region. Input fields are never cleared here. */
export function showError(el, error, nextStep) {
  const message = error?.message || 'Ocurrió un error.';
  const parts = [message];
  const step = NEXT_STEP_BY_CODE[error?.code] ?? nextStep;
  if (step) parts.push(step);
  el.className = 'error';
  el.textContent = parts.join(' ');
  if (error?.code || error?.traceId) {
    const diagnostic = h('span', { hidden: true }, [error.code, error.traceId].filter(Boolean).join(' · '));
    const toggle = h(
      'button',
      {
        type: 'button',
        'aria-expanded': 'false',
        onclick: () => {
          diagnostic.hidden = !diagnostic.hidden;
          toggle.setAttribute('aria-expanded', String(!diagnostic.hidden));
        },
      },
      'Detalles técnicos',
    );
    el.append(' ', toggle, diagnostic);
  }
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
    try {
      const raw = localStorage.getItem(`savia.device.${key}`);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  },
  set(key, value) {
    try {
      if (value === null || value === undefined) localStorage.removeItem(`savia.device.${key}`);
      else localStorage.setItem(`savia.device.${key}`, JSON.stringify(value));
    } catch {
      /* private mode: work continues without remembering */
    }
  },
};

export const GUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Opens the shared <dialog>. build(body, close) fills it. Resolves when it closes. */
export function openModal(build) {
  const dialog = document.getElementById('modal');
  const body = document.getElementById('modal-body');
  body.replaceChildren();
  return new Promise(resolve => {
    const onClose = () => {
      if (!dialog.open) {
        dialog.removeEventListener('close', onClose);
        resolve(undefined);
      }
    };
    const close = value => {
      dialog.removeEventListener('close', onClose);
      dialog.close();
      resolve(value);
    };
    dialog.addEventListener('close', onClose);
    build(body, close);
    dialog.showModal();
    const first = body.querySelector('input,select,textarea,button');
    first?.focus();
  });
}

// Phone page /etiqueta/: photo of a hanging tag -> editable product form -> register or add to the open reception.
// The photo goes only to the branch PC (POST /inventory/tag-extract); the barcode is read here first, offline.
import * as api from '../api.mjs';
import { isApprover, receivesTags } from '../roles.mjs';
import { clearMessage, device, h, replace, showError } from '../ui.mjs';
import { barcodeHint, fitSize, JPEG_QUALITY, keepForNextSize, registration, toForm } from './etiqueta-logic.mjs';

const CLIENT_TIMEOUT_MS = 15000;
const root = document.getElementById('root');
const state = { me: null, sessionId: null, previous: {} };

const LABELS = {
  barcode: 'Código de barras',
  sku: 'SKU / referencia',
  name: 'Nombre',
  brand: 'Marca',
  size: 'Talla',
  color: 'Color',
  price: 'Precio (C$)',
  composition: 'Composición',
};

start().catch(error => replace(root, h('p', { class: 'error', role: 'alert' }, `No se pudo iniciar: ${error.message}`)));

async function start() {
  api.setUnauthorizedHandler(() => {
    api.setToken(null);
    state.me = null;
    renderLogin();
  });
  if (api.getToken()) {
    try {
      state.me = await api.me();
    } catch {
      api.setToken(null);
    }
  }
  if (state.me) await renderHome();
  else renderLogin();
}

function renderLogin() {
  document.getElementById('who').textContent = '';
  const user = h('input', { id: 'login-user', autocomplete: 'username', autocapitalize: 'none', spellcheck: 'false', required: true });
  const pass = h('input', { id: 'login-pass', type: 'password', autocomplete: 'current-password', required: true });
  const message = h('p', { class: 'error', role: 'alert' });
  const submit = h('button', { class: 'primary big', type: 'submit' }, 'Ingresar');
  replace(
    root,
    h(
      'form',
      {
        class: 'panel form',
        novalidate: true,
        onsubmit: async event => {
          event.preventDefault();
          clearMessage(message);
          if (!user.value.trim() || !pass.value) {
            message.textContent = 'Escriba su usuario y su contraseña.';
            return;
          }
          submit.disabled = true;
          try {
            api.setToken((await api.login(user.value.trim(), pass.value)).token);
            state.me = await api.me();
            await renderHome();
          } catch (error) {
            showError(message, error, 'Revise los datos y vuelva a intentar.');
          } finally {
            submit.disabled = false;
          }
        },
      },
      h('h1', {}, 'Foto de etiqueta'),
      h('label', { for: 'login-user' }, 'Usuario de trabajo'),
      user,
      h('label', { for: 'login-pass' }, 'Contraseña'),
      pass,
      message,
      submit,
    ),
  );
  user.focus();
}

const roles = () => state.me?.roles ?? [];

async function renderHome() {
  document.getElementById('who').textContent = state.me.displayName ?? '';
  if (!receivesTags(roles())) {
    replace(root, h('p', { class: 'error', role: 'alert' }, 'Su usuario no recibe mercadería. Pida ayuda a gerencia.'));
    return;
  }
  const message = h('p', { class: 'error', role: 'alert' });
  const sessions = h('select', { id: 'tag-session' }, h('option', { value: '' }, 'Sin recepción (solo registrar)'));
  try {
    const open = (await api.listReceptions()).filter(s => s.status === 'counting');
    const remembered = device.get('etiqueta.session');
    const chosen = open.some(s => s.scanSessionId === remembered) ? remembered : open[0]?.scanSessionId;
    for (const s of open)
      sessions.append(h('option', { value: s.scanSessionId, selected: s.scanSessionId === chosen }, `${s.reference} · ${s.supplierName}`));
    if (!open.length) message.textContent = 'No hay recepciones abiertas. Ábrala en Recepción para sumar prendas.';
  } catch (error) {
    showError(message, error);
  }
  state.sessionId = sessions.value || null;
  sessions.addEventListener('change', () => {
    state.sessionId = sessions.value || null;
    device.set('etiqueta.session', state.sessionId);
  });

  const input = h('input', { id: 'tag-photo', type: 'file', accept: 'image/*', capture: 'environment' });
  input.addEventListener('change', () => {
    const file = input.files?.[0];
    input.value = '';
    if (file) readPhoto(file).catch(error => showError(message, error));
  });
  replace(
    root,
    h('h1', {}, 'Foto de etiqueta'),
    tipPanel(),
    h('div', { class: 'form' }, h('label', { for: 'tag-session' }, 'Recepción'), sessions),
    message,
    h('label', { class: 'photo-button' }, 'Tomar foto de la etiqueta', input),
  );
}

function tipPanel() {
  if (device.get('etiqueta.tipSeen')) return null;
  const panel = h(
    'section',
    { class: 'panel tip' },
    h(
      'p',
      {},
      'Fotografíe una etiqueta por modelo. Para las otras tallas use «Otra talla»: se repiten nombre, marca, color y composición.',
    ),
    h(
      'button',
      {
        type: 'button',
        onclick: () => {
          device.set('etiqueta.tipSeen', true);
          panel.remove();
        },
      },
      'Entendido',
    ),
  );
  return panel;
}

// ---- photo -> smaller JPEG + barcode read on the phone

async function readPhoto(file) {
  const status = h('p', { class: 'reading' }, 'Preparando la foto…');
  const preview = h('img', { class: 'tag-preview', alt: 'Foto de la etiqueta' });
  const view = formView({ values: {}, review: [], matched: null }, status, preview);
  replace(root, view.node);
  let jpeg = null,
    barcode = null;
  try {
    const { canvas, blob } = await downscale(file);
    jpeg = blob;
    preview.src = URL.createObjectURL(blob);
    barcode = await readBarcode(canvas);
    if (barcode) view.set({ barcode });
  } catch (error) {
    status.textContent = '';
    view.warn(`No se pudo preparar la foto (${error.message}). Complete los datos a mano.`);
    return;
  }
  status.textContent = 'Leyendo la etiqueta en la computadora de la sucursal…';
  const timer = new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), CLIENT_TIMEOUT_MS));
  try {
    const answer = await Promise.race([api.tagExtract(jpeg, barcode), timer]);
    const form = toForm(answer, state.previous);
    if (barcode && !form.values.barcode) form.values.barcode = barcode;
    status.textContent = '';
    if (form.matched) {
      replace(root, matchedView(form).node);
      return;
    }
    view.fill(form);
    if (form.warning) view.warn(form.warning);
  } catch (error) {
    status.textContent = '';
    view.warn(
      error.message === 'timeout'
        ? 'La lectura tardó demasiado. Complete los datos a mano.'
        : `${error.message} Complete los datos a mano.`,
    );
  }
}

async function downscale(file) {
  const bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' });
  const size = fitSize(bitmap.width, bitmap.height);
  const canvas = document.createElement('canvas');
  canvas.width = size.width;
  canvas.height = size.height;
  canvas.getContext('2d').drawImage(bitmap, 0, 0, size.width, size.height);
  bitmap.close?.();
  const blob = await new Promise((resolve, reject) =>
    canvas.toBlob(b => (b ? resolve(b) : reject(new Error('JPEG'))), 'image/jpeg', JPEG_QUALITY),
  );
  return { canvas, blob };
}

/** BarcodeDetector when the phone has it; otherwise the vendored offline ZXing (vendor/zxing). Null when unread. */
async function readBarcode(canvas) {
  try {
    if ('BarcodeDetector' in globalThis) {
      const detector = new globalThis.BarcodeDetector({ formats: ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128'] });
      const found = await detector.detect(canvas);
      const code = found.map(f => barcodeHint(f.rawValue)).find(Boolean);
      if (code) return code;
    }
    const ZXing = await loadZxing();
    const hints = new Map([
      [ZXing.DecodeHintType.TRY_HARDER, true],
      [
        ZXing.DecodeHintType.POSSIBLE_FORMATS,
        [
          ZXing.BarcodeFormat.EAN_13,
          ZXing.BarcodeFormat.EAN_8,
          ZXing.BarcodeFormat.UPC_A,
          ZXing.BarcodeFormat.UPC_E,
          ZXing.BarcodeFormat.CODE_128,
        ],
      ],
    ]);
    const reader = new ZXing.MultiFormatReader();
    reader.setHints(hints);
    const result = reader.decode(new ZXing.BinaryBitmap(new ZXing.HybridBinarizer(new ZXing.HTMLCanvasElementLuminanceSource(canvas))));
    return barcodeHint(result.getText());
  } catch {
    return null; // no barcode found: the PC still reads the printed digits
  }
}

let zxing = null;
function loadZxing() {
  zxing ??= new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = '../vendor/zxing/zxing-library-0.21.3.min.js';
    script.onload = () => resolve(globalThis.ZXing);
    script.onerror = () => reject(new Error('zxing'));
    document.head.append(script);
  });
  return zxing;
}

// ---- editable form

function formView(form, status, preview) {
  const inputs = {},
    rows = {};
  for (const key of Object.keys(LABELS)) {
    inputs[key] = h('input', {
      id: `tag-${key}`,
      autocomplete: 'off',
      inputmode: key === 'price' ? 'decimal' : key === 'barcode' ? 'numeric' : null,
      autocapitalize: key === 'sku' || key === 'size' ? 'characters' : null,
      maxlength: 200,
    });
    rows[key] = h('label', { for: `tag-${key}` }, h('span', {}, LABELS[key], ' ', h('span', { class: 'flag' })), inputs[key]);
  }
  const cost = h('input', { id: 'tag-cost', inputmode: 'decimal', autocomplete: 'off' });
  const warning = h('p', { class: 'warning', role: 'status' });
  const message = h('p', { class: 'error', role: 'alert' });
  const ids = { productId: api.uuid(), itemId: api.uuid(), scanId: api.uuid() }; // kept across retries
  const approver = isApprover(roles());
  const submit = h('button', { class: 'primary', type: 'submit' }, approver ? 'Sí, registrar' : 'Sumar a la recepción');
  const values = () => Object.fromEntries(Object.entries(inputs).map(([k, el]) => [k, el.value]));

  const node = h(
    'form',
    {
      class: 'panel form tag-form',
      novalidate: true,
      onsubmit: async event => {
        event.preventDefault();
        clearMessage(message);
        submit.disabled = true;
        try {
          if (approver) {
            const plan = registration(values(), { ...ids, costText: cost.value });
            if (plan.errors.length) {
              message.textContent = plan.errors.join(' ');
              return;
            }
            await api.registerProduct(plan.product.productId, plan.product.name);
            await api.registerItem(plan.item);
            if (state.sessionId)
              await api.recordScan(state.sessionId, { scanId: ids.scanId, rawCode: plan.scanCode, deviceCode: 'ETIQUETA' });
            done(values(), state.sessionId ? 'Registrado y sumado 1 a la recepción.' : 'Producto registrado.');
          } else {
            const code = barcodeHint(inputs.barcode.value) ?? inputs.sku.value.trim();
            if (!state.sessionId) {
              message.textContent = 'Elija una recepción abierta para sumar la prenda.';
              return;
            }
            if (!code) {
              message.textContent = 'Escriba el código de barras o el SKU.';
              return;
            }
            await api.recordScan(state.sessionId, { scanId: ids.scanId, rawCode: code, deviceCode: 'ETIQUETA' });
            done(values(), 'Sumado a la recepción. Gerencia registra el producto en Recepción.');
          }
        } catch (error) {
          showError(message, error, 'Revise los datos y vuelva a intentar.');
        } finally {
          submit.disabled = false;
        }
      },
    },
    preview,
    status,
    warning,
    h('h2', {}, '¿Registrar este producto?'),
    rows.barcode,
    rows.sku,
    rows.name,
    rows.brand,
    h('div', { class: 'row2' }, rows.size, rows.color),
    rows.price,
    rows.composition,
    approver ? h('label', { for: 'tag-cost' }, 'Costo aprobado (C$)', cost) : null,
    message,
    h('div', { class: 'tag-actions' }, h('button', { type: 'button', onclick: () => renderHome() }, 'No, volver'), submit),
  );

  const set = partial => {
    for (const [k, v] of Object.entries(partial)) if (inputs[k] && v != null) inputs[k].value = v;
  };
  const fill = f => {
    set(f.values);
    for (const key of Object.keys(LABELS)) {
      const low = f.review.includes(key);
      rows[key].classList.toggle('review', low);
      rows[key].querySelector('.flag').textContent = low ? '· Revisar' : '';
    }
  };
  fill({ values: { ...keepForNextSize(state.previous), ...form.values }, review: form.review });
  return {
    node,
    set,
    fill,
    warn: text => {
      warning.textContent = text;
    },
  };
}

function matchedView(form) {
  const item = form.matched;
  const message = h('p', { class: 'error', role: 'alert' });
  const ok = h('p', { class: 'ok', role: 'status' });
  const scanId = api.uuid();
  const add = h(
    'button',
    {
      class: 'primary',
      type: 'button',
      disabled: !state.sessionId,
      onclick: async () => {
        clearMessage(message);
        add.disabled = true;
        try {
          await api.recordScan(state.sessionId, { scanId, rawCode: form.values.barcode || item.sku, deviceCode: 'ETIQUETA' });
          ok.textContent = 'Sumado 1 a la recepción.';
          add.remove();
        } catch (error) {
          showError(message, error, 'Vuelva a intentar.');
          add.disabled = false;
        }
      },
    },
    'Sumar 1 a la recepción',
  );
  return {
    node: h(
      'section',
      { class: 'panel' },
      h('h2', {}, 'Este producto ya existe'),
      h('p', {}, h('strong', {}, item.variantName || item.productName)),
      h('p', { class: 'num' }, `SKU ${item.sku}`, form.values.barcode ? ` · ${form.values.barcode}` : ''),
      state.sessionId ? null : h('p', { class: 'warning' }, 'Elija una recepción abierta para sumar la prenda.'),
      message,
      ok,
      h('div', { class: 'tag-actions' }, h('button', { type: 'button', onclick: () => renderHome() }, 'No, volver'), add),
    ),
  };
}

function done(values, text) {
  state.previous = keepForNextSize(values);
  replace(
    root,
    h(
      'section',
      { class: 'panel' },
      h('p', { class: 'ok', role: 'status' }, text),
      h(
        'div',
        { class: 'tag-actions' },
        h('button', { class: 'primary wide', type: 'button', onclick: () => renderHome() }, 'Otra talla del mismo modelo'),
        h(
          'button',
          {
            type: 'button',
            class: 'wide',
            onclick: () => {
              state.previous = {};
              renderHome();
            },
          },
          'Otra prenda',
        ),
      ),
    ),
  );
}

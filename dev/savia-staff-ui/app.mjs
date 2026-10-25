// Private staff shell. Server identity and business contracts are required.
// No fixture business data, local authentication, persistence or transport fallback.
import {createStaffClient} from './client.mjs';
import {StaffRequestError, readStaff} from './login.mjs';
const errorIds = new WeakMap();

function visible(element) {
  return !!element && !element.closest('[hidden], [inert], dialog:not([open])');
}

export function textElement(document, tag, text, className = '') {
  const element = document.createElement(tag);
  element.textContent = text == null ? '' : String(text);
  if (className) element.className = className;
  return element;
}

export function setVisible(element, show) {
  if (!element) return;
  element.hidden = !show;
  if (show) element.removeAttribute('inert');
  else element.setAttribute('inert', '');
}

export function focusVisible(preferred, fallback) {
  const target = visible(preferred) && !preferred.disabled ? preferred : fallback;
  if (visible(target) && !target.disabled) target.focus();
}

function removeFieldError(control) {
  const id = control.dataset.staffValidationId;
  if (!id) return;
  control.ownerDocument.getElementById(id)?.remove();
  const descriptions = (control.getAttribute('aria-describedby') || '').split(/\s+/).filter(value => value && value !== id);
  if (descriptions.length) control.setAttribute('aria-describedby', descriptions.join(' '));
  else control.removeAttribute('aria-describedby');
  delete control.dataset.staffValidationId;
  control.removeAttribute('aria-invalid');
}

export function clearFormErrors(form) {
  for (const control of form.elements) removeFieldError(control);
}

function fieldMessage(control) {
  if (control.validity.typeMismatch) return control.type === 'email' ? 'Ingresá un email válido.' : 'Revisá el formato de este campo.';
  if (control.validity.rangeUnderflow || control.validity.rangeOverflow || control.validity.stepMismatch) return 'Revisá la cantidad y el rango permitido.';
  if (control.validity.tooLong || control.validity.tooShort) return 'Revisá la longitud de este campo.';
  if (control.validity.patternMismatch) return 'Revisá el formato de este campo.';
  return 'Completá este campo.';
}

export function validateForm(form, {focusFirst = true} = {}) {
  clearFormErrors(form);
  const document = form.ownerDocument;
  let serial = errorIds.get(document) || 0;
  let first = null;
  const radioGroups = new Set();
  for (const control of form.elements) {
    if (!control.willValidate || control.disabled) continue;
    if (control.type === 'radio' && radioGroups.has(control.name)) continue;
    if (control.type === 'radio') radioGroups.add(control.name);
    const blank = control.required && control.type !== 'password' && typeof control.value === 'string' && !control.value.trim();
    if (control.validity.valid && !blank) continue;
    let id;
    do { id = `staff-field-error-${++serial}`; } while (document.getElementById(id));
    const error = textElement(document, 'small', fieldMessage(control), 'field-error');
    error.id = id;
    control.after(error);
    control.dataset.staffValidationId = id;
    control.setAttribute('aria-invalid', 'true');
    const descriptions = (control.getAttribute('aria-describedby') || '').split(/\s+/).filter(Boolean);
    control.setAttribute('aria-describedby', [...descriptions, id].join(' '));
    first ||= control;
  }
  errorIds.set(document, serial);
  if (focusFirst) first?.focus();
  return !first;
}

export function readFormValues(form) {
  const FormDataType = form.ownerDocument.defaultView.FormData;
  const values = Object.create(null);
  for (const [name, value] of new FormDataType(form)) {
    if (typeof value !== 'string') throw new Error('Este formulario no admite adjuntos.');
    if (Object.hasOwn(values, name)) throw new Error('El formulario contiene campos repetidos. Revisá la selección.');
    values[name] = value;
  }
  return values;
}

export function renderTable(mount, {columns, rows, caption, emptyText = 'No hay registros en esta consulta.'}) {
  const document = mount.ownerDocument;
  if (!Array.isArray(rows)) {
    mount.replaceChildren(textElement(document, 'p', 'Los datos todavía no están disponibles. No se muestran resultados de ejemplo.', 'empty-state'));
    return;
  }
  if (!rows.length) {
    mount.replaceChildren(textElement(document, 'p', emptyText, 'empty-state'));
    return;
  }
  const table = document.createElement('table');
  table.className = 'data-table';
  if (caption) table.append(textElement(document, 'caption', caption));
  const head = table.createTHead().insertRow();
  for (const column of columns) {
    const cell = textElement(document, 'th', column.label);
    cell.scope = 'col'; head.append(cell);
  }
  const body = table.createTBody();
  for (const row of rows) {
    const line = body.insertRow();
    for (const column of columns) {
      const value = typeof column.value === 'function' ? column.value(row) : row[column.key];
      const primitive = ['string', 'number', 'boolean'].includes(typeof value) ? String(value) : '—';
      line.append(textElement(document, 'td', primitive));
    }
  }
  mount.replaceChildren(table);
}

export function mountStaffApp({document = globalThis.document, client = createStaffClient(),
  redirect = path => document.defaultView.location.assign(path)} = {}) {
  const root = document?.querySelector('[data-staff-app]');
  if (!root) throw new Error('No se encontró la pantalla interna de SAVIA.');
  const $ = selector => document.querySelector(selector);
  const $$ = selector => [...document.querySelectorAll(selector)];
  const removers = [];
  const state = {phase: 'loading', session: null, busy: false, view: null};
  let epoch = 0, destroyed = false;
  const reads = new Map();
  const newPage = () => ({q: '', includeInactive: false, skip: 0, take: 50, status: 'idle', confirmed: null});
  const pages = new Map([['clientes', newPage()], ['inventario', newPage()]]);
  const listen = (element, event, handler) => {
    element.addEventListener(event, handler);
    removers.push(() => element.removeEventListener(event, handler));
  };
  function announce(message) {
    const destination = visible($('#staff-status')) ? $('#staff-status') : $('#session-status');
    if (destination) destination.textContent = message;
  }
  function lockActions() {
    $$('[data-server-action], [data-action="logout"], [data-action="change-business"]').forEach(control => { control.disabled = true; });
    $$('[data-staff-form] button, [data-staff-form] input, [data-staff-form] select, [data-staff-form] textarea').forEach(control => { control.disabled = true; });
  }
  function clearPrivateView() {
    for (const view of pages.keys()) pages.set(view, newPage());
    reads.clear();
    $$('[data-rows]').forEach(element => element.replaceChildren());
    $$('[data-session-user], [data-session-role]').forEach(element => { element.textContent = ''; });
    $$('[data-staff-form]').forEach(form => { form.reset(); clearFormErrors(form); });
    $$('dialog[open]').forEach(dialog => dialog.close());
    $$('[data-section-empty]').forEach(element => { element.hidden = true; });
    for (const view of pages.keys()) updatePager(view);
  }
  function showPending() {
    setVisible($('#staff-shell'), false);
    setVisible($('#auth-required'), false);
    setVisible($('#session-pending'), true);
    lockActions();
    announce('Verificando la sesión con el servidor. Todavía no se consultaron datos del negocio.');
  }
  function requireAccess(message) {
    ++epoch; state.session = null; state.phase = 'unauthenticated'; state.busy = false;
    clearPrivateView(); lockActions();
    setVisible($('#staff-shell'), false);
    setVisible($('#session-pending'), false);
    setVisible($('#auth-required'), true);
    $('#auth-required-message').textContent = message;
    $('#auth-required-title')?.focus();
  }
  const section = view => view === 'clientes' ? 'clients' : 'inventory';
  function searchDraft(view) {
    return $(`#${section(view)}-search-form`).elements.namedItem('query').value.trim();
  }
  function updatePager(view) {
    const page = pages.get(view);
    if (!page) return;
    const previous = $(`[data-page-prev="${view}"]`), next = $(`[data-page-next="${view}"]`);
    const size = $(`[data-page-size="${view}"]`), info = $(`[data-page-info="${view}"]`);
    const dirty = searchDraft(view) !== page.q;
    const confirmed = page.confirmed;
    const usable = state.phase === 'ready' && page.status === 'success' && !!confirmed && !dirty;
    if (previous) previous.disabled = !usable || confirmed.skip === 0;
    if (next) next.disabled = !usable || confirmed.skip + confirmed.take >= confirmed.total || confirmed.skip + confirmed.take > 100000;
    if (size) { size.disabled = !usable; size.value = String(page.take); }
    if (!info) return;
    if (page.status === 'loading') { info.textContent = 'Consultando la página…'; return; }
    if (page.status === 'error') { info.textContent = 'Página no confirmada. Volvé a buscar o actualizar.'; return; }
    if (!confirmed || state.phase !== 'ready') { info.textContent = 'Sin consulta confirmada.'; return; }
    const range = confirmed.count
      ? `${confirmed.skip + 1}–${confirmed.skip + confirmed.count} de ${confirmed.total}.`
      : `Sin registros en esta página. Total informado: ${confirmed.total}.`;
    const filter = page.q ? ` Búsqueda aplicada: ${page.q}.` : ' Todas las coincidencias.';
    const pending = dirty ? ' Aplicá la búsqueda para cambiar de página.' : '';
    const bound = confirmed.skip + confirmed.take > 100000 && confirmed.skip + confirmed.take < confirmed.total
      ? ' Se alcanzó el límite de navegación; ajustá la búsqueda.' : '';
    info.textContent = range + filter + pending + bound;
  }
  function readControls(view, busy) {
    const prefix = section(view);
    const form = $(`#${prefix}-search-form`);
    if (form) for (const control of form.elements) control.disabled = busy || state.phase !== 'ready';
    if (view === 'inventario') $('[data-action="refresh-inventory"]').disabled = busy || state.phase !== 'ready';
    updatePager(view);
  }
  function renderRecords(view, page) {
    const mount = $(`#${section(view)}-rows`);
    const fragment = document.createDocumentFragment();
    for (const row of page.items) {
      const tr = document.createElement('tr');
      tr.dataset.recordId = row.id;
      const cells = view === 'clientes'
        ? [row.name, [row.email, row.phone].filter(Boolean).join(' · ') || 'Sin contacto registrado', row.active ? 'Activo' : 'Inactivo', 'Edición pendiente de integración']
        : [row.name, row.sku, `${row.unitPriceMinor} unidades menores · ${row.currency}`, row.active ? 'Activo' : 'Inactivo'];
      for (const value of cells) tr.append(textElement(document, 'td', value));
      fragment.append(tr);
    }
    mount.replaceChildren(fragment);
    const empty = $(`#${section(view)}-empty`);
    empty.hidden = page.items.length !== 0;
    if (!page.items.length) {
      const heading = empty.querySelector('h3'), description = empty.querySelector('p');
      if (heading) heading.textContent = page.total > 0 ? 'No hay registros en esta página' : 'No hay resultados para esta búsqueda';
      if (description) description.textContent = page.total > 0
        ? `El servidor informa ${page.total} registros. Volvé a la página anterior o actualizá la consulta.`
        : 'Probá otra búsqueda. No se agregaron registros de ejemplo.';
    }
  }
  async function loadSection(view) {
    if (state.phase !== 'ready' || !state.session || !['clientes', 'inventario'].includes(view)) return;
    const prefix = section(view), requestId = (reads.get(view) || 0) + 1;
    reads.set(view, requestId);
    const generation = epoch;
    const actor = state.session.id;
    const pageState = pages.get(view);
    const applied = {q: pageState.q, includeInactive: pageState.includeInactive, skip: pageState.skip, take: pageState.take};
    pageState.status = 'loading';
    $(`#${prefix}-error`).hidden = true;
    $(`#${prefix}-empty`).hidden = true;
    $(`#${prefix}-status`).textContent = 'Consultando el directorio autorizado…';
    $(`#${prefix}-rows`).replaceChildren();
    readControls(view, true);
    try {
      const page = await (view === 'clientes' ? client.listCustomers(applied) : client.listItems(applied));
      if (destroyed || generation !== epoch || actor !== state.session?.id || state.phase !== 'ready' || reads.get(view) !== requestId) return;
      renderRecords(view, page);
      pageState.skip = page.skip; pageState.take = page.take;
      pageState.confirmed = {skip: page.skip, take: page.take, total: page.total, count: page.items.length};
      pageState.status = 'success';
      $(`#${prefix}-status`).textContent = `${page.items.length} de ${page.total} registros recibidos del servidor. Las escrituras todavía no están habilitadas.`;
    } catch (error) {
      if (destroyed || generation !== epoch) return;
      if (error?.status === 401) { requireAccess('La sesión venció o ya no está disponible. Volvé a ingresar.'); return; }
      if (reads.get(view) !== requestId) return;
      pageState.status = 'error'; pageState.confirmed = null;
      $(`#${prefix}-rows`).replaceChildren();
      $(`#${prefix}-error`).textContent = error instanceof StaffRequestError ? error.message : 'No se pudieron cargar los datos. No se muestran resultados de ejemplo.';
      $(`#${prefix}-error`).hidden = false;
      $(`#${prefix}-status`).textContent = 'Consulta no confirmada. Podés volver a buscar.';
    } finally {
      if (!destroyed && generation === epoch && reads.get(view) === requestId) readControls(view, false);
    }
  }
  function applySearch(view) {
    const page = pages.get(view);
    if (!page) return;
    page.q = searchDraft(view); page.skip = 0;
    void loadSection(view);
  }
  function turnPage(view, direction) {
    const page = pages.get(view), confirmed = page?.confirmed;
    if (!page || state.phase !== 'ready' || page.status !== 'success' || !confirmed || searchDraft(view) !== page.q) return;
    const target = direction === 'previous' ? Math.max(0, confirmed.skip - confirmed.take) : confirmed.skip + confirmed.take;
    if (target > 100000 || (direction === 'next' && target >= confirmed.total) || target === confirmed.skip) return;
    page.skip = target;
    void loadSection(view);
  }
  function refreshSection(view) {
    const page = pages.get(view);
    if (!page || state.phase !== 'ready') return;
    // Refresh restores the applied query; it never submits a draft with an old offset.
    $(`#${section(view)}-search-form`).elements.namedItem('query').value = page.q;
    return loadSection(view);
  }
  async function verifySession() {
    const generation = ++epoch;
    state.phase = 'loading'; state.busy = true; state.session = null;
    clearPrivateView(); showPending();
    try {
      const verified = readStaff(await client.getSession());
      if (destroyed || generation !== epoch) return;
      state.session = verified; state.phase = 'ready'; state.busy = false;
      setVisible($('#session-pending'), false); setVisible($('#auth-required'), false); setVisible($('#staff-shell'), true);
      $('[data-session-user]').textContent = verified.displayName;
      $('[data-session-role]').textContent = verified.role;
      $$('[data-action="nav"], [data-action="logout"]').forEach(button => { button.disabled = false; });
      for (const view of ['clientes', 'inventario']) {
        readControls(view, false);
        $(`#${section(view)}-search-form`).elements.namedItem('query').maxLength = 200;
      }
      const create = $('[data-action="new-client"]');
      if (create) { create.disabled = true; create.title = 'El guardado de clientes está pendiente del contrato de resultado y recuperación.'; }
      announce('Sesión verificada por el servidor. Negocio de esta instancia; consultas de directorio habilitadas.');
      navigate('clientes', false, false);
      await loadSection('clientes');
    } catch (error) {
      if (destroyed || generation !== epoch) return;
      requireAccess(error instanceof StaffRequestError ? error.message : 'No se pudo verificar el acceso. El espacio de trabajo permanece cerrado.');
    }
  }
  function navigate(view, moveFocus = true, load = true) {
    if (state.phase !== 'ready' || !state.session) {
      announce('Primero debe verificarse el acceso mediante el servidor. No se abrió información del negocio.');
      return false;
    }
    const target = $$('[data-view]').find(section => section.dataset.view === view);
    if (!target) return false;
    state.view = view;
    $$('[data-view]').forEach(section => setVisible(section, section === target));
    $$('[data-action="nav"]').forEach(button => {
      if (button.dataset.target === view) button.setAttribute('aria-current', 'page');
      else button.removeAttribute('aria-current');
    });
    $('#staff-title').textContent = {clientes: 'Clientes', ventas: 'Ventas', inventario: 'Artículos del negocio', abastecimiento: 'Abastecimiento'}[view] || 'SAVIA interno';
    if (moveFocus) $('#staff-title')?.focus();
    if (load && ['clientes', 'inventario'].includes(view)) refreshSection(view);
    return true;
  }
  async function logout() {
    ++epoch; state.phase = 'signing-out'; state.busy = true;
    clearPrivateView(); showPending(); announce('Solicitando el cierre de sesión al servidor…');
    try {
      await client.logout();
      if (!destroyed) { requireAccess('El servidor confirmó el cierre de esta sesión.'); redirect('/internal/login'); }
    } catch (error) {
      if (!destroyed) requireAccess(error?.status === 401 ? 'La sesión ya no está disponible.' : 'No se pudo confirmar el cierre de sesión. Volvé a comprobar el acceso antes de continuar.');
    }
  }
  listen(document, 'click', event => {
    const control = event.target.closest?.('[data-action]');
    if (!control || control.disabled) return;
    if (control.dataset.action === 'nav') { event.preventDefault(); navigate(control.dataset.target); }
    if (control.dataset.action === 'logout' && state.phase === 'ready') { event.preventDefault(); void logout(); }
    if (control.dataset.action === 'refresh-inventory') refreshSection('inventario');
    if (control.dataset.action === 'page-prev') turnPage(control.dataset.target, 'previous');
    if (control.dataset.action === 'page-next') turnPage(control.dataset.target, 'next');
    if (control.dataset.action === 'close-dialog') control.closest('dialog')?.close();
  });
  listen(document, 'input', event => {
    if (event.target.matches('#clients-search')) updatePager('clientes');
    if (event.target.matches('#inventory-search')) updatePager('inventario');
  });
  listen(document, 'change', event => {
    const control = event.target;
    if (!control.matches('[data-page-size]') || control.disabled || state.phase !== 'ready') return;
    const view = control.dataset.pageSize, page = pages.get(view), take = Number(control.value);
    if (!page || page.status !== 'success' || searchDraft(view) !== page.q || ![25, 50, 100].includes(take)) { updatePager(view); return; }
    page.take = take; page.skip = 0;
    void loadSection(view);
  });
  listen(document, 'submit', event => {
    if (!event.target.matches('[data-staff-form]')) return;
    event.preventDefault();
    if (state.phase !== 'ready') { announce('La sesión todavía no está verificada. No se envió información.'); return; }
    if (!validateForm(event.target)) return;
    if (event.target.dataset.staffForm === 'clients-search') { applySearch('clientes'); return; }
    if (event.target.dataset.staffForm === 'inventory-search') { applySearch('inventario'); return; }
    announce('El guardado todavía no está habilitado: falta la recuperación del resultado del servidor. No se envió información.');
  });
  const ready = verifySession();
  return {
    ready, navigate, refresh: () => refreshSection(state.view),
    getState: () => ({phase: state.phase, busy: state.busy, view: state.view,
      authenticated: state.phase === 'ready' && !!state.session, role: state.session?.role || null}),
    destroy() { destroyed = true; ++epoch; state.session = null; clearPrivateView(); lockActions(); setVisible($('#staff-shell'), false); removers.forEach(remove => remove()); },
  };
}

if (typeof document !== 'undefined' && document.querySelector('[data-staff-app]')) mountStaffApp();

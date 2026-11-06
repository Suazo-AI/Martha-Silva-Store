// Private staff shell. Server identity and business contracts are required.
// No fixture business data or local authentication. Only pending operation references persist per tab.
import {mountSupply} from './supply.mjs';
import {createStaffClient, validateSaleRequest, validateStockReviewRequest, readStockReview} from './client.mjs';
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
  const commerce = typeof client.recordSale === 'function' ? mountCommerce({document, client,
    getSession: () => state.phase === 'ready' ? state.session : null,
    onUnauthorized: () => requireAccess('La sesión venció. Volvé a ingresar para comprobar la venta.')}) : null;
  const supply = typeof client.listPurchaseOrders === 'function' ? mountSupply({document, client, getSession: () => state.phase === 'ready' ? state.session : null, onUnauthorized: () => requireAccess('La sesión venció. Volvé a ingresar.') , onStock: () => commerce?.loadStock()}) : null;
  const stockReview = typeof client.reviewStockException === 'function' ? mountStockReview({document,client,getSession:()=>state.phase==='ready'?state.session:null,onUnauthorized:()=>requireAccess('La sesión venció. Volvé a ingresar.')}) : null;
  let epoch = 0, destroyed = false, commerceStarted = false;
  const reads = new Map();
  const newPage = () => ({q: '', includeInactive: false, skip: 0, take: 50, status: 'idle', confirmed: null});
  const pages = new Map([['clientes', newPage()], ['inventario', newPage()]]);
  const canReadView = view => (view !== 'clientes' || state.session?.role === 'Owner') && (view !== 'abastecimiento' || ['Owner','Manager','Inventory'].includes(state.session?.role));
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
    commerceStarted = false;
    commerce?.clear();
    supply?.clear(); stockReview?.clear();
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
    const usable = state.phase === 'ready' && canReadView(view)
      && page.status === 'success' && !!confirmed && !dirty;
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
    if (form) for (const control of form.elements)
      control.disabled = busy || state.phase !== 'ready' || !canReadView(view);
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
    if (state.phase !== 'ready' || !state.session || !canReadView(view)
      || !['clientes', 'inventario'].includes(view)) return;
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
      $$('[data-action="nav"]').forEach(button => {
        const allowed = canReadView(button.dataset.target);
        button.disabled = !allowed;
        setVisible(button, allowed);
      });
      $('[data-action="logout"]').disabled = false;
      for (const view of ['clientes', 'inventario']) {
        readControls(view, false);
        $(`#${section(view)}-search-form`).elements.namedItem('query').maxLength = 200;
      }
      const create = $('[data-action="new-client"]');
      if (create) { create.disabled = true; create.title = 'El guardado de clientes está pendiente del contrato de resultado y recuperación.'; }
      announce('Sesión verificada por el servidor. Negocio de esta instancia; consultas de directorio habilitadas.');
      const initialView = verified.role === 'Owner' ? 'clientes' : 'inventario';
      navigate(initialView, false, false);
      await loadSection(initialView);
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
    if (!canReadView(view)) {
      announce('Tu rol no tiene acceso al directorio de clientes.');
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
    if (['inventario','ventas'].includes(view) && commerce) {
      if (!commerceStarted) { commerceStarted = true; void commerce.start(); stockReview?.start(); }
      else if (load && view === 'inventario') void commerce.loadStock();
    }
    if (view === 'abastecimiento') void supply?.start();
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
    destroy() { destroyed = true; ++epoch; state.session = null; clearPrivateView(); commerce?.destroy(); supply?.destroy(); stockReview?.destroy(); lockActions(); setVisible($('#staff-shell'), false); removers.forEach(remove => remove()); },
  };
}

export function mountCommerce({document, client, getSession, onUnauthorized}) {
  const $ = id => document.getElementById(id);
  const form = $('sale-form');
  if (!form) return {clear(){}, start(){}, loadStock(){}, destroy(){}};
  let generation = 0, stockRead = 0, busy = false, pending = null, items = [], locations = [], actor = null;
  const removers = [];
  const listen = (el, event, fn) => { el.addEventListener(event, fn); removers.push(() => el.removeEventListener(event, fn)); };
  const keyFor = id => `savia.sale.pending.${id}`;
  const receiptKey = id => `savia.sale.receipt.${id}`;
  const storage = () => document.defaultView.sessionStorage;
  const current = (g, id) => generation === g && getSession()?.id === id;
  const changedScope = () => !!pending?.key && ((!!pending.actorVersion && pending.actorVersion !== getSession()?.version)
    || !locations.some(location => location.id === pending.body?.locationId));
  const cart = () => [...$('sale-lines').querySelectorAll('[data-sale-line]')].map(row => ({
    itemId:row.querySelector('select').value, quantity:Number(row.querySelector('input').value),
    ...(row.querySelector('[data-exception]')?.checked ? {exceptionReason:row.querySelector('[data-exception-reason]').value,size:row.querySelector('[data-exception-size]').value} : {})}));
  function renderLines(lines = [{itemId:items[0]?.id || '',quantity:1}]) {
    $('sale-lines').replaceChildren(...lines.map((line,index) => {
      const row=document.createElement('div'); row.className='sale-line'; row.dataset.saleLine='';
      const suffix=index ? `-${index+1}` : '';
      for(const [name,title] of [['item','Artículo y talla'],['quantity','Cantidad']]) {
        const field=document.createElement('div'); field.className='field';
        const label=textElement(document,'label',`${title} ${index+1}`); label.htmlFor=`sale-${name}${suffix}`;
        const control=document.createElement(name==='item'?'select':'input'); control.id=label.htmlFor; control.required=true;
        if(name==='item') {
          options(control,items,x=>`${x.sku} · ${x.name}`);
          const placeholder=textElement(document,'option','Elegir artículo'); placeholder.value=''; control.prepend(placeholder);
          if(line.itemId && !items.some(item=>item.id===line.itemId)) {
            const missing=textElement(document,'option',`Artículo fuera del catálogo activo: ${line.itemId}`); missing.value=line.itemId; control.append(missing);
          }
          control.value=line.itemId;
        }
        else { control.type='number'; control.min='1'; control.max='100000'; control.step='1'; control.value=String(line.quantity); }
        field.append(label,control); row.append(field);
      }
      const exceptionField=document.createElement('div'); exceptionField.className='field sale-exception';
      const exceptionLabel=textElement(document,'label','Entregar prenda física con disponible 0');
      const exception=document.createElement('input'); exception.type='checkbox'; exception.dataset.exception='';
      exception.checked=line.exceptionReason != null; exceptionLabel.prepend(exception);
      exceptionField.append(exceptionLabel);
      for (const [attribute,title,value] of [['exceptionReason','Motivo de entrega excepcional',line.exceptionReason],['size','Talla de la prenda',line.size]]) {
        const label=textElement(document,'label',title), input=document.createElement('input');
        input.type='text'; input.maxLength=attribute==='size'?80:500; input.value=value || '';
        input.dataset[attribute==='size'?'exceptionSize':'exceptionReason']='';
        input.required=exception.checked; input.hidden=!exception.checked; label.hidden=!exception.checked;
        label.append(input); exceptionField.append(label);
        exception.addEventListener('change',()=>{input.required=exception.checked; input.hidden=!exception.checked; label.hidden=!exception.checked;});
      }
      const remove=textElement(document,'button','Quitar'); remove.type='button'; remove.className='btn btn-secondary';
      remove.dataset.saleRemove=String(index); remove.setAttribute('aria-label',`Quitar artículo ${index+1}`); row.append(remove,exceptionField);
      return row;
    }));
    lock();
  }
  function lock() {
    const allowed = !!actor && getSession()?.id === actor && ['Owner','Manager','Cashier'].includes(getSession()?.role);
    for (const control of form.elements) control.disabled = !allowed || busy || !!pending || !items.length || !locations.length;
    $('sale-add').disabled ||= cart().length >= Math.min(100,items.length);
    for(const remove of form.querySelectorAll('[data-sale-remove]')) remove.disabled ||= cart().length <= 1;
    $('stock-location').disabled = !actor || busy || !locations.length;
    $('stock-refresh').disabled = !actor || busy || !locations.length;
    for (const id of ['sale-recover','sale-retry']) {
      $(id).hidden = !pending;
      $(id).disabled = busy || !allowed || !pending?.key || changedScope()
        || (id === 'sale-retry' && pending.actorVersion !== getSession()?.version);
    }
  }
  function fail(error, target = 'sale-status') {
    if (error?.status === 401) { onUnauthorized(); return; }
    $(target).textContent = error instanceof StaffRequestError ? error.message : 'No se pudo confirmar la respuesta. Volvé a comprobarla.';
    if (pending && target === 'sale-status') $(target).textContent += ' La venta sigue sin confirmar. Comprobala con la clave original.';
  }
  function clear() {
    ++generation; ++stockRead; actor=null; pending=null; busy=false; items=[]; locations=[];
    for (const id of ['stock-location','sale-location','sale-lines','stock-table','sale-receipt']) $(id).replaceChildren();
    $('sale-receipt').hidden=true; form.reset(); $('sale-status').textContent='Esperando datos del servidor.';
    $('stock-status').textContent='Sin consulta confirmada.'; lock();
  }
  async function allPages(fn) {
    const rows=[];
    for(let skip=0;skip<=100000;skip+=100) {
      const page=await fn({skip,take:100}); rows.push(...page.items);
      if(skip+page.items.length>=page.total) return rows;
      if(!page.items.length) throw new StaffRequestError('response');
    }
    throw new StaffRequestError('response');
  }
  function options(select, rows, label) { select.replaceChildren(...rows.map(row => { const option=textElement(document,'option',label(row)); option.value=row.id; return option; })); }
  async function loadStock() {
    if(!actor || !locations.length) return;
    const g=generation, id=actor, request=++stockRead, location=$('stock-location').value;
    $('stock-status').textContent='Consultando existencias…'; $('stock-table').replaceChildren();
    try {
      const rows=[];
      for(let skip=0;skip<=100000;skip+=100) {
        const page=await client.listInventory(location,skip); rows.push(...page.items);
        if(skip+page.items.length>=page.total) break;
        if(!page.items.length || skip===100000) throw new StaffRequestError('response');
      }
      if(!current(g,id) || request !== stockRead) return;
      const byId=new Map(items.map(x=>[x.id,x]));
      renderTable($('stock-table'),{columns:[{label:'SKU',value:x=>byId.get(x.itemId)?.sku || x.itemId},{label:'Artículo y talla',value:x=>byId.get(x.itemId)?.name || 'Artículo fuera del catálogo activo'},
        {label:'En existencia',key:'onHand'},{label:'Reservado',key:'reserved'},{label:'Disponible',key:'available'}],rows,caption:locations.find(x=>x.id===location)?.name,emptyText:'No hay saldos registrados para esta sucursal.'});
      $('stock-status').textContent=`${rows.length} saldos confirmados por el servidor.`;
    } catch(error) { if(current(g,id) && request===stockRead) fail(error,'stock-status'); }
  }
  function showReceipt(receipt) {
    const mount=$('sale-receipt'); mount.replaceChildren(textElement(document,'h3','Recibo confirmado'),
      textElement(document,'p',`Venta: ${receipt.saleId}`),textElement(document,'p',`Sucursal: ${locations.find(x=>x.id===receipt.locationId)?.name || receipt.locationId}`),
      textElement(document,'p',`Estado: ${{recorded:'Registrada',cancelled:'Cancelada',returned:'Devuelta',partially_returned:'Devolución parcial'}[receipt.state]} · Sin cobro bancario`));
    const money=value=>new Intl.NumberFormat('es-NI',{style:'currency',currency:receipt.currency}).format(value/100);
    for(const line of receipt.lines) mount.append(textElement(document,'p',`${line.sku} · ${line.name} · ${line.quantity} × ${money(line.unitPriceMinor)} = ${money(line.totalMinor)}`));
    for(const line of receipt.lines.filter(x=>x.exceptionReason)) mount.append(textElement(document,'p',`Entrega excepcional · ${line.sku} · Talla: ${line.size} · Motivo: ${line.exceptionReason} · Causa abierta`));
    mount.append(textElement(document,'strong',`Total: ${money(receipt.totalMinor)}`)); mount.hidden=false;
  }
  // A receipt reference is stored only after the server confirmed that sale, so failing to show it
  // must not invent an unconfirmed operation (N5). Only a real pending reference blocks new sales.
  async function restoreReceipt(saleId, g, id) {
    let receipt = null, gone = false;
    try {
      receipt = await client.getSale(saleId);
      if (receipt.actorId !== id) { receipt = null; gone = true; }
    } catch (error) {
      if (error?.status === 401) throw error;
      gone = [403, 404].includes(error?.status);
    }
    if (!current(g, id)) return;
    if (receipt) { showReceipt(receipt); if(!pending) renderLines([{itemId:'',quantity:1}]); return; }
    if (gone) { try { storage().removeItem(receiptKey(id)); } catch {} }
    const notice = gone ? 'El último recibo confirmado ya no está disponible en el servidor.'
      : 'No se pudo cargar el último recibo confirmado desde el servidor.';
    $('sale-status').textContent = `${notice} ${$('sale-status').textContent}`;
  }
  async function resolve(mode) {
    if(busy || !pending || !actor || changedScope()
      || (mode==='record' && pending.actorVersion !== getSession()?.version)) return;
    const operation=pending, id=actor, g=generation; busy=true; lock(); $('sale-status').textContent= mode==='recover' ? 'Comprobando la venta original…' : 'Esperando confirmación del servidor…';
    try {
      const receipt=await (mode==='recover' ? client.recoverSale(operation.key,operation.body) : client.recordSale(operation.key,operation.body));
      if(!current(g,id)) return;
      if(receipt.actorId !== id) throw new StaffRequestError('response');
      // Persist the receipt reference first; keep the pending operation if persistence fails.
      storage().setItem(receiptKey(id),receipt.saleId); storage().removeItem(keyFor(id));
      pending=null; showReceipt(receipt); renderLines([{itemId:'',quantity:1}]); $('sale-status').textContent='Venta confirmada por el servidor.';
      await loadStock();
    } catch(error) {
      if(current(g,id)) {
        if(mode==='recover' && error instanceof StaffRequestError && error.code==='sale_rejected') {
          try { storage().removeItem(keyFor(id)); pending=null; }
          catch { fail(new StaffRequestError('unavailable')); return; }
        }
        fail(error);
      }
    }
    finally { if(current(g,id)) { busy=false; lock(); } }
  }
  async function start() {
    const session=getSession(); if(!session) return;
    const g=generation,id=session.id; actor=id; busy=true; lock();
    try {
      const [catalog,places]=await Promise.all([allPages(client.listItems),allPages(client.listLocations)]);
      if(!current(g,id)) return;
      items=catalog.filter(x=>x.active); locations=places.filter(x=>x.active && x.branchId);
      renderLines();
      for(const select of [$('sale-location'),$('stock-location')]) options(select,locations,x=>x.name);
      $('sale-status').textContent=['Owner','Manager','Cashier'].includes(session.role) ? 'Elegí sucursal, artículos y cantidades.' : 'Tu perfil permite consultar existencias.';
      const raw=storage().getItem(keyFor(id));
      if(raw) {
        const value=JSON.parse(raw);
        // Validation is repeated by the client before every recovery or resend.
        if(!value || typeof value.key!=='string' || !/^[0-9a-f-]{36}$/i.test(value.key) || !value.body) throw new StaffRequestError('response');
        pending=value;
        validateSaleRequest(value.body);
        $('sale-location').value=value.body.locationId;
        renderLines(value.body.lines);
      }
      if(changedScope()) {
        $('sale-status').textContent='Tu acceso cambió. La venta anterior sigue sin confirmar. Pedí al responsable que la concilie.';
        await loadStock();
        return;
      }
      const last=storage().getItem(receiptKey(id));
      if(last) await restoreReceipt(last,g,id);
      await loadStock();
    } catch(error) { if(current(g,id)) { busy=false; pending ||= {}; fail(error); } }
    finally { if(current(g,id)) { busy=false; lock(); } }
    if(current(g,id) && pending?.key) await resolve('recover');
  }
  listen(form,'submit',event=>{
    event.preventDefault();
    if(busy || pending || !actor || !['Owner','Manager','Cashier'].includes(getSession()?.role) || !validateForm(form)) return;
    const body={locationId:$('sale-location').value,customerId:null,lines:cart()};
    if(new Set(body.lines.map(line=>line.itemId.toLowerCase())).size !== body.lines.length) {
      $('sale-status').textContent='Hay artículos repetidos. Usá una sola fila por artículo y sumá su cantidad.'; return;
    }
    try { validateSaleRequest(body); } catch(error) { fail(error); return; }
    const operation={key:document.defaultView.crypto.randomUUID(),body,actorVersion:getSession().version};
    try { storage().setItem(keyFor(actor),JSON.stringify(operation)); pending=operation; $('sale-receipt').hidden=true; void resolve('record'); }
    catch(error) { pending={}; fail(error); lock(); }
  });
  listen($('sale-add'),'click',()=>{
    if(busy || pending || $('sale-add').disabled) return;
    const lines=cart(),next=items.find(item=>!lines.some(line=>line.itemId===item.id));
    if(!next || lines.length>=100) return;
    renderLines([...lines,{itemId:next.id,quantity:1}]);
    $('sale-lines').lastElementChild.querySelector('select').focus();
  });
  listen($('sale-lines'),'click',event=>{
    const remove=event.target.closest('[data-sale-remove]');
    if(!remove || remove.disabled || busy || pending) return;
    const lines=cart(),index=Number(remove.dataset.saleRemove); lines.splice(index,1); renderLines(lines);
    $('sale-lines').children[Math.min(index,lines.length-1)].querySelector('select').focus();
  });
  listen($('stock-location'),'change',()=>void loadStock()); listen($('stock-refresh'),'click',()=>void loadStock());
  listen($('sale-recover'),'click',()=>void resolve('recover')); listen($('sale-retry'),'click',()=>void resolve('record'));
  return {clear,start,loadStock,destroy(){clear();removers.forEach(fn=>fn());}};
}

if (typeof document !== 'undefined' && document.querySelector('[data-staff-app]')) mountStaffApp();


export function mountStockReview({document,client,getSession,onUnauthorized}) {
  const $=id=>document.getElementById(id), panel=$('stock-review'), form=$('stock-review-form'), load=$('stock-review-load');
  if(!panel) return {start(){},clear(){},destroy(){}};
  let epoch=0,busy=false,sale=null,pending=null,blocked=false;
  const storage=()=>document.defaultView.sessionStorage;
  const storageKey=a=>`savia.stock.review.pending.${a.id}`;
  const same=(e,a)=>epoch===e && getSession()?.id===a.id && getSession()?.version===a.version;
  const allowed=()=>['Owner','Manager'].includes(getSession()?.role);
  const status=text=>$('stock-review-status').textContent=text;
  function lock(){for(const el of form.elements) el.disabled=busy||blocked||!!pending||!sale||!allowed();
    for(const el of load.elements)el.disabled=busy||blocked||!!pending||!allowed();
    $('stock-review-retry').hidden=!pending; $('stock-review-retry').disabled=busy||blocked||!allowed();}
  function clear(){epoch++;busy=false;sale=null;pending=null;blocked=false;panel.hidden=true;form.reset();load.reset();$('stock-review-evidence').replaceChildren();form.elements.saleLineId.replaceChildren();status('');lock();}
  function start(){clear();panel.hidden=!allowed();if(!allowed())return;
    try{const raw=storage().getItem(storageKey(getSession()));if(raw){pending=JSON.parse(raw);
      if(pending.actorVersion!==getSession().version||pending.actorId!==getSession().id||typeof pending.key!=='string'||!pending.body||!pending.saleId)blocked=true;
      status(blocked?'La referencia requiere conciliación por el responsable.':'Revisión sin confirmar. Reintentá con la misma referencia.');}}
    catch{blocked=true;status('No se pudo leer la referencia pendiente.');}lock();}
  function fail(e){if(e.status===401){onUnauthorized();return;}status(pending?'Revisión sin confirmar. La referencia original se conserva.':'No se pudo consultar la venta.');}
  async function send(){if(busy||blocked||!pending||!allowed())return;const a=getSession(),e=epoch,op=pending;busy=true;lock();
    try{const result=await client.reviewStockException(op.saleId,op.key,op.body);if(!same(e,a))return;
      readStockReview(result,{body:op.body,reviewerId:a.id});
      storage().removeItem(storageKey(a));pending=null;status('Revisión confirmada. Causa abierta; seguimiento registrado.');
    }catch(error){if(same(e,a)){
      if(error.code==='stock_review_rejected'){
        try{storage().removeItem(storageKey(a));pending=null;status('Revisión rechazada. Corregí los datos y volvé a enviar.');}
        catch{blocked=true;status('No se pudo retirar la referencia rechazada.');}
      }else fail(error);
    }}finally{if(same(e,a)){busy=false;lock();}}}
  async function read(event){event.preventDefault();if(busy||pending||blocked||!allowed())return;const a=getSession(),e=epoch;busy=true;sale=null;lock();
    try{const value=await client.getSale(load.elements.saleId.value.trim());const reviews=(await client.stockReviews(value.saleId)).map(value=>readStockReview(value));if(!same(e,a))return;
      $('stock-review-evidence').replaceChildren(
        textElement(document,'p',`Venta ${value.saleId} · Registró ${value.actorId} · ${value.createdAt}`),
        ...value.lines.filter(x=>x.exceptionReason).map(x=>textElement(document,'p',`${x.sku} · Talla ${x.size} · ${x.quantity} entregadas · ${x.returnedQuantity} revertidas · ${x.exceptionReason}`)),
        ...reviews.map(x=>textElement(document,'p',`Revisión ${x.id} · ${x.evidence} · ${x.outcome} · Causa abierta · Responsable ${x.responsibleActorId} · Próxima revisión ${x.nextReviewAt}`)));
      if(value.actorId===a.id){status('Otro perfil autorizado debe revisar esta entrega.');return;}
      const lines=value.lines.filter(x=>x.exceptionReason);sale=value;form.elements.saleLineId.replaceChildren(...lines.map(x=>{const option=textElement(document,'option',`${x.sku} · ${x.size} · ${x.quantity} · ${x.exceptionReason}`);option.value=x.saleLineId;return option;}));
      if(!lines.length)sale=null;status(lines.length?'Examiná la evidencia y registrá el seguimiento.':'La venta no contiene entregas excepcionales.');
    }catch(error){if(same(e,a))fail(error);}finally{if(same(e,a)){busy=false;lock();}}}
  function submit(event){event.preventDefault();if(busy||pending||blocked||!sale||!allowed()||!form.reportValidity())return;
    const a=getSession(),f=form.elements,next=new Date(f.nextReviewAt.value);
    const body={saleLineId:f.saleLineId.value,evidence:f.evidence.value,outcome:f.outcome.value,responsibleActorId:f.responsibleActorId.value.trim(),nextReviewAt:Number.isFinite(next.getTime())?next.toISOString():''};
    try{validateStockReviewRequest(body);if(next.getTime()<=Date.now())throw new StaffRequestError('invalid');}
    catch{status(new StaffRequestError('invalid').message);return;}
    try{const op={actorId:a.id,actorVersion:a.version,saleId:sale.saleId,key:document.defaultView.crypto.randomUUID(),body};const raw=JSON.stringify(op);storage().setItem(storageKey(a),raw);if(storage().getItem(storageKey(a))!==raw)throw Error('storage');pending=op;void send();
    }catch{blocked=true;status('No se pudo guardar la referencia. La revisión no se envió.');lock();}}
  const retry=()=>void send();load.addEventListener('submit',read);form.addEventListener('submit',submit);$('stock-review-retry').addEventListener('click',retry);
  return {start,clear,destroy(){clear();load.removeEventListener('submit',read);form.removeEventListener('submit',submit);$('stock-review-retry').removeEventListener('click',retry);}};
}

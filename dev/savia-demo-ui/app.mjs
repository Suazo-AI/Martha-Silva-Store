import { createDemoStore } from './model.mjs';
import { readBackendStatus } from './api-client.mjs';

const escapeHTML = value => String(value ?? '').replace(/[&<>"']/g, character => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[character]));
export const formatMoney = cents => `USD ${(Number(cents) / 100).toFixed(2)}`;
const dateLabel = value => {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? 'Hora no disponible' : new Intl.DateTimeFormat('es-NI', {dateStyle:'medium',timeStyle:'short'}).format(date);
};

export function mountSaviaDemo({document = globalThis.document, model = createDemoStore(), readStatus = readBackendStatus} = {}) {
  if (!document?.querySelector('[data-savia-app]')) throw new Error('No se encontró la pantalla SAVIA.');
  const $ = selector => document.querySelector(selector);
  const $$ = selector => [...document.querySelectorAll(selector)];
  const listeners = [], sizes = new Map(), returns = new Map();
  let currentView = 'caja', search = '', category = '', pendingConfirmation = null, processing = false, checking = false, toastTimer, destroyed = false;
  const on = (element, event, handler) => { element.addEventListener(event, handler); listeners.push(() => element.removeEventListener(event, handler)); };
  const focusKey = key => $$('[data-focus-key]').find(element => element.dataset.focusKey === key && !element.disabled && !element.closest('[hidden]'));
  const focus = (key, fallback = '[data-cart-heading]') => (focusKey(key) || $(fallback))?.focus();
  function announce(message) {
    $('#ui-status').textContent = message;
    const toast = $('[data-toast]'); toast.textContent = message; toast.hidden = false;
    clearTimeout(toastTimer); toastTimer = setTimeout(() => { toast.hidden = true; }, 3600);
  }
  function error(message, target) {
    const dialog = $$('dialog[open]').at(-1);
    const box = dialog?.querySelector('[data-payment-error], [data-confirm-error]') || $('#ui-error');
    box.textContent = message; box.hidden = false;
    target?.focus();
  }
  function clearErrors() { $('#ui-error').hidden = true; $$('[data-payment-error],[data-confirm-error]').forEach(box => { box.hidden = true; }); }
  function openDialog(dialog, trigger = document.activeElement) {
    returns.set(dialog, {element:trigger,key:trigger?.dataset.focusKey,restore:true});
    dialog.showModal();
    (dialog.querySelector('[autofocus]') || dialog.querySelector('button:not(:disabled)'))?.focus();
  }
  function closeDialog(dialog, restore = true) {
    const entry = returns.get(dialog); if (entry) entry.restore = restore;
    dialog.close();
  }
  $$('dialog').forEach(dialog => {
    on(dialog, 'close', () => {
      const entry = returns.get(dialog); returns.delete(dialog);
      if (!entry?.restore || $$('dialog[open]').length) return;
      if (entry.element?.isConnected && !['BODY','HTML'].includes(entry.element.tagName) && !entry.element.disabled && !entry.element.closest('[hidden],dialog:not([open])')) entry.element.focus();
      else focus(entry.key);
    });
    on(dialog, 'cancel', () => { pendingConfirmation = null; });
  });
  function changeView(view, moveFocus = true) {
    if (!['caja','catalogo','ventas','ayuda','conexion'].includes(view)) return;
    currentView = view;
    $$('[data-view]').forEach(section => { section.hidden = section.dataset.view !== view; });
    $$('[data-action="nav"]').forEach(button => {
      if (button.dataset.target === view) button.setAttribute('aria-current','page'); else button.removeAttribute('aria-current');
    });
    $('#view-title').textContent = {caja:'Nueva venta',catalogo:'Catálogo de muestra',ventas:'Ventas de prueba',ayuda:'Cómo usar SAVIA',conexion:'Conexión de prueba'}[view];
    if (moveFocus) $('#view-title').focus();
  }
  function productCard(product, view, index) {
    const available = product.sizes.some(size => size.available > 0), selected = sizes.get(product.id) || '';
    const id = `size-${view}-${product.id}`, colors = ['#b27868','#cbb68b','#737e70','#b19e8b','#7c7184','#727f88'];
    return `<article class="product-card" data-product-id="${escapeHTML(product.id)}"><div class="product-swatch" style="--swatch:${colors[index % colors.length]}" aria-hidden="true"><svg viewBox="0 0 120 120" fill="none" stroke="currentColor" stroke-width="2"><path d="M53 35c0-11 18-11 18 0 0 6-11 10-11 15v5L27 75c-5 3-3 9 3 9h60c6 0 8-6 3-9L60 55"/><path d="M37 70v20h46V70"/></svg></div><div class="product-meta"><p class="muted">${escapeHTML(product.category)} · ${escapeHTML(product.color)}</p><h3>${escapeHTML(product.name)}</h3><strong>${formatMoney(product.priceCents)}</strong><p class="muted">Precio de muestra</p><label for="${escapeHTML(id)}">Talla<select id="${escapeHTML(id)}" class="size-select" data-size-for="${escapeHTML(product.id)}" data-focus-key="size-${view}-${escapeHTML(product.id)}" ${available ? '' : 'disabled'}><option value="">${available ? 'Elegí una talla' : 'Sin tallas disponibles'}</option>${product.sizes.map(size => `<option value="${escapeHTML(size.size)}" ${size.available <= 0 ? 'disabled' : ''} ${selected === size.size && size.available > 0 ? 'selected' : ''}>${escapeHTML(size.size)} · ${size.available > 0 ? `${size.available} disponibles` : 'Agotada'}</option>`).join('')}</select></label><button class="btn btn-primary" data-action="add" data-product="${escapeHTML(product.id)}" data-focus-key="add-${view}-${escapeHTML(product.id)}" ${available ? '' : 'disabled'}>${available ? 'Agregar a la bolsa' : 'Agotada'}</button></div></article>`;
  }
  function renderCatalog() {
    const catalog = model.getCatalog();
    const categories = [...new Set(catalog.map(product => product.category))];
    $$('[data-category-filter]').forEach(select => { select.innerHTML = '<option value="">Todas las categorías</option>' + categories.map(value => `<option value="${escapeHTML(value)}">${escapeHTML(value)}</option>`).join(''); select.value = category; });
    $$('[data-catalog-search]').forEach(input => { if (input.value !== search) input.value = search; });
    const words = search.trim().toLocaleLowerCase('es').split(/\s+/).filter(Boolean);
    const matches = catalog.filter(product => (!category || product.category === category) && words.every(word => `${product.name} ${product.color} ${product.category}`.toLocaleLowerCase('es').includes(word)));
    $$('[data-catalog-count]').forEach(element => { element.textContent = `${matches.length} ${matches.length === 1 ? 'prenda' : 'prendas'}`; });
    $$('[data-product-grid]').forEach(grid => { grid.innerHTML = matches.length ? matches.map((product,index) => productCard(product,grid.dataset.productGrid,index)).join('') : '<div class="empty-state"><h3>No encontramos esa prenda</h3><p>Probá otro nombre, color o categoría.</p><button class="btn btn-secondary" data-action="clear-filters">Ver todas las prendas</button></div>'; });
  }
  function renderCart(state) {
    $('[data-cart-lines]').innerHTML = state.cart.length ? state.cart.map(line => `<article class="cart-line" data-line-id="${escapeHTML(line.id)}"><div><h3>${escapeHTML(line.name)}</h3><p class="muted">Talla ${escapeHTML(line.size)} · ${formatMoney(line.unitPriceCents)} cada una</p><div class="quantity-control"><button class="btn btn-secondary" data-action="decrement" data-line="${escapeHTML(line.id)}" data-focus-key="decrement-${escapeHTML(line.id)}" aria-label="Disminuir cantidad de ${escapeHTML(line.name)}, talla ${escapeHTML(line.size)}" ${line.quantity <= 1 ? 'disabled' : ''}>−</button><span aria-label="Cantidad">${line.quantity}</span><button class="btn btn-secondary" data-action="increment" data-line="${escapeHTML(line.id)}" data-focus-key="increment-${escapeHTML(line.id)}" aria-label="Aumentar cantidad de ${escapeHTML(line.name)}, talla ${escapeHTML(line.size)}">+</button></div><button class="btn btn-secondary" data-action="remove" data-line="${escapeHTML(line.id)}" data-focus-key="remove-${escapeHTML(line.id)}" aria-label="Quitar ${escapeHTML(line.name)}, talla ${escapeHTML(line.size)}">Quitar</button></div><strong>${formatMoney(line.lineTotalCents)}</strong></article>`).join('') : '<div class="empty-state"><h3>Tu bolsa está vacía</h3><p>Elegí una prenda y una talla para empezar.</p></div>';
    $('[data-cart-total]').textContent = formatMoney(state.totalCents);
    $('[data-cart-items]').textContent = `${state.itemCount} ${state.itemCount === 1 ? 'prenda' : 'prendas'}`;
    $('[data-cart-count]').textContent = state.itemCount;
    $('[data-action="pay"]').disabled = !state.cart.length || processing;
    $('[data-action="pay"]').textContent = state.cart.length ? `Cobrar ${formatMoney(state.totalCents)}` : 'Cobrar venta de prueba';
    $('[data-action="clear-cart"]').disabled = !state.cart.length || processing;
  }
  const summaryLines = lines => `<ul>${lines.map(line => `<li>${escapeHTML(line.name)} · ${escapeHTML(line.size)} · ${line.quantity} × ${formatMoney(line.unitPriceCents)} <strong>${formatMoney(line.lineTotalCents)}</strong></li>`).join('')}</ul>`;
  function renderSales(state) {
    $('[data-sales-count]').textContent = state.sales.length;
    $('[data-sales-list]').innerHTML = state.sales.length ? `<div class="table-wrap"><table class="sales-table"><caption class="sr-only">Ventas ficticias de esta sesión</caption><thead><tr><th scope="col">Comprobante</th><th scope="col">Fecha y hora</th><th scope="col">Estado</th><th scope="col">Total de muestra</th><th scope="col">Acción</th></tr></thead><tbody>${[...state.sales].reverse().map(sale => `<tr data-sale-id="${escapeHTML(sale.id)}"><th scope="row">${escapeHTML(sale.id)}</th><td>${escapeHTML(dateLabel(sale.createdAt))}</td><td><span class="status-badge">${sale.status === 'cancelled' ? 'Cancelada' : 'Completada'}</span></td><td>${formatMoney(sale.totalCents)}</td><td><button class="btn btn-secondary" data-action="cancel-sale" data-sale="${escapeHTML(sale.id)}" data-focus-key="cancel-${escapeHTML(sale.id)}" aria-label="Cancelar venta de prueba ${escapeHTML(sale.id)}" ${sale.status === 'cancelled' ? 'disabled' : ''}>${sale.status === 'cancelled' ? 'Ya cancelada' : 'Cancelar venta'}</button></td></tr>`).join('')}</tbody></table></div>` : '<div class="empty-state"><h2>Todavía no hay ventas de prueba</h2><p>Armá una bolsa en Caja para probar el cobro.</p><button class="btn btn-primary" data-action="nav" data-target="caja">Ir a Caja</button></div>';
  }
  function render() { const state = model.getState(); renderCatalog(); renderCart(state); renderSales(state); return state; }
  function mutate(action, message, key) {
    clearErrors();
    try { action(); render(); if (key) focus(key); if (message) announce(message); return true; }
    catch (exception) { error(exception.message); if (key) focus(key); return false; }
  }
  function confirmAction(kind, id, trigger) {
    pendingConfirmation = {kind,id};
    $('#confirm-title').textContent = kind === 'reset' ? '¿Reiniciar esta demo?' : '¿Cancelar esta venta de prueba?';
    $('[data-confirm-content]').textContent = kind === 'reset' ? 'Se borrarán la bolsa y las ventas de esta sesión y se recuperarán las existencias de ejemplo. Solo afecta esta demo.' : 'Las prendas volverán a las existencias de ejemplo una sola vez. No se mueve dinero.';
    $('[data-action="confirm"]').textContent = kind === 'reset' ? 'Reiniciar demo' : 'Cancelar venta de prueba';
    $('[data-confirm-error]').hidden = true; openDialog($('#confirm-dialog'),trigger);
  }
  function checkout(outcome) {
    if (processing || !$('#payment-dialog').open) return;
    processing = true; $$('[data-action="approve"],[data-action="decline"]').forEach(button => { button.disabled = true; });
    try {
      clearErrors(); const state = model.checkout(outcome);
      if (outcome === 'declined') { $('[data-payment-error]').textContent = 'Rechazo simulado. No se cobró dinero y tu bolsa sigue igual. Podés volver a intentar.'; $('[data-payment-error]').hidden = false; announce('Cobro de prueba rechazado. Tu bolsa se conservó.'); }
      else {
        const sale = state.sales.find(value => value.id === state.lastResult?.saleId);
        if (!sale) throw new Error('No se encontró el comprobante de prueba. Revisá Ventas antes de reintentar.');
        $('[data-receipt-content]').innerHTML = `<p class="status-badge">FICTICIO · SIN VALIDEZ FISCAL · SIN COBRO REAL</p><dl class="receipt-meta"><div><dt>Número de prueba</dt><dd>${escapeHTML(sale.id)}</dd></div><div><dt>Fecha y hora</dt><dd>${escapeHTML(dateLabel(sale.createdAt))}</dd></div></dl>${summaryLines(sale.lines)}<div class="summary"><span>Total de muestra</span><strong>${formatMoney(sale.totalCents)}</strong></div><p>Esta simulación solo modificó las existencias de ejemplo de esta sesión.</p>`;
        render(); closeDialog($('#payment-dialog'),false); openDialog($('#receipt-dialog')); announce('Venta ficticia aprobada. Comprobante de prueba disponible.');
      }
    } catch (exception) { error(exception.message); }
    finally { processing = false; $$('[data-action="approve"],[data-action="decline"]').forEach(button => { button.disabled = false; }); renderCart(model.getState()); if (outcome === 'declined' && $('#payment-dialog').open) $('[data-action="approve"]').focus(); }
  }
  function renderBackend(result) {
    $('[data-backend-status]').textContent = result.message;
    $('[data-backend-status]').dataset.state = result.state;
    $('[data-backend-checks]').innerHTML = (result.checks || []).map(check => `<li><strong>${check.ok ? '✓' : '—'} ${escapeHTML(check.label)}</strong><p>${escapeHTML(check.message)}</p></li>`).join('');
    const catalog = result.catalog;
    $('[data-backend-catalog]').innerHTML = catalog?.synthetic === true && Array.isArray(catalog.items) ? `<h2>Fixtures de reservas · moneda XXX</h2><p>Datos recibidos de la API sintética; no pertenecen a la caja USD de ejemplo. No se habilitan ventas ni pagos.</p><p>Autoridad: ${escapeHTML(typeof catalog.authority === 'string' ? catalog.authority : JSON.stringify(catalog.authority))}</p><div class="table-wrap"><table class="sales-table"><caption class="sr-only">Respuesta del catálogo sintético, sin equivalencia comercial</caption><thead><tr><th>Fixture</th><th>Datos de prueba de la API (XXX)</th></tr></thead><tbody>${catalog.items.map(item => `<tr><th scope="row">${escapeHTML(item.name || item.productName || item.variantId || 'Fixture sintética')}</th><td><pre>${escapeHTML(JSON.stringify(item,null,2))}</pre></td></tr>`).join('')}</tbody></table></div>` : '';
  }
  async function checkBackend(button) {
    if (checking) return; const restoreFocus = document.activeElement === button; checking = true; button.disabled = true; button.setAttribute('aria-busy','true'); $('[data-backend-status]').textContent = 'Comprobando la API de reservas sintéticas…';
    try { const result = await readStatus(); if (!destroyed) renderBackend(result); }
    catch { if (!destroyed) renderBackend({state:'unavailable',message:'La API de prueba no está disponible o aún no se desplegó. Esta caja sigue siendo una demo en memoria; no se envió ninguna operación.',checks:[],catalog:null}); }
    finally { checking = false; if (!destroyed) { button.disabled = false; button.removeAttribute('aria-busy'); if (restoreFocus && currentView === 'conexion' && [button,document.body,document.documentElement].includes(document.activeElement)) button.focus(); announce('Comprobación de conexión terminada.'); } }
  }
  on(document,'input',event => { if (event.target.matches('[data-catalog-search]')) { search = event.target.value; renderCatalog(); } });
  on(document,'change',event => {
    if (event.target.matches('[data-category-filter]')) { category = event.target.value; renderCatalog(); }
    if (event.target.matches('[data-size-for]')) sizes.set(event.target.dataset.sizeFor,event.target.value);
  });
  on(document,'click',event => {
    const button = event.target.closest('[data-action]'); if (!button || button.disabled) return;
    const {action} = button.dataset, key = button.dataset.focusKey;
    if (action === 'nav') { event.preventDefault(); clearErrors(); changeView(button.dataset.target); return; }
    if (action === 'clear-filters') { search = ''; category = ''; renderCatalog(); (currentView === 'caja' ? $('#product-search') : $('#catalog-search')).focus(); return; }
    if (action === 'add') {
      const select = button.closest('[data-product-id]').querySelector('[data-size-for]');
      if (!select.value) { error('Elegí una talla disponible para agregar esta prenda.',select); return; }
      mutate(() => model.addItem(button.dataset.product,select.value,1),'Prenda agregada a la bolsa de prueba.',key); return;
    }
    if (['increment','decrement','remove'].includes(action)) {
      const line = model.getState().cart.find(value => value.id === button.dataset.line); if (!line) return;
      mutate(() => action === 'remove' ? model.removeItem(line.id) : model.setQuantity(line.id,line.quantity + (action === 'increment' ? 1 : -1)),action === 'remove' ? 'Prenda quitada de la bolsa.' : 'Cantidad actualizada.',key); return;
    }
    if (action === 'clear-cart') { mutate(() => model.clearCart(),'Bolsa vaciada.',null); $('[data-cart-heading]').focus(); return; }
    if (action === 'pay') { const state = model.getState(); if (!state.cart.length) return; clearErrors(); $('[data-payment-summary]').innerHTML = summaryLines(state.cart) + `<div class="summary"><span>Total de muestra</span><strong>${formatMoney(state.totalCents)}</strong></div>`; openDialog($('#payment-dialog'),button); return; }
    if (action === 'approve' || action === 'decline') { checkout(action === 'approve' ? 'approved' : 'declined'); return; }
    if (action === 'close-dialog') { pendingConfirmation = null; closeDialog(button.closest('dialog')); return; }
    if (action === 'new-sale') { closeDialog($('#receipt-dialog'),false); clearErrors(); changeView('caja',false); $('#product-search').focus(); return; }
    if (action === 'cancel-sale') { confirmAction('cancel',button.dataset.sale,button); return; }
    if (action === 'reset-demo') { confirmAction('reset',null,button); return; }
    if (action === 'confirm' && pendingConfirmation) {
      const pending = pendingConfirmation;
      if (mutate(() => pending.kind === 'reset' ? model.resetDemo() : model.cancelSale(pending.id),pending.kind === 'reset' ? 'Demo reiniciada. Las existencias de ejemplo están disponibles.' : 'Venta de prueba cancelada. Existencias repuestas una sola vez.')) {
        pendingConfirmation = null; closeDialog($('#confirm-dialog'),false);
        if (pending.kind === 'reset') { search = ''; category = ''; sizes.clear(); render(); changeView('caja',false); $('#product-search').focus(); } else $('#view-title').focus();
      } return;
    }
    if (action === 'check-backend') void checkBackend(button);
  });
  render(); changeView('caja',false);
  return {render,model,destroy() { destroyed = true; clearTimeout(toastTimer); listeners.forEach(remove => remove()); }};
}

if (typeof document !== 'undefined' && document.querySelector('[data-savia-app]')) mountSaviaDemo();

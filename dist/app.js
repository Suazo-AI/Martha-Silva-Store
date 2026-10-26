/* Own storefront logic. Browser-local demonstration. No live stock, real orders or payments. */
(() => {
  'use strict';
  window.STORE_MEDIA=window.STORE_MEDIA || {};
  const $ = (s, root = document) => root.querySelector(s);
  const $$ = (s, root = document) => [...root.querySelectorAll(s)];
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const locale = () => window.MarthaI18n?.language === 'en' ? 'en-US' : 'es-NI';
  const money = n => new Intl.NumberFormat(locale(), {style:'currency',currency:'USD',currencyDisplay:'code'}).format(n / 100);
  const uuid = () => crypto.randomUUID();
  let products = [], cart = null, pageScope, lenis, raf, currentOrder, adminOrders = [], inventory = [], checkout = {}, quote, productObserver, productAdding = false;
  const MODE_KEY = 'martha-integration-mode-v1';
  const integrationInstances = new Map();
  let memoryOnlyIntegration = false;
  let integrationMode = 'savia', integrationApi, integrationEpoch = 0, pendingApi = 0, busyActions = 0, mountJobs = 0, modeSwitching = false, integrationError = '';
  try { const saved = sessionStorage.getItem(MODE_KEY); if (['savia','sisfain'].includes(saved)) integrationMode = saved; } catch {}
  const sessionKey = name => `martha-${integrationMode}-${name}-v1`;
  function loadCheckout() {
    try { checkout = JSON.parse(sessionStorage.getItem(sessionKey('checkout')) || '{}'); } catch { checkout = {}; }
    if (!checkout || typeof checkout !== 'object' || Array.isArray(checkout)) checkout = {};
  }
  function createIntegration() {
    integrationApi = null;
    try {
      if (!window.MarthaIntegrations || !window.createMarthaDemoApi || !window.DEMO_CATALOG) throw new Error('No se cargó la compra de prueba. Usá Reintentar para continuar; no se realizó ninguna operación.');
      let storage; try { storage = localStorage; } catch {}
      const factory = window.MarthaIntegrations.createDemoAdapter, engine = window.createMarthaDemoApi, catalog = window.DEMO_CATALOG;
      const cached = integrationInstances.get(integrationMode);
      // Retain memory-only models for this page, including BFCache. Stored
      // models keep their existing reload behavior; reset updates the client.
      if (storage || !cached || cached.factory !== factory || cached.engine !== engine || cached.catalog !== catalog || cached.storage !== storage) {
        const api = factory({mode:integrationMode,catalog,storage,createDemoApi:engine});
        integrationInstances.set(integrationMode, {api,factory,engine,catalog,storage});
      }
      integrationApi = integrationInstances.get(integrationMode).api;
      memoryOnlyIntegration = !storage;
      integrationError = '';
    } catch (error) { integrationError = error.message; }
  }
  function renderIntegration() {
    const panel = $('[data-integration-panel]'); if (!panel) return;
    panel.dataset.mode = integrationMode;
    panel.dataset.memoryOnly = String(memoryOnlyIntegration);
    $$('[data-integration-mode]').forEach(button => {
      button.setAttribute('aria-pressed', String(button.dataset.integrationMode === integrationMode));
      button.disabled = !!(pendingApi || busyActions || mountJobs || modeSwitching);
    });
    const name = integrationMode === 'savia' ? 'SAVIA' : 'SISFAIN';
    $('[data-integration-status]',panel).textContent = integrationError ? `${name} · Modo no disponible` : `${name} · Demostración`;
    $('[data-integration-description]',panel).textContent = integrationMode === 'savia'
      ? 'SAVIA: Sistema de Administración, Ventas, Inventarios y Abastecimiento. Existe una API .NET sintética de prueba, pero esta demo no está conectada a ella ni a un sistema real. La compatibilidad comercial no está validada.'
      : 'SISFAIN de CGA: modelo conceptual simulado. No contamos con un contrato ni una API verificada; no hay conexión configurada. La compatibilidad real está pendiente de validación con CGA.';
    $('[data-integration-availability]',panel).textContent = (integrationError ? 'Reintentá para continuar.' : 'Cada modo conserva su propia bolsa') + (memoryOnlyIntegration ? ' · Datos temporales: se pierden al recargar esta página.' : '');
    $('[data-integration-retry]',panel).hidden = !integrationError;
    $('[data-integration-error]',panel).hidden = !integrationError;
    $('[data-integration-error]',panel).textContent = integrationError;
  }
  function blockCommerce() {
    $$('[data-add], [data-sticky-add], [data-create-order], [data-test-payment], [data-quantity], [data-stock] button, [data-fulfillment] button').forEach(button => button.disabled = true);
  }
  async function switchIntegration(mode) {
    if (!['savia','sisfain'].includes(mode) || mode === integrationMode || pendingApi || busyActions || mountJobs || modeSwitching) return;
    try { sessionStorage.setItem(MODE_KEY, mode); } catch { notify('No pudimos guardar el modelo en esta pestaña. No se cambió la selección.'); return; }
    modeSwitching = true; integrationEpoch++;
    $$('dialog[open]').forEach(dialog => dialog.close());
    integrationMode = mode;
    products = []; cart = null; currentOrder = null; quote = null; checkout = {}; adminOrders = []; inventory = []; productAdding = false;
    loadCheckout(); createIntegration();
    if ($('main')?.dataset.page === 'order') { const url = new URL(location.href); url.searchParams.delete('id'); history.replaceState(null, '', url.pathname + url.search + url.hash); }
    $$('[data-error], [data-add-confirmation]').forEach(element => element.hidden = true);
    $$('input[name="variant"]').forEach(input => input.checked = false);
    $('[data-cart-summary]')?.replaceChildren(); $('[data-order-root]')?.replaceChildren(); $('[data-admin-root]')?.replaceChildren();
    renderIntegration();
    try { await mountPage(); } finally { modeSwitching = false; renderIntegration(); }
    $(`[data-integration-mode="${mode}"]`)?.focus({preventScroll:true});
    notify(`${mode === 'savia' ? 'SAVIA' : 'SISFAIN (CGA)'}: bolsa y pedidos de prueba independientes. No se transfirió información entre modelos.`);
  }
  createIntegration(); loadCheckout();
  const statusLabel = {pending:'Pago pendiente',pending_payment:'Pago pendiente',paid:'Pago de prueba aprobado',declined:'Pago de prueba rechazado',cancelled:'Pedido cancelado',preparing:'En preparación',shipped:'Enviado',delivered:'Entregado',partially_refunded:'Reembolso parcial de prueba',refunded:'Reembolso de prueba completado',requested:'Solicitud recibida',received:'Prenda recibida',order_created:'Pedido creado',newsletter_opt_in:'Novedades seleccionadas',newsletter_not_selected:'Sin suscripción a novedades',test_payment_approved:'Pago de prueba aprobado',test_payment_declined:'Pago de prueba rechazado',test_payment_cancelled:'Pago de prueba cancelado',fulfillment_preparing:'En preparación',fulfillment_shipped:'Enviado',fulfillment_delivered:'Entregado',return_requested:'Devolución solicitada',return_received:'Prenda recibida',test_refund_completed:'Reembolso de prueba completado',reserve_expired:'Reserva vencida'};
  function readStorage(key, fallback) { try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch { return fallback; } }
  let favorites = readStorage('martha-parity-favorites', []);
  favorites = Array.isArray(favorites) ? favorites.filter(id => typeof id === 'string') : [];
  function saveCheckout() { try { sessionStorage.setItem(sessionKey('checkout'), JSON.stringify(checkout)); } catch { throw new Error('No pudimos guardar el avance de prueba en esta pestaña. No se envió un pedido real.'); } }
  function orderPayload() { return {quote_id:checkout.quote_id,idempotency_key:checkout.order_key,contact:{name:checkout.name,email:checkout.email,phone:checkout.phone},address:{line1:checkout.line1,city:checkout.city,department:checkout.department},newsletter:!!checkout.newsletter}; }
  function rememberOrder(order) { currentOrder=order; checkout.order_id=order.id; sessionStorage.setItem(sessionKey('last-order'),order.id); saveCheckout(); }
  async function api(path,body,method=body===undefined?'GET':'POST') {
    if (!integrationApi) throw new Error(integrationError || 'Modelo no disponible. Las operaciones están bloqueadas.');
    const epoch = integrationEpoch, activeApi = integrationApi; pendingApi++; renderIntegration();
    try { const result = await activeApi(path,body,method); if (epoch !== integrationEpoch) throw new Error('El modelo cambió. Repetí la acción en el modelo seleccionado.'); return result; }
    finally { pendingApi--; renderIntegration(); }
  }
  // Exposed for local diagnostics only; no remote transport is configured here.
  window.marthaStoreApi = api;
  function notify(text) { const toast = $('#toast'); if (!toast) return; toast.textContent = text; toast.classList.add('visible'); clearTimeout(notify.timer); notify.timer = setTimeout(() => toast.classList.remove('visible'), 4000); }
  function productShareData() {
    const id = $('main[data-page="product"]')?.dataset.productId;
    const product = window.DEMO_CATALOG?.products.find(item => item.id === id);
    if (!product) return null;
    // Construct from the catalog identity, never from tracking/order parameters or a canonical tag.
    const url = new URL(`/producto-${encodeURIComponent(product.id)}.html`, location.origin);
    url.searchParams.set('lang', window.MarthaI18n?.language === 'en' ? 'en' : 'es');
    return {title: `${window.MarthaI18n?.translate(product.name) || product.name} · Martha Silva`, url: url.href};
  }
  function productShareControl() {
    const form = $('[data-product-form]');
    if (!form || !productShareData()) return;
    let control = $('[data-product-share-control]');
    if (!control) {
      control = document.createElement('div');
      control.className = 'product-share';
      control.dataset.productShareControl = '';
      control.innerHTML = '<button type="button" class="text-button product-share-button" data-product-share><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true"><path d="M12 16V3m-5 5 5-5 5 5M5 12v8h14v-8"/></svg><span>Compartir producto</span></button><p class="small" data-product-share-status role="status" aria-live="polite" aria-atomic="true"></p><label class="field" data-product-share-manual hidden><span>Enlace del producto</span><input type="text" data-product-share-url readonly translate="no" aria-describedby="product-share-help"><small id="product-share-help">Seleccioná y copiá este enlace para compartirlo.</small></label>';
      form.after(control);
      window.MarthaI18n?.apply(control);
    }
    window.addEventListener('martha:languagechange', () => {
      const input = $('[data-product-share-url]', control);
      if (input.value) input.value = productShareData()?.url || '';
    }, {signal:pageScope.signal});
  }
  async function shareProduct(button) {
    if (button.disabled) return;
    const data = productShareData(), control = button.closest('[data-product-share-control]');
    if (!data || !control) return;
    const status = $('[data-product-share-status]',control), manual = $('[data-product-share-manual]',control);
    status.textContent = ''; manual.hidden = true; button.disabled = true;
    try {
      if (typeof navigator.share === 'function') {
        try {
          // No await/API work before this call: preserve the click's native user activation.
          await navigator.share(data);
          return;
        } catch (error) { if (error?.name === 'AbortError') return; }
      }
      if (!button.isConnected) return;
      try {
        if (typeof navigator.clipboard?.writeText !== 'function') throw new Error('Clipboard unavailable');
        await navigator.clipboard.writeText(data.url);
        if (button.isConnected) status.textContent = 'Enlace copiado. Ya podés compartirlo.';
      } catch {
        if (!button.isConnected) return;
        status.textContent = 'No pudimos copiar el enlace. Copialo manualmente.';
        const input = $('[data-product-share-url]',control);
        input.value = data.url; manual.hidden = false;
        input.focus({preventScroll:true}); input.select();
      }
      if (button.isConnected) window.MarthaI18n?.apply(control);
    } finally { button.disabled = false; }
  }
  function showError(root, error) { let box = $('[data-error]', root); if (!box) { box = document.createElement('p'); box.className = 'error'; box.setAttribute('data-error',''); box.setAttribute('role','alert'); root.prepend(box); } box.textContent = error.message; box.hidden = false; if(!root.closest('[data-product-id]')||$('[data-sticky-buy]')?.hidden!==false)box.scrollIntoView({block:'nearest'}); }
  async function withButton(button, action) { if (button.disabled) return; const root = button.closest('form, dialog, [data-product-id], [data-checkout-root], [data-order-root], [data-admin-root], main') || document.body; $('[data-error]',root)?.setAttribute('hidden',''); button.disabled = true; busyActions++; renderIntegration(); if(button.matches('[data-add]')) {productAdding=true;syncProduct();} try { await action(); } catch (error) { showError(root, error); } finally { busyActions--; renderIntegration(); if (button.isConnected) button.disabled = false; if(button.matches('[data-add]')) {productAdding=false;syncProduct();const error=$('[data-product-error]'),sticky=$('[data-sticky-error]');if(error&&sticky){sticky.textContent=error.textContent;sticky.hidden=error.hidden;}} } }
  async function refreshCart() { cart = await api('/api/cart'); $$('[data-bag-count]').forEach(n => n.textContent = cart.lines.reduce((n, line) => n + line.quantity, 0)); if($('#mini-bag')?.open)miniBag(); return cart; }
  function card(p) {
    const saved=favorites.includes(p.id), stock=p.variants.reduce((n,v)=>n+v.stock,0);
    const photo=(src,cls='')=>{const i=p.images.indexOf(src),dimensions=window.STORE_IMAGE_DIMENSIONS?.[p.jpeg_images?.[i] || src] || [900,1200];return `<picture class="${cls}"><source type="image/webp" srcset="${esc(p.image_sets?.[i] || src+' 900w')}" sizes="(max-width:599px) 50vw,25vw"><img class="${cls}" src="${esc(p.jpeg_images?.[i] || src)}" srcset="${esc(p.jpeg_sets?.[i] || src+' 900w')}" sizes="(max-width:599px) 50vw,25vw" width="${dimensions[0]}" height="${dimensions[1]}" alt="${esc(p.name)}" loading="lazy" decoding="async"></picture>`;};
    return `<article class="product-card" data-id="${esc(p.id)}"><a class="product-image" href="/producto-${esc(p.id)}.html">${photo(p.images[0])}${p.images[1]?photo(p.images[1],'secondary-image'):''}${p.video?`<video muted loop playsinline preload="none" data-src="${esc(p.video)}" data-webm="${esc(p.video_webm || '')}"></video>`:''}</a><button class="favorite-button" data-favorite="${esc(p.id)}" aria-label="Guardar en favoritos: ${esc(p.name)}" aria-pressed="${saved}"><svg viewBox="0 0 24 24" fill="${saved?'currentColor':'none'}" stroke="currentColor" aria-hidden="true"><path d="M20.8 4.6c-2-2-5.2-1.8-7.1.2L12 6.6l-1.7-1.8C8.4 2.8 5.2 2.6 3.2 4.6s-2 5.2 0 7.2L12 21l8.8-9.2c2-2 2-5.2 0-7.2Z"/></svg></button><div class="product-meta"><p class="product-category">MARTHA SILVA</p><h3 class="product-name"><a href="/producto-${esc(p.id)}.html">${esc(p.name)}</a></h3><p class="product-price">${money(p.price_minor)}</p><p class="product-badge">${p.sample_image?'Muestra · ':''}${stock===0?'Agotada':stock===1?'Última unidad':stock<=3?'Pocas unidades':''}</p></div></article>`;
  }
  function updateHearts() {
    $$('[data-favorite]').forEach(b => {
      const saved = favorites.includes(b.dataset.favorite), label = `${saved ? 'Quitar de' : 'Guardar en'} favoritos`;
      b.setAttribute('aria-pressed', String(saved));
      const p = products.find(p => p.id === b.dataset.favorite);
      b.setAttribute('aria-label',`${label}: ${p?.name || 'prenda'}`);
      $('svg',b)?.setAttribute('fill',saved ? 'currentColor':'none');
      const text = document.createTreeWalker(b, NodeFilter.SHOW_TEXT);
      let node;
      while ((node = text.nextNode())) {
        if (!node.parentElement.closest('svg')) node.textContent = (window.MarthaI18n?.originalText(node) ?? node.textContent).replace(/(?:Guardar en|Quitar de) favoritos/g, label);
      }
    });
  }
  function catalog() {
    const form = $('#catalog-filters'); if (!form) return;
    const params = new URLSearchParams(location.search);
    for (const key of ['q','category','size','color','sort']) if (form.elements[key]) form.elements[key].value = params.get(key) || (key === 'sort' ? 'selection' : '');
    const query = (params.get('q') || '').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
    let matches = products.filter(p => {
      const original = `${p.name} ${p.category} ${p.color} ${p.description}`;
      const translated = window.MarthaI18n ? [p.name,p.category,p.color,p.description].map(window.MarthaI18n.english).join(' ') : '';
      const text = `${original} ${translated}`.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
      return (!query || query.split(/\s+/).every(word => text.includes(word))) && (!params.get('category') || p.category === params.get('category')) && (!params.get('color') || p.color === params.get('color')) && (!params.get('size') || p.variants.some(v => v.size === params.get('size') && v.stock > 0)) && (!params.has('favoritos') || favorites.includes(p.id));
    });
    if (params.get('sort') === 'price-asc') matches.sort((a,b) => a.price_minor-b.price_minor);
    if (params.get('sort') === 'price-desc') matches.sort((a,b) => b.price_minor-a.price_minor);
    $('[data-catalog-grid]').innerHTML = matches.map(card).join('') || '<div class="empty-state"><h2>No encontramos prendas con estos filtros.</h2><p>Probá otra talla, color o colección.</p><button class="button secondary" data-clear-filters>Ver todas las prendas</button></div>';
    $('[data-result-count]').textContent = `${matches.length} ${matches.length === 1 ? 'prenda':'prendas'}${params.has('favoritos') ? ' en favoritos':''}`;
    let chips = $('[data-filter-chips]');
    if (!chips) { chips = document.createElement('div'); chips.className = 'filter-chips'; chips.dataset.filterChips = ''; form.after(chips); }
    $('.catalog-status')?.classList.toggle('has-filters',[...params.keys()].some(k=>!['sort','lang'].includes(k)));
    chips.innerHTML = [...params.entries()].filter(([k]) => !['sort','lang'].includes(k)).map(([key,value]) => `<button class="filter-chip" data-remove-filter="${esc(key)}"><span ${key === 'q' ? 'translate="no"' : ''}>${esc(key === 'favoritos' ? 'Favoritos':value)}</span> <span aria-hidden="true">×</span><span class="sr-only"> Quitar filtro</span></button>`).join('');
  }
  function totals(q, cta = '') { return `<dl class="totals"><div><dt>Subtotal</dt><dd>${money(q.subtotal_minor)}</dd></div>${q.discount_minor ? `<div><dt>Descuento</dt><dd>−${money(q.discount_minor)}</dd></div>`:''}<div><dt>Entrega${q.shipping_minor === undefined ? ' estimada':''}</dt><dd>${q.shipping_minor === undefined ? 'Desde '+money(500):money(q.shipping_minor)}</dd></div><div><dt>Impuestos de prueba</dt><dd>${money(q.tax_minor || 0)}</dd></div><div class="total-row"><dt>Total${q.total_minor === undefined ? ' sin entrega':''}</dt><dd>${money(q.total_minor ?? q.subtotal_minor)}</dd></div></dl>${cta}`; }
  function runningSummary(q, lines, label) {
    return `<details class="running-summary" data-running-summary><summary><span>${esc(lines.map(line => 'Talla '+line.size+' · Cantidad '+line.quantity).join(' / '))}</span><strong><span>${label}</span> ${money(q.total_minor ?? q.subtotal_minor)}</strong></summary><div class="running-summary-content">${lines.map(line => lineView(line)).join('')}${totals(q)}<p class="small muted">Compra de prueba · sin cobros reales.</p></div></details>`;
  }
  function syncProduct() {
    const selected=$('input[name="variant"]:checked');
    const sticky=$('[data-sticky-size]'); if(sticky) sticky.value=selected?.value || '';
    const note=$('[data-stock-note]'),variant=products.flatMap(p=>p.variants).find(v=>v.id===selected?.value);if(note)note.textContent='Stock de muestra · '+(variant?(variant.stock===1?'Última unidad':variant.stock<=2?'Pocas unidades disponibles':'Talla disponible'):'demo');
    const available=$$('input[name="variant"]').some(input=>!input.disabled);
    const ready = !!integrationApi && !integrationError;
    $$('[data-add], [data-sticky-add]').forEach(button=>{button.disabled=!ready||productAdding||!available;button.textContent=available?'Agregar a la bolsa':'Agotada';});
    if(sticky) {sticky.disabled=!available;$$('option',sticky).forEach(option=>{if(option.value)option.disabled=!!$(`input[name="variant"][value="${CSS.escape(option.value)}"]`)?.disabled;});}
  }
  function productBuyBar() {
    productObserver?.disconnect(); productObserver=null;
    const button=$('[data-add]'),bar=$('[data-sticky-buy]');if(!button||!bar)return;
    const update=()=>{const passed=button.getBoundingClientRect().bottom<=0;const visible=matchMedia('(max-width:760px)').matches&&passed;if(!visible&&bar.contains(document.activeElement))button.focus({preventScroll:true});bar.hidden=!visible;};
    productObserver=new IntersectionObserver(update);productObserver.observe(button);
    window.addEventListener('scroll',update,{passive:true,signal:pageScope.signal});
    window.addEventListener('resize',update,{signal:pageScope.signal});syncProduct();update();
  }
  function filterPanel() {
    const panel=$('#filter-panel'),open=$('[data-filters-open]');if(!panel||!open)return;
    panel.addEventListener('close',()=>{open.setAttribute('aria-expanded','false');open.focus({preventScroll:true});},{signal:pageScope.signal});
    panel.addEventListener('keydown',event=>{if(event.key!=='Tab')return;const items=$$('button:not(:disabled),select:not(:disabled),input:not(:disabled)',panel);const first=items[0],last=items.at(-1);if(event.shiftKey&&document.activeElement===first){event.preventDefault();last.focus();}else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first.focus();}},{signal:pageScope.signal});

  }
  function lineView(line, edit = false) { return `<article class="cart-line"><a href="/producto-${esc(line.product_id)}.html"><img src="${esc(line.image)}" alt="${esc(line.name)}" loading="lazy" width="${window.STORE_IMAGE_DIMENSIONS?.[line.image]?.[0] || 900}" height="${window.STORE_IMAGE_DIMENSIONS?.[line.image]?.[1] || 1200}"></a><div><p class="product-category">MARTHA SILVA</p><h3><a href="/producto-${esc(line.product_id)}.html">${esc(line.name)}</a></h3><p>${esc(line.color)} · Talla ${esc(line.size)}</p>${edit ? `<label class="quantity-label">Cantidad <select data-quantity="${esc(line.variant_id)}" aria-label="Cantidad de ${esc(line.name)}, talla ${esc(line.size)}">${Array.from({length:10},(_,i) => `<option value="${i+1}" ${line.quantity === i+1 ? 'selected':''}>${i+1}</option>`).join('')}</select></label><button class="text-button" data-remove-item="${esc(line.variant_id)}" aria-label="Retirar ${esc(line.name)}, talla ${esc(line.size)}">Retirar</button><button class="text-button" data-move-favorite="${esc(line.variant_id)}" data-product="${esc(line.product_id)}" aria-label="Guardar en favoritos ${esc(line.name)}, talla ${esc(line.size)}">Guardar en favoritos</button>`:`<p>Cantidad: ${line.quantity}</p>`}</div><strong>${money(line.line_total_minor)}</strong></article>`; }
  function cartActionFocus(button) {
    const dialog = button.closest('#mini-bag');
    const root = dialog ? $('[data-mini-bag-lines]',dialog) : $('[data-cart-lines]');
    const index = root ? $$('[data-remove-item]',root).indexOf($('[data-remove-item]',button.closest('.cart-line'))) : -1;
    return () => {
      if (!root?.isConnected || (dialog && !dialog.open)) return;
      const remaining = $$('[data-remove-item]',root);
      const next = remaining[Math.max(0,Math.min(index,remaining.length-1))] || $('.empty-state a',root) || $('[data-close-dialog]',dialog || root);
      next?.focus({preventScroll:true});
    };
  }
  function renderCart() {
    const mount = $('[data-cart-lines]'); if (!mount) return;
    if (!cart.lines.length) { $('[data-cart-running]')?.remove(); mount.innerHTML = '<div class="empty-state"><h2>Tu bolsa está vacía.</h2><p>Explorá vestidos de fiesta, novias y moda femenina.</p><a class="button" href="/catalogo.html">Ver la colección</a></div>'; $('[data-cart-summary]').innerHTML=''; return; }
    mount.innerHTML = cart.lines.map(line => lineView(line,true)).join('');
    $('[data-cart-running]')?.remove(); const running=document.createElement('div');running.dataset.cartRunning='';running.innerHTML=runningSummary(cart,cart.lines,'Total sin entrega');$('.commerce-grid',mount.closest('section')).before(running);
    $('[data-cart-summary]').innerHTML = `<div class="order-summary"><h2>Resumen de compra</h2><p class="summary-selection">${esc(cart.lines.map(line => "Talla "+line.size+" - Cantidad "+line.quantity).join(" / "))}</p>${totals(cart, '<a class="button full" href="/checkout.html">Continuar con la compra</a>')}<p class="small muted">Elegí tu zona de entrega para conocer el total completo antes del pago.</p><p class="small">Compra de prueba. Precios, tallas y stock de muestra.</p></div>`;
  }
  function field(name,label,type='text',options={}) { return `<label class="field ${options.full ? 'full':''}"><span>${label}</span><input name="${name}" type="${type}" value="${esc(checkout[name] || '')}" ${options.required === false ? '' : 'required'} maxlength="${options.max || 200}" autocomplete="${options.auto || 'off'}" ${options.placeholder ? `placeholder="${esc(options.placeholder)}"`:''}>${options.help ? `<small>${options.help}</small>`:''}</label>`; }
  function renderCheckout(step = 'contact', focusStep = false) {
    const mount = $('[data-checkout-root]'); if (!mount) return;
    if (!cart.lines.length && !checkout.order_id && checkout.quote_id && checkout.order_key) { mount.innerHTML = '<div class="empty-state"><h2>Revisá tu pedido de prueba anterior.</h2><p>Podés recuperar su resultado en este mismo modelo. No se crea una compra real ni se cambia de sistema.</p><button class="button" data-recover-order>Recuperar pedido de prueba</button><p class="error" data-error role="alert" hidden></p></div>'; return; }
    if (!cart.lines.length) { mount.innerHTML = checkout.order_id ? `<div class="empty-state"><h2>Tu pedido de prueba ya fue creado.</h2><a class="button" href="/pedido.html?id=${encodeURIComponent(checkout.order_id)}">Continuar con tu pedido</a></div>` : '<div class="empty-state"><h2>Agregá una prenda para continuar.</h2><a class="button" href="/catalogo.html">Ver la colección</a></div>'; return; }
    const stages = ['contact','delivery','review','payment'];
    let content = '';
    if (step === 'contact') content = `<h2>Contacto</h2><p class="notice">Usá datos ficticios. Esta demo guarda la información solo en este navegador; no envía pedidos ni cobra.</p><form data-checkout-form="contact" novalidate><div class="form-grid">${field('name','Nombre y apellido','text',{auto:'name',full:true})}${field('email','Email','email',{auto:'email',full:true,help:'Para identificar tu pedido. Esta prueba no envía correos.'})}${field('phone','Teléfono','tel',{auto:'tel',full:true,help:'Para coordinar la entrega cuando la tienda esté activa.'})}</div><label class="check-label"><input name="newsletter" type="checkbox" ${checkout.newsletter ? 'checked':''}>Quiero recibir novedades de Martha Silva (opcional).</label><p data-error class="error" role="alert" hidden></p><button class="button full">Continuar con la entrega</button></form>`;
    if (step === 'delivery') content = `<button class="text-button" data-checkout-back="contact">← Editar contacto</button><h2>Dirección de entrega</h2><form data-checkout-form="delivery" novalidate><div class="form-grid">${field('line1','Dirección','text',{auto:'street-address',full:true})}${field('city','Ciudad','text',{auto:'address-level2'})}${field('department','Departamento','text',{auto:'address-level1'})}<label class="field full"><span>Zona de entrega de prueba</span><select name="delivery_zone" required><option value="managua" ${checkout.delivery_zone === 'resto' ? '':'selected'}>Managua - ${money(500)}</option><option value="resto" ${checkout.delivery_zone === 'resto' ? 'selected':''}>Resto de Nicaragua - ${money(800)}</option></select><small>Tarifas de muestra. La cobertura comercial está pendiente.</small></label>${field('coupon','Código de descuento','text',{required:false,full:true,help:'Código de prueba opcional: PRUEBA10.'})}</div><p data-error class="error" role="alert" hidden></p><button class="button full">Revisar la compra</button></form>`;
    if (step === 'review') content = `<button class="text-button" data-checkout-back="delivery">← Editar entrega</button><h2>Revisá tu compra</h2><div class="review-block"><h3>Contacto</h3><p translate="no">${esc(checkout.name)}<br>${esc(checkout.email)}<br>${esc(checkout.phone)}</p><h3>Entrega</h3><p translate="no">${esc(checkout.line1)}<br>${esc(checkout.city)}, ${esc(checkout.department)}</p></div><p>Todos los importes son de prueba. No se cobra dinero ni se envían prendas.</p><p data-error class="error" role="alert" hidden></p><button class="button full" data-create-order>Continuar al pago de prueba</button>`;
    if (step === 'payment') content = `<h2>Pago de prueba</h2><p>Este simulador guarda el resultado en tu pedido. No utiliza tarjetas ni una pasarela bancaria.</p><p class="notice">No se cobra dinero.</p><p data-error class="error" role="alert" hidden></p><button class="button full" data-test-payment="approved">Aprobar pago de prueba</button><div class="test-options"><button class="text-button" data-test-payment="declined">Probar pago rechazado</button><button class="text-button" data-test-payment="cancelled">Cancelar pedido</button></div>`;
    mount.innerHTML = `<ol class="steps" aria-label="Pasos de compra">${stages.map((s,i) => `<li class="${i<stages.indexOf(step)?'complete':''}" ${s === step ? 'aria-current="step"':''}>${i+1}. ${['Contacto','Entrega','Revisión','Pago'][i]}</li>`).join('')}</ol>${runningSummary(quote || cart,cart.lines,quote ? 'Total':'Total sin entrega')}<div class="commerce-grid"><section class="checkout-panel" aria-labelledby="checkout-stage-title">${content}</section><aside class="order-summary checkout-summary" data-checkout-step="${step}"><h2>Tu selección</h2>${cart.lines.map(line => lineView(line)).join('')}${totals(quote || cart)}<footer class="checkout-summary-footer"><div><h3>Compra de prueba</h3><p>USD · precios, tallas y stock de muestra.</p><p>Pago simulado. No se cobra dinero ni se envían prendas.</p><a href="/ayuda.html" data-barba-prevent>Entrega y devoluciones</a></div></footer></aside></div>`;
    const title = $('.checkout-panel h2',mount);
    title.id = 'checkout-stage-title';
    if (focusStep) { title.tabIndex = -1; title.focus({preventScroll:true}); }
    $('.checkout-panel',mount).scrollIntoView({block:'nearest'});
  }
  function returnItems(order, ret) { return '<ul class="return-items">'+ret.lines.map(line=>{const item=order.lines.find(item=>item.variant_id===line.variant_id); return '<li>'+esc(item?.name || line.variant_id)+' · Talla '+esc(item?.size)+' · Cantidad: '+line.quantity+'</li>';}).join('')+'</ul>'; }
  function orderView(order, admin = false) {
    const refunded = order.refunded_minor || 0;
    return `<div class="order-heading"><div><p class="eyebrow">PEDIDO ${esc(order.code)}</p><h2>${statusLabel[order.status] || esc(order.status)}</h2></div><span class="status-chip">${statusLabel[order.payment_status] || esc(order.payment_status)}</span></div><p class="notice">Pedido de prueba guardado. No confirma un cobro ni una entrega real.</p><div class="commerce-grid"><section>${order.lines.map(line => lineView(line)).join('')}<div class="review-block"><h3>Entrega</h3><p translate="no">${esc(order.contact.name)}<br>${esc(order.address.line1)}<br>${esc(order.address.city)}, ${esc(order.address.department)}</p>${order.tracking ? `<p>Seguimiento: <span translate="no"><span translate="no">${esc(order.tracking)}</span></span></p>`:''}</div><h3>Estado del pedido</h3><ol class="timeline">${order.events.map(event => `<li><span>${esc(new Date(event.at).toLocaleString(locale()))}</span> ${esc(statusLabel[event.type] || event.type)}</li>`).join('')}</ol></section><aside class="order-summary"><h3>Resumen de compra</h3>${totals(order)}${refunded ? `<p>Reembolsado en prueba: ${money(refunded)}</p>`:''}<p class="small muted" translate="no">${esc(order.contact.email)}</p></aside></div>${(order.returns || []).map(r => `<div class="return-card"><h3>Devolución ${esc(r.id.slice(0,8))}</h3>${returnItems(order,r)}<p><span translate="no">${esc(r.reason)}</span> · ${statusLabel[r.status] || esc(r.status)}</p>${admin && r.status === 'requested' ? `<button class="button secondary" data-receive-return="${esc(r.id)}" data-order="${esc(order.id)}">Registrar recepción</button>`:''}${admin && r.status === 'received' ? `<label class="check-label"><input type="checkbox" data-restock="${esc(r.id)}">Prenda revisada: devolver al inventario de prueba</label><button class="button secondary" data-refund="${esc(r.id)}" data-order="${esc(order.id)}">Procesar reembolso de prueba</button>`:''}</div>`).join('')}`;
  }
  async function renderOrder() {
    const mount = $('[data-order-root]'); if (!mount) return;
    const id = new URLSearchParams(location.search).get('id') || sessionStorage.getItem(sessionKey('last-order'));
    if (!id) { mount.innerHTML='<div class="empty-state"><h2>No seleccionaste un pedido.</h2><a class="button" href="/catalogo.html">Ver la colección</a></div>'; return; }
    try {
      currentOrder = (await api(`/api/orders/${encodeURIComponent(id)}`)).order;
      let action = '';
      if (currentOrder.status === 'pending_payment') action = `<h3>Completá el pago de prueba</h3><button class="button" data-test-payment="approved">Aprobar pago de prueba</button><button class="text-button" data-test-payment="cancelled">Cancelar pedido</button>`;
      if (['declined','cancelled'].includes(currentOrder.status)) action = '<p>La reserva se liberó. Podés volver a agregar las prendas disponibles.</p><button class="button" data-rebuild-order>Volver a agregar las prendas</button>';
      if (['delivered','partially_refunded'].includes(currentOrder.status)) {
        const returned = new Map(); for (const r of currentOrder.returns || []) for (const line of r.lines) returned.set(line.variant_id,(returned.get(line.variant_id)||0)+line.quantity);
        const eligible = currentOrder.lines.filter(line => line.quantity > (returned.get(line.variant_id)||0));
        if (eligible.length) action = `<details class="return-form"><summary>Solicitar una devolución de prueba</summary><form data-return-form><p>Seleccioná las prendas que querés devolver.</p>${eligible.map(line => `<label class="field"><span>${esc(line.name)} · ${esc(line.size)}</span><select name="return:${esc(line.variant_id)}"><option value="0">No devolver</option>${Array.from({length:line.quantity-(returned.get(line.variant_id)||0)},(_,i) => `<option value="${i+1}">${i+1} ${i===0?'prenda':'prendas'}</option>`).join('')}</select></label>`).join('')}<label class="field"><span>Motivo</span><textarea name="reason" required maxlength="500"></textarea></label><p data-error class="error" role="alert" hidden></p><button class="button secondary">Enviar solicitud de prueba</button></form></details>`;
      }
      mount.innerHTML=orderView(currentOrder)+`<section class="order-actions">${action}</section><a class="text-button" href="/catalogo.html">Seguir explorando la colección</a>`;
    } catch (error) { mount.innerHTML='<h2>No pudimos abrir ese pedido.</h2><p>Usá el navegador con el que hiciste la compra de prueba.</p><a href="/catalogo.html" class="button">Ver la colección</a>'; showError(mount,error); }
  }
  async function renderAdmin() {
    const mount = $('[data-admin-root]'); if (!mount) return;
    if (!(await api('/api/admin/session')).authenticated) { mount.innerHTML='<section class="admin-login checkout-panel"><h2>Acceso a administración</h2><p>Vista previa local sin autenticación real. No ingresés contraseñas personales. Usá demo para entrar.</p><form data-admin-login><input name="password" type="hidden" value="demo"><p data-error class="error" role="alert" hidden></p><button class="button full">Abrir administración de demo</button></form></section>'; return; }
    [adminOrders,inventory] = await Promise.all([api('/api/admin/orders').then(r => r.orders),api('/api/admin/inventory').then(r => r.variants)]);
    mount.innerHTML = `<div class="admin-toolbar"><h2>Pedidos e inventario</h2><button class="text-button" data-admin-refresh>Actualizar</button><button class="text-button" data-admin-logout>Cerrar sesión</button></div><p class="notice">Demo de prueba. Los cambios se guardan solo en este navegador. No es un inventario de producción ni está sincronizado con la tienda original.</p><nav class="admin-tabs"><a href="#admin-orders">Pedidos (${adminOrders.length})</a><a href="#admin-stock">Inventario</a></nav><section id="admin-orders"><h2>Pedidos</h2>${adminOrders.length ? adminOrders.map(order => `<details class="admin-order"><summary>${esc(order.code)} · ${statusLabel[order.status] || esc(order.status)} · ${money(order.total_minor)}</summary><div>${orderView(order,true)}${['paid','preparing','shipped'].includes(order.status) ? `<form data-fulfillment="${esc(order.id)}"><input type="hidden" name="status" value="${({paid:'preparing',preparing:'shipped',shipped:'delivered'})[order.status]}">${order.status === 'preparing' ? '<label class="field"><span>Número de seguimiento</span><input name="tracking" required maxlength="120"></label>':''}<p data-error class="error" role="alert" hidden></p><button class="button secondary">${({paid:'Preparar pedido',preparing:'Registrar envío',shipped:'Registrar entrega'})[order.status]}</button></form>`:''}</div></details>`).join(''):'<p>No hay pedidos todavía.</p>'}</section><section id="admin-stock"><h2>Inventario por talla</h2><div class="inventory-table"><table><thead><tr><th>Prenda / talla</th><th>Físico</th><th>Reservado</th><th>Disponible</th><th>Ajustar</th></tr></thead><tbody>${inventory.map(v => `<tr><th>${esc(v.name)} · ${esc(v.size)}</th><td>${v.stock}</td><td>${v.reserved}</td><td>${v.available}</td><td><form data-stock="${esc(v.id)}"><label class="sr-only" for="stock-${esc(v.id)}">Nuevo stock de ${esc(v.name)} ${esc(v.size)}</label><input id="stock-${esc(v.id)}" name="quantity" type="number" min="${v.reserved}" max="100000" required value="${v.stock}" aria-label="Nuevo stock ${esc(v.name)} ${esc(v.size)}"><input name="reason" placeholder="Motivo del ajuste" aria-label="Motivo del ajuste ${esc(v.name)} ${esc(v.size)}" required maxlength="200"><button class="button secondary">Guardar</button><p data-error class="error" role="alert" hidden></p></form></td></tr>`).join('')}</tbody></table></div></section>`;
  }
  function stopMotion() { if (raf) cancelAnimationFrame(raf); raf=null; lenis?.destroy(); lenis=null; }
  let mediaObserver;
  const allowVideo = () => !matchMedia('(prefers-reduced-motion: reduce)').matches && !navigator.connection?.saveData;
  function loadVideoSource(video) {
    if (!video.getAttribute('src') && video.dataset.src) video.src = video.dataset.webm && video.canPlayType('video/webm') ? video.dataset.webm : video.dataset.src;
  }
  function playVideo(video) {
    if (!allowVideo() || document.hidden) return;
    loadVideoSource(video);
    video.play().then(()=>video.classList.add('is-playing')).catch(()=>{});
  }
  function videoMotion() {
    mediaObserver?.disconnect();
    $$('video').forEach(video=>{video.pause();video.classList.remove('is-playing');});
    const manual = $$('.gallery-video video[controls][data-src]');
    if (!manual.length) return;
    mediaObserver = new IntersectionObserver(entries=>entries.forEach(entry=>{
      if (entry.isIntersecting) {
        if (entry.target.controls) loadVideoSource(entry.target);
      } else entry.target.pause();
    }), {threshold:.55});
    manual.forEach(video=>mediaObserver.observe(video));
  }
  function motion() {
    stopMotion(); videoMotion(); if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    if(window.gsap) gsap.from($$('[data-intro]'),{opacity:0,duration:.2,clearProps:'all'});
  }
  function openDialog(dialog, trigger=document.activeElement) {
    if(!dialog || dialog.open)return;
    dialog.returnFocus=trigger; dialog.showModal();
    dialog.addEventListener('close',()=>{if(dialog.id==='newsletter-dialog')localStorage.setItem('martha-parity-newsletter-dismissed','true');trigger?.setAttribute('aria-expanded','false');if(trigger?.isConnected)trigger.focus({preventScroll:true});},{once:true});
  }
  function miniBag(trigger) {
    const dialog=$('#mini-bag'); if(!dialog || !cart || (!dialog.open && !trigger))return;
    const active=dialog.contains(document.activeElement) ? document.activeElement : null;
    const control=['quantity','removeItem','moveFavorite'].find(key=>active?.dataset[key]);
    const variant=control ? active.dataset[control] : null;
    const hasLines=cart.lines.length>0;
    $('#mini-bag-title',dialog).textContent=hasLines?'Agregada a tu bolsa':'Bolsa vacía';
    $('[data-mini-bag-lines]').innerHTML=hasLines?cart.lines.map(line=>lineView(line,true)).join(''):'<p class="notice">No quedan prendas en tu bolsa. Seguí explorando la colección.</p><a class="text-link" href="/catalogo.html">Ver la colección</a>';
    const total=$('[data-mini-bag-total]');total.innerHTML=hasLines?totals(cart):'';total.hidden=!hasLines;
    const checkout=$$('a[href]',dialog).find(link=>{const url=new URL(link.href,location.href);return url.origin===location.origin&&url.pathname==='/checkout.html';});
    if(checkout){checkout.hidden=!hasLines;if(hasLines)checkout.removeAttribute('aria-disabled');else checkout.setAttribute('aria-disabled','true');}
    if(!dialog.open)openDialog(dialog,trigger);
    if(control) {const next=$$('select,button',dialog).find(el=>el.dataset[control]===variant);(next || $('[data-close-dialog]',dialog))?.focus({preventScroll:true});}
  }
  function gallery() {
    const track=$('[data-gallery-track]'),viewport=$('[data-gallery-viewport]');if(!track||!viewport)return;
    let index=0;const slides=$$('.gallery-photo,.gallery-video',track),mobile=()=>matchMedia('(max-width:1023px)').matches;
    const mark=()=>$$('[data-gallery-go]').forEach(b=>b.setAttribute('aria-current',String(Number(b.dataset.galleryGo)===index)));
    const go=n=>{index=(n+slides.length)%slides.length;mark();if(mobile())viewport.scrollTo({left:slides[index].offsetLeft,behavior:reduced.matches?'instant':'smooth'});else slides[index].scrollIntoView({block:'nearest',behavior:reduced.matches?'instant':'smooth'});};
    if(mobile())viewport.scrollLeft=slides[0].offsetLeft;
    document.addEventListener('click',e=>{const b=e.target.closest('[data-gallery-go],[data-gallery-prev],[data-gallery-next]');if(!b)return;go(b.hasAttribute('data-gallery-go')?Number(b.dataset.galleryGo):index+(b.hasAttribute('data-gallery-next')?1:-1));},{signal:pageScope.signal});
    let galleryFrame=0; viewport.addEventListener('scroll',()=>{if(!mobile()||galleryFrame)return;galleryFrame=requestAnimationFrame(()=>{galleryFrame=0;const width=slides[0].offsetWidth;if(!width)return;const next=(Math.round((viewport.scrollLeft-slides[0].offsetLeft)/width)+slides.length)%slides.length;if(next!==index){index=next;mark();}});},{passive:true,signal:pageScope.signal});pageScope.signal.addEventListener('abort',()=>cancelAnimationFrame(galleryFrame),{once:true});
    viewport.addEventListener('scrollend',()=>{if(mobile()&&viewport.scrollLeft<slides[0].offsetLeft-1)viewport.scrollTo({left:slides[index].offsetLeft,behavior:'instant'});},{signal:pageScope.signal});
  }
  function validate(form) {
    let first;
    $$('input,select,textarea',form).forEach(input=>{
      let error=input.parentElement.querySelector('.field-error');
      if(!error){error=document.createElement('small');error.className='field-error';error.id='error-'+input.name;input.after(error);}
      const invalid=!input.validity.valid || (input.required&&!input.value.trim());
      input.setAttribute('aria-invalid',String(invalid));input.setAttribute('aria-describedby',error.id);
      error.textContent=invalid?(input.validity.typeMismatch?'Ingresá un email válido.':'Completá este campo.'):'';error.hidden=!invalid;
      if(invalid&&!first)first=input;
    });
    first?.focus();return !first;
  }
  async function mountPage(focus = false) {
    mountJobs++; renderIntegration();
    pageScope?.abort(); productObserver?.disconnect(); productObserver=null; pageScope = new AbortController(); stopMotion();
    const page = $('main')?.dataset.page;
    if (page === 'product') productShareControl();
    try {
      if (!products.length || ['catalog','product'].includes(page)) products=(await api('/api/catalog')).products.map(p=>({...p,...window.STORE_MEDIA?.[p.id]}));
      await refreshCart(); updateHearts();
      if (page === 'catalog') {catalog();filterPanel();}
      if (page === 'cart') renderCart();
      if (page === 'checkout') {
        quote=null;
        // Page mounts never create an order. Only the explicit review action may do so.
        renderCheckout();
      }
      if (page === 'order') await renderOrder();
      if (page === 'admin') await renderAdmin();
      if (page === 'product') {
        const p = products.find(p => p.id === $('[data-product-id]')?.dataset.productId);
        if (p) $$('input[name="variant"]').forEach(input => {const v=p.variants.find(v => v.id === input.value); input.disabled=!v || v.stock <= 0; const label=input.closest('label');label?.classList.toggle('unavailable',input.disabled);if(label&&v){label.dataset.stock=v.stock;$('small',label).textContent=v.coming_soon&&v.stock<=0?'Próximamente':v.stock<=0?'Agotada':v.stock===1?'Última unidad':v.stock===2?'Pocas unidades':'';}});
      }
      if (page === 'product') {productBuyBar();gallery();syncProduct();}
      motion(); if (focus) $('main')?.focus({preventScroll:true});
    } catch (error) { integrationError = error.message; renderIntegration(); blockCommerce(); showError($('main')||document.body,error); }
    finally { mountJobs--; renderIntegration(); }
    const position = page === 'catalog' ? sessionStorage.getItem('martha-parity-catalog-scroll:'+location.search) : null;
    if (focus && position) window.scrollTo(0,Number(position));
  }
  document.addEventListener('click', async event => {
    const b = event.target.closest('button,a'); if (!b) return;
    if (b.matches('[data-product-share]')) { await shareProduct(b); return; }
    if (b.matches('[data-integration-mode]')) { await switchIntegration(b.dataset.integrationMode); return; }
    if (b.matches('[data-integration-retry]')) { if (!pendingApi && !busyActions && !mountJobs && !modeSwitching) { $$('[data-error]').forEach(element => element.hidden = true); createIntegration(); await mountPage(); } return; }
    if (modeSwitching) { event.preventDefault(); return; }
    if(b.matches('[data-menu-toggle]')){b.setAttribute('aria-expanded','true');openDialog($('#mobile-menu'),b);return;}
    if (b.matches('[data-filters-open]')) {openDialog($('#filter-panel'),b);b.setAttribute('aria-expanded','true');$('[data-filters-close]').focus();return;}
    if (b.matches('[data-filters-close], [data-filters-apply]')) {$('#filter-panel').close();return;}
    if(b.matches('[data-location]')){openDialog($('#location-dialog'),b);return;}
    if(b.matches('[data-size-guide]')){openDialog($('#size-guide'),b);return;}
    if(b.matches('[data-filter-reset]')){const params=new URLSearchParams(location.search);for(const name of ['q','category','size','color','favoritos'])params.delete(name);setCatalogParams(params);catalog();return;}
    if(b.matches('[data-sort-toggle]')){const open=b.getAttribute('aria-expanded')!=='true';b.setAttribute('aria-expanded',String(open));$('#sort-options').hidden=!open;if(open)$('[data-sort]')?.focus();return;}
    if(b.matches('[data-sort]')){const params=new URLSearchParams(location.search);params.set('sort',b.dataset.sort);setCatalogParams(params);$('#sort-options').hidden=true;$('[data-sort-toggle]').setAttribute('aria-expanded','false');$('[data-sort-toggle]').focus();catalog();return;}
    if(b.matches('[data-carousel-prev],[data-carousel-next]')){const root=b.closest('.carousel-section,.carousel-wrap'),track=$('[data-carousel]',root);track?.scrollBy({left:(b.hasAttribute('data-carousel-next')?1:-1)*track.clientWidth,behavior:reduced.matches?'instant':'smooth'});return;}
    if (b.matches('[data-search-open]')) { openDialog($('#search-dialog'),b); $('#search-dialog input')?.focus(); return; }
    if (b.matches('[data-close-dialog]')) { const dialog=b.closest('dialog');if(dialog?.id==='newsletter-dialog')localStorage.setItem('martha-parity-newsletter-dismissed','true');dialog?.close(); return; }
    if (b.matches('[data-zoom]')) { $('#image-dialog img').src=b.dataset.zoom || $('img',b)?.src; $('#image-dialog img').alt=window.MarthaI18n?.originalAttribute($('img',b),'alt') || $('img',b)?.alt || 'Fotografía ampliada'; openDialog($('#image-dialog'),b); return; }
    if (b.matches('[data-favorite]')) { const id=b.dataset.favorite; favorites=favorites.includes(id) ? favorites.filter(n=>n!==id):[...favorites,id]; localStorage.setItem('martha-parity-favorites',JSON.stringify(favorites)); updateHearts(); if (new URLSearchParams(location.search).has('favoritos')) catalog(); notify(favorites.includes(id)?'Prenda guardada en favoritos.':'Prenda retirada de favoritos.'); return; }
    if (b.matches('[data-clear-filters], [data-remove-filter]')) { event.preventDefault(); const params = new URLSearchParams(location.search); if (b.matches('[data-clear-filters]')) [...params.keys()].filter(k=>k!=='lang').forEach(k=>params.delete(k)); else params.delete(b.dataset.removeFilter); setCatalogParams(params); catalog(); return; }
    if (b.matches('[data-sticky-add]')) { const main=$('[data-add]');if(main&&!main.disabled)main.click();return; }
    if (b.matches('[data-add]')) { await withButton(b,async()=>{ const input=$('input[name="variant"]:checked:not(:disabled)'); if (!input) throw new Error('Elegí una talla para agregar esta prenda.'); cart=await api('/api/cart/items',{variant_id:input.value,quantity:1}); await refreshCart(); const note=$('[data-add-confirmation]'); if (note) { note.innerHTML=`Prenda agregada a tu bolsa. <a href="/bolsa.html">Ver bolsa</a>`; note.hidden=false; } notify('Prenda agregada a tu bolsa.');miniBag(b); }); return; }
    if(b.matches('[data-move-favorite]')){const focus=cartActionFocus(b);await withButton(b,async()=>{if(!favorites.includes(b.dataset.product))favorites.push(b.dataset.product);localStorage.setItem('martha-parity-favorites',JSON.stringify(favorites));cart=await api('/api/cart/items',{variant_id:b.dataset.moveFavorite,quantity:0},'PATCH');await refreshCart();renderCart();if($('#mini-bag')?.open)miniBag();updateHearts();focus();notify('Prenda guardada en favoritos y retirada de tu bolsa.');});return;}
    if (b.matches('[data-remove-item]')) { const focus=cartActionFocus(b);await withButton(b,async()=>{cart=await api('/api/cart/items',{variant_id:b.dataset.removeItem,quantity:0},'PATCH'); await refreshCart(); renderCart();if($('#mini-bag')?.open)miniBag();focus();notify('Prenda retirada de tu bolsa.');}); return; }
    if (b.matches('[data-checkout-back]')) { renderCheckout(b.dataset.checkoutBack,true); return; }
    if (b.matches('[data-recover-order]')) { await withButton(b,async()=>{ rememberOrder((await api('/api/orders',orderPayload())).order); renderCheckout(); }); return; }
    if (b.matches('[data-create-order]')) { await withButton(b,async()=>{ checkout.quote_id=quote.id; checkout.order_key ||= uuid(); saveCheckout(); rememberOrder((await api('/api/orders',orderPayload())).order); renderCheckout('payment',true); }); return; }
    if (b.matches('[data-test-payment]')) { await withButton(b,async()=>{ const id=currentOrder?.id || checkout.order_id; if (!id) throw new Error('Revisá tu compra para crear el pedido primero.'); const result=await api(`/api/orders/${encodeURIComponent(id)}/test-payment`,{outcome:b.dataset.testPayment,idempotency_key:checkout.payment_key ||= uuid()}); currentOrder=result.order; sessionStorage.removeItem(sessionKey('checkout')); checkout={}; location.href='/pedido.html?id='+encodeURIComponent(id); }); return; }
    if (b.matches('[data-rebuild-order]')) { await withButton(b,async()=>{ const existing=await refreshCart(); for(const line of currentOrder.lines) {const qty=(existing.lines.find(l=>l.variant_id===line.variant_id)?.quantity || 0)+line.quantity; await api('/api/cart/items',{variant_id:line.variant_id,quantity:qty},'PATCH');} location.href='/bolsa.html';}); return; }
    if (b.matches('[data-admin-refresh]')) { await withButton(b,renderAdmin); return; }
    if (b.matches('[data-admin-logout]')) { await withButton(b,async()=>{await api('/api/admin/logout',{}); await renderAdmin();}); return; }
    if (b.matches('[data-receive-return]')) { await withButton(b,async()=>{await api(`/api/admin/orders/${b.dataset.order}/returns/${b.dataset.receiveReturn}/receive`,{}); await renderAdmin();}); return; }
    if (b.matches('[data-refund]')) { await withButton(b,async()=>{const id=b.dataset.refund; await api(`/api/admin/orders/${b.dataset.order}/refund`,{return_id:id,restock:!!$$('[data-restock]').find(input=>input.dataset.restock===id)?.checked}); await renderAdmin();}); return; }
    if (b.tagName === 'A') { if ($('main')?.dataset.page === 'catalog') sessionStorage.setItem('martha-parity-catalog-scroll:'+location.search,String(window.scrollY)); $('#mobile-menu')?.close(); $('[data-menu-toggle]')?.setAttribute('aria-expanded','false'); if (b.closest('#search-dialog')) $('#search-dialog').close(); }
  });
  document.addEventListener('change',async event=>{
    const el=event.target; if (modeSwitching) return;
    if (el.matches('[data-sticky-size]')) { $$('input[name="variant"]').forEach(input=>input.checked=input.value===el.value&&!input.disabled); }
    if (el.matches('input[name="variant"], [data-sticky-size]')) { syncProduct();$('[data-add-confirmation]')?.setAttribute('hidden','');$('[data-product-error]')?.setAttribute('hidden','');$('[data-sticky-error]')?.setAttribute('hidden',''); }
    if (el.matches('[data-quantity]')) {
      const root=el.closest('dialog') || $('main'),variant=el.dataset.quantity,hadFocus=document.activeElement===el;
      $('[data-error]',root)?.setAttribute('hidden',''); el.disabled=true;
      try { cart=await api('/api/cart/items',{variant_id:variant,quantity:Number(el.value)},'PATCH'); await refreshCart(); renderCart(); }
      catch(error){renderCart();if($('#mini-bag')?.open)miniBag();showError(root,error);}
      finally{el.disabled=false;if(hadFocus&&root.isConnected&&(!root.matches('dialog')||root.open))$$('[data-quantity]',root).find(input=>input.dataset.quantity===variant)?.focus({preventScroll:true});}
    }
    if (el.closest('#catalog-filters')) filterChange();
  });
  let searchTimer;
  document.addEventListener('input',event=>{if (event.target.matches('#catalog-filters input[name="q"]')) { clearTimeout(searchTimer); searchTimer=setTimeout(filterChange,150); }});
  function setCatalogParams(params) { clearTimeout(searchTimer); const url='/catalogo.html'+(params.size?'?'+params.toString():''); if(location.pathname+location.search!==url)history.pushState(null,'',url); }
  window.addEventListener('popstate',()=>{clearTimeout(searchTimer);if($('#catalog-filters'))catalog();});
  window.addEventListener('pageshow',async event=>{
    if (!event.persisted) return;
    let preferred = integrationMode; try { const stored = sessionStorage.getItem(MODE_KEY); if (['savia','sisfain'].includes(stored)) preferred = stored; } catch {}
    // A restored, still-pending action must finish with its existing namespace
    // and in-memory checkout/order. Do not clear data needed after an await.
    if (pendingApi || busyActions || mountJobs || modeSwitching) {
      if (preferred !== integrationMode) { try { sessionStorage.setItem(MODE_KEY,integrationMode); } catch {} notify('La operación pendiente sigue en su modelo original. Podés cambiar al terminar.'); }
      return;
    }
    if (preferred !== integrationMode) { await switchIntegration(preferred); return; }
    loadCheckout(); quote = null; currentOrder = null; products = []; await mountPage();
  });
  function filterChange() { const form=$('#catalog-filters'); if (!form) return; const params=new URLSearchParams(location.search); for (const [key,value] of new FormData(form)) {if (value && !(key === 'sort' && value === 'selection')) params.set(key,value); else params.delete(key);} setCatalogParams(params); catalog(); }
  document.addEventListener('submit',async event=>{
    const form=event.target; if (modeSwitching) { event.preventDefault(); return; }
    if (form.id === 'catalog-filters') {event.preventDefault(); filterChange(); return;}
    if(form.matches('[data-newsletter]')){event.preventDefault();$('.newsletter-result',form).textContent='Tu código de prueba: PRUEBA10. No se envió ningún correo.';localStorage.setItem('martha-parity-newsletter-dismissed','true');return;}
    if (!form.matches('[data-checkout-form], [data-return-form], [data-admin-login], [data-fulfillment], [data-stock]')) return;
    event.preventDefault();if(form.dataset.checkoutForm&&!validate(form))return; const button=$('button[type="submit"],button:not([type])',form); const data=Object.fromEntries(new FormData(form));
    await withButton(button,async()=>{
      if (form.dataset.checkoutForm) {
        Object.assign(checkout,data); if(form.dataset.checkoutForm === 'contact') checkout.newsletter=form.elements.newsletter.checked; saveCheckout();
        if (form.dataset.checkoutForm === 'contact') renderCheckout('delivery',true);
        else {quote=await api('/api/quote',{delivery_zone:checkout.delivery_zone,coupon:checkout.coupon || ''}); checkout.order_key=uuid(); delete checkout.order_id; delete checkout.payment_key; saveCheckout(); renderCheckout('review',true);}
      } else if (form.matches('[data-return-form]')) {
        const lines=Object.entries(data).filter(([key,value])=>key.startsWith('return:')&&Number(value)>0).map(([key,value])=>({variant_id:key.slice(7),quantity:Number(value)}));
        if (!lines.length) throw new Error('Seleccioná al menos una prenda para devolver.');
        await api(`/api/orders/${currentOrder.id}/returns`,{lines,reason:data.reason}); await renderOrder(); notify('Solicitud de devolución de prueba guardada.');
      } else if(form.matches('[data-admin-login]')) {await api('/api/admin/login',{password:data.password}); form.reset(); await renderAdmin();}
      else if(form.dataset.fulfillment) {await api(`/api/admin/orders/${form.dataset.fulfillment}/fulfill`,data); await renderAdmin();}
      else if(form.dataset.stock) {await api('/api/admin/inventory',{variant_id:form.dataset.stock,quantity:Number(data.quantity),reason:data.reason}); await renderAdmin();}
    });
  });
  function syncCampaignViewport() {
    const height = $$('.test-banner, .language-bar, [data-integration-panel], .site-header')
      .reduce((total, element) => total + element.getBoundingClientRect().height, 0);
    document.documentElement.style.setProperty('--store-chrome-height', `${Math.ceil(height)}px`);
    // Only the header stays sticky; banners/language rows scroll away.
    const stickyHeaderHeight = $('.site-header')?.getBoundingClientRect().height || 0;
    document.documentElement.style.setProperty('--store-sticky-header-height', `${Math.ceil(stickyHeaderHeight)}px`);
  }
  window.addEventListener('resize', syncCampaignViewport);
  if (window.ResizeObserver) {
    const chromeObserver = new ResizeObserver(syncCampaignViewport);
    $$('.test-banner, .language-bar, [data-integration-panel], .site-header').forEach(element => chromeObserver.observe(element));
  }
  syncCampaignViewport();
  const reduced = matchMedia('(prefers-reduced-motion: reduce)'); reduced.addEventListener('change',motion);
  if (window.barba && $('[data-barba="container"]')) {
    const editorial = /^\/(?:index|catalogo|producto-[a-z0-9-]+)\.html$|^\/$/;
    barba.init({timeout:4000,preventRunning:true,prevent:({href,el})=>{const url=new URL(href,location.href);return el.hasAttribute('data-barba-prevent')||url.origin!==location.origin||!editorial.test(url.pathname)||!['home','catalog','product'].includes($('main')?.dataset.page);},transitions:[{name:'editorial',async leave(data){stopMotion(); if(window.gsap && !reduced.matches) await gsap.to(data.current.container,{opacity:0,duration:.12});},enter(){window.scrollTo(0,0);},async after(){await mountPage(true);}}]});
  }
  const mega=$('#mega-menu'),trigger=$('[data-mega-trigger]'),header=$('.site-header');
  const toggleMega=open=>{if(!mega)return;mega.hidden=!open;trigger?.setAttribute('aria-expanded',String(open));};
  trigger?.addEventListener('mouseenter',()=>toggleMega(true));trigger?.addEventListener('focus',()=>toggleMega(true));
  header?.addEventListener('mouseleave',()=>toggleMega(false));header?.addEventListener('focusout',e=>{if(!header.contains(e.relatedTarget))toggleMega(false);});
  document.addEventListener('keydown',e=>{const menu=$('#sort-options');if(menu&&!menu.hidden&&['ArrowDown','ArrowUp','Home','End'].includes(e.key)){e.preventDefault();const items=$$('[data-sort]',menu),i=items.indexOf(document.activeElement);items[e.key==='Home'?0:e.key==='End'?items.length-1:(i+(e.key==='ArrowDown'?1:-1)+items.length)%items.length]?.focus();}if(e.key==='Escape'){toggleMega(false);if(menu&&!menu.hidden)$('[data-sort-toggle]')?.focus();menu?.setAttribute('hidden','');$('[data-sort-toggle]')?.setAttribute('aria-expanded','false');}});
  document.addEventListener('pointerover',e=>{const video=e.target.closest('.product-image')?.querySelector('video');if(video&&matchMedia('(hover:hover) and (min-width:1024px)').matches)playVideo(video);});
  document.addEventListener('pointerout',e=>{const image=e.target.closest('.product-image');if(image&&!image.contains(e.relatedTarget))image.querySelector('video')?.pause();});
  document.addEventListener('click',e=>{if(!e.target.closest('.sort-field')){$('#sort-options')?.setAttribute('hidden','');$('[data-sort-toggle]')?.setAttribute('aria-expanded','false');}});
  $$('dialog').forEach(d=>{d.addEventListener('cancel',()=>{if(d.id==='newsletter-dialog')localStorage.setItem('martha-parity-newsletter-dismissed','true');});d.addEventListener('click',e=>{if(e.target===d){const r=d.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom){if(d.id==='newsletter-dialog')localStorage.setItem('martha-parity-newsletter-dismissed','true');d.close();}}});});
  navigator.connection?.addEventListener('change',videoMotion);
  document.addEventListener('visibilitychange',videoMotion);
  mountPage();


})();


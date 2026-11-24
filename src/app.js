/* Storefront logic. Cart, orders and stock are kept in this browser. */
(() => {
  'use strict';
  window.STORE_MEDIA=window.STORE_MEDIA || {};
  // While the next page mounts in the transition window, page queries skip the outgoing page.
  let outgoing = null;
  const live = element => !outgoing || !outgoing.contains(element);
  const $ = (s, root = document) => outgoing && root === document ? [...root.querySelectorAll(s)].find(live) || null : root.querySelector(s);
  const $$ = (s, root = document) => outgoing && root === document ? [...root.querySelectorAll(s)].filter(live) : [...root.querySelectorAll(s)];
  // Motion tokens: read once from the --ms-* custom properties in styles.css; effect code uses only these.
  const MOTION = (() => {
    let css = {getPropertyValue: () => ''};
    try { css = getComputedStyle(document.documentElement); } catch {}
    const raw = name => String(css.getPropertyValue(name) || '').trim();
    const seconds = (name, fallback) => { const v = raw(name), n = parseFloat(v); return Number.isFinite(n) ? (/ms$/.test(v) ? n / 1000 : n) : fallback; };
    const curve = (raw('--ms-ease').match(/cubic-bezier\(([^)]+)\)/)?.[1] || '.22,1,.36,1').split(',').map(Number);
    const at = (a, b, t) => 3 * a * (1 - t) * (1 - t) * t + 3 * b * (1 - t) * t * t + t * t * t;
    const ease = x => { if (x <= 0 || x >= 1) return x; let lo = 0, hi = 1, t = x; for (let i = 0; i < 24 && Math.abs(at(curve[0], curve[2], t) - x) > 1e-5; i++) { at(curve[0], curve[2], t) < x ? lo = t : hi = t; t = (lo + hi) / 2; } return at(curve[1], curve[3], t); };
    return Object.freeze({ease, durS: seconds('--ms-dur-s', .28), durM: seconds('--ms-dur-m', .48), durL: seconds('--ms-dur-l', .64), radius: raw('--ms-radius') || '14px', loaderMax: seconds('--ms-loader-max', 1.6), microFade: seconds('--ms-micro-fade', .2), microSlide: seconds('--ms-micro-slide', .3), microEase: raw('--ms-micro-ease') || 'cubic-bezier(.25,.1,.25,1)'});
  })();
  const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const locale = () => window.MarthaI18n?.language === 'en' ? 'en-US' : 'es-NI';
  const priceFormats = {};
  let currency = 'USD';
  const money = n => (priceFormats[currency] ||= new Intl.NumberFormat('en-US', {style:'currency',currency,currencyDisplay:'narrowSymbol'})).format(Math.abs(n) / 100);
  // Live mode: the build set a hub origin, so prices, stock and orders come from the SAVIA hub.
  const liveStore = !!window.MarthaIntegrations?.live;
  const uuid = () => crypto.randomUUID();
  // Per-entry editorial view state; leaves native scrollRestoration unchanged.
  const viewHistory = (() => {
    const key = '__marthaViewV1', records = new Map(), transitions = new WeakMap();
    const href = () => location.pathname + location.search + location.hash;
    const finite = value => Number.isFinite(Number(value)) ? Math.max(0, Number(value)) : 0;
    const stateObject = () => history.state && typeof history.state === 'object' ? history.state : {};
    const valid = value => value && typeof value.id === 'string' && typeof value.url === 'string' && value.url.startsWith('/') && value.scroll && Number.isFinite(value.scroll.y) && Number.isFinite(value.scroll.x) ? value : null;
    const initial = valid(stateObject()[key]), initialURL = href();
    let active = initial, pending = null, epoch = 0, interaction = 0, job = null, captureFrame = 0;
    let nativeState = {...stateObject()}, pendingInteraction = 0;
    const editorial = () => ['home','catalog','product'].includes(document.querySelector('main')?.dataset.page);
    function fromState(value) { const saved = valid(value); return saved && (records.get(saved.id) || saved); }
    function remember(record, persist = false) {
      if (!record) return;
      records.set(record.id, record);
      if (persist && record.url === href()) {
        const current = valid(stateObject()[key]);
        if (!current || current.id === record.id) {
          try { history.replaceState({...stateObject(),[key]:record},'',location.href); } catch {}
          nativeState = {...stateObject()};
        }
      }
    }
    function snapshot(record) {
      if (!record) return null;
      const containers = [...document.querySelectorAll('main [data-carousel],main [data-gallery-viewport]')].slice(0,24)
        .map((node,index) => {
          const saved={index,left:finite(node.scrollLeft),top:finite(node.scrollTop)};
          if(node.hasAttribute('data-gallery-viewport')){
            const detail={index:null};node.dispatchEvent(new CustomEvent('martha:gallerycapture',{detail}));
            if(Number.isInteger(detail.index) && detail.index>=0)saved.galleryIndex=detail.index;
          }
          return saved;
        });
      return {...record,scroll:{x:finite(window.scrollX),y:finite(window.scrollY)},containers};
    }
    function capture(persist = true) {
      if (!editorial() || !active || active.url !== href() || job) return active;
      active = snapshot(active); remember(active,persist); return active;
    }
    function activate(record = null, fresh = false) {
      if(!editorial()){active=null;return null;}
      let chosen = !fresh && (valid(record) || fromState(stateObject()[key]));
      if (!chosen || chosen.url !== href()) chosen = {id:crypto.randomUUID(),url:href(),scroll:{x:finite(window.scrollX),y:finite(window.scrollY)},containers:[]};
      active = chosen; records.set(active.id,active);
      try { history.replaceState({...stateObject(),[key]:active},'',location.href); } catch {}
      nativeState = {...stateObject()};
      return active;
    }
    function cancel() {
      if (captureFrame) cancelAnimationFrame(captureFrame); captureFrame = 0;
      if (!job) return;
      cancelAnimationFrame(job.frame);cancelAnimationFrame(job.settleFrame);job.resize?.disconnect();
      document.removeEventListener('load',job.onLoad,true);document.removeEventListener('error',job.onLoad,true);job = null;
    }
    function restore(record) {
      cancel();
      if (!editorial() || !valid(record) || record.url !== href() || active?.id !== record.id) return;
      const token = epoch, touched = interaction;
      const work = {frame:0,settleFrame:0,resize:null,onLoad:null,fontsReady:!document.fonts || document.fonts.status!=='loading'}; job = work;
      const apply = () => {
        work.frame = 0;
        if (job !== work || epoch !== token || interaction !== touched || href() !== record.url || active?.id !== record.id) return;
        window.scrollTo({left:finite(record.scroll.x),top:finite(record.scroll.y),behavior:'instant'});
        const containers = [...document.querySelectorAll('main [data-carousel],main [data-gallery-viewport]')];
        let galleriesReady=true;
        for (const saved of record.containers || []) {
          const node = containers[saved.index]; if (!node)continue;
          if(node.hasAttribute('data-gallery-viewport') && Number.isInteger(saved.galleryIndex)){
            const detail={index:saved.galleryIndex,handled:false,ready:false};
            node.dispatchEvent(new CustomEvent('martha:galleryrestore',{detail}));
            if(detail.handled){galleriesReady=galleriesReady && detail.ready;node.scrollTop=finite(saved.top);continue;}
          }
          node.scrollLeft=finite(saved.left);node.scrollTop=finite(saved.top);
        }
        const reached=galleriesReady && Math.abs(window.scrollY-record.scroll.y)<=1 && Math.abs(window.scrollX-record.scroll.x)<=1;
        const pendingImage=[...document.querySelectorAll('main img')].some(img=>!img.complete && img.getBoundingClientRect().top<=window.innerHeight);
        if(reached && work.fontsReady && !pendingImage){
          const height=document.documentElement.scrollHeight;
          cancelAnimationFrame(work.settleFrame);
          work.settleFrame=requestAnimationFrame(()=>{
            if(job===work && epoch===token && interaction===touched && height===document.documentElement.scrollHeight && Math.abs(window.scrollY-record.scroll.y)<=1){cancel();capture(true);}
          });
        }
      };
      const schedule = () => { if (job === work && !work.frame) work.frame=requestAnimationFrame(apply); };
      work.onLoad = event => { if (event.target.matches?.('main img,main video')) schedule(); };
      document.addEventListener('load',work.onLoad,true);document.addEventListener('error',work.onLoad,true);
      if (window.ResizeObserver) { work.resize=new ResizeObserver(schedule); const main=document.querySelector('main');if(main)work.resize.observe(main); }
      // Event-driven and outcome-bounded: keep an unreachable saved target intact until
      // layout makes it reachable, or user interaction/new navigation cancels the job.
      schedule(); document.fonts?.ready?.then(()=>{work.fontsReady=true;schedule();});
    }
    const historyTrigger = data => ['back','forward','popstate'].includes(data?.trigger) || data?.event?.type === 'popstate';
    function begin(data) {
      const traversal=historyTrigger(data);
      if(!traversal)capture(false);cancel();epoch++;
      const record=traversal ? (pending || fromState(data?.event?.state?.[key]) || fromState(stateObject()[key])) : null;
      if (!traversal) pending=null;
      transitions.set(data,{epoch,interaction,traversal,record});
    }
    function shouldFocus(data) {
      const transition=transitions.get(data);
      return !!transition && !transition.traversal && transition.epoch===epoch && transition.interaction===interaction;
    }
    function finish(data) {
      const transition=transitions.get(data);if(!transition || transition.epoch!==epoch)return;
      const record=transition.record;
      activate(record,!transition.traversal);pending=null;
      if(transition.traversal && record && transition.interaction===interaction)restore(record);else capture(true);
    }
    function sameDocument() {
      if (!pending || pending.url!==href() || location.pathname!=='/catalogo.html') return;
      const record=pending;activate(record);restore(record);
    }
    function push(url) {
      capture(true);cancel();epoch++;pending=null;
      const preserved={...stateObject()};
      if (window.barba?.history?.add) window.barba.history.add(url,'barba','push');
      else history.pushState(preserved,'',url);
      const router={...stateObject()};
      active={id:crypto.randomUUID(),url:href(),scroll:{x:finite(window.scrollX),y:finite(window.scrollY)},containers:[]};
      // Keep router-owned and unrelated metadata; only our per-entry record is replaced.
      try { history.replaceState({...preserved,...router,[key]:active},'',location.href); } catch {}
      nativeState = {...stateObject()};
      remember(active);
    }
    function resumeSnapshot() {
      cancel();epoch++;
      return {record:fromState(stateObject()[key]) || active,epoch,interaction};
    }
    function resume(saved) {
      if (!saved || saved.epoch!==epoch)return;
      activate(saved.record);
      if(saved.interaction===interaction)restore(saved.record);else capture(true);
    }
    function initialMount() {
      if(epoch!==0 || href()!==initialURL)return;
      const isHistory=performance.getEntriesByType?.('navigation')?.[0]?.type==='back_forward';
      activate(initial);
      if(isHistory && initial && interaction===0)restore(initial);else capture(true);
    }
    function interacted() { interaction++;cancel(); }
    for (const type of ['pointerdown','touchstart','wheel','keydown']) window.addEventListener(type,interacted,{passive:true,capture:true});
    document.addEventListener('click',event=>{interacted();if(event.target.closest?.('a[href]'))capture(true);},{capture:true});
    window.addEventListener('scroll',()=>{
      if(job || !editorial() || !active || active.url!==href())return;
      // Persist the inexpensive coordinates in memory immediately: native Back can
      // change location before a queued RAF gets to snapshot the outgoing entry.
      active={...active,scroll:{x:finite(window.scrollX),y:finite(window.scrollY)}};remember(active,false);
      if(!captureFrame)captureFrame=requestAnimationFrame(()=>{captureFrame=0;capture(false);});
    },{passive:true});
    window.addEventListener('pagehide',()=>{cancel();capture(true);});
    window.addEventListener('popstate',event=>{
      const target=fromState(event.state?.[key]);
      const same=target && active && target.id===active.id && target.url===active.url;
      if(!same){capture(false);cancel();epoch++;}
      pending=target;pendingInteraction=interaction;
    },{capture:true});
    window.addEventListener('martha:languagechange',()=>{
      if(!editorial() || !active || active.url===href())return;
      const current=valid(stateObject()[key]);
      if(!current || current.id!==active.id)return;
      const before=new URL(active.url,location.href),after=new URL(location.href);
      before.searchParams.delete('lang');after.searchParams.delete('lang');
      if(before.pathname+before.search+before.hash!==after.pathname+after.search+after.hash)return;
      // i18n replaces the URL of this entry, rather than creating a new one.
      cancel();epoch++;pending=null;
      active=snapshot({...active,url:href()});remember(active,true);
    });
    window.addEventListener('hashchange',event=>{
      if(!editorial())return;
      let before,after;try{before=new URL(event.oldURL);after=new URL(event.newURL);}catch{return;}
      if(after.href!==location.href || before.origin!==after.origin || before.pathname+before.search!==after.pathname+after.search)return;
      const saved=fromState(stateObject()[key]), target=saved?.url===href()?saved:null;
      const restoreKnown=target && pending?.id===target.id && pendingInteraction===interaction;
      cancel();epoch++;
      if(target){
        activate(target);pending=null;
        if(restoreKnown)restore(target);else capture(true);
      }else{
        // A native fragment entry may have null state. Carry router/custom fields
        // forward without changing the native entry or adding a second history item.
        try{history.replaceState({...nativeState,...stateObject()},'',location.href);}catch{}
        activate(null,true);pending=null;capture(true);
      }
    });
    // Installation happens before Barba init; keep its original entry snapshot if init rewrites state.
    if(initial)records.set(initial.id,initial);
    return Object.freeze({capture,activate,restore,cancel,begin,finish,shouldFocus,historyTrigger,sameDocument,push,resumeSnapshot,resume,initialMount});
  })();
  window.MarthaViewHistory = viewHistory;

  let products = [], cart = null, pageScope, raf, currentOrder, adminOrders = [], inventory = [], checkout = {}, quote, productObserver, productAdding = false;
  const integrationInstances = new Map();
  let memoryOnlyIntegration = false;
  let integrationMode = liveStore ? 'live' : 'savia', integrationApi, integrationEpoch = 0, pendingApi = 0, busyActions = 0, mountJobs = 0, modeSwitching = false, integrationError = '';
  const sessionKey = name => `martha-${integrationMode}-${name}-v1`;
  function loadCheckout() {
    try { checkout = JSON.parse(sessionStorage.getItem(sessionKey('checkout')) || '{}'); } catch { checkout = {}; }
    if (!checkout || typeof checkout !== 'object' || Array.isArray(checkout)) checkout = {};
  }
  function createIntegration() {
    integrationApi = null;
    try {
      if (!window.MarthaIntegrations || !window.createMarthaStoreApi || !window.STORE_CATALOG) throw new Error('No pudimos cargar la compra. Recargá la página para continuar.');
      let storage; try { storage = localStorage; } catch {}
      const factory = window.MarthaIntegrations.createLocalAdapter, engine = window.createMarthaStoreApi, catalog = window.STORE_CATALOG;
      const cached = integrationInstances.get(integrationMode);
      // Retain memory-only models for this page, including BFCache. Stored
      // models keep their existing reload behavior; reset updates the client.
      if (storage || !cached || cached.factory !== factory || cached.engine !== engine || cached.catalog !== catalog || cached.storage !== storage) {
        const api = liveStore ? window.MarthaIntegrations.createLiveAdapter({catalog,storage}) : factory({mode:integrationMode,catalog,storage,createStoreApi:engine});
        integrationInstances.set(integrationMode, {api,factory,engine,catalog,storage});
      }
      integrationApi = integrationInstances.get(integrationMode).api;
      memoryOnlyIntegration = !storage;
      integrationError = '';
    } catch (error) { integrationError = error.message; }
  }
  function blockCommerce() {
    $$('[data-add], [data-sticky-add], [data-create-order], [data-confirm-payment], [data-quantity], [data-stock] button, [data-fulfillment] button').forEach(button => button.disabled = true);
  }
  createIntegration(); loadCheckout();
  const statusLabel = {pending:'Pago pendiente',pending_payment:'Pago pendiente',paid:'Pago aprobado',declined:'Pago rechazado',cancelled:'Pedido cancelado',preparing:'En preparación',shipped:'Enviado',delivered:'Entregado',partially_refunded:'Reembolso parcial',refunded:'Reembolso completado',requested:'Solicitud recibida',received:'Prenda recibida',order_created:'Pedido creado',newsletter_opt_in:'Novedades seleccionadas',newsletter_not_selected:'Sin suscripción a novedades',payment_approved:'Pago aprobado',payment_declined:'Pago rechazado',payment_cancelled:'Pago cancelado',fulfillment_preparing:'En preparación',fulfillment_shipped:'Enviado',fulfillment_delivered:'Entregado',return_requested:'Devolución solicitada',return_received:'Prenda recibida',refund_completed:'Reembolso completado',reserve_expired:'Reserva vencida',reserved:'Reservado, pago pendiente',expired:'Reserva vencida',payment_review:'Pago en revisión',fulfilling:'En preparación',fulfilled:'Pedido completado'};
  function readStorage(key, fallback) { try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch { return fallback; } }
  let favorites = readStorage('martha-favorites', []);
  favorites = Array.isArray(favorites) ? favorites.filter(id => typeof id === 'string') : [];
  function saveCheckout() { try { sessionStorage.setItem(sessionKey('checkout'), JSON.stringify(checkout)); } catch { throw new Error('No pudimos guardar el avance en esta pestaña.'); } }
  function orderPayload() { return {quote_id:checkout.quote_id,idempotency_key:checkout.order_key,contact:{name:checkout.name,email:checkout.email,phone:checkout.phone},address:{line1:checkout.line1,city:checkout.city,department:checkout.department},newsletter:!!checkout.newsletter}; }
  function rememberOrder(order) { currentOrder=order; checkout.order_id=order.id; sessionStorage.setItem(sessionKey('last-order'),order.id); saveCheckout(); }
  async function api(path,body,method=body===undefined?'GET':'POST') {
    if (!integrationApi) throw new Error(integrationError || 'La compra no está disponible por ahora. Recargá la página.');
    const epoch = integrationEpoch, activeApi = integrationApi; pendingApi++;
    try { const result = await activeApi(path,body,method); if (epoch !== integrationEpoch) throw new Error('Repetí la acción.'); return result; }
    finally { pendingApi--; }
  }
  // Exposed for local diagnostics only; no remote transport is configured here.
  window.marthaStoreApi = api;
  // B3 micro-interactions: feedback for a shopper action only. Transform/opacity, one run per element, none under reduced motion.
  const calm = () => matchMedia('(prefers-reduced-motion: reduce)').matches, pulses = new WeakMap(), addedHold = 1500;
  function pulse(element, peak) {
    if (!element?.animate || calm()) return;
    pulses.get(element)?.cancel();
    pulses.set(element, element.animate([{transform: 'scale(1)'}, {transform: `scale(${peak})`, offset: .4}, {transform: 'scale(1)'}], {duration: MOTION.microSlide * 1000, easing: MOTION.microEase}));
  }
  const checkIcon = '<svg viewBox="0 0 16 16" width="16" height="16" aria-hidden="true" focusable="false" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M3 8.5l3.2 3L13 4.5"/></svg>';
  function markAdded(button) {
    if (!button?.isConnected) return;
    clearTimeout(button.addedTimer);
    if (button.dataset.state !== 'added') { button.style.width = getComputedStyle(button).width; button.dataset.state = 'added'; button.innerHTML = checkIcon + 'Agregada'; }
    button.addedTimer = setTimeout(() => { button.removeAttribute('data-state'); button.style.width = ''; if (button.isConnected) syncProduct(); }, addedHold);
  }
  let bagReady = false;
  function notify(text) { const toast = $('#toast'); if (!toast) return; toast.textContent = text; toast.classList.add('visible'); clearTimeout(notify.timer); notify.timer = setTimeout(() => toast.classList.remove('visible'), 4000); }
  function productShareData() {
    const id = $('main[data-page="product"]')?.dataset.productId;
    const product = window.STORE_CATALOG?.products.find(item => item.id === id);
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
  async function withButton(button, action) { if (button.disabled) return; const root = button.closest('form, dialog, [data-product-id], [data-checkout-root], [data-order-root], [data-admin-root], main') || document.body; $('[data-error]',root)?.setAttribute('hidden',''); button.disabled = true; busyActions++; if(button.matches('[data-add]')) {productAdding=true;syncProduct();} try { await action(); } catch (error) { showError(root, error); } finally { busyActions--; if (button.isConnected) button.disabled = false; if(button.matches('[data-add]')) {productAdding=false;syncProduct();const error=$('[data-product-error]'),sticky=$('[data-sticky-error]');if(error&&sticky){sticky.textContent=error.textContent;sticky.hidden=error.hidden;}} } }
  async function refreshCart() { cart = await api('/api/cart'); const count = cart.lines.reduce((n, line) => n + line.quantity, 0); $$('[data-bag-count]').forEach(n => { const before = Number(n.textContent) || 0; n.textContent = count; if (bagReady && count > before) pulse(n, 1.2); }); bagReady = true; if($('#mini-bag')?.open)miniBag(); return cart; }
  const priceText = p => p.price_minor === null ? 'No disponible' : money(p.price_minor);
  // The live build ships the static prices blank; they appear only once the hub catalog loads.
  function showPrices() {
    if (!liveStore) return;
    $$('.product-price').forEach(element => {
      const id = element.closest('[data-product-card]')?.dataset.productCard || (element.matches('.detail-price') ? $('main')?.dataset.productId : '');
      const product = products.find(item => item.id === id);
      element.textContent = product ? priceText(product) : 'No disponible';
    });
  }
  function card(p) {
    const saved=favorites.includes(p.id), stock=p.variants.reduce((n,v)=>n+v.stock,0);
    const photo=(src,cls='')=>{const i=p.images.indexOf(src),dimensions=window.STORE_IMAGE_DIMENSIONS?.[p.jpeg_images?.[i] || src] || [900,1200];return `<picture class="${cls}">${src.startsWith('/generated-luxury/') && src.endsWith('.png') ? `<source type="image/webp" srcset="${[360,720,dimensions[0]].filter((w,n,a)=>w<=dimensions[0]&&a.indexOf(w)===n).map(w=>esc(src.replace('/generated-luxury/','/responsive-images/').replace(/\.png$/, '-'+w+'.webp'))+' '+w+'w').join(', ')}" sizes="(max-width:599px) 50vw,25vw">` : ''}<source type="${src.endsWith('.png') ? 'image/png' : 'image/webp'}" srcset="${esc(p.image_sets?.[i] || src+' 900w')}" sizes="(max-width:599px) 50vw,25vw"><img class="${cls}" src="${esc(p.jpeg_images?.[i] || src)}" srcset="${esc(p.jpeg_sets?.[i] || src+' 900w')}" sizes="(max-width:599px) 50vw,25vw" width="${dimensions[0]}" height="${dimensions[1]}" alt="${esc(p.name)}${src.startsWith('/generated-luxury/') ? ' · Vista completa' : ''}" loading="lazy" decoding="async"></picture>`;};
    const sizes=p.variants.map(v=>`<button type="button" data-quick-size="${esc(v.id)}"${v.stock>0?'':` disabled aria-label="Talla ${esc(v.size)} agotada"`}>${esc(v.size)}</button>`).join('');
    return `<article class="product-card plp-card" data-id="${esc(p.id)}"><div class="plp-media"><a href="/producto-${esc(p.id)}.html" tabindex="-1" aria-hidden="true">${photo(p.images[0],'plp-a'+(p.images[1]?' has-b':''))}${p.images[1]?photo(p.images[1],'plp-b'):''}</a>${stock===0?'<p class="plp-sold">AGOTADO</p>':''}<div class="plp-sizes" role="group" aria-label="Elegí talla de ${esc(p.name)}">${sizes}</div></div><div class="plp-info"><p class="plp-color">${esc(p.color)}</p><button class="plp-fav" type="button" data-favorite="${esc(p.id)}" aria-label="Guardar en favoritos: ${esc(p.name)}" aria-pressed="${saved}"><svg viewBox="0 0 24 24" fill="${saved?'currentColor':'none'}" stroke="currentColor" stroke-width="1.3" aria-hidden="true"><path d="M20.8 4.7a5.5 5.5 0 0 0-7.8 0L12 5.8l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.5a5.5 5.5 0 0 0 0-7.8Z"/></svg></button><h2 class="plp-name"><a href="/producto-${esc(p.id)}.html">${esc(p.name)}</a></h2><p class="plp-price">${priceText(p)}</p>${stock===0?'':`<button class="plp-quick" type="button" data-quick aria-expanded="false" aria-label="Agregar rápido ${esc(p.name)}"><span>Agregar rápido</span></button>`}</div></article>`;
  }
  function closeQuick(c) { c.classList.remove('picking'); $('[data-quick]',c)?.setAttribute('aria-expanded','false'); }

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
    $$('[data-category-tab]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.categoryTab===(new URLSearchParams(location.search).get('category')||''))));
    const params = new URLSearchParams(location.search);
    $$('select[name="size"] option[value]:not([value=""])',form).forEach(option=>{const sellable=products.some(p=>p.variants.some(v=>v.size===option.value&&v.stock>0));option.disabled=!sellable;option.textContent=sellable?option.value:option.value+' · Agotada';});
    for (const key of ['q','category','size','color','sort']) if (form.elements[key]) form.elements[key].value = params.get(key) || (key === 'sort' ? 'selection' : '');
    const query = (params.get('q') || '').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
    let matches = products.filter(p => {
      const original = `${p.name} ${p.category} ${p.color} ${p.description}`;
      const translated = window.MarthaI18n ? [p.name,p.category,p.color,p.description].map(window.MarthaI18n.english).join(' ') : '';
      const text = `${original} ${translated}`.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
      return (!query || query.split(/\s+/).every(word => text.includes(word))) && (!params.get('category') || p.category === params.get('category')) && (!params.get('color') || p.color === params.get('color')) && (!params.get('size') || p.variants.some(v => v.size === params.get('size') && v.stock > 0)) && (!params.has('favoritos') || favorites.includes(p.id));
    });
    if (params.get('sort') === 'price-asc') matches.sort((a,b) => (a.price_minor ?? Infinity)-(b.price_minor ?? Infinity));
    if (params.get('sort') === 'price-desc') matches.sort((a,b) => (b.price_minor ?? -1)-(a.price_minor ?? -1));
    const catalogGrid = $('[data-catalog-grid]'), catalogHtml = matches.map(card).join('') || '<div class="empty-state"><h2>No encontramos prendas con estos filtros.</h2><p>Probá otra talla, color o colección.</p><button class="button secondary" data-clear-filters>Ver todas las prendas</button></div>';
    flipGrid(catalogGrid, () => { catalogGrid.innerHTML = catalogHtml; });
    $('[data-result-count]').textContent = `${matches.length} ${matches.length === 1 ? 'prenda':'prendas'}${params.has('favoritos') ? ' en favoritos':''}`;
    let chips = $('[data-filter-chips]');
    if (!chips) { chips = document.createElement('div'); chips.className = 'filter-chips'; chips.dataset.filterChips = ''; form.after(chips); }
    $('.catalog-status')?.classList.toggle('has-filters',[...params.keys()].some(k=>!['sort','lang'].includes(k)));
    chips.innerHTML = [...params.entries()].filter(([k]) => !['sort','lang'].includes(k)).map(([key,value]) => `<button class="filter-chip" data-remove-filter="${esc(key)}"><span ${key === 'q' ? 'translate="no"' : ''}>${esc(key === 'favoritos' ? 'Favoritos':value)}</span> <span aria-hidden="true">×</span><span class="sr-only"> Quitar filtro</span></button>`).join('');
  }
  // Catalog grid: manual FLIP with GSAP core. Cards move, the image scales, text only fades.
  const GRID_KEY = 'martha-grid-v1';
  let flipContext;
  function gridStored() { try { const v = JSON.parse(localStorage.getItem(GRID_KEY)); return v && typeof v === 'object' ? v : {}; } catch { return {}; } }
  function flipGrid(grid, mutate) {
    const still = !window.gsap || !gsap.context || matchMedia('(prefers-reduced-motion: reduce)').matches;
    flipContext?.revert(); flipContext = null;
    const before = new Map($$('.plp-card', grid).map(card => [card.dataset.id, card.getBoundingClientRect()]));
    mutate();
    if (still || !before.size) return;
    const near = r => r.bottom > -100 && r.top < innerHeight + 100;
    const moves = $$('.plp-card', grid).map(card => ({card, from: before.get(card.dataset.id), to: card.getBoundingClientRect()}))
      .filter(m => near(m.to) || (m.from && near(m.from)));
    const spread = MOTION.durM / 4, last = Math.max(moves.length - 1, 1);
    flipContext = gsap.context(() => moves.forEach(({card, from, to}, i) => {
      const delay = spread * i / last, base = {ease: MOTION.ease, delay};
      if (!from) { gsap.fromTo(card, {opacity: 0}, {opacity: 1, duration: MOTION.durS, ...base}); return; }
      const dx = from.left - to.left, dy = from.top - to.top, scale = from.width / to.width;
      if (Math.abs(dx) < 1 && Math.abs(dy) < 1 && Math.abs(scale - 1) < .01) return;
      const duration = MOTION.durM - spread;
      gsap.fromTo(card, {x: dx, y: dy}, {x: 0, y: 0, duration, ...base});
      gsap.fromTo($('.plp-media', card), {scale, transformOrigin: '0 0'}, {scale: 1, duration, ...base});
      gsap.fromTo($('.plp-info', card), {opacity: 0}, {opacity: 1, duration: MOTION.durS, ...base});
    }), grid);
  }
  function gridView() {
    const grid = $('[data-catalog-grid]'), group = $('.grid-views'); if (!grid || !group) return;
    const signal = pageScope.signal;
    const set = (key, value) => { grid.style.setProperty('--' + key, value); $$('[data-cols-key="' + key + '"]', group).forEach(b => b.setAttribute('aria-pressed', String(b.dataset.cols === String(value)))); };
    const saved = gridStored();
    ['cd', 'cm'].forEach(key => { if ($('[data-cols-key="' + key + '"][data-cols="' + saved[key] + '"]', group)) set(key, saved[key]); });
    group.addEventListener('click', event => {
      const b = event.target.closest('[data-cols]'); if (!b || b.getAttribute('aria-pressed') === 'true') return;
      flipGrid(grid, () => set(b.dataset.colsKey, b.dataset.cols));
      try { localStorage.setItem(GRID_KEY, JSON.stringify({...gridStored(), [b.dataset.colsKey]: b.dataset.cols})); } catch {}
    }, {signal});
    signal.addEventListener('abort', () => { flipContext?.revert(); flipContext = null; }, {once: true});
  }
  function totals(q, cta = '') {
    if (liveStore) return `<dl class="totals">${q.total_minor === undefined ? `<div class="total-row"><dt>Subtotal</dt><dd>${money(q.subtotal_minor)}</dd></div>` : `${q.shipping_minor === undefined ? '' : `<div><dt>Entrega</dt><dd>${money(q.shipping_minor)}</dd></div>`}<div class="total-row"><dt>Total</dt><dd>${money(q.total_minor)}</dd></div>`}</dl>${cta}`;
    return `<dl class="totals"><div><dt>Subtotal</dt><dd>${money(q.subtotal_minor)}</dd></div>${q.discount_minor ? `<div><dt>Descuento</dt><dd>−${money(q.discount_minor)}</dd></div>`:''}<div><dt>Entrega${q.shipping_minor === undefined ? ' estimada':''}</dt><dd>${q.shipping_minor === undefined ? 'Desde '+money(500):money(q.shipping_minor)}</dd></div><div><dt>Impuestos</dt><dd>${money(q.tax_minor || 0)}</dd></div><div class="total-row"><dt>Total${q.total_minor === undefined ? ' sin entrega':''}</dt><dd>${money(q.total_minor ?? q.subtotal_minor)}</dd></div></dl>${cta}`; }
  function runningSummary(q, lines, label) {
    return `<details class="running-summary" data-running-summary><summary><span>${esc(lines.map(line => 'Talla '+line.size+' · Cantidad '+line.quantity).join(' / '))}</span><strong><span>${label}</span> ${money(q.total_minor ?? q.subtotal_minor)}</strong></summary><div class="running-summary-content">${lines.map(line => lineView(line)).join('')}${totals(q)}</div></details>`;
  }
  function syncProduct() {
    const selected=$('input[name="variant"]:checked');
    const sticky=$('[data-sticky-size]'); if(sticky) sticky.value=selected?.value || '';
    const note=$('[data-stock-note]'),variant=products.flatMap(p=>p.variants).find(v=>v.id===selected?.value);if(note)note.textContent=variant?(variant.stock===1?'Última unidad':variant.stock<=2?'Pocas unidades disponibles':'Talla disponible'):'';
    const available=$$('input[name="variant"]').some(input=>!input.disabled);
    const ready = !!integrationApi && !integrationError;
    $$('[data-add], [data-sticky-add]').forEach(button=>{button.disabled=!ready||productAdding||!available;if(button.dataset.state!=='added')button.textContent=available?'Agregar a la bolsa':'Agotada';});
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
  // Offer no more units than the variant has; keep the current quantity so an over-stock line can be lowered.
  function quantityOptions(line) { const limit = Number.isSafeInteger(line.available) ? Math.min(10, Math.max(0, line.available)) : 10; const values = Array.from({length:limit}, (_, i) => i + 1); if (!values.includes(line.quantity)) values.push(line.quantity); return values; }
  function lineView(line, edit = false) { return `<article class="cart-line"><a href="/producto-${esc(line.product_id)}.html"><img src="${esc(line.image)}" alt="${esc(line.name)}" loading="lazy" width="${window.STORE_IMAGE_DIMENSIONS?.[line.image]?.[0] || 900}" height="${window.STORE_IMAGE_DIMENSIONS?.[line.image]?.[1] || 1200}"></a><div><p class="product-category">MARTHA SILVA</p><h2><a href="/producto-${esc(line.product_id)}.html">${esc(line.name)}</a></h2><p>${esc(line.color)} · Talla ${esc(line.size)}</p>${edit ? `<label class="quantity-label">Cantidad <select data-quantity="${esc(line.variant_id)}" aria-label="Cantidad de ${esc(line.name)}, talla ${esc(line.size)}">${quantityOptions(line).map(n => `<option value="${n}" ${line.quantity === n ? 'selected':''}>${n}</option>`).join('')}</select></label><button class="text-button" data-remove-item="${esc(line.variant_id)}" aria-label="Retirar ${esc(line.name)}, talla ${esc(line.size)}">Retirar</button><button class="text-button" data-move-favorite="${esc(line.variant_id)}" data-product="${esc(line.product_id)}" aria-label="Guardar en favoritos ${esc(line.name)}, talla ${esc(line.size)}">Guardar en favoritos</button>`:`<p>Cantidad: ${line.quantity}</p>`}</div><strong>${line.line_total_minor === null ? '' : money(line.line_total_minor)}</strong></article>`; }
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
    $('[data-cart-running]')?.remove(); const running=document.createElement('div');running.dataset.cartRunning='';running.innerHTML=runningSummary(cart,cart.lines,liveStore ? 'Subtotal' : 'Total sin entrega');$('.commerce-grid',mount.closest('section')).before(running);
    $('[data-cart-summary]').innerHTML = `<div class="order-summary"><h2>Resumen de compra</h2><p class="summary-selection">${esc(cart.lines.map(line => "Talla "+line.size+" - Cantidad "+line.quantity).join(" / "))}</p>${totals(cart, '<a class="button full" href="/checkout.html">Continuar con la compra</a>')}<p class="small muted">Elegí tu zona de entrega para conocer el total completo antes del pago.</p></div>`;
  }
  function field(name,label,type='text',options={}) { return `<label class="field ${options.full ? 'full':''}"><span>${label}</span><input name="${name}" type="${type}" value="${esc(checkout[name] || '')}" ${options.required === false ? '' : 'required'} maxlength="${options.max || 200}" autocomplete="${options.auto || 'off'}" ${options.placeholder ? `placeholder="${esc(options.placeholder)}"`:''}>${options.help ? `<small>${options.help}</small>`:''}</label>`; }
  function renderCheckout(step = 'contact', focusStep = false) {
    const mount = $('[data-checkout-root]'); if (!mount) return;
    if (!cart.lines.length && !checkout.order_id && checkout.quote_id && checkout.order_key) { mount.innerHTML = '<div class="empty-state"><h2>Revisá tu pedido anterior.</h2><p>Podés recuperar su resultado.</p><button class="button" data-recover-order>Recuperar pedido</button><p class="error" data-error role="alert" hidden></p></div>'; return; }
    if (!cart.lines.length) { mount.innerHTML = checkout.order_id ? `<div class="empty-state"><h2>Tu pedido ya fue creado.</h2><a class="button" href="/pedido.html?id=${encodeURIComponent(checkout.order_id)}">Continuar con tu pedido</a></div>` : '<div class="empty-state"><h2>Agregá una prenda para continuar.</h2><a class="button" href="/catalogo.html">Ver la colección</a></div>'; return; }
    const stages = liveStore ? ['contact','delivery','review'] : ['contact','delivery','review','payment'];
    let content = '';
    if (liveStore) content = liveCheckoutStep(step);
    else if (step === 'contact') content = `<h2>Contacto</h2><form data-checkout-form="contact" novalidate><div class="form-grid">${field('name','Nombre y apellido','text',{auto:'name',full:true})}${field('email','Email','email',{auto:'email',full:true,help:'Para identificar tu pedido.'})}${field('phone','Teléfono','tel',{auto:'tel',full:true,help:'Para coordinar la entrega cuando la tienda esté activa.'})}</div><label class="check-label"><input name="newsletter" type="checkbox" ${checkout.newsletter ? 'checked':''}>Quiero recibir novedades de Martha Silva (opcional).</label><p class="checkout-legal"><span>Usamos estos datos solo para preparar, cobrar y entregar tu pedido.</span> <a class="text-link" href="/ayuda.html#privacidad">Privacidad</a> <a class="text-link" href="/ayuda.html#terminos">Términos de compra</a></p><p data-error class="error" role="alert" hidden></p><button class="button full">Continuar con la entrega</button></form>`;
    else if (step === 'delivery') content = `<button class="text-button" data-checkout-back="contact">← Editar contacto</button><h2>Dirección de entrega</h2><form data-checkout-form="delivery" novalidate><div class="form-grid">${field('line1','Dirección','text',{auto:'street-address',full:true})}${field('city','Ciudad','text',{auto:'address-level2'})}${field('department','Departamento','text',{auto:'address-level1'})}<label class="field full"><span>Zona de entrega</span><select name="delivery_zone" required><option value="managua" ${checkout.delivery_zone === 'resto' ? '':'selected'}>Managua - ${money(500)}</option><option value="resto" ${checkout.delivery_zone === 'resto' ? 'selected':''}>Resto de Nicaragua - ${money(800)}</option></select></label>${field('coupon','Código de descuento','text',{required:false,full:true})}</div><p data-error class="error" role="alert" hidden></p><button class="button full">Revisar la compra</button></form>`;
    else if (step === 'review') content = `<button class="text-button" data-checkout-back="delivery">← Editar entrega</button><h2>Revisá tu compra</h2><div class="review-block"><h3>Contacto</h3><p translate="no">${esc(checkout.name)}<br>${esc(checkout.email)}<br>${esc(checkout.phone)}</p><h3>Entrega</h3><p translate="no">${esc(checkout.line1)}<br>${esc(checkout.city)}, ${esc(checkout.department)}</p></div><p data-error class="error" role="alert" hidden></p><button class="button full" data-create-order>Continuar al pago</button>`;
    else if (step === 'payment') content = `<h2>Pago</h2><p data-error class="error" role="alert" hidden></p><button class="button full" data-confirm-payment="approved">Confirmar pedido</button>`;
    mount.innerHTML = `<ol class="steps" aria-label="Pasos de compra">${stages.map((s,i) => `<li class="${i<stages.indexOf(step)?'complete':''}" ${s === step ? 'aria-current="step"':''}>${i+1}. ${['Contacto','Entrega','Revisión','Pago'][i]}</li>`).join('')}</ol>${runningSummary(quote || cart,cart.lines,quote ? 'Total' : liveStore ? 'Subtotal' : 'Total sin entrega')}<div class="commerce-grid"><section class="checkout-panel" aria-labelledby="checkout-stage-title">${content}</section><aside class="order-summary checkout-summary" data-checkout-step="${step}"><h2>Tu selección</h2>${cart.lines.map(line => lineView(line)).join('')}${totals(quote || cart)}<footer class="checkout-summary-footer"><div><h3>Compra</h3><p>Los precios se muestran en ${esc(currency)}.</p><a href="/ayuda.html" data-barba-prevent>Entrega y devoluciones</a></div></footer></aside></div>`;
    const title = $('.checkout-panel h2',mount);
    title.id = 'checkout-stage-title';
    if (focusStep) { title.tabIndex = -1; title.focus({preventScroll:true}); }
    $('.checkout-panel',mount).scrollIntoView({block:'nearest'});
    if (liveStore && step === 'review') { checkout.prices = Object.fromEntries(cart.lines.map(line => [line.variant_id, line.unit_price_minor])); saveCheckout(); mountTurnstile().catch(error => showError(mount, error)); }
  }
  // Field limits follow the hub; city and department travel together as one 120-character city.
  function liveCheckoutStep(step) {
    if (step === 'contact') return `<h2>Contacto</h2><form data-checkout-form="contact" novalidate><div class="form-grid">${field('name','Nombre y apellido','text',{auto:'name',full:true,max:180})}${field('email','Email','email',{auto:'email',full:true,max:254})}${field('phone','Teléfono','tel',{auto:'tel',full:true,max:40})}</div><p data-error class="error" role="alert" hidden></p><button class="button full">Continuar con la entrega</button></form>`;
    if (step === 'delivery') return `<button class="text-button" data-checkout-back="contact">← Editar contacto</button><h2>Dirección de entrega</h2><form data-checkout-form="delivery" novalidate><div class="form-grid">${field('line1','Dirección','text',{auto:'street-address',full:true,max:350})}${field('city','Ciudad','text',{auto:'address-level2',max:60})}${field('department','Departamento','text',{auto:'address-level1',max:58})}<label class="field full"><span>Zona de entrega</span><select name="delivery_zone" required><option value="managua" ${checkout.delivery_zone === 'departamentos' ? '':'selected'}>Managua</option><option value="departamentos" ${checkout.delivery_zone === 'departamentos' ? 'selected':''}>Resto de Nicaragua</option></select></label></div><p data-error class="error" role="alert" hidden></p><button class="button full">Revisar la compra</button></form>`;
    const providers = integrationApi?.providers || [];
    return `<button class="text-button" data-checkout-back="delivery">← Editar entrega</button><h2>Revisá tu compra</h2><div class="review-block"><h3>Contacto</h3><p translate="no">${esc(checkout.name)}<br>${esc(checkout.email)}<br>${esc(checkout.phone)}</p><h3>Entrega</h3><p translate="no">${esc(checkout.line1)}<br>${esc(checkout.city)}, ${esc(checkout.department)}</p></div><fieldset class="review-block"><legend>Forma de pago</legend>${providers.map((provider,i) => `<label class="check-label"><input type="radio" name="provider" value="${esc(provider.code)}" ${i === 0 ? 'checked':''}><span translate="no">${esc(provider.label)}</span></label>`).join('')}</fieldset>${integrationApi?.turnstileSiteKey ? '<div data-turnstile></div>' : ''}<p data-error class="error" role="alert" hidden></p><button class="button full" data-create-order>Confirmar pedido</button>`;
  }
  // Turnstile loads only on the review step of a live build that set a site key.
  let turnstileLoad, turnstileWidget = null;
  function turnstileScript() {
    return turnstileLoad ||= new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit'; script.async = true;
      script.onload = () => window.turnstile ? resolve(window.turnstile) : reject(new Error('No pudimos conectar con la tienda. Revisá tu conexión e intentá otra vez.'));
      script.onerror = () => { turnstileLoad = null; script.remove(); reject(new Error('No pudimos conectar con la tienda. Revisá tu conexión e intentá otra vez.')); };
      document.head.append(script);
    });
  }
  async function mountTurnstile() {
    const box = $('[data-turnstile]'); if (!box) return;
    const turnstile = await turnstileScript();
    if (turnstileWidget !== null) try { turnstile.remove(turnstileWidget); } catch {}
    if (box.isConnected) turnstileWidget = turnstile.render(box, {sitekey:integrationApi.turnstileSiteKey, language:window.MarthaI18n?.language === 'en' ? 'en' : 'es'});
  }
  function turnstileToken() {
    if (!integrationApi?.turnstileSiteKey) return undefined;
    const token = turnstileWidget !== null && window.turnstile?.getResponse(turnstileWidget);
    if (!token) throw new Error('Completá la verificación para confirmar el pedido.');
    return token;
  }
  /* The adapter keeps one Idempotency-Key per checkout attempt, so a retry or a second click
     replays the same hub order. Success leaves the checkout for the payment step the hub chose. */
  async function placeLiveOrder() {
    const provider = $('input[name="provider"]:checked')?.value;
    if (!provider) throw new Error('Elegí una forma de pago.');
    try {
      const {order} = await api('/api/orders', {contact:{name:checkout.name,email:checkout.email,phone:checkout.phone}, shipping:{zone:checkout.delivery_zone,address:checkout.line1,city:`${checkout.city}, ${checkout.department}`}, provider, locale:window.MarthaI18n?.language, turnstileToken:turnstileToken(), prices:checkout.prices});
      sessionStorage.setItem(sessionKey('last-order'), order.id); sessionStorage.removeItem(sessionKey('checkout')); checkout = {};
      const redirect = order.payment?.kind === 'redirect' && /^https:\/\//.test(order.payment.url || '') ? order.payment.url : '';
      location.assign(redirect || '/pedido.html?order=' + encodeURIComponent(order.id));
    } catch (error) {
      if (error.code === 'price_changed') { await refreshCart(); renderCheckout('review'); }
      else if (turnstileWidget !== null) try { window.turnstile?.reset(turnstileWidget); } catch {}
      throw error;
    }
  }
  function returnItems(order, ret) { return '<ul class="return-items">'+ret.lines.map(line=>{const item=order.lines.find(item=>item.variant_id===line.variant_id); return '<li>'+esc(item?.name || line.variant_id)+' · Talla '+esc(item?.size)+' · Cantidad: '+line.quantity+'</li>';}).join('')+'</ul>'; }
  function orderView(order, admin = false) {
    const refunded = order.refunded_minor || 0;
    return `<div class="order-heading"><div><p class="eyebrow">PEDIDO ${esc(order.code)}</p><h2>${statusLabel[order.status] || esc(order.status)}</h2></div><span class="status-chip">${statusLabel[order.payment_status] || esc(order.payment_status)}</span></div><div class="commerce-grid"><section>${order.lines.map(line => lineView(line)).join('')}<div class="review-block"><h3>Entrega</h3><p translate="no">${esc(order.contact.name)}<br>${esc(order.address.line1)}<br>${esc(order.address.city)}, ${esc(order.address.department)}</p>${order.tracking ? `<p>Seguimiento: <span translate="no"><span translate="no">${esc(order.tracking)}</span></span></p>`:''}</div><h3>Estado del pedido</h3><ol class="timeline">${order.events.map(event => `<li><span>${esc(new Date(event.at).toLocaleString(locale()))}</span> ${esc(statusLabel[event.type] || event.type)}</li>`).join('')}</ol></section><aside class="order-summary"><h3>Resumen de compra</h3>${totals(order)}${refunded ? `<p>Reembolsado: ${money(refunded)}</p>`:''}<p class="small muted" translate="no">${esc(order.contact.email)}</p></aside></div>${(order.returns || []).map(r => `<div class="return-card"><h3>Devolución ${esc(r.id.slice(0,8))}</h3>${returnItems(order,r)}<p><span translate="no">${esc(r.reason)}</span> · ${statusLabel[r.status] || esc(r.status)}</p>${admin && r.status === 'requested' ? `<button class="button secondary" data-receive-return="${esc(r.id)}" data-order="${esc(order.id)}">Registrar recepción</button>`:''}${admin && r.status === 'received' ? `<label class="check-label"><input type="checkbox" data-restock="${esc(r.id)}">Prenda revisada: devolver al inventario</label><button class="button secondary" data-refund="${esc(r.id)}" data-order="${esc(order.id)}">Procesar reembolso</button>`:''}</div>`).join('')}`;
  }
  function liveOrderView(order) {
    const payment = order.payment && ['reserved','payment_review'].includes(order.status) ? `<div class="review-block"><h3>Pago</h3><p translate="no">${esc(order.payment.label)}</p>${order.payment.instructions ? `<p translate="no">${esc(order.payment.instructions).replace(/\n/g,'<br>')}</p>`:''}${order.status === 'reserved' && order.expires_at ? `<p>Reservado hasta <span translate="no">${esc(new Date(order.expires_at).toLocaleString(locale()))}</span></p>`:''}</div>` : '';
    return `<div class="order-heading"><div><p class="eyebrow">PEDIDO ${esc(order.code)}</p><h2>${statusLabel[order.status] || esc(order.status)}</h2></div></div><div class="commerce-grid"><section>${order.lines.map(line => lineView(line)).join('')}${payment}</section><aside class="order-summary"><h3>Resumen de compra</h3>${totals(order)}</aside></div><a class="text-button" href="/catalogo.html">Seguir explorando la colección</a>`;
  }
  async function renderLiveOrder(mount) {
    const params = new URLSearchParams(location.search), id = params.get('order') || params.get('id') || sessionStorage.getItem(sessionKey('last-order'));
    if (!id) { mount.innerHTML='<div class="empty-state"><h2>No seleccionaste un pedido.</h2><a class="button" href="/catalogo.html">Ver la colección</a></div>'; return; }
    const signal = pageScope.signal;
    try {
      const order = (await api(`/api/orders/${encodeURIComponent(id)}`)).order;
      if (signal.aborted) return;
      const changed = currentOrder?.id === order.id && currentOrder.status !== order.status;
      currentOrder = order; currency = order.currency || currency;
      mount.innerHTML = liveOrderView(order);
      if (changed) notify(statusLabel[order.status] || order.status);
    } catch (error) {
      if (signal.aborted) return;
      if (!currentOrder) { mount.innerHTML='<h2>No pudimos abrir ese pedido.</h2><p>Usá el navegador con el que hiciste la compra.</p><a href="/catalogo.html" class="button">Ver la colección</a>'; showError(mount,error); return; }
    }
    // Poll while the buyer can still pay; staff record a manual payment on the hub.
    if (['reserved','payment_review'].includes(currentOrder?.status)) { const timer = setTimeout(() => renderLiveOrder(mount), 20000); signal.addEventListener('abort', () => clearTimeout(timer), {once:true}); }
  }
  async function renderOrder() {
    const mount = $('[data-order-root]'); if (!mount) return;
    if (liveStore) { currentOrder = null; await renderLiveOrder(mount); return; }
    const id = new URLSearchParams(location.search).get('id') || sessionStorage.getItem(sessionKey('last-order'));
    if (!id) { mount.innerHTML='<div class="empty-state"><h2>No seleccionaste un pedido.</h2><a class="button" href="/catalogo.html">Ver la colección</a></div>'; return; }
    try {
      currentOrder = (await api(`/api/orders/${encodeURIComponent(id)}`)).order;
      let action = '';
      if (currentOrder.status === 'pending_payment') action = `<h3>Completá el pago</h3><button class="button" data-confirm-payment="approved">Confirmar pedido</button>`;
      if (['declined','cancelled'].includes(currentOrder.status)) action = '<p>La reserva se liberó. Podés volver a agregar las prendas disponibles.</p><button class="button" data-rebuild-order>Volver a agregar las prendas</button>';
      if (['delivered','partially_refunded'].includes(currentOrder.status)) {
        const returned = new Map(); for (const r of currentOrder.returns || []) for (const line of r.lines) returned.set(line.variant_id,(returned.get(line.variant_id)||0)+line.quantity);
        const eligible = currentOrder.lines.filter(line => line.quantity > (returned.get(line.variant_id)||0));
        if (eligible.length) action = `<details class="return-form"><summary>Solicitar una devolución</summary><form data-return-form><p>Seleccioná las prendas que querés devolver.</p>${eligible.map(line => `<label class="field"><span>${esc(line.name)} · ${esc(line.size)}</span><select name="return:${esc(line.variant_id)}"><option value="0">No devolver</option>${Array.from({length:line.quantity-(returned.get(line.variant_id)||0)},(_,i) => `<option value="${i+1}">${i+1} ${i===0?'prenda':'prendas'}</option>`).join('')}</select></label>`).join('')}<label class="field"><span>Motivo</span><textarea name="reason" required maxlength="500"></textarea></label><p data-error class="error" role="alert" hidden></p><button class="button secondary">Enviar solicitud</button></form></details>`;
      }
      mount.innerHTML=orderView(currentOrder)+`<section class="order-actions">${action}</section><a class="text-button" href="/catalogo.html">Seguir explorando la colección</a>`;
    } catch (error) { mount.innerHTML='<h2>No pudimos abrir ese pedido.</h2><p>Usá el navegador con el que hiciste la compra.</p><a href="/catalogo.html" class="button">Ver la colección</a>'; showError(mount,error); }
  }
  async function renderAdmin() {
    const mount = $('[data-admin-root]'); if (!mount) return;
    if (!(await api('/api/admin/session')).authenticated) { mount.innerHTML='<section class="admin-login checkout-panel"><h2>Acceso a administración</h2><p>Este panel no tiene autenticación propia. Los datos se guardan en este navegador.</p><form data-admin-login><input name="password" type="hidden" value="admin"><p data-error class="error" role="alert" hidden></p><button class="button full">Abrir administración</button></form></section>'; return; }
    [adminOrders,inventory] = await Promise.all([api('/api/admin/orders').then(r => r.orders),api('/api/admin/inventory').then(r => r.variants)]);
    mount.innerHTML = `<div class="admin-toolbar"><h2>Pedidos e inventario</h2><button class="text-button" data-admin-refresh>Actualizar</button><button class="text-button" data-admin-logout>Cerrar sesión</button></div><p class="notice">Los cambios se guardan en este navegador.</p><nav class="admin-tabs"><a href="#admin-orders">Pedidos (${adminOrders.length})</a><a href="#admin-stock">Inventario</a></nav><section id="admin-orders"><h2>Pedidos</h2>${adminOrders.length ? adminOrders.map(order => `<details class="admin-order"><summary>${esc(order.code)} · ${statusLabel[order.status] || esc(order.status)} · ${money(order.total_minor)}</summary><div>${orderView(order,true)}${['paid','preparing','shipped'].includes(order.status) ? `<form data-fulfillment="${esc(order.id)}"><input type="hidden" name="status" value="${({paid:'preparing',preparing:'shipped',shipped:'delivered'})[order.status]}">${order.status === 'preparing' ? '<label class="field"><span>Número de seguimiento</span><input name="tracking" required maxlength="120"></label>':''}<p data-error class="error" role="alert" hidden></p><button class="button secondary">${({paid:'Preparar pedido',preparing:'Registrar envío',shipped:'Registrar entrega'})[order.status]}</button></form>`:''}</div></details>`).join(''):'<p>No hay pedidos todavía.</p>'}</section><section id="admin-stock"><h2>Inventario por talla</h2><div class="inventory-table"><table><thead><tr><th>Prenda / talla</th><th>Físico</th><th>Reservado</th><th>Disponible</th><th>Ajustar</th></tr></thead><tbody>${inventory.map(v => `<tr><th>${esc(v.name)} · ${esc(v.size)}</th><td>${v.stock}</td><td>${v.reserved}</td><td>${v.available}</td><td><form data-stock="${esc(v.id)}"><label class="sr-only" for="stock-${esc(v.id)}">Nuevo stock de ${esc(v.name)} ${esc(v.size)}</label><input id="stock-${esc(v.id)}" name="quantity" type="number" min="${v.reserved}" max="100000" required value="${v.stock}" aria-label="Nuevo stock ${esc(v.name)} ${esc(v.size)}"><input name="reason" placeholder="Motivo del ajuste" aria-label="Motivo del ajuste ${esc(v.name)} ${esc(v.size)}" required maxlength="200"><button class="button secondary">Guardar</button><p data-error class="error" role="alert" hidden></p></form></td></tr>`).join('')}</tbody></table></div></section>`;
  }
  function stopMotion() { if (raf) cancelAnimationFrame(raf); raf=null; }
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
    if (loaderHold) introDue = true; else playIntro();
  }
  // Home loader: the head gate sets html.ms-loading; this drives it, then plays [data-intro].
  let loaderHold = false, introDue = false;
  function playIntro() {
    const intro = $$('[data-intro]'); if (!window.gsap || !intro.length) return;
    intro.forEach(element => { element.style.transition = 'none'; });
    gsap.from(intro, {opacity: 0, duration: MOTION.durS, ease: MOTION.ease, clearProps: 'all'});
  }
  function initLoader() {
    const root = document.documentElement, node = document.querySelector('.ms-loader');
    const started = root.classList.contains('ms-loading') && performance.getEntriesByName?.('ms-loader-start')[0];
    if (!node || !started) { node?.remove(); root.classList.remove('ms-loading'); return; }
    const elapsed = () => (performance.now() - started.startTime) / 1000, ac = new AbortController(), {signal} = ac;
    let done = false, timeline = null, backstop = 0;
    const release = () => { loaderHold = false; if (introDue) { introDue = false; playIntro(); } };
    const end = () => {
      if (done) return; done = true; ac.abort(); clearTimeout(backstop); timeline?.kill(); node.remove(); root.classList.remove('ms-loading');
      try { performance.mark('ms-loader-end'); } catch {}
      release();
    };
    loaderHold = true;
    if (!window.gsap || elapsed() >= MOTION.loaderMax) { end(); return; }
    backstop = setTimeout(end, Math.max(0, MOTION.loaderMax - MOTION.durS / 8 - elapsed()) * 1000);
    for (const type of ['pointerdown', 'keydown', 'wheel', 'touchmove', 'pagehide']) window.addEventListener(type, end, {passive: true, signal});
    window.addEventListener('pageshow', event => { if (event.persisted) end(); }, {signal});
    const gap = node.querySelector('.ms-loader-gap'), pics = [...gap.querySelectorAll('img')], layer = node.querySelector('.ms-loader-hero'), frames = [...layer.children];
    // The layer mirrors the active hero slide (same file, crop, scale) for a pixel-aligned hand-off.
    const slots = $$('.ho-slide[data-active] .ho-m').filter(item => getComputedStyle(item).display !== 'none').slice(0, frames.length), art = frames.slice(0, slots.length).map(frame => frame.firstChild);
    frames.slice(slots.length).forEach(frame => { frame.style.display = 'none'; });
    const settle = image => Promise.race([image.decode ? image.decode().catch(() => {}) : 0, new Promise(resolve => setTimeout(resolve, MOTION.durS * 1000))]);
    Promise.all([...pics, ...art].map(settle)).then(() => {
      if (done) return;
      const rects = slots.map(slot => slot.getBoundingClientRect()), view = {left: 0, top: 0, right: innerWidth, bottom: innerHeight};
      const box = rects.length && rects.every(r => r.width && r.height) ? {left: Math.min(...rects.map(r => r.left)), top: Math.min(...rects.map(r => r.top)), right: Math.max(...rects.map(r => r.right)), bottom: Math.max(...rects.map(r => r.bottom))} : view;
      box.width = box.right - box.left; box.height = box.bottom - box.top;
      const spot = gap.getBoundingClientRect();
      const inset = (outer, inner, radius) => `inset(${inner.top - outer.top}px ${outer.right - inner.right}px ${outer.bottom - inner.bottom}px ${inner.left - outer.left}px round ${radius})`;
      Object.assign(layer.style, {left: box.left + 'px', top: box.top + 'px', width: box.width + 'px', height: box.height + 'px', clipPath: inset(box, spot, MOTION.radius)});
      art.forEach((image, index) => {
        const look = getComputedStyle($('img', slots[index])), rect = rects[index];
        Object.assign(image.parentNode.style, {left: rect.left - box.left + 'px', top: rect.top - box.top + 'px', width: rect.width + 'px', height: rect.height + 'px'});
        Object.assign(image.style, {objectPosition: look.objectPosition, transform: look.transform === 'none' ? '' : look.transform});
      });
      const step = MOTION.durS / 2, open = Math.max(0, MOTION.durM / 2 - elapsed()), grow = open + MOTION.durS / 2 + step * pics.length, fade = grow + MOTION.durM - step;
      timeline = gsap.timeline({onComplete: end});
      timeline.call(() => node.setAttribute('data-open', ''), null, open);
      pics.forEach((pic, index) => timeline.call(() => pics.forEach(other => other.toggleAttribute('data-on', other === pic)), null, open + MOTION.durS / 2 + step * index));
      timeline.set(layer, {visibility: 'visible'}, grow)
        .fromTo(layer, {clipPath: layer.style.clipPath}, {clipPath: 'inset(0px 0px 0px 0px round 0px)', duration: MOTION.durM, ease: MOTION.ease, immediateRender: false}, grow)
        .call(release, null, fade)
        .to(node, {opacity: 0, duration: MOTION.durS, ease: MOTION.ease}, fade);
      const room = MOTION.loaderMax - MOTION.durS / 4 - elapsed();
      if (room <= 0) end(); else if (timeline.duration() > room) timeline.timeScale(timeline.duration() / room);
    }).catch(end);
  }
  function openDialog(dialog, trigger=document.activeElement) {
    if(!dialog || dialog.open)return;
    dialog.returnFocus=trigger; dialog.showModal();
    dialog.addEventListener('close',()=>{if(dialog.id==='newsletter-dialog')localStorage.setItem('martha-newsletter-dismissed','true');trigger?.setAttribute('aria-expanded','false');if(trigger?.isConnected)trigger.focus({preventScroll:true});},{once:true});
  }
  // Mobile menu: the card grows from the bottom pill and shrinks back before dialog.close(); instant under reduced motion or without GSAP.
  let menuTimeline = null, menuClosing = false;
  const menuParts = dialog => [$('.mobile-menu-inner', dialog), ...$$('.drawer-heading, .mobile-menu-inner > a', dialog)];
  const menuAnimated = () => { const pill = $('.menu-pill'); return !!window.gsap && !!pill && getComputedStyle(pill).display !== 'none' && !matchMedia('(prefers-reduced-motion: reduce)').matches; };
  function menuOpen(toggle) {
    const dialog = $('#mobile-menu'); if (!dialog || dialog.open) return;
    toggle?.setAttribute('aria-expanded', 'true'); openDialog(dialog, toggle);
    if (!menuAnimated()) return;
    const from = $('.menu-pill').getBoundingClientRect(), to = dialog.getBoundingClientRect(), base = {ease: MOTION.ease};
    menuTimeline?.kill(); menuClosing = false;
    menuTimeline = gsap.timeline()
      .fromTo(dialog, {width: from.width}, {width: to.width, duration: MOTION.durM, ...base}, 0)
      .fromTo(dialog, {height: from.height}, {height: to.height, duration: MOTION.durM, clearProps: 'width,height', ...base}, MOTION.durM / 2)
      .from($$('.drawer-heading, .mobile-menu-inner > a', dialog), {opacity: 0, yPercent: 40, duration: MOTION.durS, stagger: MOTION.durS / 4, clearProps: 'all', ...base}, MOTION.durM / 2);
  }
  function menuClose() {
    const dialog = $('#mobile-menu'); if (!dialog?.open || menuClosing) return;
    if (!menuAnimated()) { dialog.close(); return; }
    menuClosing = true; menuTimeline?.kill();
    const to = $('.menu-pill').getBoundingClientRect(), base = {ease: MOTION.ease};
    menuTimeline = gsap.timeline({onComplete: () => { menuClosing = false; dialog.close(); gsap.set([dialog, ...menuParts(dialog)], {clearProps: 'all'}); }})
      .to($('.mobile-menu-inner', dialog), {opacity: 0, duration: MOTION.durS, ...base}, 0)
      .to(dialog, {height: to.height, duration: MOTION.durM, ...base}, MOTION.durS / 2)
      .to(dialog, {width: to.width, duration: MOTION.durM, ...base}, MOTION.durM / 2);
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
    if(!slides.length)return;
    const signal=pageScope.signal,strip=$('.gallery-thumbnails');
    let pendingDesktopIndex=null,pendingMobileIndex=null,desktopFrame=0,resizeFrame=0,frameSettleTimer=0,framePointerDown=false,lastFrameHostWidth=0,lastFrameLimit=0,lastWidth=viewport.clientWidth,lastMobile=mobile();
    const galleryRoot=viewport.closest?.('.product-gallery'),detailRoot=viewport.closest?.('.product-detail');
    const attributeRatio=img=>{const w=Number(img?.getAttribute('width')),h=Number(img?.getAttribute('height'));return w>0&&h>0?w/h:0;};
    const photoImages=slides.filter(slide=>slide.classList.contains('gallery-photo')).map(slide=>$('img',slide)).filter(Boolean);
    const slotRatio=Math.max(...photoImages.map(attributeRatio),0) || .75;
    const fitDesktopFrame=(reanchor=false)=>{
      if(mobile()||!galleryRoot||!detailRoot)return;
      const set=(node,name,value)=>{if(node.style.getPropertyValue(name)!==value)node.style.setProperty(name,value);};
      set(detailRoot,'--desktop-max-media-ratio',String(slotRatio));
      const width=galleryRoot.clientWidth,limit=Number.parseFloat(getComputedStyle(viewport).maxHeight);
      if(!width||!Number.isFinite(limit)||limit<=0)return;
      lastFrameHostWidth=width;lastFrameLimit=limit;
      const slide=slides[index],img=$('img',slide),video=$('video',slide);
      const imageRatio=img?.naturalWidth>0&&img?.naturalHeight>0?img.naturalWidth/img.naturalHeight:attributeRatio(img);
      const videoRatio=video?.videoWidth>0&&video?.videoHeight>0?video.videoWidth/video.videoHeight:0;
      const posterRatio=photoImages[0]?.naturalWidth>0&&photoImages[0]?.naturalHeight>0?photoImages[0].naturalWidth/photoImages[0].naturalHeight:attributeRatio(photoImages[0]);
      const ratio=imageRatio || videoRatio || posterRatio || slotRatio;
      const reservedHeight=Math.min(limit,width/slotRatio),height=Math.min(reservedHeight,width/ratio);
      set(galleryRoot,'--desktop-reserved-height',`${reservedHeight}px`);
      set(viewport,'--desktop-frame-width',`${height*ratio}px`);
      set(viewport,'--desktop-frame-height',`${height}px`);
      if(reanchor && viewport.clientWidth!==lastWidth){
        cancelAnimationFrame(galleryFrame);galleryFrame=0;cancelAnimationFrame(desktopFrame);desktopFrame=0;
        lastWidth=viewport.clientWidth;lastMobile=false;
        viewport.scrollTo({left:desktopLeft(slides[index]),behavior:'instant'});
      }
    };
    const layoutChanged=()=>mobile()!==lastMobile || viewport.clientWidth!==lastWidth;
    const desktopLeft=slide=>Math.max(0,Math.min(viewport.scrollWidth-viewport.clientWidth,viewport.scrollLeft+slide.getBoundingClientRect().left-viewport.getBoundingClientRect().left-viewport.clientLeft));
    const nearest=()=>slides.reduce((best,slide,n)=>Math.abs(desktopLeft(slide)-viewport.scrollLeft)<Math.abs(desktopLeft(slides[best])-viewport.scrollLeft)?n:best,0);
    const mark=()=>{
      $$('[data-gallery-go]').forEach(b=>b.setAttribute('aria-current',String(Number(b.dataset.galleryGo)===index)));
      if(mobile()||!strip)return;
      const thumb=$(`[data-gallery-go="${index}"]`,strip);if(!thumb)return;
      const r=thumb.getBoundingClientRect(),s=strip.getBoundingClientRect(),left=s.left+strip.clientLeft,right=left+strip.clientWidth;
      if(r.left<left)strip.scrollLeft+=r.left-left;else if(r.right>right)strip.scrollLeft+=r.right-right;
    };
    const go=n=>{
      if(layoutChanged())realign();
      clearTimeout(frameSettleTimer);frameSettleTimer=0;
      index=(n+slides.length)%slides.length;mark();
      if(mobile()){pendingMobileIndex=index;viewport.scrollTo({left:slides[index].offsetLeft,behavior:reduced.matches?'instant':'smooth'});}
      else{pendingDesktopIndex=index;viewHistory.capture(true);viewport.scrollTo({left:desktopLeft(slides[index]),behavior:reduced.matches?'instant':'smooth'});}
    };
    if(mobile())viewport.scrollLeft=slides[0].offsetLeft;
    document.addEventListener('click',e=>{const b=e.target.closest('[data-gallery-go],[data-gallery-prev],[data-gallery-next]');if(!b)return;go(b.hasAttribute('data-gallery-go')?Number(b.dataset.galleryGo):index+(b.hasAttribute('data-gallery-next')?1:-1));},{signal:pageScope.signal});
    let galleryFrame=0; viewport.addEventListener('scroll',()=>{if(!mobile()||galleryFrame||layoutChanged())return;galleryFrame=requestAnimationFrame(()=>{galleryFrame=0;if(layoutChanged()){scheduleResize();return;}const width=slides[0].offsetWidth;if(!width)return;const next=(Math.round((viewport.scrollLeft-slides[0].offsetLeft)/width)+slides.length)%slides.length;if(next!==index){index=next;mark();}});},{passive:true,signal:pageScope.signal});pageScope.signal.addEventListener('abort',()=>cancelAnimationFrame(galleryFrame),{once:true});
    viewport.addEventListener('scrollend',()=>{if(mobile()&&viewport.scrollLeft<slides[0].offsetLeft-1)viewport.scrollTo({left:slides[index].offsetLeft,behavior:'instant'});},{signal:pageScope.signal});
    const syncDesktop=()=>{
      desktopFrame=0;if(mobile())return;
      if(layoutChanged()){scheduleResize();return;}
      if(pendingDesktopIndex!==null){if(Math.abs(viewport.scrollLeft-desktopLeft(slides[pendingDesktopIndex]))>1)return;pendingDesktopIndex=null;}
      index=nearest();mark();viewHistory.capture(false);scheduleFrameSettled();
    };
    const settleDesktopFrame=()=>{
      clearTimeout(frameSettleTimer);frameSettleTimer=0;
      if(mobile()||framePointerDown||layoutChanged()||pendingDesktopIndex!==null)return;
      const settled=nearest();if(Math.abs(viewport.scrollLeft-desktopLeft(slides[settled]))>1)return;
      index=settled;fitDesktopFrame(true);mark();viewHistory.capture(false);
    };
    const scheduleFrameSettled=()=>{if(mobile())return;clearTimeout(frameSettleTimer);frameSettleTimer=setTimeout(settleDesktopFrame,160);};
    viewport.addEventListener('scroll',()=>{if(!mobile()&&!desktopFrame)desktopFrame=requestAnimationFrame(syncDesktop);},{passive:true,signal});
    viewport.addEventListener('scrollend',()=>{if(!mobile()){if(layoutChanged()){scheduleResize();return;}if(pendingDesktopIndex!==null&&Math.abs(viewport.scrollLeft-desktopLeft(slides[pendingDesktopIndex]))>1)return;if(desktopFrame){cancelAnimationFrame(desktopFrame);desktopFrame=0;}syncDesktop();settleDesktopFrame();}},{signal});
    viewport.addEventListener('scrollend',()=>{if(mobile())pendingMobileIndex=null;},{signal});
    for(const type of ['wheel','pointerdown','touchstart'])viewport.addEventListener(type,()=>{if(mobile())pendingMobileIndex=null;else{pendingDesktopIndex=null;if(type==='pointerdown')framePointerDown=true;}},{passive:true,signal});
    for(const type of ['pointerup','pointercancel'])window.addEventListener(type,()=>{framePointerDown=false;scheduleFrameSettled();},{passive:true,capture:true,signal});
    viewport.addEventListener('martha:gallerycapture',event=>{
      if(layoutChanged()){event.detail.index=mobile()?(pendingMobileIndex ?? index):(pendingDesktopIndex ?? index);return;}
      const width=slides[0].offsetWidth;
      event.detail.index=mobile()?(pendingMobileIndex ?? (width?(Math.round((viewport.scrollLeft-slides[0].offsetLeft)/width)+slides.length)%slides.length:index)):(pendingDesktopIndex ?? nearest());
    },{signal});
    viewport.addEventListener('martha:galleryrestore',event=>{
      const detail=event.detail;if(detail.index<0||detail.index>=slides.length)return;
      detail.handled=true;if(!viewport.clientWidth)return;
      pendingDesktopIndex=null;pendingMobileIndex=null;index=detail.index;mark();
      const left=mobile()?slides[index].offsetLeft:desktopLeft(slides[index]);viewport.scrollTo({left,behavior:'instant'});detail.ready=Math.abs(viewport.scrollLeft-left)<=1;
    },{signal});
    const realign=()=>{
      const nowMobile=mobile();
      const hostChanged=!nowMobile&&galleryRoot&&(galleryRoot.clientWidth!==lastFrameHostWidth||Number.parseFloat(getComputedStyle(viewport).maxHeight)!==lastFrameLimit);
      if(nowMobile!==lastMobile||hostChanged)fitDesktopFrame();
      resizeFrame=0;const width=viewport.clientWidth;
      if(nowMobile===lastMobile && width===lastWidth)return;
      if(!width)return;
      const wasMobile=lastMobile;
      cancelAnimationFrame(galleryFrame);galleryFrame=0;cancelAnimationFrame(desktopFrame);desktopFrame=0;
      pendingDesktopIndex=null;pendingMobileIndex=null;
      lastMobile=nowMobile;lastWidth=width;
      if(!nowMobile)viewport.scrollTo({left:desktopLeft(slides[index]),behavior:'instant'});
      else if(!wasMobile)viewport.scrollLeft=slides[index].offsetLeft;
      mark();viewHistory.capture(false);
    };
    const scheduleResize=()=>{if(!resizeFrame)resizeFrame=requestAnimationFrame(realign);};
    window.addEventListener('resize',scheduleResize,{passive:true,signal});
    const sourceReady=event=>{if(slides[index].contains(event.target))scheduleFrameSettled();};
    viewport.addEventListener('load',sourceReady,{capture:true,signal});
    viewport.addEventListener('loadedmetadata',sourceReady,{capture:true,signal});
    const resize=window.ResizeObserver?new ResizeObserver(scheduleResize):null;resize?.observe(viewport);if(galleryRoot)resize?.observe(galleryRoot);
    fitDesktopFrame(true);lastWidth=viewport.clientWidth;
    signal.addEventListener('abort',()=>{clearTimeout(frameSettleTimer);cancelAnimationFrame(desktopFrame);cancelAnimationFrame(resizeFrame);resize?.disconnect();},{once:true});
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
  function heroCarousel() {
    const hero=$('[data-hero]'); if (!hero) return;
    const signal=pageScope.signal, slides=$$('.ho-slide',hero), dots=$$('.ho-dots button',hero), pause=$('[data-hero-pause]',hero), DUR=6000;
    const ICON={pause:'<svg viewBox="0 0 12 12" fill="currentColor" aria-hidden="true"><rect x="2" y="1" width="2.5" height="10"/><rect x="7.5" y="1" width="2.5" height="10"/></svg>',play:'<svg viewBox="0 0 12 12" fill="currentColor" aria-hidden="true"><path d="M3 1l8 5-8 5z"/></svg>'};
    let i=0, timer=0, paused=matchMedia('(prefers-reduced-motion: reduce)').matches, visible=true, focused=false;
    hero.style.setProperty('--dur',DUR+'ms');
    const schedule=()=>{ clearTimeout(timer); hero.classList.remove('run'); const label=paused?'Reproducir':'Pausar'; if (pause.getAttribute('aria-label')!==label||!pause.firstChild) { pause.innerHTML=paused?ICON.play:ICON.pause; pause.setAttribute('aria-label',label); } if (paused||!visible||focused||signal.aborted) return; void hero.offsetWidth; hero.classList.add('run'); timer=setTimeout(()=>go(i+1),DUR); };
    const go=n=>{ i=(n+slides.length)%slides.length; hero.style.setProperty('--i',i); slides.forEach((s,k)=>{s.toggleAttribute('data-active',k===i); s.inert=k!==i;}); dots.forEach((d,k)=>d.setAttribute('aria-current',String(k===i))); schedule(); };
    dots.forEach((d,k)=>d.addEventListener('click',()=>go(k),{signal}));
    pause.addEventListener('click',()=>{paused=!paused;schedule();},{signal});
    hero.addEventListener('keydown',e=>{ if (e.key==='ArrowRight') go(i+1); if (e.key==='ArrowLeft') go(i-1); },{signal});
    hero.addEventListener('focusin',()=>{focused=!!$(':focus-visible',hero);schedule();},{signal});
    hero.addEventListener('focusout',()=>{focused=false;schedule();},{signal});
    const io=window.IntersectionObserver?new IntersectionObserver(([e])=>{visible=e.isIntersecting;schedule();},{threshold:.4}):{observe(){},disconnect(){}}; io.observe(hero);
    signal.addEventListener('abort',()=>{clearTimeout(timer);io.disconnect();});
    let x0=null, dx=0, moved=false;
    hero.addEventListener('pointerdown',e=>{ if (e.button!==0||e.target.closest('.ho-dots,.ho-pause')) return; x0=e.clientX; dx=0; moved=false; },{signal});
    window.addEventListener('pointermove',e=>{ if (x0===null) return; dx=e.clientX-x0; if (!moved&&Math.abs(dx)>6) { moved=true; hero.classList.add('dragging'); } if (moved) hero.style.setProperty('--drag',dx+'px'); },{signal});
    window.addEventListener('pointerup',()=>{ if (x0===null) return; hero.classList.remove('dragging'); hero.style.setProperty('--drag','0px'); if (Math.abs(dx)>40) go(i+(dx<0?1:-1)); x0=null; },{signal});
    hero.addEventListener('click',e=>{ if (moved) { e.preventDefault(); e.stopPropagation(); moved=false; } },{capture:true,signal});
    go(0);
  }

  async function mountPage(focus = false) {
    mountJobs++;
    pageScope?.abort(); productObserver?.disconnect(); productObserver=null; pageScope = new AbortController(); stopMotion();
    const page = $('main')?.dataset.page;
    if (page === 'product') productShareControl();
    try {
      if (!products.length || ['catalog','product'].includes(page)) products=(await api('/api/catalog')).products.map(p=>({...p,...window.STORE_MEDIA?.[p.id]}));
      if (liveStore) currency = products.find(p => p.currency)?.currency || currency;
      await refreshCart(); updateHearts(); showPrices();
      if (page === 'catalog') {gridView();catalog();filterPanel();}
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
      if (page === 'home') heroCarousel();
      motion(); if (typeof focus==='function' ? focus() : focus) $('main')?.focus({preventScroll:true});
    } catch (error) { integrationError = error.message; blockCommerce(); showError($('main')||document.body,error); }
    finally { mountJobs--; }
  }
  document.addEventListener('click', async event => {
    const b = event.target.closest('button,a'); if (!b) return;
    if(b.matches('[data-category-tab]')){const params=new URLSearchParams(location.search);if(b.dataset.categoryTab)params.set('category',b.dataset.categoryTab);else params.delete('category');setCatalogParams(params);catalog();return;}
    if (b.matches('[data-product-share]')) { await shareProduct(b); return; }
    if (modeSwitching) { event.preventDefault(); return; }
    if(b.matches('[data-menu-toggle]')){menuOpen(b);return;}
    if (b.matches('[data-filters-open]')) {openDialog($('#filter-panel'),b);b.setAttribute('aria-expanded','true');$('[data-filters-close]').focus();return;}
    if (b.matches('[data-filters-close], [data-filters-apply]')) {$('#filter-panel').close();return;}
    if(b.matches('[data-location]')){openDialog($('#location-dialog'),b);return;}
    if(b.matches('[data-size-guide]')){openDialog($('#size-guide'),b);return;}
    if(b.matches('[data-filter-reset]')){const params=new URLSearchParams(location.search);for(const name of ['q','category','size','color','favoritos'])params.delete(name);setCatalogParams(params);catalog();return;}
    if(b.matches('[data-sort-toggle]')){const open=b.getAttribute('aria-expanded')!=='true';b.setAttribute('aria-expanded',String(open));$('#sort-options').hidden=!open;if(open)$('[data-sort]')?.focus();return;}
    if(b.matches('[data-sort]')){const params=new URLSearchParams(location.search);params.set('sort',b.dataset.sort);setCatalogParams(params);$('#sort-options').hidden=true;$('[data-sort-toggle]').setAttribute('aria-expanded','false');$('[data-sort-toggle]').focus();catalog();return;}
    if(b.matches('[data-carousel-prev],[data-carousel-next]')){const root=b.closest('.carousel-section,.carousel-wrap'),track=$('[data-carousel]',root);track?.scrollBy({left:(b.hasAttribute('data-carousel-next')?1:-1)*track.clientWidth,behavior:reduced.matches?'instant':'smooth'});return;}
    if (b.matches('[data-search-open]')) { openDialog($('#search-dialog'),b); $('#search-dialog input')?.focus(); return; }
    if (b.matches('[data-close-dialog]')) { const dialog=b.closest('dialog');if(dialog?.id==='mobile-menu'){menuClose();return;}if(dialog?.id==='newsletter-dialog')localStorage.setItem('martha-newsletter-dismissed','true');dialog?.close(); return; }
    if (b.matches('[data-zoom]')) { $('#image-dialog img').src=b.dataset.zoom || $('img',b)?.src; $('#image-dialog img').alt=window.MarthaI18n?.originalAttribute($('img',b),'alt') || $('img',b)?.alt || 'Fotografía ampliada'; openDialog($('#image-dialog'),b); return; }
    if (b.matches('[data-favorite]')) { const id=b.dataset.favorite; favorites=favorites.includes(id) ? favorites.filter(n=>n!==id):[...favorites,id]; localStorage.setItem('martha-favorites',JSON.stringify(favorites)); updateHearts(); { const icon = $('svg',b); pulse(icon || b, icon ? 1.2 : 1.04); } if (new URLSearchParams(location.search).has('favoritos')) catalog(); notify(favorites.includes(id)?'Prenda guardada en favoritos.':'Prenda retirada de favoritos.'); return; }
    if (b.matches('[data-clear-filters], [data-remove-filter]')) { event.preventDefault(); const params = new URLSearchParams(location.search); if (b.matches('[data-clear-filters]')) [...params.keys()].filter(k=>k!=='lang').forEach(k=>params.delete(k)); else params.delete(b.dataset.removeFilter); setCatalogParams(params); catalog(); return; }
    if (b.matches('[data-sticky-add]')) { const main=$('[data-add]');if(main&&!main.disabled)main.click();return; }
    if (b.matches('[data-quick]')) { const c=b.closest('.plp-card'), open=!c.classList.contains('picking'); $$('.plp-card.picking').forEach(closeQuick); if (open) { c.classList.add('picking'); b.setAttribute('aria-expanded','true'); $('[data-quick-size]:not(:disabled)',c)?.focus(); } return; }
    if (b.matches('[data-quick-size]')) { const c=b.closest('.plp-card'); b.dataset.selected=''; await withButton(b,async()=>{ try { cart=await api('/api/cart/items',{variant_id:b.dataset.quickSize,quantity:1}); await refreshCart(); closeQuick(c); notify('Prenda agregada a tu bolsa.'); miniBag(); } catch (error) { notify(error.message); } finally { b.removeAttribute('data-selected'); } }); return; }
    if (b.matches('[data-add]')) { let added=false; await withButton(b,async()=>{ const input=$('input[name="variant"]:checked:not(:disabled)'); if (!input) throw new Error('Elegí una talla para agregar esta prenda.'); cart=await api('/api/cart/items',{variant_id:input.value,quantity:1}); await refreshCart(); const note=$('[data-add-confirmation]'); if (note) { note.innerHTML=`Prenda agregada a tu bolsa. <a href="/bolsa.html">Ver bolsa</a>`; note.hidden=false; } notify('Prenda agregada a tu bolsa.');added=true;miniBag(b); }); if(added)markAdded(b); return; }
    if(b.matches('[data-move-favorite]')){const focus=cartActionFocus(b);await withButton(b,async()=>{if(!favorites.includes(b.dataset.product))favorites.push(b.dataset.product);localStorage.setItem('martha-favorites',JSON.stringify(favorites));cart=await api('/api/cart/items',{variant_id:b.dataset.moveFavorite,quantity:0},'PATCH');await refreshCart();renderCart();if($('#mini-bag')?.open)miniBag();updateHearts();focus();notify('Prenda guardada en favoritos y retirada de tu bolsa.');});return;}
    if (b.matches('[data-remove-item]')) { const focus=cartActionFocus(b);await withButton(b,async()=>{cart=await api('/api/cart/items',{variant_id:b.dataset.removeItem,quantity:0},'PATCH'); await refreshCart(); renderCart();if($('#mini-bag')?.open)miniBag();focus();notify('Prenda retirada de tu bolsa.');}); return; }
    if (b.matches('[data-checkout-back]')) { renderCheckout(b.dataset.checkoutBack,true); return; }
    if (b.matches('[data-recover-order]')) { await withButton(b,async()=>{ rememberOrder((await api('/api/orders',orderPayload())).order); renderCheckout(); }); return; }
    if (b.matches('[data-create-order]') && liveStore) { await withButton(b,placeLiveOrder); return; }
    if (b.matches('[data-create-order]')) { await withButton(b,async()=>{ checkout.quote_id=quote.id; checkout.order_key ||= uuid(); saveCheckout(); rememberOrder((await api('/api/orders',orderPayload())).order); renderCheckout('payment',true); }); return; }
    if (b.matches('[data-confirm-payment]')) { await withButton(b,async()=>{ const id=currentOrder?.id || checkout.order_id; if (!id) throw new Error('Revisá tu compra para crear el pedido primero.'); const result=await api(`/api/orders/${encodeURIComponent(id)}/payment`,{outcome:b.dataset.confirmPayment,idempotency_key:checkout.payment_key ||= uuid()}); currentOrder=result.order; sessionStorage.removeItem(sessionKey('checkout')); checkout={}; location.href='/pedido.html?id='+encodeURIComponent(id); }); return; }
    if (b.matches('[data-rebuild-order]')) { await withButton(b,async()=>{ const existing=await refreshCart(); for(const line of currentOrder.lines) {const qty=(existing.lines.find(l=>l.variant_id===line.variant_id)?.quantity || 0)+line.quantity; await api('/api/cart/items',{variant_id:line.variant_id,quantity:qty},'PATCH');} location.href='/bolsa.html';}); return; }
    if (b.matches('[data-admin-refresh]')) { await withButton(b,renderAdmin); return; }
    if (b.matches('[data-admin-logout]')) { await withButton(b,async()=>{await api('/api/admin/logout',{}); await renderAdmin();}); return; }
    if (b.matches('[data-receive-return]')) { await withButton(b,async()=>{await api(`/api/admin/orders/${b.dataset.order}/returns/${b.dataset.receiveReturn}/receive`,{}); await renderAdmin();}); return; }
    if (b.matches('[data-refund]')) { await withButton(b,async()=>{const id=b.dataset.refund; await api(`/api/admin/orders/${b.dataset.order}/refund`,{return_id:id,restock:!!$$('[data-restock]').find(input=>input.dataset.restock===id)?.checked}); await renderAdmin();}); return; }
    if (b.tagName === 'A') { viewHistory.capture(true); menuClose(); $('[data-menu-toggle]')?.setAttribute('aria-expanded','false'); if (b.closest('#search-dialog')) $('#search-dialog').close(); }
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
  function setCatalogParams(params) { clearTimeout(searchTimer); const url='/catalogo.html'+(params.size?'?'+params.toString():''); if(location.pathname+location.search!==url)viewHistory.push(url); }
  window.addEventListener('popstate',()=>{clearTimeout(searchTimer);if(location.pathname==='/catalogo.html'&&$('#catalog-filters')){catalog();viewHistory.sameDocument();}});
  window.addEventListener('pageshow',async event=>{
    if (!event.persisted) return;
    const resumeView = viewHistory.resumeSnapshot();
    // A restored, still-pending action must finish with its in-memory checkout/order.
    if (pendingApi || busyActions || mountJobs || modeSwitching) return;
    loadCheckout(); quote = null; currentOrder = null; products = []; await mountPage(); viewHistory.resume(resumeView);
  });
  function filterChange() { const form=$('#catalog-filters'); if (!form) return; const params=new URLSearchParams(location.search); for (const [key,value] of new FormData(form)) {if (value && !(key === 'sort' && value === 'selection')) params.set(key,value); else params.delete(key);} setCatalogParams(params); catalog(); }
  document.addEventListener('submit',async event=>{
    const form=event.target; if (modeSwitching) { event.preventDefault(); return; }
    if (form.id === 'catalog-filters') {event.preventDefault(); filterChange(); return;}
    if(form.matches('[data-newsletter]')){event.preventDefault();$('.newsletter-result',form).textContent=liveStore?'Las novedades por email todavía no están disponibles.':'Tu código: BIENVENIDA10.';localStorage.setItem('martha-newsletter-dismissed','true');return;}
    if (!form.matches('[data-checkout-form], [data-return-form], [data-admin-login], [data-fulfillment], [data-stock]')) return;
    event.preventDefault();if(form.dataset.checkoutForm&&!validate(form))return; const button=$('button[type="submit"],button:not([type])',form); const data=Object.fromEntries(new FormData(form));
    await withButton(button,async()=>{
      if (form.dataset.checkoutForm) {
        Object.assign(checkout,data); if(form.dataset.checkoutForm === 'contact') checkout.newsletter=!!form.elements.newsletter?.checked; saveCheckout();
        if (form.dataset.checkoutForm === 'contact') renderCheckout('delivery',true);
        else if (liveStore) renderCheckout('review',true);
        else {quote=await api('/api/quote',{delivery_zone:checkout.delivery_zone,coupon:checkout.coupon || ''}); checkout.order_key=uuid(); delete checkout.order_id; delete checkout.payment_key; saveCheckout(); renderCheckout('review',true);}
      } else if (form.matches('[data-return-form]')) {
        const lines=Object.entries(data).filter(([key,value])=>key.startsWith('return:')&&Number(value)>0).map(([key,value])=>({variant_id:key.slice(7),quantity:Number(value)}));
        if (!lines.length) throw new Error('Seleccioná al menos una prenda para devolver.');
        await api(`/api/orders/${currentOrder.id}/returns`,{lines,reason:data.reason}); await renderOrder(); notify('Solicitud de devolución guardada.');
      } else if(form.matches('[data-admin-login]')) {await api('/api/admin/login',{password:data.password}); form.reset(); await renderAdmin();}
      else if(form.dataset.fulfillment) {await api(`/api/admin/orders/${form.dataset.fulfillment}/fulfill`,data); await renderAdmin();}
      else if(form.dataset.stock) {await api('/api/admin/inventory',{variant_id:form.dataset.stock,quantity:Number(data.quantity),reason:data.reason}); await renderAdmin();}
    });
  });
  function syncCampaignViewport() {
    const height = $$('.language-bar, .site-header')
      .reduce((total, element) => total + element.getBoundingClientRect().height, 0);
    document.documentElement.style.setProperty('--store-chrome-height', `${Math.ceil(height)}px`);
    // Only the header stays sticky; the language row scrolls away.
    document.documentElement.style.setProperty('--header', `${Math.ceil(height)}px`);
    const stickyHeaderHeight = $('.site-header')?.getBoundingClientRect().height || 0;
    document.documentElement.style.setProperty('--store-sticky-header-height', `${Math.ceil(stickyHeaderHeight)}px`);
  }
  window.addEventListener('resize', syncCampaignViewport);
  if (window.ResizeObserver) {
    const chromeObserver = new ResizeObserver(syncCampaignViewport);
    $$('.language-bar, .site-header').forEach(element => chromeObserver.observe(element));
  }
  syncCampaignViewport();
  const reduced = matchMedia('(prefers-reduced-motion: reduce)'); reduced.addEventListener('change',motion);
  // Page transition: the next page mounts in a clipped window that grows from the bottom center over the still outgoing page.
  const HISTORY_FADE = .12; // existing back/forward fade (s), not a set-piece token
  function pageTransition() {
    let run = null;
    const wait = seconds => new Promise(resolve => setTimeout(resolve, seconds * 1000));
    const frames = count => new Promise(resolve => { const step = () => --count > 0 ? requestAnimationFrame(step) : resolve(); requestAnimationFrame(step); });
    const traversal = data => viewHistory.historyTrigger(data);
    const lock = (elements, on) => elements.forEach(element => element && (on ? element.setAttribute('inert','') : element.removeAttribute('inert')));
    const clip = (inset, radius) => `inset(${inset} round ${radius})`;
    function closeOverlays() {
      const menu = $('#mobile-menu');
      if (menu) {
        menuTimeline?.kill(); menuClosing = false; menu.returnFocus = null;
        if (menu.open) { menu.close(); if (window.gsap) gsap.set([menu, ...menuParts(menu)], {clearProps:'all'}); }
      }
      $$('[data-menu-toggle]').forEach(toggle => toggle.setAttribute('aria-expanded','false'));
      const search = $('#search-dialog'); if (search?.open) search.close();
    }
    async function decodeVisible(root) {
      const images = $$('img', root).filter(image => { const box = image.getBoundingClientRect(); return box.width > 0 && box.bottom > 0 && box.top < innerHeight; });
      images.forEach(image => { if (image.loading === 'lazy') image.loading = 'eager'; });
      await Promise.race([Promise.all(images.map(image => image.decode ? image.decode().catch(() => {}) : null)), wait(MOTION.durM)]);
    }
    // One frame: drop the outgoing page, return the next page to flow, reset the scroll.
    function swap() {
      if (!run || run.swapped) return;
      run.swapped = true;
      if (run.current !== run.next) run.current.remove();
      if (run.holder?.isConnected) run.holder.replaceWith(run.next);
      document.documentElement.removeAttribute('data-page-transition');
      if (!traversal(run.data)) window.scrollTo({top:0, left:0, behavior:'instant'});
      lock(run.locked, false);
    }
    function cleanup() {
      if (!run) return;
      if (run.holder) swap();
      lock(run.locked, false); document.documentElement.removeAttribute('data-page-transition');
      run.ctx?.revert(); outgoing = null; run = null;
    }
    return {
      name: 'editorial',
      beforeLeave(data) {
        run = {data, current: data.current.container, next: null, holder: null, ctx: null, swapped: false, windowed: !!window.gsap && !reduced.matches && !traversal(data), locked: []};
        closeOverlays();
        run.locked = [run.current, $('.site-header'), $('.menu-pill')];
        lock(run.locked, true);
      },
      async leave(data) {
        viewHistory.begin(data); stopMotion();
        if (window.gsap && !reduced.matches && traversal(data)) await gsap.to(data.current.container, {opacity:0, duration:HISTORY_FADE});
      },
      async beforeEnter(data) {
        const current = data.current.container, next = data.next.container;
        try {
          if (!run?.windowed) { if (current !== next) current.remove(); await mountPage(false); return; }
          run.next = next;
          const holder = run.holder = document.createElement('div');
          holder.className = 'page-window';
          next.before(holder); holder.append(next);
          document.documentElement.setAttribute('data-page-transition','');
          outgoing = current;
          const mounted = mountPage(false).catch(() => {}).finally(() => { outgoing = null; });
          await Promise.race([mounted, wait(MOTION.durL * 3)]);
          window.MarthaI18n?.apply(next);
          await decodeVisible(next);
          await Promise.race([frames(2), wait(MOTION.durS)]);
        } catch (error) { console.error(error); swap(); }
      },
      async enter(data) {
        if (!run?.holder) { if (!traversal(data)) window.scrollTo(0,0); return; }
        try {
          if (run.swapped) return;
          const holder = run.holder;
          const done = new Promise(resolve => { run.ctx = gsap.context(() => { gsap.fromTo(holder, {clipPath: clip('100% 50% 0% 50%', MOTION.radius)}, {clipPath: clip('0% 0% 0% 0%', '0px'), duration: MOTION.durL, ease: MOTION.ease, onComplete: resolve}); }); });
          await Promise.race([done, wait(MOTION.durL * 3)]);
        } catch (error) { console.error(error); }
        swap();
      },
      after(data) {
        const main = $('main'), active = document.activeElement;
        if (main && (viewHistory.shouldFocus(data) || !active || active === document.body || !active.isConnected)) main.focus({preventScroll:true});
        viewHistory.finish(data);
        cleanup();
      }
    };
  }
  if (window.barba && $('[data-barba="container"]')) {
    const editorial = /^\/(?:index|catalogo|producto-[a-z0-9-]+)\.html$|^\/$/;
    barba.init({timeout:4000,preventRunning:true,prevent:({href,el})=>{const url=new URL(href,location.href);return el.hasAttribute('data-barba-prevent')||url.origin!==location.origin||!editorial.test(url.pathname)||!['home','catalog','product'].includes($('main')?.dataset.page);},transitions:[pageTransition()]});
  }
  const mega=$('#mega-menu'),trigger=$('[data-mega-trigger]'),header=$('.site-header');
  const toggleMega=open=>{if(!mega)return;mega.hidden=!open;trigger?.setAttribute('aria-expanded',String(open));};
  trigger?.addEventListener('mouseenter',()=>toggleMega(true));trigger?.addEventListener('focus',()=>toggleMega(true));
  header?.addEventListener('mouseleave',()=>toggleMega(false));header?.addEventListener('focusout',e=>{if(!header.contains(e.relatedTarget))toggleMega(false);});
  document.addEventListener('keydown',e=>{const menu=$('#sort-options');if(menu&&!menu.hidden&&['ArrowDown','ArrowUp','Home','End'].includes(e.key)){e.preventDefault();const items=$$('[data-sort]',menu),i=items.indexOf(document.activeElement);items[e.key==='Home'?0:e.key==='End'?items.length-1:(i+(e.key==='ArrowDown'?1:-1)+items.length)%items.length]?.focus();}if(e.key==='Escape'){toggleMega(false);if(menu&&!menu.hidden)$('[data-sort-toggle]')?.focus();menu?.setAttribute('hidden','');$('[data-sort-toggle]')?.setAttribute('aria-expanded','false');}});
  document.addEventListener('pointerover',e=>{const video=e.target.closest('.product-image')?.querySelector('video');if(video&&matchMedia('(hover:hover) and (min-width:1024px)').matches)playVideo(video);});
  document.addEventListener('pointerout',e=>{const image=e.target.closest('.product-image');if(image&&!image.contains(e.relatedTarget))image.querySelector('video')?.pause();});
  document.addEventListener('click',e=>{if(!e.target.closest('.sort-field')){$('#sort-options')?.setAttribute('hidden','');$('[data-sort-toggle]')?.setAttribute('aria-expanded','false');}});
  $$('dialog').forEach(d=>{d.addEventListener('cancel',()=>{if(d.id==='newsletter-dialog')localStorage.setItem('martha-newsletter-dismissed','true');});d.addEventListener('click',e=>{if(e.target===d){const r=d.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom){if(d.id==='newsletter-dialog')localStorage.setItem('martha-newsletter-dismissed','true');d.id==='mobile-menu'?menuClose():d.close();}}});});
  $('#mobile-menu')?.addEventListener('cancel',event=>{event.preventDefault();menuClose();});
  matchMedia('(min-width:1024px)').addEventListener?.('change',event=>{if(event.matches){menuTimeline?.kill();menuClosing=false;$('#mobile-menu')?.close();}});
  // Tab title: away message while the tab is hidden; the saved title returns only if the away title still shows.
  let tabSaved = null, tabAway = '';
  function tabTitle() {
    if (document.hidden) {
      const en = String(window.MarthaI18n?.language || document.documentElement.lang).toLowerCase().startsWith('en');
      tabAway = (cart?.lines?.length ? en ? 'Your bag is waiting' : 'Tu bolsa te espera' : en ? 'Come back soon' : 'Vuelve pronto') + ' · MARTHA SILVA';
      if (document.title !== tabAway) { tabSaved = document.title; document.title = tabAway; }
    } else if (tabSaved !== null) {
      if (document.title === tabAway) document.title = tabSaved;
      tabSaved = null;
    }
  }
  navigator.connection?.addEventListener('change',videoMotion);
  document.addEventListener('visibilitychange',videoMotion);
  document.addEventListener('visibilitychange',tabTitle);
  viewHistory.activate();
  initLoader();
  mountPage().then(()=>viewHistory.initialMount());


})();


/* ADDITIVE SUPPORT ILLUSTRATIONS: no original A code changed. */
/* Isolated additive module. Install globally only after the exact current shell/build is restored. */
(() => {
  'use strict';
  if (window.MarthaSupportingIllustrations) return;
  const allowed = Object.freeze({
    'blanco-perlado-sirena':'/generated-illustrations/blanco-perlado-sirena-g1-gen-001-48170acd71bf.png',
    'rosa-empolvado-pedreria':'/generated-illustrations/rosa-empolvado-pedreria-g1-gen-001-8e13cba8e436.png'
  });
  const selector = '[data-ai-support-illustration]';
  let lastLanguage = null;
  const language = () => (window.MarthaI18n?.language || document.documentElement.lang).toLowerCase().startsWith('en') ? 'en' : 'es';
  function validImage(img) {
    if (!img?.matches?.('img[data-ai-support-image]')) return null;
    const section = img.closest(selector), id = section?.dataset.aiProduct;
    if (!id || section.closest('main[data-product-id]')?.dataset.productId !== id) return null;
    try { const url = new URL(img.getAttribute('src'),location.href); return url.origin === location.origin && url.pathname === allowed[id] ? section : null; }
    catch { return null; }
  }
  function imageState(img, failed) {
    const section = validImage(img); if (!section) return;
    const notice = section.querySelector('[data-ai-support-load-error]');
    if (img.hidden !== failed) img.hidden = failed;
    if (notice && notice.hidden !== !failed) notice.hidden = !failed;
    const state = failed ? 'failed' : 'ready';
    if (section.dataset.aiImageState !== state) section.dataset.aiImageState = state;
  }
  function refresh(root = document) {
    const sections = [...(root.matches?.(selector) ? [root] : []), ...(root.querySelectorAll?.(selector) || [])];
    const lang = language(); lastLanguage = lang;
    for (const section of sections) {
      const img = section.querySelector('img[data-ai-support-image]');
      if (!validImage(img)) continue;
      if (section.dataset.aiLanguage !== lang) section.dataset.aiLanguage = lang;
      section.querySelectorAll('[data-ai-lang]').forEach(node => { const hidden = node.dataset.aiLang !== lang; if (node.hidden !== hidden) node.hidden = hidden; });
      const alt = img.getAttribute(lang === 'en' ? 'data-ai-alt-en' : 'data-ai-alt-es') || img.alt;
      if (img.alt !== alt) img.alt = alt;
      if (img.complete) imageState(img, !img.naturalWidth);
    }
  }
  // Enhance only the two supporting-image reference links. Keep their native
  // anchor fallback, but normal activation does not create a hash history entry.
  document.addEventListener('click',event => {
    if (event.defaultPrevented || event.button > 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const link = event.target.closest?.('[data-ai-support-illustration] > a[href="#main"]');
    const section = link?.closest(selector);
    if (!section || !validImage(section.querySelector('img[data-ai-support-image]'))) return;
    const main = section.closest('main#main[tabindex="-1"]'), gallery = main?.querySelector('.product-gallery');
    if (!gallery || typeof gallery.scrollIntoView !== 'function') return;
    event.preventDefault();
    main.focus({preventScroll:true});
    gallery.scrollIntoView({block:'start',behavior:'instant'});
    window.MarthaViewHistory?.capture(true);
  });
  document.addEventListener('error',event => imageState(event.target,true),true);
  document.addEventListener('load',event => imageState(event.target,false),true);
  window.addEventListener('martha:languagechange',() => refresh());
  const observer = new MutationObserver(records => {
    for (const record of records) {
      if (record.type === 'attributes') {
        if (record.target === document.documentElement && language() !== lastLanguage) refresh();
        continue;
      }
      record.addedNodes.forEach(node => { if (node.nodeType === 1) refresh(node); });
    }
  });
  observer.observe(document.documentElement,{subtree:true,childList:true,attributes:true,attributeFilter:['lang']});
  window.MarthaSupportingIllustrations = Object.freeze({refresh});
  refresh();
})();

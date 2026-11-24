/* Integration models for the storefront. Local models keep cart, orders and stock in this
   browser. The live model reads prices and stock from the SAVIA hub and places real orders
   there; it is on only when the build sets apiBase. No CGA endpoint or credential exists. */
(function (root) {
  'use strict';
  // prepare.py replaces this line with the settings in site.config.json; the empty value keeps the local store.
  const CONFIG = {"apiBase":"","turnstileSiteKey":"","skus":{}};
  const MODES = Object.freeze(['savia', 'sisfain']);
  const record = x => !!x && typeof x === 'object' && !Array.isArray(x);
  const own = (x, key) => Object.prototype.hasOwnProperty.call(x, key);
  const fail = (code, message, details = {}) => { const error = new Error(message); Object.assign(error, {code}, details); throw error; };
  const freeze = object => { Object.values(object).forEach(value => { if (record(value) || Array.isArray(value)) freeze(value); }); return Object.freeze(object); };
  const provenance = (mode, kind) => ({integration_id:mode, data_kind:kind, data_origin:'browser', authoritative:false, real_orders:false});
  const DESCRIPTORS = freeze({
    savia: {
      id:'savia', label:'SAVIA', fullName:'Sistema de Administración, Ventas, Inventarios y Abastecimiento',
      status:'local', connectionStatus:'unconfigured', storageNamespace:'martha-integration-v1:savia:',
      capabilities:{catalog:true, localCart:true, localOrders:true, httpAdapter:true, externalInventory:false, externalReservations:false, realOrders:false, payments:false},
      notice:'SAVIA: catálogo y pedidos en este navegador.'
    },
    sisfain: {
      id:'sisfain', label:'SISFAIN (CGA)', fullName:'SISFAIN de CGA',
      status:'local', connectionStatus:'unconfigured', storageNamespace:'martha-integration-v1:sisfain:',
      capabilities:{catalog:true, localCart:true, localOrders:true, httpAdapter:false, externalInventory:false, externalReservations:false, realOrders:false, payments:false},
      notice:'SISFAIN (CGA): catálogo y pedidos en este navegador; sin conexión con CGA.'
    }
  });
  function getDescriptor(mode) {
    if (!MODES.includes(mode)) fail('unknown_integration', 'Esta operación no está disponible.');
    return DESCRIPTORS[mode];
  }
  const realOrderBlocked = async () => fail('real_orders_disabled', 'Esta operación no está disponible.');
  function scopedId(scope, value) { return scope + '~' + value; }
  function unscopedId(scope, value) {
    if (typeof value !== 'string' || !value.startsWith(scope + '~') || !value.slice(scope.length + 1) || /[~/?#]/.test(value.slice(scope.length + 1))) {
      fail('integration_mismatch', 'Esta referencia no es válida.');
    }
    return value.slice(scope.length + 1);
  }
  function checkOptionalScope(value, mode) {
    if (!record(value)) return;
    if ((own(value, 'integration_id') && value.integration_id !== mode) ||
        (own(value, 'data_kind') && value.data_kind !== 'local')) {
      fail('integration_mismatch', 'La operación no es válida.');
    }
    if (value.real_orders === true || value.authoritative === true) {
      fail('real_orders_disabled', 'Esta operación no está disponible.');
    }
    if (Array.isArray(value.lines)) value.lines.forEach(line => checkOptionalScope(line, mode));
  }
  function localCatalog(response, mode) {
    return {
      ...provenance(mode, 'local'),
      products:response.products.map(product => ({
        id:product.id, name:product.name,
        variants:product.variants.map(variant => ({
          id:variant.id, sku:typeof variant.sku === 'string' ? variant.sku : null,
          unit_price_minor:product.price_minor, currency:product.currency,
          available_quantity:variant.stock
        }))
      }))
    };
  }
  function createLocalAdapter({mode, catalog, storage, createStoreApi} = {}) {
    const descriptor = getDescriptor(mode);
    if (typeof createStoreApi !== 'function') fail('missing_store_factory', 'No se cargó la compra. Recargá la página.');
    if (!Array.isArray(catalog) && !(record(catalog) && Array.isArray(catalog.products))) fail('missing_catalog', 'No se cargó el catálogo. Recargá la página.');
    // Never read or migrate legacy/unscoped state. Recovery backups inherit the
    // same prefix. Browser storage is editable and is not a security boundary.
    const scopedStorage = storage ? {
      getItem:key => storage.getItem(descriptor.storageNamespace + key),
      setItem:(key, value) => storage.setItem(descriptor.storageNamespace + key, value)
    } : undefined;
    const local = createStoreApi(catalog, scopedStorage);
    const tags = provenance(mode, 'local');
    const tagLines = value => Array.isArray(value.lines) ? {...value, lines:value.lines.map(line => ({...line, ...tags}))} : value;
    const tagReturn = value => ({...tagLines(value), id:scopedId(mode, value.id), ...tags});
    const tagOrder = value => ({...tagLines(value), id:scopedId(mode, value.id), ...(value.quote_id ? {quote_id:scopedId(mode, value.quote_id)} : {}), returns:value.returns.map(tagReturn), ...tags});
    const api = async (path, body, method) => {
      checkOptionalScope(body, mode);
      let internalPath = path, internalBody = record(body) ? {...body} : body;
      if (record(internalBody)) {
        for (const key of ['quote_id', 'return_id']) {
          if (own(internalBody, key)) internalBody[key] = unscopedId(mode, internalBody[key]);
        }
      }
      // Opaque mode-prefixed IDs prevent an old order URL, checkout quote or
      // return form from being interpreted in another model, even on collision.
      if (typeof path === 'string') {
        internalPath = path.replace(/^(\/api\/(?:admin\/)?orders\/)([^/]+)/, (_, prefix, id) => {
          let decoded;
          try { decoded = decodeURIComponent(id); } catch { fail('integration_mismatch', 'Referencia de pedido inválida.'); }
          return prefix + unscopedId(mode, decoded);
        }).replace(/(\/returns\/)([^/]+)(\/receive)$/, (_, prefix, id, suffix) => {
          let decoded;
          try { decoded = decodeURIComponent(id); } catch { fail('integration_mismatch', 'Referencia de devolución inválida.'); }
          return prefix + unscopedId(mode, decoded) + suffix;
        });
      }
      const run = () => local(internalPath, internalBody, method);
      const response = await (root.navigator?.locks?.request ? root.navigator.locks.request(descriptor.storageNamespace + 'lock', run) : run());
      let result = {...tagLines(response), ...tags};
      if (path === '/api/quote' && own(result, 'id')) result.id = scopedId(mode, result.id);
      if (response.order) result.order = tagOrder(response.order);
      if (response.orders) result.orders = response.orders.map(tagOrder);
      if (response.return) result.return = tagReturn(response.return);
      return result;
    };
    Object.assign(api, {mode, descriptor, reset:() => local.reset(), readCatalog:async () => localCatalog(await api('/api/catalog'), mode), createRealOrder:realOrderBlocked});
    return api;
  }

  // Messages map hub problem codes, never hub prose, so both languages stay authored here.
  const LIVE_MESSAGES = {
    price_changed:'El precio de una prenda cambió. Revisá el nuevo total antes de confirmar.',
    rate_limited:'Hiciste muchos intentos seguidos. Esperá un minuto e intentá otra vez.',
    turnstile_failed:'No pudimos verificar que sos una persona. Completá la verificación otra vez.',
    validation:'Revisá tus datos: falta información o un campo es demasiado largo.',
    payload_too_large:'Revisá tus datos: falta información o un campo es demasiado largo.',
    too_many_unpaid:'Tenés pedidos sin pagar. Completá su pago o esperá a que venzan.',
    provider_unavailable:'Esa forma de pago no está disponible.',
    not_found:'No encontramos ese pedido en este navegador.',
    network:'No pudimos conectar con la tienda. Revisá tu conexión e intentá otra vez.',
    unavailable:'La tienda no pudo procesar tu pedido. Intentá otra vez en unos minutos.'
  };
  const LIVE_NAMESPACE = 'martha-live-v1:';
  // The hub labels the manual provider with this exact text (savia/src/Savia.Api/Payments.cs).
  const MANUAL_PROVIDER = Object.freeze({code:'manual', label:'Pago manual (no es tarjeta)'});
  function liveFail(code, details = {}) { fail(code, LIVE_MESSAGES[code] || LIVE_MESSAGES.unavailable, details); }
  /* Prices, stock and orders come only from the hub. A storefront variant without a hub SKU,
     or a SKU the hub does not list, is not for sale: nothing here invents a price or stock. */
  function createLiveAdapter({config = CONFIG, catalog, storage, fetch:request = root.fetch && root.fetch.bind(root), uuid = () => root.crypto.randomUUID()} = {}) {
    if (!record(catalog) || !Array.isArray(catalog.products)) fail('missing_catalog', 'No se cargó el catálogo. Recargá la página.');
    if (typeof request !== 'function') liveFail('network');
    const base = String(config.apiBase).replace(/\/+$/, '');
    const skus = record(config.skus) ? config.skus : {};
    const byVariant = new Map(), bySku = new Map();
    for (const product of catalog.products) for (const variant of product.variants) {
      byVariant.set(variant.id, {product, variant});
      if (typeof skus[variant.id] === 'string') bySku.set(skus[variant.id], variant.id);
    }
    // Without browser storage the cart and order tokens last for this page only.
    const memory = new Map();
    const store = storage || {getItem:key => memory.has(key) ? memory.get(key) : null, setItem:(key, value) => memory.set(key, String(value))};
    const read = (key, fallback) => { try { return JSON.parse(store.getItem(LIVE_NAMESPACE + key)) ?? fallback; } catch { return fallback; } };
    const write = (key, value) => { try { store.setItem(LIVE_NAMESPACE + key, JSON.stringify(value)); } catch {} };
    const itemName = variantId => { const found = byVariant.get(variantId); return found ? `${found.product.name}, talla ${found.variant.size}` : 'una prenda de tu bolsa'; };
    const outOfStock = (variantId, details = {}) => fail('out_of_stock', `Ya no hay suficiente existencia de ${itemName(variantId)}.`, details);
    let hub = null;
    async function call(path, {method = 'GET', body, headers = {}, fresh = false} = {}) {
      let response;
      try {
        response = await request(base + path, {method, credentials:'omit', cache:fresh || method !== 'GET' ? 'no-store' : 'default',
          headers:body === undefined ? headers : {'Content-Type':'application/json', ...headers},
          body:body === undefined ? undefined : JSON.stringify(body)});
      } catch { liveFail('network', {ambiguous:true}); }
      let data = null;
      try { data = await response.json(); } catch {}
      if (response.ok && record(data)) return data;
      const code = record(data) && typeof data.code === 'string' ? data.code : '';
      if (code === 'out_of_stock') outOfStock(bySku.get(data.sku), {sku:data.sku});
      if (response.status === 429) liveFail('rate_limited');
      liveFail(LIVE_MESSAGES[code] ? code : 'unavailable', {ambiguous:response.status >= 500 || !code});
    }
    async function loadHub(fresh = false) {
      const data = await call('/api/v1/public/catalog', {fresh});
      if (!Array.isArray(data.items)) liveFail('unavailable');
      hub = new Map(data.items.filter(item => record(item) && typeof item.sku === 'string' && Number.isSafeInteger(item.unitPriceMinor)
        && item.unitPriceMinor >= 0 && typeof item.currency === 'string').map(item => [item.sku, item]));
    }
    const offer = variantId => hub?.get(skus[variantId]) || null;
    const available = variantId => { const item = offer(variantId); return item && Number.isSafeInteger(item.available) ? Math.max(0, item.available) : 0; };
    function products() {
      return catalog.products.map(product => {
        const offers = product.variants.map(variant => offer(variant.id)).filter(Boolean);
        return {...product, price_minor:offers.length ? Math.min(...offers.map(item => item.unitPriceMinor)) : null, currency:offers[0]?.currency || null,
          variants:product.variants.map(variant => ({...variant, sku:skus[variant.id] || null, stock:available(variant.id), coming_soon:false}))};
      });
    }
    const storedCart = () => { const value = read('cart', {}); return record(value) ? value : {}; };
    function cart() {
      const lines = Object.entries(storedCart()).filter(([id, quantity]) => offer(id) && byVariant.has(id) && Number.isSafeInteger(quantity) && quantity > 0).map(([id, quantity]) => {
        const {product, variant} = byVariant.get(id), price = offer(id).unitPriceMinor;
        return {product_id:product.id, variant_id:id, sku:skus[id], name:product.name, color:product.color, size:variant.size, image:product.images[0],
          quantity, available:available(id), unit_price_minor:price, price_minor:price, line_total_minor:price * quantity};
      });
      return {lines, subtotal_minor:lines.reduce((sum, line) => sum + line.line_total_minor, 0), currency:lines.length ? offer(lines[0].variant_id).currency : null, mode:'live'};
    }
    function setQuantity(body, add) {
      if (!record(body) || !byVariant.has(body.variant_id)) fail('unknown_variant', 'Esta talla no existe en el catálogo.');
      const current = storedCart(), quantity = (add ? current[body.variant_id] || 0 : 0) + body.quantity;
      if (!Number.isInteger(body.quantity) || quantity < 0 || quantity > 10) fail('invalid_quantity', 'La cantidad debe ser un número entero entre 0 y 10.');
      if (quantity > available(body.variant_id)) fail('insufficient_stock', 'No hay suficientes unidades de esta talla.');
      if (quantity) current[body.variant_id] = quantity; else delete current[body.variant_id];
      write('cart', current);
      return cart();
    }
    function orderView(id, saved, status) {
      const shipping = Number.isSafeInteger(saved.shipping_minor) ? saved.shipping_minor : undefined;
      const lines = (Array.isArray(status.lines) ? status.lines : []).map(line => {
        const found = byVariant.get(bySku.get(line.sku)), price = saved.lines?.find(item => item.sku === line.sku)?.unit_price_minor;
        return {product_id:found?.product.id || '', variant_id:found?.variant.id || line.sku, sku:line.sku, name:found?.product.name || line.sku, color:found?.product.color || '',
          size:found?.variant.size || '', image:found?.product.images[0] || '', quantity:line.qty, line_total_minor:Number.isSafeInteger(price) ? price * line.qty : null};
      });
      // Only the hub's own amounts: its total can include tax that the catalog prices leave out.
      return {id, code:status.code, status:status.status, currency:status.currency, total_minor:status.totalMinor, shipping_minor:shipping,
        expires_at:status.expiresAt, payment:saved.payment || null, lines};
    }
    /* One Idempotency-Key per checkout attempt. The key stays with the exact body until the hub
       answers with an order, so a retry after a lost response replays that order instead of
       placing a second one. The key derives the order token on the hub: it is never logged. */
    async function placeOrder(input) {
      if (!record(input)) liveFail('validation');
      await loadHub(true);
      const stored = storedCart();
      for (const id of Object.keys(stored)) if (!offer(id)) outOfStock(id);
      const current = cart();
      if (!current.lines.length) fail('empty_cart', 'Tu bolsa está vacía.');
      if (current.lines.some(line => input.prices?.[line.variant_id] !== line.unit_price_minor)) liveFail('price_changed');
      const body = {lines:current.lines.map(line => ({sku:line.sku, qty:line.quantity})),
        contact:{name:input.contact?.name, email:input.contact?.email, ...(input.contact?.phone ? {phone:input.contact.phone} : {})},
        shipping:{zone:input.shipping?.zone, address:input.shipping?.address, city:input.shipping?.city},
        provider:input.provider, locale:input.locale === 'en' ? 'en' : 'es'};
      const signature = JSON.stringify(body), pending = read('pending', null);
      const key = record(pending) && pending.body === signature && typeof pending.key === 'string' ? pending.key : uuid();
      write('pending', {key, body:signature});
      const data = await call('/api/v1/public/orders', {method:'POST', headers:{'Idempotency-Key':key},
        body:input.turnstileToken ? {...body, turnstileToken:input.turnstileToken} : body});
      const orders = read('orders', {}), saved = {token:data.accessToken, code:data.code, shipping_minor:data.shippingMinor, payment:data.payment || null,
        lines:current.lines.map(line => ({sku:line.sku, unit_price_minor:line.unit_price_minor}))};
      orders[data.orderId] = saved;
      write('orders', orders);
      write('pending', null);
      write('cart', {});
      return {order:orderView(data.orderId, saved, {code:data.code, status:data.status, totalMinor:data.totalMinor, currency:data.currency, expiresAt:data.expiresAt, lines:body.lines})};
    }
    async function readOrder(id) {
      const saved = read('orders', {})[id];
      if (!record(saved) || typeof saved.token !== 'string') liveFail('not_found');
      return {order:orderView(id, saved, await call(`/api/v1/public/orders/${encodeURIComponent(id)}`, {fresh:true, headers:{'X-Order-Token':saved.token}}))};
    }
    const api = async (path, body, method = body === undefined ? 'GET' : 'POST') => {
      const verb = String(method).toUpperCase();
      if (path === '/api/catalog' && verb === 'GET') { await loadHub(); return {products:products(), mode:'live'}; }
      if (path === '/api/cart' && verb === 'GET') { if (!hub) await loadHub(); return cart(); }
      if (path === '/api/cart/items' && (verb === 'POST' || verb === 'PATCH')) { if (!hub) await loadHub(); return setQuantity(body, verb === 'POST'); }
      if (path === '/api/orders' && verb === 'POST') return placeOrder(body);
      const match = typeof path === 'string' && verb === 'GET' && path.match(/^\/api\/orders\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/i);
      if (match) return readOrder(match[1].toLowerCase());
      fail('unsupported_route', 'Esta acción no está disponible.');
    };
    Object.assign(api, {mode:'live', providers:[MANUAL_PROVIDER], turnstileSiteKey:String(config.turnstileSiteKey || '')});
    return api;
  }

  const exported = Object.freeze({MODES, getDescriptor, createLocalAdapter, createLiveAdapter, config:freeze(CONFIG), live:!!CONFIG.apiBase});
  if (typeof module === 'object' && module.exports) module.exports = exported;
  root.MarthaIntegrations = exported;
})(typeof window !== 'undefined' ? window : globalThis);

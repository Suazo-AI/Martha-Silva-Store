/* Contract test harness for the SAVIA .NET HTTP backend (synthetic XXX contract).
   Not shipped with the storefront build. */
(function (root) {
  'use strict';
  const base = typeof require === 'function' ? require('./integration-adapters.js') : root.MarthaIntegrations;
  const {getDescriptor} = base;
  const record = x => !!x && typeof x === 'object' && !Array.isArray(x);
  const own = (x, key) => Object.prototype.hasOwnProperty.call(x, key);
  const fail = (code, message, details = {}) => { const error = new Error(message); Object.assign(error, {code}, details); throw error; };
  const freeze = object => { Object.values(object).forEach(value => { if (record(value) || Array.isArray(value)) freeze(value); }); return Object.freeze(object); };
  const provenance = (mode, kind) => ({integration_id:mode, data_kind:kind, data_origin:'savia_synthetic_http', authoritative:false, real_orders:false});
  const realOrderBlocked = async () => fail('real_orders_disabled', 'Esta operación no está disponible.');
  function scopedId(scope, value) { return scope + '~' + value; }
  function unscopedId(scope, value) {
    if (typeof value !== 'string' || !value.startsWith(scope + '~') || !value.slice(scope.length + 1) || /[~/?#]/.test(value.slice(scope.length + 1))) {
      fail('integration_mismatch', 'Esta referencia no es válida.');
    }
    return value.slice(scope.length + 1);
  }
  function requireScope(value, mode, kind) {
    if (!record(value) || value.integration_id !== mode || value.data_kind !== kind) {
      fail('integration_mismatch', 'La operación no es válida.');
    }
  }
  // Canonical catalog: {integration_id,data_kind,data_origin,authoritative:false,
  // real_orders:false,products:[{id,name,variants:[{id,sku,unit_price_minor,
  // currency,available_quantity}]}]}. No guessed image, size or USD mapping is
  // created for the HTTP fixtures, whose GUIDs differ from storefront slugs.
  const GUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const isGuid = value => typeof value === 'string' && GUID.test(value) && value !== '00000000-0000-0000-0000-000000000000';
  const integer = (value, max) => Number.isSafeInteger(value) && value >= 0 && value <= max;
  const closed = (value, keys) => record(value) && Object.keys(value).length === keys.length && keys.every(key => own(value, key));
  const scope = 'savia-synthetic';
  function validateCatalog(value) {
    const productIds = new Set(), variantIds = new Set();
    if (!closed(value, ['synthetic', 'items']) || value.synthetic !== true || !Array.isArray(value.items)) return false;
    return value.items.every(product => {
      if (!closed(product, ['productId', 'name', 'variants']) || !isGuid(product.productId) || typeof product.name !== 'string' || !Array.isArray(product.variants)) return false;
      const productId = product.productId.toLowerCase();
      if (productIds.has(productId)) return false;
      productIds.add(productId);
      return product.variants.every(variant => {
        if (!closed(variant, ['variantId', 'sku', 'unitPriceMinor', 'currency', 'availableQuantity']) || !isGuid(variant.variantId) || typeof variant.sku !== 'string' || !integer(variant.unitPriceMinor, 9000000000000) || variant.currency !== 'XXX' || !integer(variant.availableQuantity, Number.MAX_SAFE_INTEGER)) return false;
        const variantId = variant.variantId.toLowerCase();
        if (variantIds.has(variantId)) return false;
        variantIds.add(variantId);
        return true;
      });
    });
  }
  function validateOrder(value) {
    return closed(value, ['orderId', 'variantId', 'quantity', 'unitPriceMinor', 'currency', 'totalMinor', 'status', 'createdAt', 'synthetic']) &&
      isGuid(value.orderId) && isGuid(value.variantId) && Number.isInteger(value.quantity) && value.quantity >= 1 && value.quantity <= 100 &&
      integer(value.unitPriceMinor, 9000000000000) && integer(value.totalMinor, 900000000000000) && value.totalMinor === value.unitPriceMinor * value.quantity &&
      value.currency === 'XXX' && value.status === 'reserved' && value.synthetic === true && typeof value.createdAt === 'string' &&
      /T.*(?:Z|\+00:00)$/.test(value.createdAt) && Number.isFinite(Date.parse(value.createdAt));
  }
  const mapOrder = value => ({
    ...provenance('savia', 'synthetic'), id:scopedId(scope, value.orderId.toLowerCase()),
    variant_id:scopedId(scope, value.variantId.toLowerCase()), quantity:value.quantity,
    unit_price_minor:value.unitPriceMinor, currency:value.currency, total_minor:value.totalMinor,
    status:value.status, created_at:value.createdAt
  });
  const problemCodes = new Set(['invalid_request', 'unknown_variant', 'order_not_found', 'not_found', 'out_of_stock', 'idempotency_conflict', 'storage_unavailable', 'catalog_not_enabled', 'internal_error']);
  function createSaviaSyntheticAdapter({transport, allowSyntheticOrders = false} = {}) {
    if (transport !== undefined && typeof transport !== 'function') fail('invalid_configuration', 'El transporte HTTP debe configurarse explícitamente.');
    if (typeof allowSyntheticOrders !== 'boolean') fail('invalid_configuration', 'La habilitación sintética debe ser explícita.');
    const descriptor = freeze({
      ...getDescriptor('savia'), status:transport ? 'synthetic' : 'unconfigured', connectionStatus:transport ? 'injected_transport' : 'unconfigured',
      capabilities:{catalog:!!transport, localCart:false, simulatedOrders:false, syntheticHttp:true, syntheticOrders:!!transport && allowSyntheticOrders, realOrders:false, payments:false},
      notice:'Adaptador del contrato .NET sintético: XXX, una variante por pedido, solo reserva de prueba. Transporte inyectado no implica conexión verificada.'
    });
    async function request(path, {method = 'GET', body, key} = {}) {
      if (!transport) fail('integration_unconfigured', 'SAVIA HTTP no está configurado. No se sustituye por una compra local.');
      const write = method === 'POST';
      const headers = {Accept:'application/json'};
      if (write) Object.assign(headers, {'Content-Type':'application/json', 'Idempotency-Key':key});
      let response, value;
      try {
        response = await transport(path, {method, headers, ...(body ? {body:JSON.stringify(body)} : {}), credentials:'omit', redirect:'error', cache:'no-store'});
      } catch {
        fail(write ? 'synthetic_outcome_unknown' : 'transport_unavailable', write ? 'Resultado sintético desconocido. Conservá y reintentá la misma clave; no cambies de modelo ni crees otra compra.' : 'No se pudo consultar SAVIA HTTP. No hay sustitución por datos locales.', {retryWithSameKey:write});
      }
      if (!response || !Number.isInteger(response.status) || typeof response.json !== 'function') fail(write ? 'synthetic_outcome_unknown' : 'invalid_response', 'Respuesta HTTP no válida; no se usará una simulación como sustituto.', {retryWithSameKey:write});
      try { value = await response.json(); } catch { fail(write ? 'synthetic_outcome_unknown' : 'invalid_response', 'SAVIA HTTP no devolvió JSON válido.', {retryWithSameKey:write}); }
      if (response.status >= 400 && response.status <= 599) {
        const code = record(value) && problemCodes.has(value.code) ? value.code : 'http_error';
        // Do not surface arbitrary server titles, payloads, SQL or trace data.
        fail(code, 'SAVIA HTTP rechazó la operación sintética (' + code + '). No se aplicó ningún fallback local.', {status:response.status, retryWithSameKey:write && response.status >= 500});
      }
      if (response.status !== (write ? 201 : 200)) fail(write ? 'synthetic_outcome_unknown' : 'invalid_response', 'Estado HTTP inesperado para el contrato sintético.', {retryWithSameKey:write});
      return value;
    }
    return Object.freeze({
      mode:'savia', descriptor,
      async readCatalog() {
        const value = await request('/api/v1/catalog');
        if (!validateCatalog(value)) fail('invalid_response', 'El catálogo no cumple el contrato sintético XXX; no se usará para vender.');
        return {...provenance('savia', 'synthetic'), products:value.items.map(product => ({
          id:scopedId(scope, product.productId.toLowerCase()), name:product.name,
          variants:product.variants.map(variant => ({id:scopedId(scope, variant.variantId.toLowerCase()), sku:variant.sku,
            unit_price_minor:variant.unitPriceMinor, currency:variant.currency, available_quantity:variant.availableQuantity}))
        }))};
      },
      async createSyntheticOrder(input) {
        requireScope(input, 'savia', 'synthetic');
        if (!closed(input, ['integration_id', 'data_kind', 'variant_id', 'quantity', 'idempotency_key'])) fail('invalid_request', 'La reserva sintética acepta solo una variante, cantidad y clave; nunca contacto, precio, pago o líneas múltiples.');
        const variantId = unscopedId(scope, input.variant_id).toLowerCase();
        if (!isGuid(variantId) || !Number.isInteger(input.quantity) || input.quantity < 1 || input.quantity > 100 || typeof input.idempotency_key !== 'string' || !/^[!-~]{8,128}$/.test(input.idempotency_key)) fail('invalid_request', 'Variante, cantidad o clave de idempotencia inválida.');
        if (!allowSyntheticOrders) fail('synthetic_writes_disabled', 'Las reservas HTTP sintéticas necesitan habilitación explícita; las ventas reales siempre están bloqueadas.');
        const value = await request('/api/v1/synthetic/orders', {method:'POST', body:{variantId, quantity:input.quantity}, key:input.idempotency_key});
        if (!validateOrder(value) || value.variantId.toLowerCase() !== variantId || value.quantity !== input.quantity) fail('synthetic_outcome_unknown', 'La respuesta no confirma este intento sintético. Conservá la misma clave; no crees otro pedido.', {retryWithSameKey:true});
        return mapOrder(value);
      },
      async readOrder(orderId) {
        const id = unscopedId(scope, orderId).toLowerCase();
        if (!isGuid(id)) fail('invalid_request', 'Identificador sintético inválido.');
        const value = await request('/api/v1/synthetic/orders/' + id);
        if (!validateOrder(value) || value.orderId.toLowerCase() !== id) fail('invalid_response', 'El pedido no cumple el contrato o corresponde a otro identificador.');
        return mapOrder(value);
      },
      createRealOrder:realOrderBlocked
    });
  }
  const exported = Object.freeze({createSaviaSyntheticAdapter});
  if (typeof module === 'object' && module.exports) module.exports = exported;
  root.MarthaSaviaHttp = exported;
})(typeof window !== 'undefined' ? window : globalThis);

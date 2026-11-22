/* Integration models for the storefront. Each model keeps its own cart, orders and
   stock in this browser. No CGA endpoint, credentials or automatic connection exists. */
(function (root) {
  'use strict';
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

  const exported = Object.freeze({MODES, getDescriptor, createLocalAdapter});
  if (typeof module === 'object' && module.exports) module.exports = exported;
  root.MarthaIntegrations = exported;
})(typeof window !== 'undefined' ? window : globalThis);

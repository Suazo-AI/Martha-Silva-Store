// Every HTTP call of the staff web lives here. Same origin: the API hosts savia/web/ at "/".
// Routes and bodies follow docs/pilot/API-PILOT.md and Savia.Contracts.

const BASE = '/api/v1';
const TOKEN_KEY = 'savia.token';

export class ApiError extends Error {
  constructor({ status, code, message, traceId = null, missing = false, network = false }) {
    super(message);
    Object.assign(this, { status, code, traceId, missing, network });
  }
}

/** RFC 4122 v4. Browsers omit crypto.randomUUID on plain HTTP (the phone page on the shop LAN); getRandomValues stays. */
export function uuid() {
  if (typeof crypto.randomUUID === 'function') return crypto.randomUUID();
  const b = crypto.getRandomValues(new Uint8Array(16));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  const hex = Array.from(b, x => x.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

/**
 * Ids for one action that may be sent twice. The same content keeps its ids, so the server applies a retry once;
 * changed content gets new ids. Call reset() after a success when the same content may be sent again as a new action.
 *   const ids = retryIds('saleId');  ...  const { saleId } = ids([lines, tenders]);
 */
export function retryIds(...names) {
  let key = null;
  let ids = null;
  const next = content => {
    const text = JSON.stringify(content);
    if (text !== key) {
      key = text;
      ids = Object.fromEntries(names.map(name => [name, uuid()]));
    }
    return ids;
  };
  next.reset = () => {
    key = null;
    ids = null;
  };
  return next;
}

let storage = null;
function store() {
  if (storage) return storage;
  try {
    storage = globalThis.sessionStorage;
    storage.getItem('x');
  } catch {
    storage = new Map();
    storage.getItem = storage.get;
    storage.setItem = storage.set;
    storage.removeItem = storage.delete;
  }
  return storage;
}
export const getToken = () => store().getItem(TOKEN_KEY) || null;
export const setToken = token => (token ? store().setItem(TOKEN_KEY, token) : store().removeItem(TOKEN_KEY));

let onUnauthorized = () => {};
export function setUnauthorizedHandler(fn) {
  onUnauthorized = fn;
}

/** Turns a non-OK response into ApiError. Exported for tests. */
export async function toError(response) {
  let body = null;
  const text = await response.text();
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = null;
  }
  if (body && typeof body.code === 'string') {
    return new ApiError({
      status: response.status,
      code: body.code,
      message: body.message || 'Error del servidor.',
      traceId: body.traceId ?? null,
    });
  }
  return new ApiError({
    status: response.status,
    code: `http.${response.status}`,
    message: `El servidor respondió ${response.status}. Reintente; si se repite, avise a soporte.`,
  });
}

const NETWORK_MESSAGE = 'Sin conexión con el servidor de la sucursal. Revise la red y reintente: el mismo intento no se duplica.';

/** The one fetch of the web: headers, the network error, the server's error body and the expired session. */
async function send(
  method,
  path,
  {
    body,
    form,
    fetchImpl = globalThis.fetch,
    token = getToken(),
    notifyUnauthorized = true,
    approvalToken,
    networkMessage = NETWORK_MESSAGE,
  } = {},
) {
  const headers = { Accept: 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (approvalToken) headers['X-Savia-Approval'] = approvalToken;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  let response;
  try {
    response = await fetchImpl(BASE + path, { method, headers, body: form ?? (body === undefined ? undefined : JSON.stringify(body)) });
  } catch {
    throw new ApiError({ status: 0, code: 'network', network: true, message: networkMessage });
  }
  if (!response.ok) {
    const error = await toError(response);
    if (response.status === 401 && path !== '/auth/login' && notifyUnauthorized) onUnauthorized(error);
    throw error;
  }
  return response;
}

/** JSON in, JSON out. options: token, approvalToken, notifyUnauthorized, form (multipart instead of a JSON body). */
export async function request(method, path, body, options = {}) {
  const response = await send(method, path, { ...options, body });
  if (response.status === 204) return null;
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

const q = params => {
  const entries = Object.entries(params).filter(([, v]) => v !== undefined && v !== null && v !== '');
  return entries.length ? `?${new URLSearchParams(entries).toString()}` : '';
};
const path = (strings, ...values) => strings.reduce((out, s, i) => out + s + (i < values.length ? encodeURIComponent(values[i]) : ''), '');

// ---- auth
export const login = (loginName, password) => request('POST', '/auth/login', { loginName, password });
export const logout = () => request('POST', '/auth/logout');
export const me = () => request('GET', '/me');

// ---- catalog
/** exact barcode or supplier code. ItemLookup[] */
export const lookup = (code, supplierId) => request('GET', `/catalog/lookup${q({ code, supplierId })}`);
export const catalogItems = () => request('GET', '/catalog/items');
export const searchProducts = text => request('GET', `/catalog/search${q({ q: text })}`);
/** Branch writes require the local pilot catalog flag and an approving role. */
export const registerProduct = (productId, name) => request('POST', '/catalog/products', { productId, name });
export const registerItem = item => request('POST', '/catalog/items', item);
/** Tag photo -> suggested fields, read on the branch PC (docs/pilot/ETIQUETA.md). image: Blob; barcode: phone reading or null. */
export function tagExtract(image, barcode, { fetchImpl = globalThis.fetch } = {}) {
  const form = new FormData();
  form.append('image', image, 'etiqueta.jpg');
  if (barcode) form.append('barcode', barcode);
  return request('POST', '/inventory/tag-extract', undefined, {
    form,
    fetchImpl,
    networkMessage: 'Sin conexión con la computadora de la sucursal. Complete los datos a mano o reintente.',
  });
}

// ---- receiving
export const suppliers = () => request('GET', '/suppliers');
export const openReception = ({ containerId, scanSessionId, reference, supplierId, deviceCode }) =>
  request('POST', '/receiving/sessions', { containerId, scanSessionId, reference, supplierId, deviceCode });
export const recordScan = (sessionId, { scanId, rawCode, quantity = 1, deviceCode }) =>
  request('POST', path`/receiving/sessions/${sessionId}/scans`, { scanId, rawCode, quantity, deviceCode });
/** { scanSessionId, containerId, reference, status, scanEvents, matchedUnits, unitsPendingReview } */
export const receptionProgress = sessionId => request('GET', path`/receiving/sessions/${sessionId}`);
export const receptionLines = sessionId => request('GET', path`/receiving/sessions/${sessionId}/lines`);
export const listReceptions = (open = true) => request('GET', `/receiving/sessions${q({ open, limit: 50 })}`);
export const approveReception = sessionId => request('POST', path`/receiving/sessions/${sessionId}/approve`);
/** { receiptId } */
export const postReception = sessionId => request('POST', path`/receiving/sessions/${sessionId}/post` + q({ currency: 'NIO' }));

// ---- stock and labels
/** StockRow[]: { itemId, sku, variantName, locationId, pool, onHand, reserved, available } */
export const stock = itemId => request('GET', `/stock${q({ itemId })}`);
/** LabelJob[]: { id, itemId, storeName, sku, barcode, copiesRequested, copiesAcknowledged, status } */
export const labelJobs = status => request('GET', `/labels/jobs${q({ status })}`);

// ---- cash and sales
export const registers = () => request('GET', '/cash/registers');
export const approvals = () => request('GET', '/approvals');
export const sellers = () => request('GET', '/sellers');
export const quality = session => request('GET', path`/receiving/sessions/${session}/quality`);
export const recordQuality = (session, body) => request('POST', path`/receiving/sessions/${session}/quality`, body);
export const qualityReport = (from, to) => request('GET', `/reports/receiving-quality${q({ from, to })}`);
export const itemValues = query => request('GET', `/catalog/values${q({ q: query })}`);
export const setItemValues = (itemId, body) => request('POST', path`/catalog/items/${itemId}/values`, body);
export const commissions = (period, date) => request('GET', `/reports/commissions${q({ period, date })}`);
export const setSellerRate = (sellerId, body) => request('POST', path`/sellers/${sellerId}/rate`, body);
export const exchangeRate = () => request('GET', '/exchange-rate');
export const setExchangeRate = body => request('POST', '/exchange-rates', body);
export const denominations = () => request('GET', '/cash/denominations');
export const openTill = ({ tillId, registerId, currencyCode = 'NIO', openingMinor, lines, usdLines }) =>
  request('POST', '/cash/tills', { tillId, registerId, currencyCode, openingMinor, lines, ...(usdLines ? { usdLines } : {}) });
export const currentTill = () => request('GET', '/cash/tills/current');
export const tillSummary = tillId => request('GET', path`/cash/tills/${tillId}/summary`);
export const recordCashCount = (tillId, { cashCountId, lines, usdCashCountId, usdLines }) =>
  request('POST', path`/cash/tills/${tillId}/counts`, { cashCountId, lines, ...(usdLines ? { usdCashCountId, usdLines } : {}) });
/** { closureId, expectedMinor, countedMinor, differenceMinor } */
export const closeTill = (tillId, { closureId, cashCountId, usdCashCountId }) =>
  request('POST', path`/cash/tills/${tillId}/close`, { closureId, cashCountId, ...(usdCashCountId ? { usdCashCountId } : {}) });
/** { saleId, subtotalMinor, discountMinor, taxMinor, totalMinor, status } */
export const postSale = (sale, approvalToken) => request('POST', '/sales', sale, { approvalToken, notifyUnauthorized: !approvalToken });
export const getSale = saleId => request('GET', path`/sales/${saleId}`);

export const resolveScan = (sessionId, scanId, itemId, reason) =>
  request('POST', path`/receiving/sessions/${sessionId}/scans/${scanId}/resolve`, { itemId, reason });
export const rejectScan = (sessionId, scanId, reason) =>
  request('POST', path`/receiving/sessions/${sessionId}/scans/${scanId}/reject`, { reason });

// ---- sales history, customers and reports. All money stays in server minor units.
export const saleTenderKinds = ['cash', 'card', 'transfer', 'credit', 'other'];
export const searchSales = ({ q: query, date, page = 1 } = {}) =>
  request('GET', `/sales${q({ q: query, from: date, to: date, page, pageSize: 25 })}`);
export const searchCustomers = query => request('GET', `/customers${q({ q: query })}`);
export const searchCredits = query => request('GET', `/credits/search${q({ q: query })}`);
export const dayReport = date => request('GET', `/reports/day${q({ date })}`);
export const summaryReport = (period, date) => request('GET', `/reports/summary${q({ period, date })}`);
export const stockExceptions = () => request('GET', '/stock/exceptions');
export const reviewStockException = (id, reason) => request('POST', path`/stock/exceptions/${id}/review`, { reason });
export const exportSummary = (period, date) => exportReport('/reports/summary.csv', period, date, 'reporte');
export const exportCommissions = (period, date) => exportReport('/reports/commissions.csv', period, date, 'comisiones');
/** Downloads a CSV the server built; the browser needs the object URL until the download starts. */
async function exportReport(path, period, date, name) {
  const response = await send('GET', path + q({ period, date }));
  const url = URL.createObjectURL(await response.blob());
  const link = document.createElement('a');
  link.href = url;
  link.download = `${name}-${period}-${date}.csv`;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
export const postCreditReturn = (saleId, body, token) =>
  request('POST', path`/sales/${saleId}/returns/credit`, body, token ? { token, notifyUnauthorized: false } : {});
export const postReturnOutcome = (saleId, body, token) =>
  request('POST', path`/sales/${saleId}/returns/outcome`, body, token ? { token, notifyUnauthorized: false } : {});
export const returnPolicy = () => request('GET', '/returns/policy');
export const setReturnWindow = body => request('POST', '/returns/policy', body);
export const kpiBusiness = (period, date) => request('GET', `/reports/kpi/business${q({ period, date })}`);
export const kpiTeam = (period, date) => request('GET', `/reports/kpi/team${q({ period, date })}`);
export const exportKpiBusiness = (period, date) => exportReport('/reports/kpi/business.csv', period, date, 'negocio');
export const exportKpiTeam = (period, date) => exportReport('/reports/kpi/team.csv', period, date, 'equipo');
export const importFile = (fileName, contentBase64) => request('POST', '/catalog/import/file', { fileName, contentBase64 });
export const previewImport = body => request('POST', '/catalog/import/preview', body);
export const importCatalog = body => request('POST', '/catalog/import', body);
export const endApproval = token => request('POST', '/auth/logout', undefined, { token, notifyUnauthorized: false });

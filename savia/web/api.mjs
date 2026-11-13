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

export const uuid = () => crypto.randomUUID();

let storage = null;
function store() {
  if (storage) return storage;
  try { storage = globalThis.sessionStorage; storage.getItem('x'); } catch { storage = new Map(); storage.getItem = storage.get; storage.setItem = storage.set; storage.removeItem = storage.delete; }
  return storage;
}
export const getToken = () => store().getItem(TOKEN_KEY) || null;
export const setToken = token => token ? store().setItem(TOKEN_KEY, token) : store().removeItem(TOKEN_KEY);

let onUnauthorized = () => {};
export function setUnauthorizedHandler(fn) { onUnauthorized = fn; }

/** Turns a non-OK response into ApiError. Exported for tests. */
export async function toError(response) {
  let body = null;
  const text = await response.text();
  try { body = text ? JSON.parse(text) : null; } catch { body = null; }
  if (body && typeof body.code === 'string') {
    return new ApiError({ status: response.status, code: body.code, message: body.message || 'Error del servidor.', traceId: body.traceId ?? null });
  }
  return new ApiError({ status: response.status, code: `http.${response.status}`,
    message: `El servidor respondió ${response.status}. Reintente; si se repite, avise a soporte.` });
}

export async function request(method, path, body, { fetchImpl = globalThis.fetch, token = getToken(), notifyUnauthorized = true, approvalToken } = {}) {
  const headers = { Accept: 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (approvalToken) headers['X-Savia-Approval'] = approvalToken;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  let response;
  try {
    response = await fetchImpl(BASE + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  } catch {
    throw new ApiError({ status: 0, code: 'network', network: true,
      message: 'Sin conexión con el servidor de la sucursal. Revise la red y reintente: el mismo intento no se duplica.' });
  }
  if (!response.ok) {
    const error = await toError(response);
    if (response.status === 401 && path !== '/auth/login' && notifyUnauthorized) onUnauthorized(error);
    throw error;
  }
  if (response.status === 204) return null;
  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

const q = params => {
  const entries = Object.entries(params).filter(([, v]) => v !== undefined && v !== null && v !== '');
  return entries.length ? '?' + new URLSearchParams(entries).toString() : '';
};
const path = (strings, ...values) => strings.reduce((out, s, i) => out + s + (i < values.length ? encodeURIComponent(values[i]) : ''), '');

// ---- auth (existing)
export const login = (loginName, password) => request('POST', '/auth/login', { loginName, password });
export const logout = () => request('POST', '/auth/logout');
export const me = () => request('GET', '/me');

// ---- catalog
/** Existing: exact barcode or supplier code. ItemLookup[] */
export const lookup = (code, supplierId) => request('GET', '/catalog/lookup' + q({ code, supplierId }));
export const catalogItems = () => request('GET', '/catalog/items');
export const searchProducts = text => request('GET', '/catalog/search' + q({ q: text }));
/** Branch writes require the local pilot catalog flag and an approving role. */
export const registerProduct = (productId, name) => request('POST', '/catalog/products', { productId, name });
export const registerItem = item => request('POST', '/catalog/items', item);

// ---- receiving
export const suppliers = () => request('GET', '/suppliers');
export const openReception = ({ containerId, scanSessionId, reference, supplierId, deviceCode }) =>
  request('POST', '/receiving/sessions', { containerId, scanSessionId, reference, supplierId, deviceCode });
export const recordScan = (sessionId, { scanId, rawCode, quantity = 1, deviceCode }) =>
  request('POST', path`/receiving/sessions/${sessionId}/scans`, { scanId, rawCode, quantity, deviceCode });
/** Existing: { scanSessionId, containerId, reference, status, scanEvents, matchedUnits, unitsPendingReview } */
export const receptionProgress = sessionId => request('GET', path`/receiving/sessions/${sessionId}`);
export const receptionLines = sessionId => request('GET', path`/receiving/sessions/${sessionId}/lines`);
export const listReceptions = (open = true) => request('GET', '/receiving/sessions' + q({ open, limit: 50 }));
export const approveReception = sessionId => request('POST', path`/receiving/sessions/${sessionId}/approve`);
/** Existing: { receiptId } */
export const postReception = sessionId => request('POST', path`/receiving/sessions/${sessionId}/post` + q({ currency: 'NIO' }));

// ---- stock and labels (existing)
/** StockRow[]: { itemId, sku, variantName, locationId, pool, onHand, reserved, available } */
export const stock = itemId => request('GET', '/stock' + q({ itemId }));
/** LabelJob[]: { id, itemId, storeName, sku, barcode, copiesRequested, copiesAcknowledged, status } */
export const labelJobs = status => request('GET', '/labels/jobs' + q({ status }));

// ---- cash and sales
export const registers = () => request('GET', '/cash/registers');
export const denominations = () => request('GET', '/cash/denominations');
export const openTill = ({ tillId, registerId, currencyCode = 'NIO', openingMinor, lines }) =>
  request('POST', '/cash/tills', { tillId, registerId, currencyCode, openingMinor, lines });
export const currentTill = () => request('GET', '/cash/tills/current');
export const tillSummary = tillId => request('GET', path`/cash/tills/${tillId}/summary`);
export const recordCashCount = (tillId, { cashCountId, lines }) =>
  request('POST', path`/cash/tills/${tillId}/counts`, { cashCountId, lines });
/** Existing: { closureId, expectedMinor, countedMinor, differenceMinor } */
export const closeTill = (tillId, { closureId, cashCountId }) =>
  request('POST', path`/cash/tills/${tillId}/close`, { closureId, cashCountId });
/** Existing: { saleId, subtotalMinor, discountMinor, taxMinor, totalMinor, status } */
export const postSale = (sale, approvalToken) => request('POST', '/sales', sale, { approvalToken, notifyUnauthorized: !approvalToken });
export const getSale = saleId => request('GET', path`/sales/${saleId}`);

export const resolveScan = (sessionId, scanId, itemId, reason) => request('POST', path`/receiving/sessions/${sessionId}/scans/${scanId}/resolve`, { itemId, reason });
export const rejectScan = (sessionId, scanId, reason) => request('POST', path`/receiving/sessions/${sessionId}/scans/${scanId}/reject`, { reason });

// ---- final pilot sales contract (V013). All money remains in server minor units.
export const saleTenderKinds = ['cash', 'card', 'transfer', 'credit', 'other'];
export const saleReceipt = getSale;
export const searchSales = ({ q: query, date, page = 1 } = {}) => request('GET', '/sales' + q({ q: query, from: date, to: date, page, pageSize: 25 }));
export const searchCustomers = query => request('GET', '/customers' + q({ q: query }));
export const searchCredits = query => request('GET', '/credits/search' + q({ q: query }));
export const dayReport = date => request('GET', '/reports/day' + q({ date }));
export const summaryReport = (period, date) => request('GET', '/reports/summary' + q({ period, date }));
export const stockExceptions = () => request('GET', '/stock/exceptions');
export const reviewStockException = (id, reason) => request('POST', path`/stock/exceptions/${id}/review`, { reason });
export async function exportSummary(period, date) {
  const response = await fetch(BASE + '/reports/summary.csv' + q({ period, date }), { headers: { Authorization: `Bearer ${getToken()}` } });
  if (!response.ok) throw await toError(response);
  const url = URL.createObjectURL(await response.blob());
  const link = document.createElement('a');
  link.href = url; link.download = `reporte-${period}-${date}.csv`; link.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}
export const postCreditReturn = (saleId, body, token) => request('POST', path`/sales/${saleId}/returns/credit`, body,
  token ? { token, notifyUnauthorized: false } : {});
export const endApproval = token => request('POST', '/auth/logout', undefined, { token, notifyUnauthorized: false });

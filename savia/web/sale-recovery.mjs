// One origin-local pending write. Never stores authentication or supervisor credentials.
import { GUID_RE } from './ui.mjs';
export const RECOVERY_KEY = 'savia.sale.pending.v1';
const guid = value => typeof value === 'string' && GUID_RE.test(value);
export const sameGuid = (a, b) => guid(a) && guid(b) && a.toLowerCase() === b.toLowerCase();
export const actorScope = (me, origin = location.origin) => ({
  origin,
  staffId: me.staffId,
  nodeId: me.nodeId,
  branchId: me.branchId,
  locationId: me.locationId,
});
export const sameScope = (a, b) =>
  a.origin === b.origin && ['staffId', 'nodeId', 'branchId', 'locationId'].every(key => sameGuid(a[key], b[key]));
const only = (obj, keys) => obj && typeof obj === 'object' && !Array.isArray(obj) && Object.keys(obj).every(k => keys.includes(k));
const integer = n => Number.isSafeInteger(n) && n >= 0;
export function validateRecord(r) {
  const body = r?.body;
  if (
    !only(r, ['version', 'scope', 'body', 'changeMinor']) ||
    r.version !== 1 ||
    !only(r.scope, ['origin', 'staffId', 'nodeId', 'branchId', 'locationId']) ||
    typeof r.scope.origin !== 'string' ||
    !['staffId', 'nodeId', 'branchId', 'locationId'].every(k => guid(r.scope[k])) ||
    !integer(r.changeMinor) ||
    !only(body, ['saleId', 'tillId', 'currencyCode', 'customerId', 'lines', 'tenders', 'discountReason', 'stockExceptionNote']) ||
    !guid(body.saleId) ||
    !guid(body.tillId) ||
    body.currencyCode !== 'NIO' ||
    (body.customerId != null && !guid(body.customerId)) ||
    ![body.discountReason, body.stockExceptionNote].every(v => v == null || (typeof v === 'string' && v.length <= 1000)) ||
    !Array.isArray(body.lines) ||
    !body.lines.length ||
    body.lines.length > 1000 ||
    !body.lines.every(
      l =>
        only(l, ['lineNumber', 'itemId', 'quantity', 'unitPriceMinor', 'discountMinor', 'sellerId']) &&
        guid(l.itemId) &&
        guid(l.sellerId) &&
        integer(l.lineNumber) &&
        l.lineNumber > 0 &&
        integer(l.quantity) &&
        l.quantity > 0 &&
        integer(l.unitPriceMinor) &&
        integer(l.discountMinor) &&
        l.discountMinor <= l.unitPriceMinor * l.quantity,
    ) ||
    !Array.isArray(body.tenders) ||
    body.tenders.length > 100 ||
    !body.tenders.every(
      t =>
        only(t, [
          'tenderNumber',
          'tenderKind',
          'amountMinor',
          'receivedMinor',
          'changeMinor',
          'reference',
          'creditId',
          'foreignCurrencyCode',
          'foreignReceivedMinor',
          'exchangeRateId',
          'exchangeRate',
          'roundingMinor',
          'foreignChangeMinor',
        ]) &&
        integer(t.tenderNumber) &&
        ['cash', 'card', 'transfer', 'credit', 'other'].includes(t.tenderKind) &&
        integer(t.amountMinor) &&
        Object.entries(t).every(
          ([k, v]) =>
            v == null ||
            (['tenderNumber', 'amountMinor', 'receivedMinor', 'changeMinor', 'foreignReceivedMinor', 'foreignChangeMinor'].includes(k)
              ? integer(v)
              : k === 'roundingMinor'
                ? Number.isSafeInteger(v)
                : k === 'exchangeRate'
                  ? Number.isFinite(v) && v > 0
                  : typeof v === 'string'),
        ),
    )
  ) {
    throw new Error('No se pudo verificar el registro pendiente. Avise a la gerente; no vuelva a cobrar.');
  }
  const total = body.lines.reduce((sum, l) => sum + l.unitPriceMinor * l.quantity - l.discountMinor, 0);
  if (
    !integer(total) ||
    body.tenders.reduce((sum, t) => sum + t.amountMinor, 0) !== total ||
    body.tenders.reduce((sum, t) => sum + (t.changeMinor ?? 0), 0) !== r.changeMinor ||
    new Set(body.lines.map(l => l.sellerId.toLowerCase())).size > 3 ||
    !body.tenders.every(t => (t.creditId == null || guid(t.creditId)) && (t.exchangeRateId == null || guid(t.exchangeRateId)))
  ) {
    throw new Error('El registro pendiente contiene importes o vendedores inválidos. Avise a la gerente.');
  }
  return r;
}
export function readPending(storage = localStorage) {
  const raw = storage.getItem(RECOVERY_KEY);
  if (raw !== null && raw.length > 250000) throw new Error('El registro pendiente excede el límite. Avise a la gerente.');
  return raw === null ? null : validateRecord(JSON.parse(raw));
}
export function persistPending(record, storage = localStorage) {
  validateRecord(record);
  if (storage.getItem(RECOVERY_KEY) !== null) throw new Error('Existe una venta pendiente. Consulte su recibo.');
  const raw = JSON.stringify(record);
  storage.setItem(RECOVERY_KEY, raw);
  if (storage.getItem(RECOVERY_KEY) !== raw) throw new Error('No se pudo guardar el intento. No se envió la venta.');
  return validateRecord(JSON.parse(raw));
}
export function clearPending(record, storage = localStorage) {
  const current = readPending(storage);
  if (!current || !sameGuid(current.body.saleId, record.body.saleId)) throw new Error('El registro pendiente cambió. Avise a la gerente.');
  storage.removeItem(RECOVERY_KEY);
  if (storage.getItem(RECOVERY_KEY) !== null) throw new Error('No se pudo cerrar la recuperación. Consulte el recibo antes de continuar.');
}
export function validResponse(sale, saleId) {
  return (
    sameGuid(sale?.saleId, saleId) &&
    sale.status === 'posted' &&
    ['subtotalMinor', 'discountMinor', 'taxMinor', 'totalMinor'].every(k => integer(sale[k]))
  );
}
export function matchesReceipt(sale, record) {
  return (
    validResponse(sale, record.body.saleId) && sameGuid(sale.cashierId, record.scope.staffId) && sameGuid(sale.tillId, record.body.tillId)
  );
}

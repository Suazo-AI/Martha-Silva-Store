// Protected directory and commerce contracts. Server prices and receipts are authoritative.
import {createAuthClient, StaffRequestError} from './login.mjs';
const string = value => typeof value === 'string' && value.length > 0;
function entity(value, kind) {
  if (!value || !string(value.id) || !string(value.name) || typeof value.active !== 'boolean') throw new StaffRequestError('response');
  const base = {id: value.id, name: value.name, active: value.active};
  if (kind === 'items') {
    if (!string(value.sku) || !Number.isSafeInteger(value.unitPriceMinor) || value.unitPriceMinor < 0
      || value.unitPriceMinor > 9000000000000 || !/^[A-Z]{3}$/.test(value.currency)
      || value.currency === 'XXX') throw new StaffRequestError('response');
    return Object.freeze({...base, sku: value.sku, unitPriceMinor: value.unitPriceMinor, currency: value.currency});
  }
  if (kind === 'parties') {
    if (!['customer', 'supplier'].includes(value.kind)
      || (value.email != null && typeof value.email !== 'string')
      || (value.phone != null && typeof value.phone !== 'string')) throw new StaffRequestError('response');
    return Object.freeze({...base, kind: value.kind, email: value.email ?? '', phone: value.phone ?? ''});
  }
  return Object.freeze({...base, branchId: value.branchId ?? null});
}
export function createStaffClient(options = {}) {
  const auth = createAuthClient(options);
  async function list(kind, {q = '', includeInactive = false, skip = 0, take = 50, partyKind} = {}) {
    const verified = auth.getVerifiedSession();
    if (kind === 'parties' && verified && verified.role !== 'Owner')
      throw new StaffRequestError('forbidden', 403);
    if (typeof q !== 'string' || q.length > 200 || typeof includeInactive !== 'boolean'
      || !Number.isSafeInteger(skip) || skip < 0 || skip > 100000
      || !Number.isSafeInteger(take) || take < 1 || take > 100) throw new StaffRequestError('invalid');
    const params = new URLSearchParams({includeInactive: String(includeInactive), skip: String(skip), take: String(take)});
    if (q.trim()) params.set('q', q.trim());
    if (kind === 'parties') {
      if (!['customer', 'supplier'].includes(partyKind)) throw new StaffRequestError('invalid');
      params.set('kind', partyKind);
    }
    const response = await auth.requestAuthenticated(`/internal/api/directory/${kind}?${params}`);
    if (!response || !Array.isArray(response.items)
      || ![response.total, response.skip, response.take].every(value => Number.isSafeInteger(value) && value >= 0)
      || response.take < 1 || response.take > 100 || response.skip > 100000
      || response.skip !== skip || response.take !== take
      || response.items.length > take) throw new StaffRequestError('response');
    const items = response.items.map(value => entity(value, kind));
    if (response.total < items.length || (items.length > 0 && response.total < skip + items.length)
      || (kind === 'parties' && items.some(value => value.kind !== partyKind))) throw new StaffRequestError('response');
    return Object.freeze({items, total: response.total, skip: response.skip, take: response.take});
  }
  return Object.freeze({getSession: auth.getSession, getVerifiedSession: auth.getVerifiedSession,
    async listInventory(locationId, skip = 0) {
      if (!isId(locationId) || !Number.isSafeInteger(skip) || skip < 0) throw new StaffRequestError('invalid');
      const page = await auth.requestBusiness(`/internal/api/commerce/inventory?locationId=${locationId}&skip=${skip}&take=100`);
      if (!page || !Array.isArray(page.items) || page.skip !== skip || page.take !== 100
        || !Number.isSafeInteger(page.total) || page.total < skip + page.items.length || page.items.length > 100
        || page.items.some(x => !isId(x.itemId) || x.locationId !== locationId || ![x.onHand,x.reserved,x.available].every(Number.isSafeInteger)
          || x.available !== x.onHand-x.reserved || x.onHand < 0 || x.reserved < 0)) throw new StaffRequestError('response');
      return page;
    },
    async recordSale(key, body) { validateSaleRequest(body); return readReceipt(await auth.requestBusiness('/internal/api/commerce/sales', {method:'POST',key,body}), body); },
    async recoverSale(key, body) { validateSaleRequest(body); const v=await auth.requestBusiness('/internal/api/operations/commerce.sale.record',{key});
      if(v?.status !== 'completed' || !v.result) throw new StaffRequestError('response');
      const outcome=v.result;
      if(outcome.success===false && outcome.value===null && typeof outcome.error==='string' && /^[a-z_]{1,80}$/.test(outcome.error))
        throw new StaffRequestError('sale_rejected');
      if(outcome.success!==true || outcome.error!==null) throw new StaffRequestError('response');
      return readReceipt(outcome.value, body); },
    async getSale(id) { if(!isId(id)) throw new StaffRequestError('invalid'); return readReceipt(await auth.requestBusiness(`/internal/api/commerce/sales/${id}`)); },
    logout: auth.logout, listCustomers: options => list('parties', {...options, partyKind: 'customer'}),
    listSuppliers: options => list('parties', {...options, partyKind: 'supplier'}),
    listItems: options => list('items', options), listLocations: options => list('locations', options)});
}
const isId = value => typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value) && !/^0{8}-0{4}-0{4}-0{4}-0{12}$/.test(value);
export function validateSaleRequest(body) {
  if (!body || !isId(body.locationId) || body.customerId !== null || !Array.isArray(body.lines) || body.lines.length !== 1
    || !isId(body.lines[0].itemId) || !Number.isSafeInteger(body.lines[0].quantity) || body.lines[0].quantity < 1 || body.lines[0].quantity > 100000)
    throw new StaffRequestError('invalid');
}
export function readReceipt(value, expected) {
  if (!value || !isId(value.saleId) || !isId(value.locationId) || !isId(value.actorId)
    || !/^[A-Z]{3}$/.test(value.currency) || value.currency === 'XXX' || !['recorded','cancelled','partially_returned','returned'].includes(value.state)
    || value.paymentStatus !== 'not_processed' || !Number.isFinite(Date.parse(value.createdAt))
    || !Number.isSafeInteger(value.totalMinor) || value.totalMinor < 0 || !Array.isArray(value.lines) || !value.lines.length)
    throw new StaffRequestError('response');
  let total = 0;
  for (const line of value.lines) {
    if (!isId(line.saleLineId) || !isId(line.itemId) || !string(line.sku) || !string(line.name)
      || !Number.isSafeInteger(line.quantity) || line.quantity < 1 || !Number.isSafeInteger(line.unitPriceMinor) || line.unitPriceMinor < 0
      || !Number.isSafeInteger(line.returnedQuantity) || line.returnedQuantity < 0 || line.returnedQuantity > line.quantity
      || !Number.isSafeInteger(line.totalMinor) || line.totalMinor !== line.quantity * line.unitPriceMinor) throw new StaffRequestError('response');
    total += line.totalMinor;
  }
  if (!Number.isSafeInteger(total) || total !== value.totalMinor || (expected && (value.locationId !== expected.locationId
    || value.lines.length !== 1 || value.lines[0].itemId !== expected.lines[0].itemId || value.lines[0].quantity !== expected.lines[0].quantity))) throw new StaffRequestError('response');
  return value;
}

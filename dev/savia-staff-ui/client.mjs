// Protected directory and commerce contracts. Server prices and receipts are authoritative.
import {createSupplyClient} from './supply.mjs';
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
  return Object.freeze({...createSupplyClient(auth), getSession: auth.getSession, getVerifiedSession: auth.getVerifiedSession,
    async listInventory(locationId, skip = 0) {
      if (!isId(locationId) || !Number.isSafeInteger(skip) || skip < 0) throw new StaffRequestError('invalid');
      const page = await auth.requestBusiness(`/internal/api/commerce/inventory?locationId=${locationId}&skip=${skip}&take=100`);
      if (!page || !Array.isArray(page.items) || page.skip !== skip || page.take !== 100
        || !Number.isSafeInteger(page.total) || page.total < skip + page.items.length || page.items.length > 100
        || page.items.some(x => !isId(x.itemId) || x.locationId !== locationId || ![x.onHand,x.reserved,x.available].every(Number.isSafeInteger)
          || x.available !== x.onHand-x.reserved || x.onHand < 0 || x.reserved < 0)) throw new StaffRequestError('response');
      return page;
    },
    async stockReviews(saleId) {
      if (!isId(saleId)) throw new StaffRequestError('invalid');
      const values = await auth.requestBusiness(`/internal/api/commerce/sales/${saleId}/stock-reviews`);
      if (!Array.isArray(values)) throw new StaffRequestError('response');
      const reviews = values.map(value => readStockReview(value));
      if (new Set(reviews.map(x => x.id.toLowerCase())).size !== reviews.length) throw new StaffRequestError('response');
      return reviews;
    },
    async reviewStockException(saleId, key, body) {
      if (!isId(saleId)) throw new StaffRequestError('invalid');
      validateStockReviewRequest(body);
      const reviewerId = auth.getVerifiedSession()?.id;
      let result;
      try {
        result = await auth.requestBusiness(`/internal/api/commerce/sales/${saleId}/stock-reviews`, {method:'POST',key,body});
      } catch (error) {
        if (![400,403,404,409].includes(error.status)) throw error;
        // A 4xx alone cannot release an uncertain operation. Read its durable outcome with the original key.
        const operation = await auth.requestBusiness('/internal/api/operations/commerce.stock.review', {key});
        if (operation?.status !== 'completed' || !operation.result) throw new StaffRequestError('response');
        const outcome = operation.result;
        if (outcome.success === false && outcome.value === null && typeof outcome.error === 'string'
          && /^[a-z_]{1,80}$/.test(outcome.error)) throw new StaffRequestError('stock_review_rejected');
        if (outcome.success !== true || outcome.error !== null) throw new StaffRequestError('response');
        result = outcome.value;
      }
      return readStockReview(result, {body,reviewerId});
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
const sameId = (a,b) => isId(a) && isId(b) && a.toLowerCase() === b.toLowerCase();
const auditText = (v,max) => typeof v==='string' && v.length<=max && v.trim().length>0 && !/[\x00-\x1f\x7f]/.test(v);
export function validateStockReviewRequest(body) {
  if (!body || !isId(body.saleLineId) || !isId(body.responsibleActorId)
    || !auditText(body.evidence,500) || !auditText(body.outcome,500)
    || typeof body.nextReviewAt !== 'string' || !Number.isFinite(Date.parse(body.nextReviewAt)))
    throw new StaffRequestError('invalid');
}
export function readStockReview(value, expected) {
  if (!value || !isId(value.id) || !isId(value.saleLineId) || !isId(value.reviewerId)
    || !isId(value.responsibleActorId) || !auditText(value.evidence,500) || !auditText(value.outcome,500)
    || value.causeState !== 'open' || typeof value.createdAt !== 'string' || !Number.isFinite(Date.parse(value.createdAt))
    || typeof value.nextReviewAt !== 'string' || !Number.isFinite(Date.parse(value.nextReviewAt))
    || Date.parse(value.nextReviewAt) <= Date.parse(value.createdAt)) throw new StaffRequestError('response');
  if (expected && (!sameId(value.saleLineId,expected.body.saleLineId) || !sameId(value.reviewerId,expected.reviewerId)
    || value.evidence !== expected.body.evidence.trim() || value.outcome !== expected.body.outcome.trim()
    || !sameId(value.responsibleActorId,expected.body.responsibleActorId)
    || Date.parse(value.nextReviewAt) !== Date.parse(expected.body.nextReviewAt))) throw new StaffRequestError('response');
  return value;
}
export function validateSaleRequest(body) {
  if (!body || !isId(body.locationId) || body.customerId !== null || !Array.isArray(body.lines)
    || body.lines.length < 1 || body.lines.length > 100
    || body.lines.some(line => !line || !isId(line.itemId) || !Number.isSafeInteger(line.quantity) || line.quantity < 1 || line.quantity > 100000
      || (line.exceptionReason != null ? !auditText(line.exceptionReason,500) || !auditText(line.size,80) : line.size != null))
    || new Set(body.lines.map(line => line.itemId.toLowerCase())).size !== body.lines.length)
    throw new StaffRequestError('invalid');
}
export function readReceipt(value, expected) {
  if (!value || !isId(value.saleId) || !isId(value.locationId) || !isId(value.actorId)
    || !/^[A-Z]{3}$/.test(value.currency) || value.currency === 'XXX' || !['recorded','cancelled','partially_returned','returned'].includes(value.state)
    || value.paymentStatus !== 'not_processed' || !Number.isFinite(Date.parse(value.createdAt))
    || !Number.isSafeInteger(value.totalMinor) || value.totalMinor < 0 || !Array.isArray(value.lines) || !value.lines.length || value.lines.length > 100)
    throw new StaffRequestError('response');
  let total = 0;
  for (const line of value.lines) {
    if (!line || !isId(line.saleLineId) || !isId(line.itemId) || !string(line.sku) || !string(line.name)
      || !Number.isSafeInteger(line.quantity) || line.quantity < 1 || !Number.isSafeInteger(line.unitPriceMinor) || line.unitPriceMinor < 0
      || !Number.isSafeInteger(line.returnedQuantity) || line.returnedQuantity < 0 || line.returnedQuantity > line.quantity
      || !Number.isSafeInteger(line.totalMinor) || line.totalMinor !== line.quantity * line.unitPriceMinor) throw new StaffRequestError('response');
    if(line.exceptionReason != null ? !auditText(line.exceptionReason,500) || !auditText(line.size,80) : line.size != null) throw new StaffRequestError('response');
    total += line.totalMinor;
  }
  if (!Number.isSafeInteger(total) || total !== value.totalMinor
    || new Set(value.lines.map(line => line.itemId.toLowerCase())).size !== value.lines.length
    || new Set(value.lines.map(line => line.saleLineId.toLowerCase())).size !== value.lines.length) throw new StaffRequestError('response');
  if (expected) {
    validateSaleRequest(expected);
    const quantities = new Map(expected.lines.map(line => [line.itemId.toLowerCase(), line.quantity]));
    if (value.locationId.toLowerCase() !== expected.locationId.toLowerCase() || value.lines.length !== expected.lines.length
      || value.lines.some(line => quantities.get(line.itemId.toLowerCase()) !== line.quantity
        || (expected.lines.find(x=>x.itemId.toLowerCase()===line.itemId.toLowerCase())?.exceptionReason?.trim() ?? null) !== (line.exceptionReason ?? null)
        || (expected.lines.find(x=>x.itemId.toLowerCase()===line.itemId.toLowerCase())?.size?.trim() ?? null) !== (line.size ?? null))) throw new StaffRequestError('response');
  }
  return value;
}

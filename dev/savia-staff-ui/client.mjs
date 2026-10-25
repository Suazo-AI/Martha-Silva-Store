// Protected reads only. Business writes await receipt/reconciliation contracts.
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
  return Object.freeze(base);
}
export function createStaffClient(options = {}) {
  const auth = createAuthClient(options);
  async function list(kind, {q = '', includeInactive = false, skip = 0, take = 50, partyKind} = {}) {
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
    logout: auth.logout, listCustomers: options => list('parties', {...options, partyKind: 'customer'}),
    listSuppliers: options => list('parties', {...options, partyKind: 'supplier'}),
    listItems: options => list('items', options), listLocations: options => list('locations', options)});
}

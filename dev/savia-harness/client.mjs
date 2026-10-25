// Development-only HTTP client. No storefront imports, ERP fallback, or storage simulation.
import { randomUUID } from 'node:crypto';

export const AUTHORITY = Object.freeze({ mode: 'savia', instanceId: 'savia-synthetic-v2', epoch: 1 });
export const ROOT = '/api/v2/synthetic';
const clone = value => JSON.parse(JSON.stringify(value));
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const authorityMatches = a => a?.mode === AUTHORITY.mode && a?.instanceId === AUTHORITY.instanceId && a?.epoch === AUTHORITY.epoch;
const pending = attempt => ['prepared', 'unknown'].includes(attempt.status);

export function loopbackOrigin(value) {
  const url = new URL(value);
  if (url.protocol !== 'http:' || !['localhost', '127.0.0.1', '[::1]'].includes(url.hostname)
    || url.username || url.password || url.pathname !== '/' || url.search || url.hash) {
    throw new Error('Use an HTTP loopback origin only, e.g. http://127.0.0.1:5080');
  }
  return url.origin;
}

export function initialState(baseUrl) {
  return { version: 1, baseUrl: loopbackOrigin(baseUrl), mode: 'savia', attempts: [], reservationId: null,
    creation: null, current: null };
}

export class Harness {
  constructor({ state, save, fetchImpl = globalThis.fetch, timeoutMs = 5000, uuid = randomUUID }) {
    if (state?.version !== 1 || !Array.isArray(state.attempts)) throw new Error('Unsupported attempt state');
    this.state = clone(state);
    this.state.baseUrl = loopbackOrigin(state.baseUrl);
    for (const attempt of this.state.attempts) {
      const payload = JSON.parse(attempt.body);
      const route = attempt.operation === 'reserve' ? ROOT + '/reservations'
        : attempt.operation === 'cancel' ? ROOT + '/reservations/' : null;
      if (!route || !authorityMatches(attempt.authority) || !same(payload.authority, attempt.authority)
        || payload.attemptId !== attempt.attemptId || !/^[!-~]{8,128}$/.test(attempt.key)
        || (attempt.operation === 'reserve' ? attempt.path !== route
          : !attempt.path.startsWith(route) || !/^\/api\/v2\/synthetic\/reservations\/[0-9a-f-]{36}\/cancel$/i.test(attempt.path))) {
        throw new Error('Corrupted saved attempt; inspect its original state before any request');
      }
    }
    this.save = save;
    this.fetch = fetchImpl;
    this.timeoutMs = timeoutMs;
    this.uuid = uuid;
  }

  async persist() { await this.save(clone(this.state)); }
  unresolved() { return this.state.attempts.filter(pending); }
  attempt(id) {
    const found = id ? this.state.attempts.find(a => a.attemptId === id) : this.state.attempts.at(-1);
    if (!found) throw new Error('No matching local attempt');
    return found;
  }

  async mode(value) {
    if (!['savia', 'api-cga'].includes(value)) throw new Error('Supported labels: savia, api-cga');
    if (this.unresolved().length) throw new Error('Resolve the pending/unknown attempt with its original authority first');
    // This label is deliberately closed: no unverified CGA endpoint exists here.
    if (value === 'api-cga') throw new Error('API CGA not_verified: all capabilities closed; no request sent');
    this.state.mode = value;
    await this.persist();
    return { mode: value, authority: clone(AUTHORITY) };
  }

  async request(path, options = {}) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      const response = await this.fetch(this.state.baseUrl + path, { ...options,
        headers: { Accept: 'application/json', ...options.headers }, signal: controller.signal,
        redirect: 'error' });
      const body = await response.json();
      return { status: response.status, ok: response.ok, body };
    } finally { clearTimeout(timer); }
  }

  async read(path) {
    const response = await this.request(path);
    if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.body?.code ?? 'request_failed'}`);
    return response.body;
  }

  async capabilities() { return this.read(ROOT + '/capabilities'); }
  async catalog() {
    const catalog = await this.read(ROOT + '/catalog');
    if (catalog.synthetic !== true || !authorityMatches(catalog.authority) || catalog.items?.length !== 1) {
      throw new Error('Expected the isolated V2 synthetic single-variant catalog');
    }
    const item = catalog.items[0];
    if (item.synthetic !== true || item.currency !== 'XXX' || !authorityMatches(item.authority)
      || !item.variantId || !item.locationId) throw new Error('Invalid synthetic fixture');
    return catalog;
  }
  async movements() { return this.read(ROOT + '/movements'); }
  async status() {
    if (!this.state.reservationId) throw new Error('No known reservation; use lookup for an unknown attempt');
    const current = await this.read(ROOT + '/reservations/' + encodeURIComponent(this.state.reservationId));
    if (!same(current.creation, this.state.creation) || !['active', 'cancelled'].includes(current.status)) {
      throw new Error('GET must retain the immutable original creation receipt');
    }
    this.state.current = current;
    await this.persist();
    return current;
  }

  async prepare(operation, payload, path) {
    if (this.state.mode !== 'savia') throw new Error('Provider capability closed');
    if (this.unresolved().length) throw new Error('A pending/unknown attempt exists; lookup or retry it first');
    const attemptId = this.uuid();
    const authority = clone(AUTHORITY);
    const body = { ...payload, attemptId, authority };
    const attempt = { operation, attemptId, authority, key: 'savia-harness-' + this.uuid(), path,
      body: JSON.stringify(body), status: 'prepared', result: null, error: null };
    this.state.attempts.push(attempt);
    // Persist exact authority/key/body BEFORE any POST. A write failure prevents sending.
    await this.persist();
    return attempt;
  }

  async reserve(quantity = 1) {
    if (!Number.isInteger(quantity) || quantity < 1 || quantity > 100) throw new Error('Quantity must be an integer 1..100');
    if (this.unresolved().length) throw new Error('A pending/unknown attempt exists; lookup or retry it first');
    const { items: [fixture] } = await this.catalog();
    const attempt = await this.prepare('reserve', { variantId: fixture.variantId,
      locationId: fixture.locationId, quantity }, ROOT + '/reservations');
    return this.dispatch(attempt);
  }

  async cancel() {
    if (!this.state.reservationId) throw new Error('No known reservation; resolve the reserve attempt first');
    const attempt = await this.prepare('cancel', {}, ROOT + '/reservations/'
      + encodeURIComponent(this.state.reservationId) + '/cancel');
    return this.dispatch(attempt);
  }

  accept(attempt, receipt) {
    if (!receipt || receipt.synthetic !== true || !authorityMatches(receipt.authority)
      || receipt.attemptId !== attempt.attemptId || !receipt.reservationId) throw new Error('Invalid operation receipt');
    if (attempt.operation === 'reserve') {
      const payload = JSON.parse(attempt.body);
      if (receipt.status !== 'active' || receipt.currency !== 'XXX' || !Number.isSafeInteger(receipt.unitPriceMinor)
        || receipt.unitPriceMinor < 0 || receipt.totalMinor !== receipt.unitPriceMinor * payload.quantity || receipt.variantId !== payload.variantId
        || receipt.locationId !== payload.locationId || receipt.quantity !== payload.quantity) throw new Error('Invalid creation receipt');
      if (attempt.result && !same(attempt.result, receipt)) throw new Error('Original creation response changed');
      if (this.state.reservationId === receipt.reservationId && this.state.creation && !same(this.state.creation, receipt)) {
        throw new Error('Original creation response changed');
      }
      // A replay after cancellation is still the original active creation receipt.
      // Never replace mutable current status with this receipt.
      if (this.state.reservationId !== receipt.reservationId) this.state.current = null;
      this.state.reservationId = receipt.reservationId;
      this.state.creation = clone(receipt);
    } else if (!['cancelled', 'already_cancelled'].includes(receipt.status)
      || attempt.path !== ROOT + '/reservations/' + encodeURIComponent(receipt.reservationId) + '/cancel'
      || !Number.isInteger(receipt.releasedQuantity) || receipt.releasedQuantity < 0) throw new Error('Invalid cancellation receipt');
    if (attempt.result && !same(attempt.result, receipt)) throw new Error('Original operation response changed');
    attempt.result = clone(receipt);
    attempt.status = 'succeeded';
    attempt.error = null;
  }

  async dispatch(attempt) {
    let response;
    try {
      response = await this.request(attempt.path, { method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Idempotency-Key': attempt.key }, body: attempt.body });
      if (response.ok) {
        if (response.status !== (attempt.operation === 'reserve' ? 201 : 200)) throw new Error('Unexpected successful HTTP status');
        this.accept(attempt, response.body);
      } else if (response.status >= 400 && response.status < 500 && ![408, 429].includes(response.status)) {
        // A concrete rejection is different from transport uncertainty. Preserve prior receipts.
        if (attempt.status !== 'succeeded') attempt.status = 'rejected';
        attempt.error = response.body?.code ?? 'request_rejected';
      } else {
        if (attempt.status !== 'succeeded') attempt.status = 'unknown';
        attempt.error = response.body?.code ?? 'outcome_unknown';
      }
    } catch (error) {
      if (attempt.status !== 'succeeded') attempt.status = 'unknown';
      attempt.error = error.name === 'AbortError' ? 'timeout_outcome_unknown' : 'transport_or_contract_outcome_unknown';
    }
    await this.persist();
    return clone(attempt);
  }

  async retry(id) {
    // No new catalog, key, authority, route or body is created on retry.
    return this.dispatch(this.attempt(id));
  }

  async lookup(id) {
    const attempt = this.attempt(id);
    let response;
    try {
      response = await this.request(ROOT + '/attempts/' + attempt.operation + '/' + encodeURIComponent(attempt.attemptId));
    } catch {
      if (attempt.status !== 'succeeded' && attempt.status !== 'rejected') attempt.status = 'unknown';
      attempt.error = 'lookup_unavailable_outcome_unknown';
      await this.persist();
      return clone(attempt);
    }
    if (response.status === 404) {
      if (pending(attempt)) attempt.status = 'unknown';
      attempt.error = 'attempt_unknown'; // Missing lookup never proves that POST did not execute.
    } else if (response.ok) {
      const receipt = response.body;
      if (receipt.operation !== attempt.operation || receipt.attemptId !== attempt.attemptId
        || !same(receipt.authority, attempt.authority)) throw new Error('Attempt lookup identity mismatch');
      if (receipt.outcome === 'succeeded') this.accept(attempt, receipt.result);
      else if (receipt.outcome === 'rejected' && receipt.result === null && typeof receipt.error === 'string') {
        if (attempt.status === 'succeeded') throw new Error('Lookup contradicts an acknowledged receipt');
        attempt.status = 'rejected';
        attempt.error = receipt.error;
      } else throw new Error('Unknown attempt lookup outcome');
    } else {
      if (pending(attempt)) attempt.status = 'unknown';
      attempt.error = response.body?.code ?? 'lookup_unavailable_outcome_unknown';
    }
    await this.persist();
    return clone(attempt);
  }
}

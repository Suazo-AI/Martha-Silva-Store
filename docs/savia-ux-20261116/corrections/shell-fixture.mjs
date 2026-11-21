// Runs the real app/router against fictional HTTP responses, never a real API.
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const mode = new URLSearchParams(location.search).get('case');
const variants = ['S', 'M'].map((sizeCode, i) => ({
  itemId: id(8 + i), sku: `FIX-${sizeCode}`, sizeCode, available: 5, unitPriceMinor: 10000,
}));
const me = staffId => ({
  staffId, nodeId: id(2), branchId: id(3), locationId: id(4), roles: ['MANAGER'],
  displayName: staffId === id(1) ? 'Cuenta A ficticia' : 'Cuenta B ficticia', branchName: 'Sucursal ficticia',
});
const body = {
  saleId: id(20), tillId: id(5), currencyCode: 'NIO',
  lines: [{ lineNumber: 1, itemId: id(8), sellerId: id(6), quantity: 1, unitPriceMinor: 10000, discountMinor: 0 }],
  tenders: [{ tenderNumber: 1, tenderKind: 'cash', amountMinor: 10000, receivedMinor: 10000, changeMinor: 0 }],
};
const pending = { version: 1, scope: { origin: location.origin, ...me(id(1)) }, body, changeMinor: 0 };
delete pending.scope.roles;
delete pending.scope.displayName;
delete pending.scope.branchName;
const key = 'savia.sale.pending.v1';
localStorage.removeItem(key);
window.fixture = { calls: [], held: false, released: false, posts: [], mode };
let registerReads = 0;
const response = (value, status = 200) => new Response(status === 204 ? null : JSON.stringify(value), {
  status, headers: { 'Content-Type': 'application/json' },
});
const hold = async value => {
  fixture.held = true;
  await new Promise(resolve => { fixture.release = resolve; });
  fixture.released = true;
  return response(value);
};
globalThis.fetch = async (url, options = {}) => {
  const path = String(url).replace('/api/v1', '');
  fixture.calls.push({ path, method: options.method ?? 'GET', token: options.headers?.Authorization });
  if (options.method === 'POST' && path !== '/auth/logout' && path !== '/auth/login') fixture.posts.push(path);
  if (path === '/me') return response(me(options.headers.Authorization === 'Bearer fixture-B' ? id(11) : id(1)));
  if (path === '/auth/login') return response({ token: 'fixture-B', roles: ['MANAGER'] });
  if (path === '/auth/logout') return response(null, 204);
  if (path === '/exchange-rate') return response({}, 404);
  if (path === '/cash/registers') {
    registerReads++;
    const originalTill = [{ registerId: id(9), openTillId: id(5), openTillCashierId: id(1) }];
    if (mode === 'mount-register' && registerReads === 1) return hold(originalTill);
    if (mode === 'mount-summary' && registerReads === 1) return response(originalTill);
    if (mode === 'lookup') return response(originalTill);
    if (mode === 'recovery-register-hold') return hold([]);
    if (mode === 'recovery-register-fail') return response({}, 503);
    return response(mode.startsWith('recovery-summary')
      ? [{ registerId: id(9), openTillId: id(5), openTillCashierId: id(1) }] : []);
  }
  if (path.endsWith('/summary')) {
    if (mode === 'mount-summary') return hold({ tillId: id(5) });
    if (mode === 'recovery-summary-hold') return hold({ tillId: id(5) });
    if (mode === 'recovery-summary-fail') return response({}, 503);
    return response({ tillId: id(5) });
  }
  if (path === '/cash/denominations') return hold([10000, 5000]);
  if (mode === 'lookup' && path === '/sellers') return response([{ sellerId: id(6), name: 'Vendedora ficticia' }]);
  if (mode === 'lookup' && path === '/catalog/items') return response([{ productId: id(7), name: 'Prenda ficticia', type: 'Dress', variants }]);
  if (mode === 'lookup' && path.startsWith('/catalog/lookup')) return hold(variants);
  if (path === `/sales/${body.saleId}`) return response({
    ...body, status: 'posted', subtotalMinor: 10000, discountMinor: 0, taxMinor: 0, totalMinor: 10000,
    cashierId: id(1), cashierName: 'Cuenta A ficticia', lines: [], reversals: [],
  });
  if (path.startsWith('/sales?')) return response({ items: [], page: 1, pageSize: 50, total: 0 });
  return response([]);
};
if (mode.startsWith('recovery-')) localStorage.setItem(key, JSON.stringify(pending));
sessionStorage.setItem('savia.token', 'fixture-A');
location.hash = '#/venta';
await import('/savia/web/app.mjs');
fixture.booted = true;

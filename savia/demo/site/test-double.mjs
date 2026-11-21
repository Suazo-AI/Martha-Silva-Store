// Shell-only fixture. This is not the product fake API or a business workflow proof.
export const DEMO_USERS = [
  ['duena.muestra', 'OWNER', 'Dueña de muestra'],
  ['gerente.muestra', 'MANAGER', 'Gerente de muestra'],
  ['vendedor1.muestra', 'SELLER', 'Vendedora de muestra'],
  ['vendedor2.muestra', 'SELLER', 'Vendedora dos'],
  ['vendedor3.muestra', 'SELLER', 'Vendedora tres'],
  ['bodega.muestra', 'INVENTORY', 'Bodega de muestra'],
].map(([loginName, role, displayName]) => ({ loginName, role, displayName }));
export function createFakeApi({ storage, now }) {
  return {
    reset() { storage.removeItem('shell.fixture.user'); },
    async handle(req) {
      const path = req.path.split('?')[0];
      const ok = body => ({ status: 200, body });
      if (path === '/auth/login') {
        const body = JSON.parse(req.body);
        const user = DEMO_USERS.find(u => u.loginName === body.loginName);
        if (!user || body.password !== 'demo') return { status: 401, body: { code: 'auth.invalid' } };
        storage.setItem('shell.fixture.user', JSON.stringify(user));
        return ok({ token: `fixture-${user.loginName}` });
      }
      if (path === '/auth/logout') return { status: 204 };
      if (path === '/me') {
        const user = JSON.parse(storage.getItem('shell.fixture.user') || 'null');
        if (!user) return { status: 401, body: { code: 'auth.invalid' } };
        return ok({ ...user, userId: user.loginName, roles: [user.role], branchName: 'Sucursal demo' });
      }
      if (path === '/cash/registers') return ok([{ registerId: '00000000-0000-4000-8000-000000000001', code: 'D1', name: 'Caja demo' }]);
      if (path === '/cash/denominations') return ok([10000, 5000, 1000, 500, 100]);
      if (path === '/exchange-rate') return ok({ rate: 36.6243, rateScaled: 366243, effectiveDate: now().toISOString().slice(0, 10) });
      if (path === '/suppliers') return ok([{ supplierId: '00000000-0000-4000-8000-000000000002', name: 'Proveedor demo' }]);
      if (path === '/reports/commissions') return ok([]);
      if (path === '/receiving/sessions') return ok([]);
      if (path === '/shell-probe') return ok({ method: req.method, path: req.path, headers: req.headers,
        body: req.body instanceof FormData ? Object.fromEntries(req.body) : req.body });
      return { status: 404, body: { code: 'fixture.unsupported', message: `Fixture: ${req.method} ${req.path}` } };
    },
  };
}

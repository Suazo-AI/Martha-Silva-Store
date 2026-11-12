const SALES = ['CASHIER', 'MANAGER', 'OWNER'];
export function canAccess(route, roles) {
  const name = route.split('/')[0];
  const allowed = name === 'reporte' ? ['MANAGER', 'OWNER'] :
    ['venta', 'caja', 'historial', 'recibo', 'devolucion', 'clientes'].includes(name) ? SALES :
      ['CASHIER', 'INVENTORY', 'MANAGER', 'OWNER'];
  return roles.some(role => allowed.includes(role));
}

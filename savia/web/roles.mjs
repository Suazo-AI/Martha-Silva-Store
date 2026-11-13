const SALES = ['MANAGER', 'OWNER'];
export function canAccess(route, roles) {
  const name = route.split('/')[0].split('?')[0];
  const allowed = ['aprobaciones', 'precios'].includes(name) ? ['OWNER'] : name === 'comisiones' ? ['SELLER','MANAGER','OWNER'] : ['reporte', 'excepciones'].includes(name) ? ['MANAGER', 'OWNER'] :
    ['venta', 'caja', 'historial', 'recibo', 'devolucion', 'clientes'].includes(name) ? SALES :
      name === 'ajustes' ? ['SELLER','INVENTORY','MANAGER','OWNER'] : ['recepcion','inventario','calidad'].includes(name) ? ['INVENTORY', 'MANAGER', 'OWNER'] : [];
  return roles.some(role => allowed.includes(role));
}

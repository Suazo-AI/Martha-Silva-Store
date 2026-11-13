const SALES = ['MANAGER', 'OWNER'];
export function canAccess(route, roles) {
  const name = route.split('/')[0].split('?')[0];
  const allowed = ['aprobaciones', 'precios', 'importar'].includes(name) ? ['OWNER'] : ['comisiones', 'reporte'].includes(name) ? ['SELLER','MANAGER','OWNER'] : name === 'excepciones' ? ['MANAGER', 'OWNER'] :
    ['venta', 'caja', 'historial', 'recibo', 'devolucion', 'clientes'].includes(name) ? SALES :
      name === 'ajustes' ? ['SELLER','INVENTORY','MANAGER','OWNER'] : ['recepcion','inventario','calidad'].includes(name) ? ['INVENTORY', 'MANAGER', 'OWNER'] : [];
  return roles.some(role => allowed.includes(role));
}

import assert from 'node:assert/strict';
import test from 'node:test';
import { canAccess, isApprover, isOwner, landing, receivesTags, roleName, roleSummary, SCREENS } from '../roles.mjs';

// The table as it was before roles.mjs became one table (commit df6ed8b). A change here is a product decision.
const ACCESS = {
  venta: 'OWNER,MANAGER',
  caja: 'OWNER,MANAGER',
  historial: 'OWNER,MANAGER',
  recibo: 'OWNER,MANAGER',
  devolucion: 'OWNER,MANAGER',
  clientes: 'OWNER,MANAGER',
  excepciones: 'OWNER,MANAGER',
  ajustes: 'OWNER,MANAGER,SELLER,INVENTORY',
  comisiones: 'OWNER,MANAGER,SELLER',
  reporte: 'OWNER,MANAGER,SELLER',
  aprobaciones: 'OWNER',
  precios: 'OWNER',
  importar: 'OWNER',
  recepcion: 'OWNER,MANAGER,INVENTORY',
  'recepcion/revisar': 'OWNER,MANAGER,INVENTORY',
  inventario: 'OWNER,MANAGER,INVENTORY',
  calidad: 'OWNER,MANAGER,INVENTORY',
  etiqueta: '',
  ingreso: '',
  noexiste: '',
  '': '',
};
const ALL = ['OWNER', 'MANAGER', 'SELLER', 'INVENTORY', 'CASHIER', 'ACCOUNTANT'];

test('every screen admits exactly the roles it admitted before', () => {
  for (const [route, roles] of Object.entries(ACCESS)) assert.equal(ALL.filter(role => canAccess(route, [role])).join(','), roles, route);
  assert.deepEqual(
    SCREENS.map(s => s.route).sort(),
    Object.keys(ACCESS)
      .filter(route => ACCESS[route])
      .sort(),
  );
  assert.equal(canAccess('reporte?tab=equipo', ['SELLER']), true);
});

test('the menu keeps its order and leaves out screens reached from another screen', () => {
  assert.deepEqual(
    SCREENS.filter(s => s.label).map(s => s.route),
    [
      'venta',
      'caja',
      'historial',
      'recepcion',
      'inventario',
      'clientes',
      'ajustes',
      'aprobaciones',
      'comisiones',
      'precios',
      'importar',
      'calidad',
      'excepciones',
      'reporte',
    ],
  );
});

test('landing page, approver, owner and tag receivers', () => {
  assert.deepEqual(
    ['OWNER', 'MANAGER', 'SELLER', 'INVENTORY'].map(role => landing([role])),
    ['venta', 'venta', 'comisiones', 'recepcion'],
  );
  assert.deepEqual(
    ALL.filter(role => isApprover([role])),
    ['OWNER', 'MANAGER'],
  );
  assert.deepEqual(
    ALL.filter(role => isOwner([role])),
    ['OWNER'],
  );
  assert.deepEqual(
    ALL.filter(role => receivesTags([role])),
    ['OWNER', 'MANAGER', 'INVENTORY', 'CASHIER'],
  );
  for (const role of ['OWNER', 'MANAGER', 'SELLER', 'INVENTORY']) assert.equal(canAccess(landing([role]), [role]), true, role);
});

test('each real role has a name and one sentence; a seller is not described as stock staff', () => {
  assert.deepEqual(['OWNER', 'MANAGER', 'SELLER', 'INVENTORY'].map(roleName), ['Dueña', 'Gerente', 'Vendedora', 'Bodega']);
  assert.equal(roleName('OTRO'), 'OTRO');
  assert.match(roleSummary(['SELLER'])[0], /^Vendedora:/);
  assert.equal(roleSummary(['MANAGER', 'OWNER']).length, 2);
  assert.match(roleSummary(['MANAGER', 'OWNER'])[0], /^Dueña:/);
  assert.deepEqual(roleSummary(['CASHIER']), []);
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { canAccess } from '../roles.mjs';

test('day report is restricted to manager and owner; sales screens follow sales roles', () => {
  assert.equal(canAccess('reporte', ['CASHIER']), false);
  assert.equal(canAccess('reporte', ['MANAGER']), true);
  assert.equal(canAccess('reporte', ['OWNER']), true);
  for (const screen of ['historial', 'recibo', 'devolucion', 'clientes', 'venta', 'caja']) {
    assert.equal(canAccess(screen, ['CASHIER']), true);
    assert.equal(canAccess(screen, ['INVENTORY']), false);
  }
  assert.equal(canAccess('recepcion/revisar', ['INVENTORY']), true);
});

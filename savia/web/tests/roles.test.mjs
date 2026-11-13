import test from 'node:test';
import assert from 'node:assert/strict';
import { canAccess } from '../roles.mjs';

test('real staff roles have only their modules',()=>{
  for(const role of ['SELLER','INVENTORY']) for(const screen of ['venta','caja','historial','recibo','devolucion','clientes','reporte','excepciones','precios','aprobaciones'])
    assert.equal(canAccess(screen,[role]),false,`${role} ${screen}`);
  for(const role of ['OWNER','MANAGER']) for(const screen of ['venta','caja','historial','recibo','devolucion','clientes','reporte','excepciones','comisiones','recepcion'])
    assert.equal(canAccess(screen,[role]),true,`${role} ${screen}`);
  for(const screen of ['precios','aprobaciones']) {assert.equal(canAccess(screen,['OWNER']),true);assert.equal(canAccess(screen,['MANAGER']),false);}
  assert.equal(canAccess('comisiones',['SELLER']),true);
  assert.equal(canAccess('recepcion/revisar',['INVENTORY']),true);
  assert.equal(canAccess('recepcion',['SELLER']),false);
  assert.equal(canAccess('comisiones',['INVENTORY']),false);
});

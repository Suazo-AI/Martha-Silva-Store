import assert from 'node:assert/strict';
import test from 'node:test';
import * as api from '../api.mjs';
import { newSupplier } from '../screens/import-logic.mjs';
import { passwordProblem } from '../screens/password-logic.mjs';

test('a new password follows the API rules before it is sent', () => {
  assert.equal(passwordProblem('', 'nueva-clave-12', 'nueva-clave-12'), 'Escriba su contraseña actual.');
  assert.match(passwordProblem('actual', 'corta', 'corta'), /al menos 10/);
  assert.match(passwordProblem('actual', 'x'.repeat(201), 'x'.repeat(201)), /hasta 200/);
  assert.match(passwordProblem('misma-clave-1', 'misma-clave-1', 'misma-clave-1'), /distinta/);
  assert.match(passwordProblem('actual', 'nueva-clave-12', 'nueva-clave-13'), /no coinciden/);
  assert.equal(passwordProblem('actual', 'nueva-clave-12', 'nueva-clave-12'), null);
});

test('a supplier needs a name and keeps the id it is given', () => {
  assert.equal(newSupplier('  ', 's').error, 'Escriba el nombre del proveedor.');
  assert.deepEqual(newSupplier(' Proveedor Uno ', 's').body, { supplierId: 's', name: 'Proveedor Uno' });
});

test('password change and supplier calls use the routes of the API', async () => {
  const original = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async (url, init) => {
    calls.push(`${init.method} ${url} ${init.body ?? ''}`.trim());
    return new Response(null, { status: 204 });
  };
  try {
    await api.changePassword('a', 'b');
    await api.createSupplier({ supplierId: 's', name: 'P' });
  } finally {
    globalThis.fetch = original;
  }
  assert.deepEqual(calls, [
    'POST /api/v1/auth/password {"currentPassword":"a","newPassword":"b"}',
    'POST /api/v1/suppliers {"supplierId":"s","name":"P"}',
  ]);
});

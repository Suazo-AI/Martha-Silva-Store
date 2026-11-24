import assert from 'node:assert/strict';
import test from 'node:test';
import { syncNotice } from '../ui.mjs';

test('a store refused for schema skew names the reason and keeps the cashier selling', () => {
  const text = syncNotice({ enabled: true, code: 'sync.schema_mismatch', message: 'Esquema distinto.' });
  assert.match(text, /versión de su base de datos no coincide/);
  assert.match(text, /ventas siguen guardadas/);
});

test('no banner after a round that worked, or when sync is off', () => {
  assert.equal(syncNotice({ enabled: true, lastRoundAt: '2026-11-22T13:00:00Z', code: null }), null);
  assert.equal(syncNotice({ enabled: false, code: null }), null);
  assert.equal(syncNotice(undefined), null);
});

test('an unknown refusal still shows a banner', () => {
  assert.match(syncNotice({ enabled: true, code: 'sync.failed' }), /sincronización con la central falló/);
});

test('a rebuild in progress shows tables done of total, also after a failed round', () => {
  const running = syncNotice({ enabled: true, code: null, rebuild: { done: 12, total: 39 } });
  assert.match(running, /12 de 39/);
  assert.match(running, /reconstruye/i);
  const failed = syncNotice({ enabled: true, code: 'sync.unreachable', rebuild: { done: 12, total: 39 } });
  assert.match(failed, /No hay conexión con la central/);
  assert.match(failed, /12 de 39/);
});

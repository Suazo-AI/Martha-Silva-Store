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

import assert from 'node:assert/strict';
import test from 'node:test';
import { uuid } from '../api.mjs';

// Phone page over http://<lan-ip>:5080 is not a secure context: browsers omit crypto.randomUUID there
// (found on an iPhone, 2026-11-13: the photo button did nothing). getRandomValues stays available.
test('uuid works without crypto.randomUUID (plain HTTP on the shop LAN)', () => {
  const original = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(globalThis.crypto), 'randomUUID');
  Object.defineProperty(Object.getPrototypeOf(globalThis.crypto), 'randomUUID', { value: undefined, configurable: true });
  try {
    const ids = new Set(Array.from({ length: 200 }, () => uuid()));
    assert.equal(ids.size, 200);
    for (const id of ids) assert.match(id, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  } finally {
    Object.defineProperty(Object.getPrototypeOf(globalThis.crypto), 'randomUUID', original);
  }
});

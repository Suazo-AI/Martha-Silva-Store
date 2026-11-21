import assert from 'node:assert/strict';
import test from 'node:test';
import { uuid } from '../api.mjs';
import { addToTicket, removeLine, saleRequest, setQuantity } from '../screens/sale-logic.mjs';

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

test('seller ticket lines stay editable and attributed without crypto.randomUUID', () => {
  const prototype = Object.getPrototypeOf(globalThis.crypto);
  const original = Object.getOwnPropertyDescriptor(prototype, 'randomUUID');
  Object.defineProperty(prototype, 'randomUUID', { value: undefined, configurable: true });
  try {
    const item = { itemId: 'garment', unitPriceMinor: 1200 };
    let lines = addToTicket([], { ...item, sellerId: 'seller-a' });
    lines = addToTicket(lines, { ...item, sellerId: 'seller-b' });
    const [first, second] = lines.map(line => line.ticketKey);
    for (const key of [first, second]) assert.match(key, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    assert.notEqual(first, second);
    lines = addToTicket(lines, { ...item, sellerId: 'seller-a' });
    assert.equal(lines[0].ticketKey, first);
    assert.deepEqual(
      lines.map(line => line.quantity),
      [2, 1],
    );
    lines = setQuantity(lines, second, 3);
    assert.deepEqual(
      lines.map(line => line.quantity),
      [2, 3],
    );
    const request = saleRequest({ saleId: 'sale', tillId: 'till', lines, receivedMinor: 6000 });
    assert.deepEqual(
      request.lines.map(line => [line.sellerId, line.quantity]),
      [
        ['seller-a', 2],
        ['seller-b', 3],
      ],
    );
    assert.deepEqual(
      removeLine(lines, first).map(line => line.ticketKey),
      [second],
    );
  } finally {
    Object.defineProperty(prototype, 'randomUUID', original);
  }
});

import assert from 'node:assert/strict';
import test from 'node:test';
import { shouldReclaimFocus } from '../scan.mjs';

test('history date filter retains focus when the scanner search field blurs', () => {
  const search = { tagName: 'INPUT', type: 'search' };
  const date = { tagName: 'INPUT', type: 'date', closest: () => null };
  assert.equal(shouldReclaimFocus(date, search), false);
});

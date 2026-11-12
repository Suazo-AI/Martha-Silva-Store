import test from 'node:test';
import assert from 'node:assert/strict';
import * as api from '../api.mjs';

test('pilot route contract uses implemented paths, query names and bodies', async () => {
  const original = globalThis.fetch;
  const calls = [];
  globalThis.fetch = async (url, options) => {
    calls.push({ url, method: options.method, body: options.body && JSON.parse(options.body) });
    return { ok: true, status: 204 };
  };
  try {
    await api.listReceptions(false);
    await api.currentTill();
    await api.tillSummary('till');
    await api.resolveScan('session', 'scan', 'item', 'registered');
    await api.rejectScan('session', 'scan', 'unreadable');
    await api.postReception('session');
    assert.deepEqual(calls, [
      { url: '/api/v1/receiving/sessions?open=false&limit=50', method: 'GET', body: undefined },
      { url: '/api/v1/cash/tills/current', method: 'GET', body: undefined },
      { url: '/api/v1/cash/tills/till/summary', method: 'GET', body: undefined },
      { url: '/api/v1/receiving/sessions/session/scans/scan/resolve', method: 'POST', body: { itemId: 'item', reason: 'registered' } },
      { url: '/api/v1/receiving/sessions/session/scans/scan/reject', method: 'POST', body: { reason: 'unreadable' } },
      { url: '/api/v1/receiving/sessions/session/post?currency=NIO', method: 'POST', body: undefined },
    ]);
  } finally { globalThis.fetch = original; }
});

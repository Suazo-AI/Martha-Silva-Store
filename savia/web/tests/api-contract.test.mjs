import assert from 'node:assert/strict';
import test from 'node:test';
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
  } finally {
    globalThis.fetch = original;
  }
});

test('final sales paths preserve dates, paging, credit ids and the authenticated approver', async () => {
  const original = globalThis.fetch;
  const token = api.getToken();
  const calls = [];
  globalThis.fetch = async (url, options) => {
    calls.push({
      url,
      method: options.method,
      body: options.body && JSON.parse(options.body),
      authorization: options.headers.Authorization,
    });
    return { ok: true, status: 204 };
  };
  try {
    api.setToken('cashier-test-token');
    await api.searchSales({ q: 'Blusa & lino', date: '2026-11-12', page: 2 });
    await api.getSale('sale');
    await api.searchCustomers('MUESTRA');
    await api.searchCredits('MUESTRA');
    await api.dayReport('2026-11-12');
    const body = {
      reversalId: 'reversal',
      creditId: 'credit',
      tillId: 'till',
      customerId: 'customer',
      reason: 'MUESTRA',
      lines: [{ saleLineId: 'line', quantity: 1, restockPool: 'store' }],
    };
    await api.postCreditReturn('sale', body, 'supervisor-test-token');
    await api.endApproval('supervisor-test-token');
    assert.deepEqual(
      calls.map(row => row.url),
      [
        '/api/v1/sales?q=Blusa+%26+lino&from=2026-11-12&to=2026-11-12&page=2&pageSize=25',
        '/api/v1/sales/sale',
        '/api/v1/customers?q=MUESTRA',
        '/api/v1/credits/search?q=MUESTRA',
        '/api/v1/reports/day?date=2026-11-12',
        '/api/v1/sales/sale/returns/credit',
        '/api/v1/auth/logout',
      ],
    );
    assert.equal(calls[0].authorization, 'Bearer cashier-test-token');
    assert.deepEqual(calls[5].body, body);
    assert.equal(calls[5].authorization, 'Bearer supervisor-test-token');
    assert.equal(calls[6].authorization, 'Bearer supervisor-test-token');
    assert.equal(api.getToken(), 'cashier-test-token');
  } finally {
    globalThis.fetch = original;
    api.setToken(token);
  }
});

test('expired secondary approval does not sign out the cashier', async () => {
  let signedOut = false;
  api.setUnauthorizedHandler(() => {
    signedOut = true;
  });
  try {
    await assert.rejects(
      api.request(
        'POST',
        '/sales/s/returns/credit',
        {},
        {
          token: 'expired-test-approval',
          notifyUnauthorized: false,
          fetchImpl: async () => ({ ok: false, status: 401, text: async () => '{"code":"auth.required","message":"Ingrese de nuevo."}' }),
        },
      ),
    );
    assert.equal(signedOut, false);
  } finally {
    api.setUnauthorizedHandler(() => {});
  }
});

test('a delayed logout rejection cannot invalidate a newer login', async () => {
  const original = globalThis.fetch;
  const previous = api.getToken();
  let release;
  let notified = 0;
  let authorization;
  globalThis.fetch = async (_url, options) => {
    authorization = options.headers.Authorization;
    return new Promise(resolve => {
      release = resolve;
    });
  };
  api.setUnauthorizedHandler(() => {
    notified++;
    api.setToken(null);
  });
  try {
    api.setToken('fictional-old-session');
    const retiring = api.logout();
    api.setToken('fictional-new-session');
    release(new Response('{"code":"auth.required"}', { status: 401 }));
    await assert.rejects(retiring, error => error.status === 401);
    assert.equal(authorization, 'Bearer fictional-old-session');
    assert.equal(notified, 0);
    assert.equal(api.getToken(), 'fictional-new-session');
  } finally {
    globalThis.fetch = original;
    api.setUnauthorizedHandler(() => {});
    api.setToken(previous);
  }
});

for (const phase of ['headers', 'error body']) {
  test(`a delayed ${phase} rejection cannot invalidate a newer login`, async () => {
    const previous = api.getToken();
    let release;
    let notified = 0;
    const held = new Promise(resolve => {
      release = resolve;
    });
    const response = {
      ok: false,
      status: 401,
      text: async () => {
        if (phase === 'error body') await held;
        return '{"code":"auth.required"}';
      },
    };
    api.setUnauthorizedHandler(() => {
      notified++;
      api.setToken(null);
    });
    try {
      api.setToken('fictional-old-session');
      const pending = api.request('GET', '/cash/registers', undefined, {
        fetchImpl: async () => {
          if (phase === 'headers') await held;
          return response;
        },
      });
      api.setToken('fictional-new-session');
      release();
      await assert.rejects(pending, error => error.status === 401);
      assert.equal(notified, 0);
      assert.equal(api.getToken(), 'fictional-new-session');
    } finally {
      api.setUnauthorizedHandler(() => {});
      api.setToken(previous);
    }
  });
}

test('sale approval keeps cashier bearer and passes supervisor separately', async () => {
  const original = globalThis.fetch;
  const previous = api.getToken();
  const calls = [];
  globalThis.fetch = async (url, options) => {
    calls.push({ url, headers: options.headers });
    return { ok: true, status: 204 };
  };
  try {
    api.setToken('cashier-test-token');
    await api.catalogItems();
    await api.postSale({ saleId: 'sale' }, 'approval-test-token');
    assert.equal(calls[0].url, '/api/v1/catalog/items');
    assert.equal(calls[1].headers.Authorization, 'Bearer cashier-test-token');
    assert.equal(calls[1].headers['X-Savia-Approval'], 'approval-test-token');
    assert.equal(api.getToken(), 'cashier-test-token');
  } finally {
    globalThis.fetch = original;
    api.setToken(previous);
  }
});

test('catalogItems and stock follow the Link header and return every page as one list', async () => {
  const original = globalThis.fetch;
  const urls = [];
  const page = (rows, next) => ({
    ok: true,
    status: 200,
    headers: new Headers(next ? { Link: `<${next}>; rel="next"` } : {}),
    text: async () => JSON.stringify(rows),
  });
  const pages = {
    '/api/v1/catalog/items': page([{ productId: 'a' }], '/api/v1/catalog/items?after=a'),
    '/api/v1/catalog/items?after=a': page([{ productId: 'b' }]),
    '/api/v1/stock?itemId=x': page([{ pool: 'store' }]),
  };
  globalThis.fetch = async url => {
    urls.push(url);
    return pages[url];
  };
  try {
    assert.deepEqual(await api.catalogItems(), [{ productId: 'a' }, { productId: 'b' }]);
    assert.deepEqual(await api.stock('x'), [{ pool: 'store' }]);
    assert.deepEqual(urls, ['/api/v1/catalog/items', '/api/v1/catalog/items?after=a', '/api/v1/stock?itemId=x']);
  } finally {
    globalThis.fetch = original;
  }
});

test('retryIds: the same content keeps its ids; changed content or reset gets new ones', () => {
  const ids = api.retryIds('saleId', 'tillId');
  const first = ids([1, 'x']);
  assert.match(first.saleId, /^[0-9a-f-]{36}$/);
  assert.notEqual(first.saleId, first.tillId);
  assert.equal(ids([1, 'x']), first);
  const changed = ids([2, 'x']);
  assert.notEqual(changed.saleId, first.saleId);
  assert.notEqual(ids([1, 'x']).saleId, first.saleId);
  const before = ids([3]);
  ids.reset();
  assert.notEqual(ids([3]).saleId, before.saleId);
});

test('the tag upload goes through the same request path: expired session and network error', async () => {
  let notified = 0;
  api.setUnauthorizedHandler(() => {
    notified += 1;
  });
  try {
    const expired = async () => ({ ok: false, status: 401, text: async () => '{"code":"auth.required","message":"Inicie sesión."}' });
    await assert.rejects(api.tagExtract(new Blob(['x']), '7501234567893', { fetchImpl: expired }), error => error.status === 401);
    assert.equal(notified, 1);
    const offline = async () => {
      throw new TypeError('offline');
    };
    await assert.rejects(
      api.tagExtract(new Blob(['x']), null, { fetchImpl: offline }),
      error => error.network && /Complete los datos a mano/.test(error.message),
    );
    let sent;
    const ok = async (url, options) => {
      sent = { url, options };
      return { ok: true, status: 200, text: async () => '{"source":"ocr"}' };
    };
    assert.deepEqual(await api.tagExtract(new Blob(['x']), '7501234567893', { fetchImpl: ok }), { source: 'ocr' });
    assert.equal(sent.url, '/api/v1/inventory/tag-extract');
    assert.equal(sent.options.body.get('barcode'), '7501234567893');
    assert.equal(sent.options.headers['Content-Type'], undefined);
  } finally {
    api.setUnauthorizedHandler(() => {});
  }
});

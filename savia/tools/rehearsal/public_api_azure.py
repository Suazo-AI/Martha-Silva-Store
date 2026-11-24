"""Probes the public API protections on a deployed hub. Read-only: every request is one the hub must refuse or a GET.

Usage: python public_api_azure.py <hub base url> <allowed storefront origin> <output json>
Checks: catalog 200, CORS allow and deny, strict JSON 400, 16 KB cap 413, bot check fails closed,
staff and sync routes refuse an anonymous caller, and the per-address rate limit answers 429.
"""
import json, sys, time, urllib.request, urllib.error, uuid

BASE, ORIGIN, OUT = sys.argv[1].rstrip('/'), sys.argv[2], sys.argv[3]


def req(method, path, body=None, headers=None, raw=None):
    data = raw if raw is not None else (None if body is None else json.dumps(body).encode())
    r = urllib.request.Request(BASE + path, data=data, method=method)
    if data is not None:
        r.add_header('Content-Type', 'application/json')
    for k, v in (headers or {}).items():
        r.add_header(k, v)
    for attempt in range(3):  # a TLS handshake timeout is a network fault, not an answer from the hub
        try:
            with urllib.request.urlopen(r, timeout=60) as resp:
                return resp.status, dict(resp.headers), resp.read().decode('utf-8', 'replace')
        except urllib.error.HTTPError as e:
            return e.code, dict(e.headers), e.read().decode('utf-8', 'replace')
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            print(f"  network fault on {method} {path} (attempt {attempt + 1}): {e}", flush=True)
            time.sleep(5)
    raise RuntimeError(f'{method} {path}: no answer after 3 attempts')


def code_of(text):
    try:
        return json.loads(text).get('code')
    except (ValueError, AttributeError):
        return None


ORDER = {'lines': [{'sku': 'NO-SUCH-SKU', 'qty': 1}],
         'contact': {'name': 'Prueba', 'email': 'prueba@example.invalid', 'phone': None},
         'shipping': {'zone': 'managua', 'address': 'Prueba', 'city': 'Managua', 'notes': None},
         'provider': 'manual', 'locale': 'es', 'turnstileToken': 'not-a-real-token'}
results = []


def check(name, expect, status, detail):
    ok = status in expect if isinstance(expect, (list, tuple, set)) else status == expect
    results.append({'check': name, 'expected': expect, 'status': status, 'detail': detail, 'pass': ok})
    print(f"{'PASS' if ok else 'FAIL'} {name}: {status} {detail}", flush=True)


time.sleep(61)  # an earlier run from this address may still hold the rate-limit window
s, h, t = req('GET', '/api/v1/public/catalog')
check('public catalog answers', 200, s, f"items={len(json.loads(t).get('items', [])) if s == 200 else '-'}")

s, h, t = req('OPTIONS', '/api/v1/public/orders', headers={'Origin': ORIGIN, 'Access-Control-Request-Method': 'POST',
                                                          'Access-Control-Request-Headers': 'content-type,idempotency-key'})
acao = {k.lower(): v for k, v in h.items()}.get('access-control-allow-origin')
check('CORS allows the storefront origin', True, acao == ORIGIN, f"status={s} allow-origin={acao}")

s, h, t = req('OPTIONS', '/api/v1/public/orders', headers={'Origin': 'https://evil.example', 'Access-Control-Request-Method': 'POST'})
acao = {k.lower(): v for k, v in h.items()}.get('access-control-allow-origin')
check('CORS refuses another origin', True, acao is None, f"status={s} allow-origin={acao}")

s, h, t = req('POST', '/api/v1/public/orders', body=dict(ORDER, extra='x'), headers={'Idempotency-Key': str(uuid.uuid4())})
check('unknown field is refused', 400, s, code_of(t))

s, h, t = req('POST', '/api/v1/public/orders', raw=b'{"pad":"' + b'a' * 17000 + b'"}', headers={'Idempotency-Key': str(uuid.uuid4())})
check('body over 16 KB is refused', 413, s, code_of(t))

s, h, t = req('POST', '/api/v1/public/orders', body=ORDER, headers={'Idempotency-Key': str(uuid.uuid4())})
# The bot check runs after validation and the provider lookup, before any stock is read (PublicEndpoints.CreateOrderAsync).
check('order with a fake bot-check token is refused before stock (turnstile_failed)', True,
      s == 403 and code_of(t) == 'turnstile_failed', f"{s} {code_of(t)}")

# Reports, sales and cash are mapped only on a branch node (SaviaEndpoints.MapSaviaEndpoints); these three exist on the hub.
for path in ['/api/v1/catalog/items', '/api/v1/web-orders', '/api/v1/me']:
    s, h, t = req('GET', path)
    check(f'anonymous staff route {path}', [401, 403], s, code_of(t))
# Consign is mapped only on a branch node (WebStoreEndpoints.Map), so the hub answers 404.
s, h, t = req('POST', '/api/v1/stock/web-consignments', body={})
check('consign is not mapped on the hub', 404, s, code_of(t))
s, h, t = req('GET', '/sync/v1/state')
check('sync without a node credential', [401, 403], s, code_of(t))

time.sleep(61)  # start the rate-limit window clean
# Concurrent, so 70 requests land inside one 60 s window even on a slow link.
from concurrent.futures import ThreadPoolExecutor
with ThreadPoolExecutor(max_workers=35) as pool:
    statuses = list(pool.map(lambda _: req('GET', '/api/v1/public/catalog')[0], range(70)))
first429 = statuses.index(429) + 1 if 429 in statuses else None
check('rate limit answers 429 within 70 requests a minute', True, first429 is not None,
      f"first 429 at request {first429}; counts {{{', '.join(f'{c}: {statuses.count(c)}' for c in sorted(set(statuses)))}}}")

json.dump({'base': BASE, 'origin': ORIGIN, 'at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()), 'results': results},
          open(OUT, 'w', encoding='utf-8'), indent=1)
print(f"{sum(r['pass'] for r in results)} of {len(results)} pass")
sys.exit(0 if all(r['pass'] for r in results) else 1)

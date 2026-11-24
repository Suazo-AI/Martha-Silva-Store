# Public API protections on the Azure hub (W3)

Date: 2026-11-24 (UTC). Jason approved points 1-5 on 2026-11-24; this is point 4.
Target: `ca-savia-api` revision `ca-savia-api--0000002` (image `1b1e0016`), 100% of traffic.
Tool: [public_api_azure.py](../../../savia/tools/rehearsal/public_api_azure.py). Every request is a GET or one the hub must refuse; nothing was created.
Output: [run-20261124.txt](run-20261124.txt), [run-20261124.json](run-20261124.json). Result: 12 of 12 pass.

| Check | Result |
| --- | --- |
| `GET /api/v1/public/catalog` | 200, 0 items (no web stock yet) |
| CORS preflight from `https://martha-silva-preview.jason-suazof.workers.dev` | allow-origin is that origin |
| CORS preflight from another origin | no allow-origin header |
| `POST /orders` with an unknown field | 400 `validation` |
| `POST /orders` body over 16 KB | 413 `payload_too_large` |
| `POST /orders`, valid shape, fake Turnstile token | 403 `turnstile_failed`; the bot check runs before any stock read |
| `GET /catalog/items`, `/web-orders`, `/me` without sign-in | 401 `auth.required` |
| `POST /stock/web-consignments` | 404: mapped only on a branch node |
| `GET /sync/v1/state` without a node credential | 401 `sync.unauthorized` |
| 70 concurrent catalog GETs after a clean window | 60 × 200, then 10 × 429 |

Hub settings changed for this point (point 3, hub side), as a new revision with rollback to `ca-savia-api--g1b1e001-1`:
- `Savia__Public__AllowedOrigins` and ingress CORS: the preview origin only; methods GET, POST, OPTIONS; headers `Content-Type`, `Idempotency-Key`, `X-Order-Token`; no credentials.
- `Savia__Public__OrderPageUrl`: `https://martha-silva-preview.jason-suazof.workers.dev/pedido`.

Limits:
- The rate limit is per client address (`Savia__Proxy__TrustForwardedHeaders=true`). Only one address was tested.
- Turnstile is not configured on the hub, so every real order is refused today (fails closed). A real Turnstile pass is not tested.
- The preview storefront stays in demo mode (`storefront.apiBase` empty) until Turnstile and the real catalog (W8) exist.
- During the first runs this PC's link had about 2 s round trips; those runs were repeated. The hub itself was not slow.

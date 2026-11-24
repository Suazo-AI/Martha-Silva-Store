# Public web order path (hub side)

This is how the hub takes an order from the storefront, holds stock for it, gets it paid and hands it to staff.
Contract: `docs/production-20261122/ORDER-PATH-SPEC.md`, sections 2 to 4.
Checklist rows: W1, W2, W3 and W5 are built here; W4 (card payment) has only its interface and a test gateway.
Evidence: [`../evidence/order-path-20261122/README.md`](../evidence/order-path-20261122/README.md).

## Rule that never bends

A web order can only reserve stock that a store has already handed to the web.
Each store location has one web location (`WEB-<code>`, under branch `WEB`), and only the hub writes its balance.
Reservation and the stock check run in one transaction under an application lock, so two buyers cannot both get the last unit.

## Stock flow

1. A store hands units to the web: `POST /api/v1/stock/web-consignments` on the branch (`StockWorkers`).
   The branch moves them out of its own pool at once (`transfer_out`), and the consignment travels to the hub as an event.
2. The hub credits the web location when the event arrives (`inventory.usp_ApplyWebConsignments`, run by the sweep).
   A replayed batch credits once: the consignment id is the key.
3. A buyer orders: the hub reserves at the web location and sets `ExpiresAt` (30 minutes).
4. Paid and sent: staff press "Marcar enviado"; `webstore.usp_FulfillPaidOrder` takes the units off the web location.
5. Expired or cancelled: the reservation is released once; the units stay at the web location for the next buyer.
6. Staff return web units to their store: `POST /api/v1/web-stock/release` on the hub (`Approvers`).
   The branch credits its pool when the release arrives (`inventory.usp_ApplyWebReleases`), also once.

Web-location rows never travel in the normal hub-to-branch batch, and a branch batch that carries one is refused (51851).

## Public routes (hub only)

All are under `/api/v1/public`, need no sign-in, and answer errors as `{ code, message, traceId, sku? }`.

| Route | What it does |
|---|---|
| `GET /catalog` | Active items with `available` = what one order can reserve, capped at 10. Cached 30 s. |
| `POST /orders` | Creates and reserves an order. Header `Idempotency-Key` (UUID) is required. 201, or 200 on a replay. |
| `GET /orders/{id}` | Status and lines. Header `X-Order-Token` from the create answer. Never returns the address. |
| `GET or POST /payments/{provider}/return` | The buyer's browser after a hosted page. Always 303 to `Savia:Public:OrderPageUrl?order=<id>`. |
| `POST /payments/{provider}/webhook` | Provider notice. The provider checks the signature first. |

The order request carries no prices: the hub prices lines and shipping itself, so a stale page cannot underpay.

### Retry and replay

The idempotency key fixes the order id and the access token (`WebOrderKeys`), so a retry finds its own order.
The same body returns the same order; a changed body returns 409 `idempotency_conflict`.
The bot check runs after that lookup, because a Turnstile token works once and a retry carries a new one.
The database keeps only SHA-256 hashes of the token, of the request and of the client address.

### Public error codes

| Code | Status | When |
|---|---|---|
| `validation` | 400 | Bad JSON, an unknown field, a missing key, or a value out of range. |
| `turnstile_failed` | 403 | The bot check said no. Nothing was reserved. |
| `not_found` | 404 | Unknown order or wrong token (the two are not told apart). |
| `out_of_stock` | 409 | Not enough web stock; `sku` names the first short line. |
| `too_many_unpaid` | 409 | The same email or client address already holds 2 unpaid orders. |
| `idempotency_conflict` | 409 | The key was used with another body. |
| `provider_unavailable` | 409 | The chosen payment way is not set up (today: `card`). |
| `signature_invalid` | 401 | A webhook with a bad signature. Nothing was written. |
| `payload_too_large` | 413 | Body over 16 KB. |
| `rate_limited` | 429 | Over the per-address limit. |

## Abuse controls

- Rate limit per client address on every public route: `Savia:Public:PerMinute` (60; 0 turns it off).
- Body cap of 16 KB, enforced while reading, not only from `Content-Length`.
- Strict JSON: unknown fields are refused.
- CORS only for origins in `Savia:Public:AllowedOrigins` (comma-separated), GET and POST, never credentials.
  Staff routes stay same-origin.
- Bot check (`IBotCheck`): Cloudflare Turnstile with `Savia:Public:Turnstile:Secret` from the environment.
  It fails closed: no secret or no answer means no order.
  `Savia:Public:BotCheck=disabled` exists for local runs and tests only.
- At most 2 unpaid orders per email and per client address (SQL error 51746).
- Provider webhooks are public routes too, so they share the per-address limit and the 16 KB cap.
- The client address is the proxy's last hop only when `Savia:Proxy:TrustForwardedHeaders` is on (Container Apps).
  Without it behind a proxy, every buyer shares one address, one rate limit and one 2-unpaid limit.

## Payments

`IPaymentProvider` (in `Savia.Api/Payments.cs`) follows spec 4.3, plus `OrderId` on `PaymentResult` so a return or webhook can name its order.
Only a server-side answer records a payment: `ConfirmReturnAsync`, `QueryAsync`, or a signed webhook.
A browser parameter such as `?status=paid` is never believed.

- `manual` is the only real provider. It is not a card (D-008).
  The buyer sees instructions (`Savia:Payments:Manual:Instructions`); staff record the transfer on the staff screen.
- A buyer who asks for `card` gets the registered card provider, or 409 `provider_unavailable` while none exists.
- `FakeHostedGateway` lives in the test project only. It shows what BAC or Pagadito must do: keep state server-side and sign webhooks.
- A capture the order cannot take is recorded with its real amount and currency in `webstore.PaymentReviews` (V057), never refused.
  - Reserved order, other amount or currency: `payment_review`; the reservation is released once.
  - Expired or cancelled order: `payment_review`; stock does not change.
  - Paid, shipped or already in review: the status stays; the second capture is flagged for review.
- A person then marks the money refunded (order cancelled) or accepts it (order paid, stock reserved again or 51102).

## Expiry sweep

`WebStoreWorker` runs `WebStoreSweep` every `Savia:WebStore:SweepSeconds` (60; 0 turns it off).
The first pass waits one interval, so a host that starts and stops at once never sweeps.

- On the hub: credit arrived consignments, then settle each reservation past `ExpiresAt`.
  It asks the provider first, because the buyer may have paid and closed the tab.
  Captured means paid; no answer keeps the order reserved for the next pass; anything else expires it.
- On a branch: credit arrived releases.

Every step is idempotent in SQL, so a retry or a second host cannot release twice.
A capture for another amount or currency moves the order to `payment_review` and is counted as review.
An order the pass cannot settle (a provider or database error) is logged, stays reserved and is counted as kept.
The orders behind it still expire, and a failed consignment step does not stop expiry.
A pass reads at most 50 due orders, oldest first, so 50 such stuck orders would hold back the rest until staff act on them.

## Staff screen (W5)

Menu "Administración → Pedidos web" (`#/pedidos-web`), for `MANAGER` and `OWNER`, shown only on the hub.
It lists up to 500 orders by status (unpaid, to send, payments to review, all) with contact, address, lines and source store.

- Unpaid: "Registrar pago" with a reference (records the order total as a manual payment), or "Cancelar".
- Paid: "Marcar enviado".
- Payment to review: the captured amount, currency and reason, then "Aceptar pago" (order paid, stock reserved again)
  or "Marcar devuelto" with the refund reference (order cancelled).

The routes behind it are `GET /api/v1/web-orders?status=` and `POST /api/v1/web-orders/{id}/manual-payment|fulfill|cancel|accept-payment|mark-refunded`.

## Settings

| Key | Default | Purpose |
|---|---|---|
| `Savia:Public:AllowedOrigins` | none | Storefront origins for CORS. |
| `Savia:Public:PerMinute` | 60 | Public requests per address per minute. |
| `Savia:Public:BotCheck` | Turnstile | `disabled` for local runs only. |
| `Savia:Public:Turnstile:Secret` | none | Secret from the environment. Without it, no order is taken. |
| `Savia:Public:OrderPageUrl` | `/` | Where a payment return sends the buyer. |
| `Savia:Payments:Manual:Instructions` | built-in text | What a manual-payment buyer reads. |
| `Savia:WebStore:SweepSeconds` | 60 | Sweep interval. |

## Database

| File | Adds |
|---|---|
| `V047__web_stock_location.sql` | Branch `WEB`, one web location per store location, `webstore.WebLocationSources`. |
| `V048__web_consignment_release.sql` | Consign and release procedures and their apply-once tables. |
| `V049__web_order.sql` | Shipping zones, order columns, `webstore.usp_CreateWebOrder`. |
| `V050__web_order_expiry_payment.sql` | Expiry, cancel, verified payment and `payment_review`. |
| `V051__web_order_reads.sql` | JSON reads for the catalog, one order, the staff list and due orders. |
| `V057__web_payment_review.sql` | `webstore.PaymentReviews`, card capture into review, accept and mark-refunded. |

No public SQL role exists: the public routes run as the API host login, like every other route.

## Open decisions for the owner

- Shipping prices: `managua` C$500 and `departamentos` C$800 are copied from the demo storefront.
- Who may record a manual payment: today `MANAGER` and `OWNER`.
- Whether 30 minutes is enough to pay by bank transfer.
- The 2-unpaid limit per client address may block buyers who share one mobile-carrier address.

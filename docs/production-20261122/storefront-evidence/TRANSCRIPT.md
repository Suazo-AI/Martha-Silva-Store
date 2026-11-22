# Storefront live order path: end-to-end run, 2026-11-22

Result: the live storefront placed real hub orders, kept one order per checkout attempt, gave the last unit to one buyer, and showed the paid state after staff recorded the payment.
One hub defect blocked the staff screen itself; the staff API it calls worked.

## Setup

- Hub: `savia/` API built from source commit c4ca690f, on 127.0.0.1:5181, node kind Cloud, bot check disabled, CORS allow-list `http://127.0.0.1:8787`, rate limit off.
- Database: disposable `SAVIA_T_storefront_e2e` cloned through `saviadb.py`, dropped at the end.
- Stock consigned to the web: 3 of `T-SKU-0001` (120000 NIO) and 1 of `T-SKU-0002` (85000 NIO plus 15% tax).
- Storefront: `prepare.py --config` with `apiBase http://127.0.0.1:5181`, the Turnstile test site key `1x00000000000000000000AA`, and two SKU mappings (`rosa-empolvado-pedreria-M`, `gris-perla-hombros-S`).
- Served by `wrangler dev` (it applies `_headers`) on 127.0.0.1:8787.
- Browser: agent-browser 0.34.0 (Chrome 152), sessions `default`, `buyerA`, `buyerB`.
- Buyers: fictitious names and `example.test` addresses only.

## Steps and observations

| # | Step | Observed | Screenshot |
|---|---|---|---|
| 1 | Open the rosa product page | hub price C$1,200.00; unmapped sizes show "Agotada"; CSP allows only the hub and Turnstile | 01 |
| 2 | Add size M to the bag | bag shows the hub subtotal | 02 |
| 3 | Checkout to the review step | the delivery step has no coupon field; provider radio reads "Pago manual (no es tarjeta)", the hub label; the Turnstile test widget passes | 03 |
| 4 | Two synchronous clicks on "Confirmar pedido" | one row in `webstore.Orders` (W512F4AD7); one Idempotency-Key | 04 |
| 5 | Reload the order page | `/pedido?order=<id>`; the token is only in localStorage, never in the URL | 04 |
| 6 | Staff records the manual payment | `POST /api/v1/web-orders/{id}/manual-payment` returned 204 | 05 is the blank staff screen (defect below) |
| 7 | Buyer reloads the order page | status "Pago aprobado" | 06 |
| 8 | Two buyers race for the last `T-SKU-0002` | buyerB got WDDA50D5B; buyerA saw "Ya no hay suficiente existencia de Vestido gris perla de hombros descubiertos, talla S."; hub stock 0 | 07, 08 |
| 9 | Bag after the sell-out | the line stays in the bag until checkout refuses it | 09 |
| 10 | English review step | product, checkout and review are English; the manual label stays the hub's Spanish label | 10 |
| 11 | Confirm while offline | "We could not connect to the store. Check your connection and try again."; no order created | 11 |
| 12 | Back online, confirm again | exactly one new order (W0A6C983C); the hub list shows 3 orders in total | 12 |

The order total for `T-SKU-0002` was 177750 = 85000 + 12750 tax + 80000 shipping.
The order page shows only the hub's own delivery and total amounts.

Step 8 caveat: buyerA's refusal may come from the storefront's catalog pre-check rather than from the hub's 409.
The hub log has two `out_of_stock|409` entries; which request each belongs to was not traced.
The hub tests cover the atomic reservation itself.

## Hub defect found (not fixed: `savia/` is outside this task)

- Request: staff signs in on the Cloud node and opens `#/pedidos-web`.
- Response: `savia/web/app.mjs` line 177 calls `syncTill` for approvers; `GET /api/v1/cash/registers` returns 404 on a Cloud node; the route throws "El servidor respondió 404" and the screen never mounts.
- Expected: on a Cloud node the staff app skips the till sync and mounts "Pedidos web".
- Workaround in this run: the same staff API calls, made by a script that never printed the token.

## Lighthouse 12.8.2, mobile, live build

| Page | Performance | Accessibility | Best practices | SEO |
|---|---|---|---|---|
| Home `/` | 61 | 100 | 96 | 66 |
| Catalog `/catalogo` | 85 | 100 | 96 | 66 |
| Product `/producto-rosa-empolvado-pedreria` | 67 | 100 | 96 | 66 |
| Checkout `/checkout` | 87 | 100 | 96 | 63 |

- With `Cross-Origin-Opener-Policy: same-origin` every run failed with `NO_NAVSTART` (trace lost in the process swap); the table comes from the same build with only that header removed.
- SEO is below 90 on purpose: `noindex` and `Disallow: /` stay until launch.
- Best practices loses 4 points to a `/favicon.ico` 404 that predates this work.
- Performance below 90 predates this work: the demo build scored home 54, product 46 and checkout 75 on a plain local server.
  Product LCP is 17 s in the simulation, almost all render delay after 1 to 1.5 s of blocking scripts; Lighthouse also flags about 1 MB of oversized product images.
- Fixed from these runs: the hub `preconnect` link, and the checkout back link's 24 px target size (WCAG 2.2 2.5.8).

## axe 4.12.1 (WCAG 2.0, 2.1 and 2.2 A and AA tags)

| Page | Violations | Needs manual review |
|---|---|---|
| Home | 0 | color contrast over photos and video; captions on product videos |
| Catalog | 0 | color contrast over photos |
| Product | 0 | color contrast over photos; captions on product videos |
| Checkout, empty | 0 | none |
| Checkout, review step with Turnstile | 0 (1 before the target-size fix) | color contrast |
| Order page with a live order | 0 | none |

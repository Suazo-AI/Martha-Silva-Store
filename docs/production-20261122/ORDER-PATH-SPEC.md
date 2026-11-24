# Order path specification

Task: `store-order-path-research-20261122`, mode DISCOVER.
Every source was read on 2026-11-22.
No repository file was changed.

Evidence tags:
- [F] means a verified fact, read directly from the primary source or from the repository.
- [V] means a vendor claim on the vendor's own marketing page.
- [S] means a third-party source or a search snippet only, with the page itself not read.
- [I] means my inference.

## 0. Result first

- [I] Primary card provider: the BAC Credomatic "E-Commerce" gateway with a hosted payment page and 3-D Secure.
- [I] Interim under the same BAC contract: Compra-Click payment links, created by staff, with no integration.
- [I] Fallback if BAC refuses or stalls: Pagadito (public docs, sandbox, USD only, 5% + US$0.25 published).
- [I] A second bank option to quote in parallel: Banpro, whose e-commerce platform runs on CyberSource.
- [F] Stripe cannot be used, because Nicaragua is not a supported country.
- [I] The oversell risk is in the current design, not in the future: the hub would write stock rows that the branch owns.
- [I] Fix: a hub-owned web stock location, filled only by consignments that the branch sends.
- [I] Build order: the `manual` provider ships first, labelled "not card"; the card adapter follows when BAC assigns its gateway and sandbox.
- [F] D-008 says cards are required for production, so the `manual` provider alone does not meet the production goal.

## 1. Card providers for a Nicaraguan merchant (late 2026)

### 1.1 Evidence per provider

BAC Credomatic Nicaragua:
- [F] The page https://www.baccredomatic.com/es-ni/pymes/ventas-digitales lists Compra-Click at US$20 sign-up and US$10 a month, plus a processing rate that it does not publish.
- [F] The same page lists the "E-Commerce BAC" gateway with registration, monthly and per-transaction fees, but no amounts.
- [F] It names Visa, Mastercard, Amex and 3-D Secure (Verified by Visa/SafeKey).
- [F] It requires return and shipping policies, SSL, a cart on the site, and a web catalog with current prices.
- [F] The 2020 BAC article https://www.baccredomatic.com/es-ni/nuestra-empresa/que-tan-facil-es-vender-en-linea-en-nicaragua says Compra-Click needs an affiliated merchant with a POS or MiPOS.
- [F] That article gives pagosenlinea@baccredomatic.ni and 1-800-1111 option 3 as the contact.
- [F] That article says the commission depends on the business type, settlement is daily, and IR is withheld.
- [S] A snippet of https://www.baccredomatic.com/es-ni/pymes/comercio-afiliado (the page returned 403) lists "API, WebService, Hosted Payment Page, PlugIns".
- [S] The same snippet requires development certification, committee approval and a contract addendum.
- [S] Another BAC NI snippet shows activation US$75, monthly US$35 and US$0.10 per transaction, plus commission.
- [S] The Costa Rica page lists gateway choices CARDINAL, PowerTranz (FAC), Cybersource and LYRA; whether Nicaragua uses the same list is unknown.
- [F] The BAC NI affiliation contract V13 (https://www.baccredomatic.com/sites/default/files/2024-04/CONTRATO_DE_AFILIACION_Final_aprobado_V13_18032024_R11_final.pdf) defines e-commerce as sales on the merchant page or through a Compra-Click link, certified by the gateway.
- [S] The BAC API Center (https://www.baccredomatic.com/es-cr/empresas/api-center) shows eCommerce APIs as "Pronto".
- [S] The legacy Credomatic API (`credomatic.compassmerchantsolutions.com/api/transact.php`, MD5 hash) appears only in 2001–2007 guides; treat it as obsolete.
- Currencies: [I] BAC NI accounts exist in NIO and USD, but the gateway currencies are not published.
- Webhook: not published.
- PCI scope: [I] SAQ A with a hosted page or a full redirect; SAQ A-EP or D with a direct API.

PowerTranz (formerly First Atlantic Commerce):
- [V] https://www.powertranz.com marketing pages offer a "Hosted Payment Page" and "3D-Secure 2.X", and they show a BAC logo.
- [F] The developer documentation is password-protected; access needs a contact form.
- [S] Unofficial PHP SDKs (https://packagist.org/packages/nexvia-llc/powertranz-sdk, https://packagist.org/packages/ylynfatt/powertranz-php-sdk) describe the flow `POST /api/spi/sale`, then a browser POST to `MerchantResponseUrl`, then `POST /api/spi/payment` with the `SpiToken`.
- [S] Those SDKs say the `SpiToken` lasts about 5 minutes and `PageSet` starts with `PTZ/`.
- [I] PowerTranz is the likely gateway behind BAC e-commerce, but no source confirms that for Nicaragua.

Banpro (Grupo Promerica):
- [F] https://www.banprogrupopromerica.com.ni/banca-de-personas/e-commerce/ offers "una plataforma de pagos procesada a través de CyberSource" with fraud prevention and tokenization.
- [F] https://www.banprogrupopromerica.com.ni/banca-de-empresas/comercios-afiliados/ requires RUC, Matrícula de la Alcaldía, the legal representative's cédula and a Banpro account.
- [I] CyberSource offers a hosted checkout (Secure Acceptance or Unified Checkout) with public docs, so an adapter can be shaped on a real API.
- Fees, currencies and 3-D Secure: not published.

Banco LAFISE:
- [F] https://www.lafise.com/blb/banca-personal/adquirencia/ lists "E-Commerce" ("Comience a vender en línea desde su página web o app móvil"), POS, recurring payments and Poket payment links.
- [F] https://www.lafise.com/ni returned a 404 page; the Nicaragua-specific e-commerce detail page was not read.
- Fees, currencies, gateway and webhook: unknown.

Ficohsa Nicaragua:
- [F] ficohsa.com.ni refused the connection (ECONNREFUSED).
- [S] A press article (URL not kept) mentions a payment link, with acquiring on Visanet and processing on First Data/Fiserv.
- Everything else: unknown.

Pagadito:
- [F] https://dev.pagadito.com/es/nicaragua/ lists Nicaragua among the countries where a merchant can open an account.
- [F] The terms page https://www.pagadito.com/contenido/ACUERDOS_Y_CONDICIONES_DE_USO publishes US$1.00 affiliation and "USD0.25 + 5% + impuesto local" per transaction.
- [F] https://www.pagadito.com/contenido/CARGOS says the processing fee "se fija durante el proceso de validación", so the 5% may be negotiated.
- [F] The terms say payments are made only in US dollars; NIO is not supported.
- [F] Pagadito offers a Web Service, an API with Java and PHP libraries, cart plugins, a "Botón de pago", a return URL, a webhook guide and a sandbox.
- [F] Onboarding for a company: articles of incorporation, tax document, proof of address, legal representative's credential and ID, and a bank reference.
- 3-D Secure and webhook signature: not found.
- PCI scope: [I] SAQ A if the buyer pays on Pagadito's page.

PayPal:
- [F] paypal.com/ni returned 403 to the fetch, so nothing was verified on PayPal's own pages.
- [S] The PayPal fee PDF https://www.paypalobjects.com/marketing/ua/OA/merchant-fees/es-ROW-102826.pdf puts Nicaragua at 5.40% + US$0.30 on international commercial receipts.
- [S] Prensa Libre (https://www.prensalibre.com/economia/paypal-amplia-sus-servicios-en-nicaragua/) reports PayPal business accounts in Nicaragua, undated.
- [I] PayPal is a wallet checkout; local buyers without PayPal accounts and withdrawal to a local bank are unproven.

Stripe:
- [F] https://stripe.com/global does not list Nicaragua; it says "Payments not supported yet" for unsupported countries.
- [F] https://docs.stripe.com/connect/cross-border-payouts limits self-serve cross-border payouts to the US, UK, EEA, Canada and Switzerland.

dLocal:
- [F] https://docs.dlocal.com/docs/nicaragua.md covers payins in NIO with Visa, Mastercard, JCB, Amex, Discover, Diners and PuntoXpress cash.
- [F] https://docs.dlocal.com/docs/nicaragua-payouts-v3.md covers payouts to BAC, Banpro and Lafise.
- [F] The dLocal homepage targets global merchants with "Contact sales"; no page says a Nicaraguan company can contract it.
- [I] Not a fit for a small domestic store.

Verifone / 2Checkout:
- [F] 2checkout.com returned an empty body and its knowledge center failed TLS.
- [S] The 2Checkout FAQ (https://docs.2checkout.com/get-started/getting-started/help-and-faqs) lists Nicaragua among countries whose merchants are not accepted.

Tilopay:
- [S] Revista Summa (https://revistasumma.com/?p=230960) reports a Nicaragua expansion.
- [S] BigCommerce (https://support.bigcommerce.com/articles/en_US/Knowledge/Tilopay-Payment-Methods) lists "Cuotas BAC" for Nicaragua through Tilopay.
- [I] Worth one question to BAC, but not a plan input today.

Regulation:
- [S] The BCN card-payment circular (https://bcn.gob.ni/sites/default/files/noticias/notas_prensa/2024/NP Circular Pagos con Tarjetas.pdf) applies.
- [S] BCN resolution GG-08-MAYO-2025 on payment service providers applies (under bcn.gob.ni/sites/default/files/normas_disposiciones/; full URL not kept).
- [S] The US trade guide (https://www.trade.gov/country-commercial-guides/nicaragua-ecommerce) says an e-commerce business must be incorporated with a physical address.

### 1.2 Recommendation

Primary: BAC E-Commerce gateway, hosted page, 3-D Secure.
- [I] Reason: BAC is the largest acquirer in Nicaragua, it settles to a local account, and its hosted page keeps the site in SAQ A.
- What the merchant must do:
  1. Be a BAC SME client with a BAC business account.
  2. Become a BAC affiliated merchant (POS or MiPOS first, if BAC still requires it).
  3. Request "E-Commerce BAC" with "Hosted Payment Page" as the integration model.
  4. Provide the site URL with SSL, return and shipping policies, and a catalog with current prices.
  5. Ask for the written fee quote, the gateway name, NIO and USD support, webhook support, sandbox credentials and the certification steps.
  6. Sign the e-commerce addendum and pass the development certification.

Interim under the same BAC contract: Compra-Click links.
- [I] Staff create a link per order and send it; SAVIA records the payment through the `manual` provider.
- [I] This does not remove the BAC dependency, so it is not a fallback.

Fallback: Pagadito.
- [I] Reason: a public sandbox and documented API, self-serve onboarding, and no bank committee.
- [F] Limits: USD only and a 5% + US$0.25 published rate.
- What the merchant must do: open a Pagadito Comercio account, upload the company documents, pass validation, and get the production UID and WSK.

Parallel quote: Banpro (CyberSource).
- [I] Ask for it if the merchant already banks at Banpro; a CyberSource hosted checkout is a valid primary as well.

## 2. Order path architecture

### 2.1 Standards that apply

- [F] PCI SAQ A v4.0.1 (January 2025 update) removed requirements 6.4.3, 11.6.1 and 12.3.1 from SAQ A: https://blog.pcisecuritystandards.org/important-updates-announced-for-merchants-validating-to-self-assessment-questionnaire-a.
- [F] In their place, the merchant must confirm that its site is not susceptible to attacks from scripts that could affect its e-commerce systems: https://blog.pcisecuritystandards.org/faq-clarifies-new-saq-a-eligibility-criteria-for-e-commerce-merchants.
- [I] The task's premise that SAQ A needs 6.4.3 and 11.6.1 is out of date; the script-safety criterion replaces them.
- [S] PCI SSC FAQ 1588 (https://www.pcisecuritystandards.org/faqs/1588/, search summary) limits that criterion to pages that embed a payment page or form, not to full redirects.
- [S] The same FAQ says it can be met with techniques such as 6.4.3 and 11.6.1, run by the merchant or a third party.
- [S] SAQ A still requires quarterly ASV scans of the merchant web pages (requirement 11.3.2), even with a redirect.
- [I] Choose a full redirect, not an iframe: the script criterion then does not apply, and no card field touches our origin.
- [F] Adyen's guide https://docs.adyen.com/development-resources/pci-dss-compliance-guide/saq-a-eligibility describes the same eligibility change.
- [F] OWASP ASVS 5.0 (https://github.com/OWASP/ASVS) covers business logic in V2.3 and anti-automation in V2.4.
- [F] OWASP API Security Top 10 2023 (https://owasp.org/www-project-api-security/) names API1 broken object-level authorization, API4 unrestricted resource consumption and API6 unrestricted access to sensitive business flows.
- [F] Cloudflare Turnstile tokens must be checked on the server with siteverify; a token lasts 300 seconds, is at most 2048 characters, and is single-use: https://developers.cloudflare.com/turnstile/get-started/server-side-validation/.
- [F] Siteverify accepts an `idempotency_key` so a retry does not fail as a reused token.
- [F] Cloudflare `_headers` applies only to static asset responses: https://developers.cloudflare.com/workers/static-assets/headers/.
- [F] Azure Container Apps supports ingress CORS with `az containerapp ingress cors enable --allowed-origins`, and CLI updates replace the current settings: https://learn.microsoft.com/azure/container-apps/cors.

### 2.2 Flow

1. The storefront loads static pages from Cloudflare and fetches live prices and availability from the hub read API.
2. The cart stays in the browser (localStorage), holds SKUs and quantities only, and never holds a price that the server trusts.
3. At checkout the browser sends one `POST /api/v1/public/orders` with an `Idempotency-Key` header, a Turnstile token, lines, contact and shipping.
4. The hub verifies Turnstile, validates input, prices the lines from `catalog.Items`, and reserves stock at the web stock location in one transaction.
5. The hub returns the order with `expiresAt` and the payment start (a redirect URL for card, instructions for `manual`).
6. For card, the browser goes to the provider's hosted page; no card data touches our origin.
7. The provider returns the buyer to `POST /api/v1/public/payments/{provider}/return`.
8. The hub never trusts the return parameters alone; it confirms with the provider server-to-server, then records the payment.
9. A signed provider webhook, if the provider has one, takes the same server-side confirm path.
10. An expiry job queries the provider before it releases an unpaid reservation, because the buyer may have closed the browser after paying.
11. A paid order creates an outbox notice for the store team and a fulfillment row.

### 2.3 Order state machine

- `pending` to `reserved`: stock reserved, `ExpiresAt` set (30 minutes, as in `src/store-api.js`).
- `reserved` to `paid`: verified payment only, amount and currency match.
- `reserved` to `expired`: expiry job, after a provider query says "not paid"; stock released.
- `reserved` to `cancelled`: buyer or staff cancel; stock released.
- `expired` to `payment_review`: a verified payment arrives after expiry; no stock change; staff refund or re-reserve.
- `paid` to `fulfilling` to `fulfilled`: staff action; stock leaves the web location.
- `paid` or `fulfilled` to `refunded`: staff action through the provider refund.
- [F] The `webstore.Orders` CHECK in V001 allows pending, reserved, paid, fulfilling, fulfilled, cancelled and refunded.
- [I] `expired` and `payment_review` need a migration that widens that CHECK.

### 2.4 Abuse controls

- [I] Reservation hoarding is the main business-flow risk (API6): a bot can reserve all stock and never pay.
- Controls:
  - Turnstile on order creation, checked server-side.
  - A per-IP rate limit on public routes, at the app and at the Cloudflare edge.
  - At most 10 units per line (as today) and 20 lines per order.
  - At most 2 unpaid orders per email and per IP at a time.
  - A 30-minute expiry; 15 minutes is an option if hoarding appears.
  - A 16 KB request body limit and strict JSON schema validation, with unknown fields rejected.
- [I] Order lookup uses a random UUID plus a per-order access token, stored as a hash, to block API1 enumeration.
- [I] The per-IP limiter needs the real client IP; `Savia:Proxy:TrustForwardedHeaders` must be on, with only the ingress proxy trusted.

### 2.5 CORS and headers

- [I] The browser calls the Azure API cross-origin, without cookies or credentials.
- [I] I chose this over a Worker proxy because the repository keeps the Worker static (AGENTS.md: do not enable Worker by default).
- CORS: allow only the storefront origin, methods GET and POST, headers `Content-Type`, `Idempotency-Key` and `X-Order-Token`, with no credentials.
- [F] `Hosting.cs` has no CORS today.
- Storefront CSP changes:
  - add the API origin to `connect-src`;
  - add the payment page origin to `form-action` if the redirect is a form POST;
  - add `https://challenges.cloudflare.com` to `script-src` and `frame-src` for Turnstile ([S] from Cloudflare's Turnstile CSP guidance, not re-read today).

### 2.6 Notices and privacy

- [I] Phase 1: store staff see web orders on a signed-in hub screen; an outbox row triggers an email to the store.
- [I] Phase 2: a WhatsApp notice through the Meta Cloud API, which needs a Meta business account (Jason's decision).
- [I] Notices carry the order code, items and delivery zone, not the full address or phone.
- [I] Collect only name, email, phone and delivery address; keep no card data; keep personal data out of logs.
- [S] Nicaragua's personal data law (Ley 787 of 2012) applies; the privacy notice text needs legal review.

## 3. Repository map

### 3.1 What a web order can reuse

- [F] `webstore.Orders`, `OrderLines`, `OrderAddresses`, `Payments` and `Fulfillments` exist in `savia/db/migrations/V001__baseline.sql`.
- [F] `webstore.Orders.ExternalOrderRef` is unique and `RequestHash` supports idempotency.
- [F] `webstore.Payments` is unique on (Provider, ExternalPaymentId) and allows initiated, authorized, captured, failed and refunded.
- [F] `inventory.StockReservations.ExpiresAt` exists (nullable), but `usp_CreateReservedOrder` does not set it.
- [F] `inventory.StockBalances` has pools `store`, `web` and `quarantine`, and reservations are allowed only on `web`.
- [F] `usp_CreateReservedOrder` hashes the request, raises 51710 on a changed request, 51703 on a price or currency mismatch, and 51102 when stock is short.
- [F] It routes `web.order_reserved` to the branch node and raises 51711 when the branch has no node.
- [F] `@CustomerId` is optional (default NULL), so guest checkout with `OrderAddresses` needs no `crm.Customers` row.
- [I] Guest checkout avoids the D-039 rule that the creating branch owns its customers.
- [F] `usp_RecordVerifiedPayment` requires `@VerifiedByTrustedService=1`, rejects a reused gateway id (51705) and an amount mismatch or non-reserved order (51706).
- [F] `usp_FulfillPaidOrder` takes the quantity off both OnHand and Reserved in the web pool.
- [F] Roles `savia_web_checkout`, `savia_payment_worker` and `savia_fulfillment_worker` hold the grants.
- [F] `catalog.Items` stores `UnitPriceMinor` and `CurrencyCode` per item.
- [F] Six database tests exist in `savia/db/tests/webstore/` (010 to 060).

### 3.2 Why the current stock design can oversell

- [F] `sync.SyncTables` (V032) gives `inventory.StockBalances` the owner "branch node of the location's branch".
- [F] Branch-to-hub apply is a `MERGE` that updates every changed column (V032, around line 345).
- [I] If the hub reserves stock in a branch-owned row, the next branch push overwrites `Reserved` with the branch's value.
- [I] The web would then see stock that was already sold, so it can oversell.

### 3.3 Stock rule that cannot oversell

- [I] Create a `WEB` branch in `core.Branches` with no `sync.Nodes` branch node.
- [I] Create one web location per physical store under that branch (for example `WEB-<store>`), because `core.Locations.BranchId` cannot be null.
- [F] With no branch node, the owner expression returns NULL for those rows.
- [F] In normal mode the hub sends rows only where `(owner)<>@target` (V032 line 229); NULL fails that test, so web-location rows stay on the hub.
- [F] In rebuild mode the hub sends every row to a restored branch (`1=1`, V032 lines 182 and 229), so a restored branch gets a copy of web-location rows.
- [F] A branch exports only rows where `(owner)=@me`, so it never sends that copy back.
- [F] The hub rejects incoming rows where `ISNULL(owner, zero-guid)<>@peer` with 51851 (V032 line 333), and it refuses rebuild batches with 51850 (line 288).
- [I] So no branch can write web-location rows on the hub; a branch copy after a rebuild is stale and must not be shown as stock.
- [I] A new table `webstore.WebLocationSources(WebLocationId, SourceBranchId, SourceLocationId, PriorityRank)` tells fulfillment which store holds the garment.
- [I] One order reserves at one web location, so every line ships from one store.
- [I] The hub picks the web location with the best `PriorityRank` that can fill every line; if none can, it answers `out_of_stock`.
- [I] The catalog shows, per SKU, the largest stock at any single web location, not the sum, so it never shows units that one order cannot reserve.
- [I] A split shipment across stores is out of scope for the first release.
- [I] Stock enters a web location only by consignment:
  1. The branch runs `inventory.usp_ConsignToWeb`, which lowers its store pool and writes a branch-owned `inventory.WebConsignments` row.
  2. Sync carries that row to the hub.
  3. The hub runs `inventory.usp_ApplyWebConsignments`, which credits the web location once per consignment id.
- [I] Stock returns to a store by release:
  1. The hub runs `inventory.usp_ReleaseFromWeb`, which lowers web-location available stock and writes a hub-owned `inventory.WebReleases` row.
  2. Sync carries it to the branch.
  3. The branch credits its store pool once per release id.
- [I] The web sells only consigned units, and only the hub writes web-location rows, so the web cannot oversell.
- [I] The store cannot sell consigned units either, because they already left its store pool.

### 3.4 What is missing today

- [F] `Endpoints.cs` has only two open routes: `POST /auth/login` and a 404 stub `POST /catalog/items`.
- [F] There is no public catalog, order, payment return or webhook endpoint.
- [F] The rate limiter in `Hosting.cs` has only `LoginPolicy`, and it is off by default.
- [F] There is no CORS policy and no Turnstile check.
- [F] Webstore tables are not in `sync.SyncTables`, so an offline branch never sees web orders.
- [F] `usp_CreateReservedOrder` does not set `ExpiresAt`, and no job expires reservations.
- [F] `src/integration-adapters.js` throws `real_orders_disabled` from `createRealOrder`, and its SAVIA descriptor has `realOrders:false` and `payments:false`.
- [F] `src/store-api.js` keeps cart, orders and a fake admin in localStorage key `martha-store-state-1`, and it simulates payment outcomes.
- [I] Missing schema and procedures: the web stock location, consignment and release, the web order procedure, the expiry procedure, and the late-payment path (section 4.1).

## 4. Build plan

### 4.1 Migrations

- [F] The highest migration in this checkout and on `Tony` is `V035__api_host_role.sql`; `savia/db/migrations/MANIFEST.sha256` lists the files.
- [I] I number from V047 as the packet asked; renumber to the next free number at merge if V036 to V046 are not taken.
- [I] Regenerate the manifest with the repository tool; do not hand-edit it.
- V047 web stock location:
  - adds the `WEB` branch and one web location per store;
  - adds `webstore.WebLocationSources`.
- V048 consignment and release:
  - adds `inventory.WebConsignments` (branch-owned, synced) and `inventory.WebReleases` (hub-owned, synced);
  - registers both in `sync.SyncTables`;
  - adds `usp_ConsignToWeb`, `usp_ApplyWebConsignments`, `usp_ReleaseFromWeb` and `usp_ApplyWebReleases`.
- V049 web order:
  - adds `webstore.usp_CreateWebOrder`, which reserves at a web location, sets `ExpiresAt`, and enqueues a hub-only notice instead of branch routing;
  - adds `AccessTokenHash` to `webstore.Orders`;
  - widens the status CHECK with `expired` and `payment_review`.
- V050 routing, expiry and late payment:
  - [F] `usp_RecordVerifiedPayment` routes `web.payment_captured` to the branch node of `Fulfillments.BranchId` and raises 51712 when none exists.
  - [I] Replace it with a version that routes through `WebLocationSources` to the source store, or enqueues a hub-only notice.
  - adds `webstore.usp_ExpireReservation(@OrderId)`, which is idempotent and releases Reserved;
  - changes payment recording so a verified payment on an expired order sets `payment_review` and keeps stock unchanged.
- V051 public access:
  - adds a `savia_public_api` role with EXECUTE on the public procedures and no table access;
  - adds `webstore.ShippingZones` (zone, price minor, currency) to replace the hard-coded 500/800.
- [I] Every migration is forward-only; a rollback is a new compensating migration.

### 4.2 Endpoints (hub node)

`GET /api/v1/public/catalog`
- Response 200: `{ "items": [ { "sku", "productId", "name", "size", "color", "unitPriceMinor", "currency", "available" } ], "asOf" }`.
- `available` is capped at 10 so the exact stock does not leak.
- Cache: `Cache-Control: public, max-age=30`.

`POST /api/v1/public/orders`
- Headers: `Idempotency-Key` (UUID, required) and `Content-Type: application/json`.
- Request: `{ "lines": [ { "sku", "qty" } ], "contact": { "name", "email", "phone" }, "shipping": { "zone", "address", "city", "notes" }, "provider": "manual" | "card", "locale": "es" | "en", "turnstileToken" }`.
- Response 201: `{ "orderId", "code", "accessToken", "status": "reserved", "totalMinor", "shippingMinor", "currency", "expiresAt", "payment": { "provider", "kind": "redirect" | "instructions", "url"?, "method"?, "instructions"? } }`.
- Same key and same body: 200 with the same order.
- Same key and a changed body: 409 `idempotency_conflict`.
- Errors: 400 `validation`, 403 `turnstile_failed`, 409 `out_of_stock` with the SKU, 409 `price_changed`, 429 `rate_limited`.
- The hub derives `@OrderId` from the key (a UUID v5 of the key) and looks it up before it calls siteverify.
- A known key with the same request hash returns the stored order without a new Turnstile check, because the token is single-use.
- The request hash excludes `turnstileToken`, so a retry with a fresh token is the same request.

`GET /api/v1/public/orders/{orderId}` with header `X-Order-Token`
- Response 200: `{ "code", "status", "totalMinor", "currency", "expiresAt", "lines" }`.
- A wrong or missing token returns 404, not 403.

`POST /api/v1/public/payments/{provider}/return`
- This is the browser return from the hosted page (a form POST or a GET).
- The hub confirms server-side, records the result, and answers 303 to the storefront order page.

`POST /api/v1/public/payments/{provider}/webhook`
- The hub verifies the signature before it parses the body; an invalid signature returns 401 with no state change.
- A repeat delivery returns 200 with no second write.

Staff routes (signed in, `api` group with `ActorFilter`):
- `GET /api/v1/web-orders?status=` returns at most 500 rows (D-041).
- `POST /api/v1/web-orders/{id}/manual-payment` takes the amount and reference, needs a staff role, and is audited.
- `POST /api/v1/web-orders/{id}/fulfill` and `POST /api/v1/web-orders/{id}/cancel`.
- `POST /api/v1/web-stock/release` lets staff return stock from the web to a store.

Branch route:
- `POST /api/v1/stock/web-consignments` with `{ "itemId", "qty", "fromLocationId" }`, served by a branch node.

### 4.3 Payment provider interface (.NET)

```csharp
public interface IPaymentProvider
{
    string Code { get; }          // "manual", "bac", "pagadito"
    bool IsCard { get; }          // false for "manual"
    Task<PaymentStart> StartAsync(PaymentStartRequest request, CancellationToken ct);
    Task<PaymentResult> ConfirmReturnAsync(HttpRequest request, CancellationToken ct);   // server-to-server confirm
    Task<PaymentResult?> HandleWebhookAsync(HttpRequest request, CancellationToken ct); // null if unsupported
    Task<PaymentResult> QueryAsync(Guid orderId, string? providerPaymentId, CancellationToken ct);
    Task<RefundResult> RefundAsync(Guid orderId, string providerPaymentId, long amountMinor, CancellationToken ct);
}

public sealed record PaymentResult(PaymentStatus Status, string? ProviderPaymentId,
    long? AmountMinor, string? Currency, string? FailureCode);
public enum PaymentStatus { Captured, Authorized, Declined, Pending, Unknown }
```

- [I] Only `ConfirmReturnAsync`, `QueryAsync` or a verified webhook may lead to `usp_RecordVerifiedPayment` with `@VerifiedByTrustedService=1`.
- [I] A browser parameter alone never marks an order paid.

`manual` provider:
- `IsCard=false`; the UI and API label it "Pago manual (no es tarjeta)".
- `StartAsync` returns instructions: a bank transfer, a Compra-Click link sent by staff, or payment on pickup.
- `ConfirmReturnAsync` and `HandleWebhookAsync` are not supported.
- `QueryAsync` returns `Pending` until a staff member records the payment.
- [I] It never satisfies D-008.

Card adapter for the BAC gateway, shaped on PowerTranz SPI ([S] unofficial SDKs, not official docs):
- `StartAsync` calls `POST {base}/api/spi/sale` with amount, currency, order id, `ThreeDSecure=true`, `HostedPage { PageSet, PageName }` and `MerchantResponseUrl` set to our return route.
- `ConfirmReturnAsync` reads the `SpiToken` from the gateway POST and calls `POST {base}/api/spi/payment` within the token's lifetime (about 5 minutes).
- `QueryAsync` uses the gateway's transaction-status call, whose name is unknown until the docs are released.
- [I] The adapter is written only after BAC names the gateway and gives sandbox access; until then a `FakeHostedGateway` test double fills its place.

Pagadito adapter (fallback):
- [F] Pagadito has an API, a return URL, a webhook guide and a sandbox.
- [I] Shape: connect with UID and WSK, create a transaction for a redirect URL, then check status server-side on return.
- [I] Read the dev.pagadito.com API and webhook pages before coding; I did not read their method lists.

### 4.4 Storefront changes

- `src/integration-adapters.js`:
  - add an HTTP adapter for `savia` that sets `realOrders:true` only when `apiBase` is configured;
  - its `createRealOrder` calls `POST {apiBase}/api/v1/public/orders` with the cart's idempotency key.
- `src/store-api.js`:
  - keep the local engine for demo mode;
  - in live mode, read prices and availability from the hub;
  - show the server's totals, not the local quote;
  - drop the local coupon and the simulated payment outcome.
- [F] The local engine uses USD, shipping 500 or 800 minor units, coupon `BIENVENIDA10` and a 30-minute reservation; the coupon and shipping prices must move to the server or be removed.
- Checkout page:
  - add the Turnstile widget;
  - add the provider choice with the "not card" label;
  - add an order page that polls `GET /orders/{id}` with the token.
- `site.config.json`: add `apiBase`, `turnstileSiteKey` and `siteUrl` (all empty today, [F]).
- `build-inputs/static/_headers`: the CSP changes in 2.5, then run `python3 prepare.py`.

### 4.5 Tests

T-SQL, following `savia/db/tests/webstore/`:
- 070: an order larger than the web-location stock fails with 51102.
- 080: two sessions race for the last unit and exactly one wins.
- 090: a same-key replay returns the same order; a changed body raises 51710.
- 100: expiry releases Reserved once, and a second run changes nothing.
- 110: a verified payment after expiry sets `payment_review` and leaves stock unchanged.
- 120: a branch batch that carries a web-location row fails with 51851.
- 130: the hub's normal outbound batch to a branch has no web-location rows; a rebuild batch has them and the branch does not send them back.
- 140: a consignment applies once, even when the batch is replayed.
- 150: a release credits the store pool once.

.NET:
- A contract test suite that every `IPaymentProvider` must pass, run against `manual` and `FakeHostedGateway`.
- A return without a server-side confirm never marks an order paid.
- A webhook with a bad signature returns 401 and writes nothing.
- A failed Turnstile check returns 403 and reserves nothing.
- Rate-limit, body-size and validation tests return 429, 413 and 400.
- An order lookup with a wrong token returns 404.
- A CORS preflight from an unlisted origin gets no allow headers.

Browser (the repository's browser runner, or `agent-browser` for a real browser):
- Add to cart, check out with `manual`, see the order code, and see the order on the staff screen.
- Check out with `FakeHostedGateway`, return, and see `paid`.
- Close the tab after a fake payment; the expiry job's query still marks the order paid.
- Run `python3 tests/check.py` and `python tests/static_headers.py` after every storefront change.

### 4.6 Deploy

Azure (hub):
1. Run the migrations through the existing migrator against the hub database.
2. Store the Turnstile secret and provider credentials in Key Vault `kv-savia-bukmlt` (D-040).
3. Deploy a new Container Apps revision with the new image.
4. Set CORS with `az containerapp ingress cors enable --allowed-origins <storefront origin>`, and read it back, because the CLI replaces the old settings.
5. Turn on `Savia:Proxy:TrustForwardedHeaders` only for the ingress proxy.
6. Roll back by moving traffic to the previous revision; database changes roll forward only.
- [F] The Azure trial must be upgraded before about 2026-12-12 (production README).

Cloudflare (storefront):
1. Run `python3 prepare.py` and `python3 tests/check.py` from a clean commit.
2. Deploy to the preview Worker `martha-silva-preview` (D-035 allows the preview).
3. Record the version id and the commit SHA.
4. Roll back with `wrangler rollback <version-id>`.
- [F] `wrangler.jsonc` serves `./dist` as static assets with `workers_dev:true`.

### 4.7 Acceptance criteria and checks

- W1 public catalog from the hub: `GET /public/catalog` returns hub prices; a browser test shows the hub price on the product page.
- W2 browser to API to SQL with an idempotent retry: test 090 plus a .NET replay test plus a browser double-submit test.
- W2 no oversell: tests 070, 080, 120, 130 and 140.
- W3 abuse controls: the .NET tests for 429, 413, 400, 403 and CORS; a manual check that no staff route answers without sign-in.
- W4 card payment with verified confirmation: the provider contract suite against the real sandbox; blocked until a merchant account exists.
- W5 the store sees the order: the browser test that ends on the staff screen.
- W6 Cloudflare deploy: the recorded version id, SHA and a tested rollback.
- W7 quality: Lighthouse at 90 or more in all four mobile categories, and the headers check in 5.2.

## 5. Storefront production checklist

### 5.1 Core Web Vitals

- Targets (web.dev "good" thresholds, from memory, not re-read today): LCP at most 2.5 s, INP at most 200 ms, CLS at most 0.1.
- [F] `tests/storefront_scorecard/scorecard.py` measures vitals and runs axe.
- [F] I did not run it; no vitals or Lighthouse score is measured in this spec.
- [I] The live catalog fetch must not move the layout; reserve space for the price and the stock badge.

### 5.2 Security headers and CSP (`build-inputs/static/_headers`)

- [F] Present: CSP with `default-src 'self'`, a hashed `script-src`, `frame-ancestors 'none'` and `form-action 'self'`.
- [F] Present: `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin` and `X-Robots-Tag: noindex`.
- [F] Missing: `Strict-Transport-Security`, `Permissions-Policy` and `Cross-Origin-Opener-Policy`.
- [F] `style-src` allows `'unsafe-inline'`.
- Add before launch:
  - HSTS with a max-age of one year, once the domain is final;
  - `Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()`;
  - `Cross-Origin-Opener-Policy: same-origin`;
  - the API, payment and Turnstile origins from 2.5.
- Remove `X-Robots-Tag: noindex` only at launch.
- [I] With a full redirect the script criterion does not apply; keep the checkout page free of third-party scripts other than Turnstile anyway.

### 5.3 SEO

- [F] Product pages carry JSON-LD for Organization, WebSite, BreadcrumbList and Product, with one Offer per size in USD.
- [F] Offer availability is fixed at build time, and URLs and images are relative.
- [F] No canonical tag and no hreflang tag appear on any page (0 found).
- [F] Every page has `meta robots noindex,nofollow`, and `robots.txt` has `Disallow: /`.
- [F] There is no sitemap, and `prepare.py` does not generate one.
- [F] `site.config.json` has an empty `siteUrl` and `indexable:false`.
- [F] `<html lang="es-NI">`; English is rendered in the client by `i18n.js` and `locale-en.js`, with no English URLs.
- Fix:
  - set `siteUrl`, then make Offer `url` and `image` absolute;
  - add a canonical tag to every page;
  - generate `sitemap.xml` in `prepare.py`;
  - drop build-time availability from the JSON-LD, or rebuild when stock changes;
  - flip robots and noindex at launch only.
- [I] hreflang needs separate English URLs; launch Spanish-only with no hreflang, or generate `/en/` pages first.

### 5.4 WCAG 2.2 AA

- [F] axe runs inside the scorecard; I did not run it today.
- Manual checks that axe does not cover:
  - 2.4.11 the sticky header does not hide the focused element;
  - 2.5.8 every target is at least 24 by 24 CSS pixels;
  - 3.3.7 checkout does not ask twice for the same data;
  - 3.3.8 Turnstile stays non-interactive, with no puzzle;
  - 4.1.3 the order status and errors are announced to screen readers.

### 5.5 Business blockers in the repository

- [F] Every business field in `site.config.json` is empty.
- [F] The production README marks W8 to W10 (catalog, legal details, domain) as blocked on inputs.

## 6. Unverified and open

- BAC NI fees, gateway name, NIO support, webhook support and sandbox: not published, and the comercio-afiliado page returned 403.
- PowerTranz API shape: from unofficial SDKs only; the official docs are gated.
- Whether PowerTranz serves BAC Nicaragua: not confirmed.
- PayPal Nicaragua: its pages returned 403; only a fee PDF snippet was seen.
- 2Checkout: the exclusion comes from a search snippet; its site was unreadable.
- Ficohsa: the site refused the connection.
- LAFISE: its e-commerce detail page was not read.
- Pagadito API method names, webhook signature and 3-D Secure: not read.
- PCI FAQ 1588 scope: from a search summary; the FAQ page itself was not read.
- Turnstile CSP hosts and web.dev thresholds: from known docs, not re-read today.
- Vitals, Lighthouse and axe: not run.
- Migration numbering: this checkout ends at V035, not V046.

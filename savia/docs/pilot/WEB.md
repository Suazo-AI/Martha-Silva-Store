# SAVIA Masaya staff web

Owner decisions, 2026-11-12. Local static modules served by the .NET API.
No new dependency, Playwright, external service or deployment.
See [API-PILOT](API-PILOT.md) for roles, environment variables and contracts.
Current command evidence: [OWNER-ROLES-VERIFICATION](OWNER-ROLES-VERIFICATION.md).

## Roles and navigation

Dueña sees everything, plus Precios and Aprobaciones.
Gerente also operates the till and approves discounts, credit returns and stock exceptions.
Vendedoras see only Comisiones and Ajustes. They do not see the header till link or Caja.
Bodega sees Recepción, Inventario and Ajustes, with prices redacted by the API.
Navigation redirects a newly signed-in account to a module its role can use.
API and SQL authorization remain necessary; hidden navigation is not security.

## Venta and commissions

Venta has one seller chip per active local seller. The selected chip applies to the next garment.
Each ticket line has a seller selector. The same garment can have separate lines for two sellers.
The request sends sellerId per line. SQL owns commission, discount, price, stock and cost validation.
Comisiones has day/week/month/year periods and a date. Values and CSV come from SQL.
Sellers see only their own row. Manager/owner see all. The owner may change future rates with a reason.
Return reversals retain the sale's original seller/rate and appear in the return period.

A normal sale has no customer field. Customer selection appears only when an advance payment is chosen.
Card tender is a manual POS record. Its voucher number is optional. No card data is collected.
Split payments remain. Discounts require a manager and reason. The owner can inspect self-approval.
Parked tickets remain local drafts, reserve no stock and need current SQL validation when restored.

## Prices and oversight

Owner Precios supports search, current price/cost, reason and append-only history.
The next sale must use the current SQL price. The history remains unchanged by later edits.
Manager/owner inventory shows cost. Period reports include SQL cost of goods and gross margin.
Aprobaciones lists recorded discounts, returns, stock exceptions and price changes.
Layaway, exchange and void workflows are not implemented; the available reversal is a credit return.

## Confirmation and quality

The reusable in-page dialog states the consequence and has “Si, confirmar” and “No, volver”.
It guards receipt posting, new garment acceptance, scan rejection, return submission,
ticket clearing, till closing, price changes, exception review and quality classification.
The component has a unit test. Browser tests cancel a quality write, read unchanged API state,
then confirm it and read the stored classification. No window.confirm is used.
Reception classifies expected units as Buena, Dañada, Manchada, Mal olor or Faltante.
Good units enter sellable stock. Defects enter quarantine. Missing units never enter stock.
The report endpoint aggregates quality per supplier/date range.

## Verification and limits

`e2e_pilot.py` uses agent-browser, a real browser and the real loopback API.
It signs in all five roles, checks navigation, two sellers on one ticket, commissions against the API,
owner-only price changes and the next sale, quality, confirmation cancel/accept and anonymous sales.
It inspects console/page errors and captures 1024x768 images; layout also checks 1440x900.
Credentials use the CLI encrypted vault through stdin and are removed after sign-in.
Close retries are bounded. A persistent session falls back to stopping only its verified daemon.
Cleanup cannot conceal an earlier flow failure.

Not verified: production, deployment, bank gateway, physical devices, mobile, full accessibility or performance.

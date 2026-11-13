# SAVIA Masaya staff web

Owner decisions, 2026-11-12. Local static modules served by the .NET API.
No new dependency, Playwright, external service or deployment.
See [API-PILOT](API-PILOT.md) for roles, environment variables and contracts.
Current command evidence: [OWNER-ROLES-VERIFICATION](OWNER-ROLES-VERIFICATION.md).

## Roles and navigation

Dueña sees everything, plus Precios, Aprobaciones and Importar catálogo.
Gerente also operates the till and approves discounts, credit returns and stock exceptions.
Vendedoras see only Comisiones, Reportes (Equipo tab, own row) and Ajustes. They do not see the header till link or Caja.
Bodega sees Recepción, Inventario and Ajustes, with prices redacted by the API.
Navigation redirects a newly signed-in account to a module its role can use.
API and SQL authorization remain necessary; hidden navigation is not security.

## Venta and commissions

Venta has a "Vendedor" dropdown with the active local sellers; it scrolls when the list is long.
Manager/owner can press "Venta compartida" to add a second and a third seller (maximum 3).
New garments go to the first seller. With more than one seller, each line shows a "Vendedor" selector
limited to the ticket's sellers. Removing or replacing a seller moves her lines to the remaining one.
One receipt and one payment cover the ticket. The receipt and sale detail show "Vendedor: ..." per line.
The request sends sellerId per line; SQL rejects a missing or inactive seller and more than 3 sellers. SQL owns commission, discount, price, stock and cost validation.
Comisiones has day/week/month/year periods and a date. Values and CSV come from SQL.
Sellers see only their own row. Manager/owner see all. The owner may change future rates with a reason.
Return reversals retain the sale's original seller/rate and appear in the return period.

A normal sale has no customer field. Customer selection appears only when an advance payment is chosen.
Card tender is a manual POS record. Its voucher number is optional. No card data is collected.
Split payments remain. Discounts require a manager and reason. The owner can inspect self-approval.
Parked tickets remain local drafts, reserve no stock and need current SQL validation when restored.

## Devolución: four outcomes

Devolución offers four outcomes with one confirmation step that states amounts, till effect and commission reversal.
- Cambio por otra prenda: the returned garments and the new garments are one SQL operation.
  The new sale keeps the chosen seller. A difference is charged with a tender, or paid back in cash or by transfer.
- Anticipo al cliente: the existing store-credit return.
- Efectivo de caja: cash leaves the open till; SQL refuses it when the till lacks the cash.
- Transferencia bancaria: the reference is required; the till is not touched.
The preview mirrors SQL's proportional value. SQL decides the window (owner setting, default 30 days) and the amount.
A seller still needs a manager/owner approval login.

## Reportes: Negocio and Equipo

Negocio (dueña, gerente) shows SQL KPIs for day/week/month/year.
It lists net sales, sales, average ticket, units per ticket, gross margin and %, discounts %, returns % and refunds by kind.
It also lists sell-through per product, days of inventory, stock value at cost and garments without movement for 60+ days.
Stock exceptions, quality rejects, till differences and sales by hour complete it.
The earlier summary and the day report follow; the day report and each till list refunds by kind.
Equipo shows sellers: net sales, units, tickets, average ticket, units per ticket, returns %, discounts and commission.
It shows managers (till closures and differences, approvals count and amount) and stock workers (garments received, rejects, average reception minutes).
A seller only receives her own row from SQL. "Exportar CSV" exports the active tab.

## Importar catálogo (dueña)

Upload a CSV (comma, semicolon or tab; UTF-8 or Latin-1) or an XLSX (first sheet). The API parses the file.
The screen guesses the mapping from Spanish headers and remembers it per header set in this browser.
"Revisar filas" previews in SQL without writing.
It reports bad EAN check digits, repeated or registered code/SKU, missing name or price, and invalid cost or stock.
"Importar catálogo" asks for confirmation and imports all rows in one transaction with a batch id.
Opening stock enters as adjustments tied to that batch.
Samples: `import-samples/catalogo-ejemplo.csv` and `import-samples/inventario-ejemplo.xlsx` (different column order).

## Prices and oversight

Owner Precios supports search, current price/cost, reason and append-only history.
The next sale must use the current SQL price. The history remains unchanged by later edits.
Manager/owner inventory shows cost. Period reports include SQL cost of goods and gross margin.
Aprobaciones lists recorded discounts, returns, stock exceptions and price changes.
Layaway, exchange and void workflows are not implemented; the available reversal is a credit return.

## Confirmation and quality

The reusable in-page dialog states the consequence and has “Sí, confirmar” and “No, volver”.
It guards receipt posting, new garment acceptance, scan rejection, return submission,
ticket clearing, till closing, price changes, exception review and quality classification.
The component has a unit test. Browser tests cancel a quality write, read unchanged API state,
then confirm it and read the stored classification. No window.confirm is used.
Reception classifies expected units as Buena, Dañada, Manchada, Mal olor or Faltante.
Good units enter sellable stock. Defects enter quarantine. Missing units never enter stock.
The report endpoint aggregates quality per supplier/date range.

## Verification and limits

`e2e_pilot.py` uses agent-browser, a real browser and the real loopback API.
It signs in all five roles and checks navigation and the seller's own-row Equipo view.
It checks a shared sale with two sellers, per-line sellers on the receipt and one payment.
It checks the four return outcomes and a transfer refund that leaves the till unchanged.
It compares commissions and Reportes Negocio/Equipo values with the API.
It imports the CSV sample as the owner; a repeat run must show every row as already registered.
It also checks owner-only price changes, quality, confirmation cancel/accept and anonymous sales.
It inspects console/page errors and captures 1024x768 images; layout also checks 1440x900.
Credentials use the CLI encrypted vault through stdin and are removed after sign-in.
Close retries are bounded. A persistent session falls back to stopping only its verified daemon.
Cleanup cannot conceal an earlier flow failure.

Not verified: production, deployment, bank gateway, physical devices, mobile, full accessibility or performance.

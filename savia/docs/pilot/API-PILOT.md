# SAVIA local Masaya API

Owner decisions, 2026-11-12. Local pilot only. No deployment or remote service.
The API serves `savia/web` and `/api/v1` on http://127.0.0.1:5080.
Business rules run in SQL procedures (ADR-001 D2). Money is integer NIO centavos.
Current commands and results are in [OWNER-ROLES-VERIFICATION](OWNER-ROLES-VERIFICATION.md).

## Five independent logins

| Login | Display name (invented) | Role code | Access |
| --- | --- | --- | --- |
| duena.muestra | María Elena López | OWNER | All; only role that changes item price/cost or commission rates; approvals |
| gerente.muestra | Claudia Reyes | MANAGER | Cashier and manager; till, sales, discounts, returns, stock exceptions, costs and reports |
| vendedor1.muestra | Ana Lucía Pérez | SELLER | Own commissions; no till or charging |
| vendedor2.muestra | Rosa Isabel Gutiérrez | SELLER | Own commissions; no till or charging |
| bodega.muestra | Marta Solís | INVENTORY | Reception, quality and inventory; no till, costs or prices |

Set one random password per login using `SAVIA_PILOT_PASSWORD_DUENA`, `_GERENTE`,
`_VENDEDOR1`, `_VENDEDOR2`, `_BODEGA`. The part before the dot determines the key.
Passwords never belong in files, arguments, screenshots or Git.
Shared `SAVIA_PILOT_PASSWORD` is refused unless `SAVIA_PILOT_ALLOW_SHARED=1`.
`--no-provision` verifies all five hashes without changing them or invalidating sessions.
Legacy CASHIER role codes remain for historical compatibility and test fixtures; no pilot login receives one.

```powershell
python savia/tools/pilot.py reset --demo
python savia/tools/pilot.py up
python savia/tools/pilot_smoke.py
python savia/web/tests/e2e_pilot.py
python savia/tools/pilot.py down
python savia/tools/check.py
node --test "savia/web/tests/*.test.mjs"
```

Use the existing `savia-sqlserver-dev` container. Do not create another container.
The connection string is built in memory from the existing local environment/container.
Stop the API before building or running the full check.
`down` verifies the exact pilot DLL path before stopping its PID.
`reset` replaces only `SAVIA_DEV_pilot`. `--demo` also migrates, seeds and writes history.

## Contract

JSON uses camelCase. Every write uses client-generated GUIDs for retry identity.
Authenticate using `POST /auth/login {loginName,password}` and send the returned bearer token.
Paths below have prefix `/api/v1`. `GET /me` reports roles, branch and location.
`POST /auth/logout` revokes the session. `/health` is anonymous.
Errors are `{code,message,traceId}`: 401 unauthenticated, 403 forbidden, 404 absent,
409 rule conflict, 422 invalid input, 503 busy/unavailable. OpenAPI: `/openapi/v1.json`.

## Sales and commissions

Manager/owner `POST /sales` takes `{saleId,tillId,currencyCode,lines,tenders,discountReason?,stockExceptionNote?}`.
Each line takes `{lineNumber,itemId,quantity,unitPriceMinor,discountMinor?,sellerId}`.
Every real pilot sale line requires an active local SELLER. SQL snapshots the seller rate,
commission and unit cost atomically with the sale. Retries include seller attribution in their fingerprint.
Old historical CASHIER fixtures can still replay their original contract without attribution.
A normal sale rejects `customerId`. Advance redemption may use it with a `credit` tender.
Discounts require manager/owner approval and a reason. The manager can approve her own sale;
the owner reviews these actions in Aprobaciones. A zero-price authorized ticket needs no tender.
Stock shortages require an explicit physical-stock note and create traced stock exceptions.

Tenders take `{tenderNumber,tenderKind,amountMinor,receivedMinor?,changeMinor?,reference?,creditId?}`.
Kinds: cash, card, transfer, credit, other. Card records the external terminal tender and an optional
voucher reference. There is no gateway or terminal connection. Transfers require their reference.
Cash received minus change must match the tender amount.

| Method/path | Roles | Meaning |
| --- | --- | --- |
| GET /sellers | SELLER, MANAGER, OWNER | Local active sellers and rates (basis points; 300 = 3%) |
| POST /sellers/{id}/rate | OWNER | `{changeId,rateBps,reason}`; rate history; future sales only |
| GET /reports/commissions?period=day\|week\|month\|year&date=YYYY-MM-DD | SELLER, MANAGER, OWNER | Seller sees own row; manager/owner see all |
| GET /reports/commissions.csv?... | Same | Same SQL response serialized as CSV |
| GET /sales?from=&to=&q=&page=&pageSize= | MANAGER, OWNER | History |
| GET /sales/{id} | MANAGER, OWNER | Detail, seller attribution, tenders, reversals |
| POST /sales/{id}/returns/credit | MANAGER, OWNER | `{reversalId,creditId,tillId,customerId,reason,lines[{saleLineId,quantity,restockPool}]}` |
| POST /sales/{id}/returns/outcome | MANAGER, OWNER | `{reversalId,outcome:cash\|transfer\|exchange,tillId,reason,lines,reference?,exchangeSaleId?,newLines?,newTenders?,differenceKind?,differenceReference?}` |
| GET /returns/policy | SELLER, MANAGER, OWNER | `{windowDays}` (default 30) |
| POST /returns/policy | OWNER | `{changeId,windowDays,reason}` |
| GET /reports/kpi/business(.csv)?period=&date= | MANAGER, OWNER | Negocio KPIs from `sales.usp_KpiBusiness` |
| GET /reports/kpi/team(.csv)?period=&date= | SELLER, MANAGER, OWNER | Equipo KPIs; a seller gets only her row |
| POST /catalog/import/file | OWNER | `{fileName,contentBase64}` -> `{fileName,headers,rows}`; CSV or XLSX, 5 MB, 5000 rows |
| POST /catalog/import/preview | OWNER | `{batchId,fileName,rows[{row,code,sku,name,type,size,color,cost,price,stock}]}` -> counts, errors, sample |
| POST /catalog/import | OWNER | Same body; one transaction; 409 `import.row_errors` when any row fails |

Commission rows include `sellerId,name,rateBps,salesLines,units,netSoldMinor,returnedUnits,returnsMinor,
commissionEarnedMinor,commissionReversedMinor,commissionPayableMinor`.
SQL calculates commission on line value after discounts, excluding tax, rounded down to centavos.
Partial returns allocate the original commission cumulatively so a full return reverses it exactly.
Reversal belongs to the return period. Rate changes do not rewrite sale snapshots.
Periods use Nicaragua dates and Monday weeks. Return customer identity belongs to the issued advance;
the original anonymous sale remains anonymous. Restock pool is store or quarantine.
Shared sale (V024): a ticket has up to 3 sellers. Commission goes to each line's seller.
SQL rejects a line without seller or with an inactive seller (`sale.seller_required`, 422).
SQL rejects a fourth seller (`sale.too_many_sellers`, 422).

Returns (V024): `sales.usp_PostCreditReturn` issues store credit. `sales.usp_PostReturnOutcome` handles the other three outcomes.
Cash is refused with 409 `return.till_cash_short` when the till lacks the cash.
Transfer requires a reference (422 `return.transfer_reference`) and leaves the till untouched.
Exchange posts the return and a new sale in one transaction.
The customer pays a difference with `newTenders`; `differenceKind` cash or transfer pays a difference back.
SQL refuses a sale older than the owner's window (409 `return.window_expired`). Every outcome reverses commission.
`sales.ReturnSettlements` records the money per return.
The conservation oracle checks that settlements equal the returned value and cash refunds equal till entries.
It also checks that exchange tenders pay their sale.
The day report adds `refundsByKind` (`tillId,kind,returnsCount,amountMinor,cashOutMinor`); till close lines list returns by kind.

KPIs (V024) are computed in SQL for Nicaragua day/week/month/year periods; CSV uses the same response.
Ratios are basis points (`...Bps`, 10000 = 100%) and `unitsPerTicketX100`.

Catalog import (V025, `catalog.usp_ImportCatalog`): the API only parses the file.
XLSX is read with `System.IO.Compression.ZipArchive` and `System.Xml.Linq`: shared strings, inline strings, and numbers without scientific notation.
`System.IO.Packaging` is not in the shared framework, and no package was added.
SQL validates EAN/UPC check digits, duplicates in the file and the database, name, price, cost and stock.
It then creates products, items, barcodes and opening stock adjustments tied to `catalog.ImportBatches` in one transaction.
A repeated batch id with the same content replays; different content is refused.
There is no layaway, transfer between branches or sale-void workflow in this delivery.

## Price, cost and owner oversight

`GET /catalog/values?q=` allows MANAGER/OWNER. It returns up to 100 active items with
`itemId,sku,name,priceMinor,costMinor,history[]`.
`POST /catalog/items/{id}/values {changeId,priceMinor,costMinor,reason}` allows only OWNER.
SQL appends `catalog.ItemValueHistory`; `Items` is the current-value projection that sale SQL validates.
The existing `catalog.usp_ChangePrice` independently checks OWNER and appends PriceHistory.
Registering an item with price/cost also requires OWNER at the API.
`GET /approvals` allows OWNER only and independently authorizes in SQL.
It computes discounts, credit returns/cancellations, stock exceptions and price changes with actor,
action, amount, reason and time. It cannot invent layaway/void events for workflows that do not exist.

Manager/owner reports: `GET /reports/summary?period=&date=`, `/reports/summary.csv`,
`/reports/day?date=`. Summary includes `costOfGoodsMinor` and `grossMarginMinor` from SQL snapshots.
The demo catalog has zero tax. Full accounting/tax acceptance is outside this local pilot.

## Tag photo -> suggested fields

`POST /api/v1/inventory/tag-extract` reads a garment tag photo on this PC and suggests the fields of a new product.
It writes nothing; the client still calls the catalog and reception endpoints above. Details: [ETIQUETA.md](ETIQUETA.md).

- Roles: INVENTORY, CASHIER, MANAGER, OWNER (the receiving roles); others get 403 `auth.role_required`.
- Body: `multipart/form-data` with `image` (JPEG, PNG or WebP, at most 6 MB) and optional `barcode` (the phone's reading).
- 422 `tag.image_missing`, `tag.image_too_large` or `tag.image_type`; 503 `tag.ocr_missing` when the local OCR is not installed.
- A valid `barcode` (or an OCR barcode/SKU) that matches one item returns it in `matchedItem`; with the phone barcode, OCR is skipped.
- OCR failure or timeout still returns 200 with `source: "none"`, the fields known so far and a Spanish `warning`.

```json
{
  "barcode": "7501234567893", "sku": "BL-2041-AZ", "name": "Blusa manga corta", "brand": "ALMA TEXTIL",
  "size": "M", "color": "Azul", "priceMinor": 125000, "composition": "95% Algodón 5% Elastano",
  "confidence": { "barcode": 0.99, "sku": 0.98, "name": 0.62, "brand": 0.6, "size": 0.97, "color": 0.95, "priceMinor": 0.96, "composition": 0.9 },
  "rawText": "ALMA TEXTIL\nBlusa manga corta\n...", "matchedItem": null,
  "source": "ocr", "engine": "rapidocr-onnxruntime 1.4.4 (local CPU)", "elapsedMs": 1840, "warning": null
}
```

`source` is `match`, `ocr` or `none`. `matchedItem` has `itemId`, `sku`, `productName`, `variantName`, `sizeCode`, `colorCode`, `unitPriceMinor` and `matchedBy` (`barcode` or `sku`).
Every field may be null. A confidence below 0.7 means "check this field".

## Reception and quality

Inventory/manager/owner open a session with `POST /receiving/sessions`:
`{containerId,scanSessionId,reference,supplierId,deviceCode?}`.
`GET /suppliers`, `GET /receiving/sessions?open=true`, `GET .../{id}`, `GET .../{id}/lines` read state.
`POST .../{id}/scans {scanId,rawCode,quantity?,deviceCode?}` records an idempotent scan.
Manager/owner can resolve registered codes or reject unknown/ambiguous scans with a reason.
Only OWNER can register a new priced item. Rejected scans remain auditable and never create stock.

`POST .../{id}/quality {checkId,itemId,buena,danada,manchada,malOlor,faltante,reason}`
requires INVENTORY/MANAGER/OWNER. Counts must be nonnegative and sum to matched expected units.
`GET .../{id}/quality` reads the latest append-only classification for each item.
Pilot sessions require an explicit valid classification for every matched item before approval.
Manager/owner `POST .../{id}/approve`, then `POST .../{id}/post?currency=NIO`.
Only buena enters sellable store stock (unapproved-cost/draft garments still go to quarantine).
Damaged/stained/odor units enter the existing quarantine pool. Missing units create no stock or receipt line.
`GET /reports/receiving-quality?from=&to=` aggregates posted quality per supplier.
`audit.usp_CheckConservation @Throw=1` reconciles expected units, missing units, physical receipts and movements.
The scan procedure locks the session before child scan keys to prevent the reproduced deadlock.

## Cash, inventory and local history

Manager/owner: `/cash/registers`, `/cash/denominations`, `POST /cash/tills`, `/cash/tills/current`,
`/cash/tills/{id}/summary`, `POST .../{id}/counts`, `POST .../{id}/close`.
Opening and closing counts use denomination breakdowns; SQL checks the submitted totals.
`GET /stock`, `/catalog/lookup?code=`, `/catalog/search?q=`, `/catalog/items` provide local catalog/stock.
Inventory-role catalog responses redact price to null. They never contain cost.
`GET /stock/exceptions` and `POST /stock/exceptions/{id}/review {reason}` require manager/owner.
Customer/credit search is for advances: `/customers?q=`, `/credits/search?q=`.

`pilot_demo_history.py` writes exclusively into SAVIA_DEV_pilot through real procedures.
It uses the connection-scoped `core.usp_SetDemoDate`; the setter refuses other databases.
Each demo day runs at 15:00 UTC. Before 15:00 UTC, the last day runs just before now, so `reset --demo` works at any hour.
V022 changes selected business timestamp defaults to `core.ufn_BusinessNow`. Authentication/session
timestamps stay real UTC. Without a demo context, business time is real UTC everywhere.
No HTTP caller can set this clock. No original migration was edited.

Not verified here: deployment, payments integration, physical scanner/printer, multi-node sync,
production security, mobile, accessibility or performance acceptance.

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

Commission rows include `sellerId,name,rateBps,salesLines,units,netSoldMinor,returnedUnits,returnsMinor,
commissionEarnedMinor,commissionReversedMinor,commissionPayableMinor`.
SQL calculates commission on line value after discounts, excluding tax, rounded down to centavos.
Partial returns allocate the original commission cumulatively so a full return reverses it exactly.
Reversal belongs to the return period. Rate changes do not rewrite sale snapshots.
Periods use Nicaragua dates and Monday weeks. Return customer identity belongs to the issued advance;
the original anonymous sale remains anonymous. Restock pool is store or quarantine.
The available reversal procedure is `sales.usp_PostCreditReturn`; it is a credit return, not a void or exchange.
There is no complete layaway, exchange or sale-void workflow in this delivery.

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
V022 changes selected business timestamp defaults to `core.ufn_BusinessNow`. Authentication/session
timestamps stay real UTC. Without a demo context, business time is real UTC everywhere.
No HTTP caller can set this clock. No original migration was edited.

Not verified here: deployment, payments integration, physical scanner/printer, multi-node sync,
production security, mobile, accessibility or performance acceptance.

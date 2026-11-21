# Owner decisions: local verification

Base: `b33091b`. Branch: `local/savia-owner-roles-20261112`.
Canonical checkout only. No commit, push, deployment, paid service, external API or new dependency.
The existing SQL container is reused. Passwords are random process environment values and never written here.

## Delivered behavior

Five pilot logins and role navigation; owner approvals; line sellers and commission snapshots;
commission periods/CSV and partial return reversals; anonymous normal sales and optional POS voucher;
owner price/cost history; manager cost visibility and margin; shared confirmation; reception quality;
15 invented products, 60 EAN-13 variants, two suppliers and 60 days of history through procedures.
V001 and all previously committed migrations remain unchanged. New migrations are V017–V023.
New API routes are kept in `OwnerPilotEndpoints.cs` to reduce overlap with the phone/deployment work.

## Reproduced defects

The scan stress test passed three early isolated attempts with its original 200 HTTP requests.
A focused real-SQL test then reproduced a lock inversion using two scanner connections and caller-owned
transactions. Pre-existing scan keys are essential: an empty table conceals the competing key ranges.
Before V021, SQL returned deadlock 1205. V021 locks the parent session before a scan key range.
The regression passed after that change. This does not claim the original intermittent full-run failure
was observed unchanged during those early isolated attempts.

The cleanup regression first failed because close was neither retried nor bounded.
Cleanup now makes two bounded close attempts, then identifies the exact named daemon by its live
session metadata and PID, checks its executable path and stops it. It removes only that stopped PID's
runtime transport files. The real fallback was exercised against about:blank: no named session remained.
The original flow error remains recorded if cleanup also fails. No other browser session is stopped.

An early overlapping build/stress attempt caused DLL file-lock failures. Those runs are not acceptance.
Full check runs are sequential and stop the pilot at startup. Browser acceptance restarted the pilot after the third check had completed its SQL phase; the final .NET tests use isolated databases.

## Evidence

Three consecutive full `python savia/tools/check.py` runs returned RESULT PASS, exit 0 each: 131 SQL tests and 45 .NET tests per run. Logs: `savia/.out/full-check-1.log`, `full-check-2.log`, `full-check-3.log`. The third run includes the empty-quality regression fix.
Current local logs are in `savia/.out/`; they are intentionally excluded from staging.

- Web unit tests: 44 passed, exit 0.
- Runner/cleanup Python tests: 5 + 5 + 1 passed, exit 0.
- EAN-13 audit: 60 unique valid codes, zero invalid.
- Demo reset: 60 days, 240 sales, 60 variants, conservation zero violations, exit 0.
- Initial broad run: 130/131 SQL and 43/45 .NET. The three obsolete fixture assumptions were updated:
  a valid seller before a till-mismatch assertion; optional card voucher; owner registration while
  keeping the manager as the rejection audit actor. Positive owner/card coverage remains in the new tests.

## Final browser acceptance: INCOMPLETE

Earlier smoke runs passed, but the last completed smoke attempt returned exit 1 because the failed browser run had left a synthetic till open. The pending recovery/rerun was stopped at the time limit; no fresh smoke or two consecutive browser PASS results are claimed. Browser roles (all five), quality damaged/missing classification, and both confirmation choices passed with API readback. The completed browser attempt returned exit 1 at a seller-ID comparison: SQL data confirmed correct attribution, but the assertion compared GUID letter case. The assertion now normalizes case; that correction has not completed a browser rerun. Console and page errors were both zero for the completed attempt.

Only Venta with seller chips, reception quality and confirmation have final 1024x768 screenshots. Comisiones, Precios and Aprobaciones screenshots remain missing. Obsolete screenshots were removed.

Final `python savia/tools/pilot.py down`: exit 0. Final read-only demo verification: exit 0, 60 days, 246 sales, 21 products, 66 variants, two suppliers, five staff, 13 returns, six stock exceptions, zero conservation violations. Additional products are smoke-test synthetic accessories; the reset seed itself is 15 products/60 variants.

## Limits and remaining work

No dedicated layaway, exchange or sale-void workflow is implemented. The available reversal procedure
is `sales.usp_PostCreditReturn`, which issues an advance; it is not labelled as a void.
There are consequently no layaway/void/exchange confirmation or approval events to demonstrate.
Legacy CASHIER fixtures/contracts remain for historical compatibility; no pilot login has that role.
Historical sale lines without a seller are not assigned an invented commission.
The demo catalog has zero tax. Full tax/accounting acceptance is outside this pilot.
No production, deployment, external payment terminal/gateway, physical scanner/printer, multi-node,
mobile, accessibility or performance acceptance is claimed.

Additional regressions: empty quality originally returned HTTP 500 because SQL NULL was read as text. It now returns an empty array, with .NET coverage. Closed-till fixtures now capture one timestamp for OpenedAt and ClosedAt; separate clock evaluations could invert their order.

Read-only `python savia/tools/db/saviadb.py run SAVIA_DEV_pilot savia/db/pilot/verify_demo.sql`: exit 0, 60 business days, zero conservation violations. Repeated smoke/browser verification adds synthetic rows beyond the 15-product/60-variant reset seed (20 products/65 variants when checked).

## Explicit staged paths

- `savia/db/migrations/V017__real_roles_and_approvals.sql`
- `savia/db/migrations/V018__seller_commissions.sql`
- `savia/db/migrations/V019__owner_prices_costs_margin.sql`
- `savia/db/migrations/V020__receiving_quality.sql`
- `savia/db/migrations/V021__scan_parent_lock_order.sql`
- `savia/db/migrations/V022__development_demo_clock.sql`
- `savia/db/migrations/V023__anonymous_sale_return_advance.sql`
- `savia/db/pilot/seed_masaya.sql`
- `savia/db/pilot/verify_demo.sql`
- `savia/db/tests/cash/101_record_cash_entry_validation.sql`
- `savia/db/tests/cash/111_submit_cash_count_validation.sql`
- `savia/db/tests/cash/122_close_till_validation.sql`
- `savia/db/tests/receiving/160_quality.sql`
- `savia/db/tests/sales/114_post_sale_tender_validation.sql`
- `savia/db/tests/sales/117_post_sale_till_mismatch.sql`
- `savia/db/tests/sales/160_seller_commissions.sql`
- `savia/docs/pilot/API-PILOT.md`
- `savia/docs/pilot/OPERACION.md`
- `savia/docs/pilot/OWNER-ROLES-VERIFICATION.md`
- `savia/docs/pilot/WEB.md`
- `savia/docs/pilot/screens/WEB-VERIFICATION.json`
- `savia/docs/pilot/screens/abrir-caja.png`
- `savia/docs/pilot/screens/cierre.png`
- `savia/docs/pilot/screens/confirmacion.png`
- `savia/docs/pilot/screens/excepciones.png`
- `savia/docs/pilot/screens/recepcion-calidad.png`
- `savia/docs/pilot/screens/recibo.png`
- `savia/docs/pilot/screens/reportes.png`
- `savia/docs/pilot/screens/venta-vendedoras.png`
- `savia/docs/pilot/screens/venta.png`
- `savia/src/Savia.Api/Endpoints.cs`
- `savia/src/Savia.Api/OwnerPilotEndpoints.cs`
- `savia/src/Savia.Api/Provisioning.cs`
- `savia/src/Savia.Application/Modules.cs`
- `savia/src/Savia.Application/PilotSales.cs`
- `savia/src/Savia.Contracts/Contracts.cs`
- `savia/src/Savia.Contracts/PilotSales.cs`
- `savia/src/Savia.Domain/Errors.cs`
- `savia/src/Savia.Domain/Node.cs`
- `savia/src/Savia.Infrastructure/PilotSales.cs`
- `savia/src/Savia.Infrastructure/Stores.cs`
- `savia/tests/Savia.Tests/LocalCatalogRejectTests.cs`
- `savia/tests/Savia.Tests/OwnerPilotTests.cs`
- `savia/tests/Savia.Tests/PilotProvisioningTests.cs`
- `savia/tests/Savia.Tests/PilotSalesTests.cs`
- `savia/tests/Savia.Tests/ScanLockOrderTests.cs`
- `savia/tests/test_pilot_browser_cleanup.py`
- `savia/tests/test_pilot_cleanup_retry.py`
- `savia/tests/test_pilot_runner.py`
- `savia/tools/check.py`
- `savia/tools/pilot.py`
- `savia/tools/pilot_demo_history.py`
- `savia/tools/pilot_smoke.py`
- `savia/web/api.mjs`
- `savia/web/app.css`
- `savia/web/app.mjs`
- `savia/web/confirm.mjs`
- `savia/web/index.html`
- `savia/web/roles.mjs`
- `savia/web/screens/approvals.mjs`
- `savia/web/screens/cash.mjs`
- `savia/web/screens/commissions.mjs`
- `savia/web/screens/exceptions.mjs`
- `savia/web/screens/inventory.mjs`
- `savia/web/screens/payment-logic.mjs`
- `savia/web/screens/payments.mjs`
- `savia/web/screens/prices.mjs`
- `savia/web/screens/quality-report.mjs`
- `savia/web/screens/quality.mjs`
- `savia/web/screens/reception-data.mjs`
- `savia/web/screens/reception.mjs`
- `savia/web/screens/report.mjs`
- `savia/web/screens/return.mjs`
- `savia/web/screens/review.mjs`
- `savia/web/screens/sale-logic.mjs`
- `savia/web/screens/sale.mjs`
- `savia/web/tests/catalog-ticket.test.mjs`
- `savia/web/tests/confirm.test.mjs`
- `savia/web/tests/e2e_pilot.py`
- `savia/web/tests/payments.test.mjs`
- `savia/web/tests/roles.test.mjs`

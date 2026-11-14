# USD cash: implementation evidence

Date: 2026-11-13. Host: SUAZO-PC. Model: gpt-6.1-sol, high reasoning.
Worktree: `C:/Users/Jason/.t3/worktrees/github/t3-f70675b9-3dd165f1219ea644`.
Branch: `t3/usd-cash-tenders`. Base: `f3caf5738c718f66341ae02f2742648ab6777b4d`.
Contract: [DOLARES](../../design/DOLARES.md). No sub-agents were started.

## Scope and implementation

V027 adds immutable exchange rates, saved FX tender fields, paired NIO/USD drawers,
currency denominations, physical USD receipts and NIO change, paired counts and closures,
separate currency KPIs, saved receipt/event conversion and conservation checks.
V001 through V026 remain unchanged. The migration manifest was registered through `tools/rules.py`.

API contracts and stores carry the conversion and paired counts. Rate creation requires
MANAGER or OWNER. The web keeps the existing screen-table pattern and adds USD payment,
USD totals, drawer counts, receipt conversion and a rate form in settings.

Existing accounting tests now expect the required NIO CASH_ROUNDING line. Existing counted
open/close integration tests submit the required USD closing count and count parent tills.
`tools/check.py --isolated` skips pilot shutdown; all its other checks remain enabled.
The default command's behavior remains unchanged.

## Acceptance mapping

All methods live under `tests/Savia.Tests`. A theory expands into multiple executable cases.

| Spec | Class | Test method | Result |
| --- | --- | --- | --- |
| 1 | UsdCashTests | Spec01_02_conversion_and_physical_cash (6000) | PASS |
| 2 | UsdCashTests | Spec01_02_conversion_and_physical_cash (5900) | PASS |
| 3 | UsdCashTests | Spec03_mixed_cash | PASS |
| 4 | UsdCashTests | Spec04_rejections_have_no_effect (7 cases) | PASS |
| 5 | UsdCashTests | Spec05_concurrent_change_is_serialized | PASS |
| 6 | UsdCashTests | Spec06_replay_after_rate_change_and_close_conflicts_on_changed_dollars | PASS |
| 7 | UsdCashTests | Spec07_sale_and_close_are_atomic | PASS |
| 8 | UsdCashTests | Spec08_open_rolls_back_and_close_requires_both_counts | PASS |
| 9 | UsdCashTests | Spec09_expected_cash_by_currency | PASS |
| 10 | UsdCashTests | Spec10_child_till_is_internal | PASS |
| 11 | UsdAcceptanceTests | Spec11_exchange_rejects_fx_and_cash_refund_uses_parent | PASS |
| 12 | UsdCashTests | Spec12_count_replay_conflicts_in_both_currencies | PASS |
| 13 | UsdAcceptanceTests | Spec13_kpis_keep_currencies_separate_and_count_parent_once | PASS |
| 14 | UsdAcceptanceTests | Spec14_rate_permissions_dates_and_future_rate | PASS |
| 15 | UsdAcceptanceTests | Spec15_oracle_detects_corruption (4 cases) | PASS |
| 16 | UsdAcceptanceTests | Spec16_detail_and_event_preserve_conversion | PASS |
| 17 | UsdVerifyTests | Spec17_quick_verification_preserves_pilot | PASS |

## Commands and results

The SDK executable is
`C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe`.
Commands below run from the worktree root unless stated otherwise.

- `"<SDK>" format savia/Savia.slnx --no-restore --include <changed C# paths>`: exit 0.
- `"<SDK>" test savia/tests/Savia.Tests --filter "FullyQualifiedName~Usd" --logger "console;verbosity=normal"`:
  exit 0; 26/26 cases passed. Log: `.out/usd-focused-accepted.log`.
- `python savia/tools/verify.py --quick`: exit 0; 4 stages passed, 1 formal stage skipped.
  Tool tests: 25/25. Web tests: 78/78. Biome checked 59 files.
  Final repeat: exit 0; `.out/verify/20261113T222202Z/summary.json` (same counts).
- `python -u savia/tools/check.py --isolated`: exit 0; 8 stages passed.
  SQL: 134/134. .NET integration suite: 109/109, 0 skipped. Rules: 9/9.
  Build, C# format, generated baseline and no-physical-delete checks passed.
  Log: `.out/usd-full-final-green.log`.
  The preceding run (`.out/usd-full-accepted.log`) passed 109/109 .NET tests, build,
  format and rules; SQL passed 133/134 before the final reused-opening error-code correction.
- `python -u savia/tools/db/saviadb.py test sales/101 --jobs 1`: exit 0, 1/1 SQL case.
- `python -u savia/tools/db/saviadb.py test cash/12 --jobs 4`: exit 0, 5/5 SQL cases.
- `python -u savia/tools/db/saviadb.py test sales/117 --jobs 1`: exit 0, 1/1 SQL case.
- `git diff --check`: exit 0. Changed source files passed UTF-8/LF and C# size/width checks.
Logs are local ignored evidence under `savia/.out/usd-*`.
Final V027 SHA256: `4ce4971c29a646da2788d97b3b822ca116614d3c5fce0d6b4fad72058ca6e0d2`.
Reflog records a branch rename from `t3/f70675b9` to `t3/usd-cash-tenders` during this run;
this implementation agent did not run a branch rename. HEAD stayed at the base commit.

## Boundaries and blockers

- SQL work used only `savia-sqlserver-dev` and throwaway `SAVIA_T_*` databases.
  `SAVIA_TEST_SQL_SERVER` was unset. No other SQL instance or pilot database was used.
- Red-first evidence is incomplete. The initial old-behavior run failed, including the old
  procedure rejecting the new USD parameter, but did not independently establish each
  of the 17 acceptance cases red before implementation. This process requirement is not claimed.
- Full `tools/verify.py` was deliberately not run: it resets and starts `SAVIA_DEV_pilot`
  (`tools/verify.py:42-44`). Spec 17 uses the expressly allowed quick mode; real SQL and
  application coverage run separately through `tools/check.py --isolated`.
- Formal checks were skipped because TLA+ tools are absent. Browser visual/mobile QA,
  production, deployment and cross-branch rate synchronization are not verified.
- Local commit is blocked by the shared hook contract. `tools/progress.py:85-86` requires
  branch Tony; this worktree is on `t3/usd-cash-tenders`. Its post-commit hook publishes remotely,
  while this task forbids pushing. No hooks, branches or publication rules were bypassed.
  Owner: primary/Jason. Next action: provide an approved local-only hook path or integrate
  the reviewed changes under the primary's commit authority. Completion check: local commit
  exists, hooks pass, and no remote mutation occurs. Attempt: `git commit -m "Add USD cash tenders and paired cash drawers"`, exit 1.
  Exact failure: `Progress sync BLOCKED: This hook only publishes Tony; select the approved branch. Local work is preserved.`
  HEAD remains `f3caf5738c718f66341ae02f2742648ab6777b4d`. Changes are staged; no result commit exists.
  Log: `.out/usd-commit.log`.

## Integration and acceptance by the primary

The primary applied the worker's staged diff to `Tony` and ran the full `tools/verify.py`.
The worker's green (`check.py --isolated`, `verify.py --quick`) missed three clients of the new close contract.
CI (`savia-v2.yml`) does not run the pilot, demo, smoke or e2e stages either.

| Run | Failure | Cause | Fix |
| --- | --- | --- | --- |
| 1 | `pilot-reset-demo`: 51541 | Demo history counted every denomination, now including USD | `tools/pilot_demo_history.py` counts NIO denominations only |
| 1b | `pilot-reset-demo`: 51523 "Falta el arqueo USD." | Every counted opening now creates a USD drawer; the demo closed without its count | Demo days record and pass a US$0 closing count |
| 2 | `smoke`: 409 `cash.count_missing` | Smoke closed without the USD count | `tools/pilot_smoke.py` sends `usdCashCountId` and `usdLines` |
| 3 | `e2e`: 409 `cash.count_missing` | e2e closed without the USD count | e2e counts the USD drawer from `usdExpectedMinor` |

New browser coverage in `web/tests/e2e_pilot.py`: the manager sets the day rate, a line is scanned,
"Efectivo US$" takes one dollar more than needed, and the test reads back the saved tender.
It checks the dollars received, the córdoba equivalent, whole-córdoba change, rounding,
`received - change - rounding = sale`, and the USD drawer's expected amount. It passed in e2e-1 and e2e-2.

Full `verify.py` results on the final code:

- Run 4 (`.out/verify/20261113T230707Z`): 12 of 13; `tag-live` failed.
- Run 5 (`.out/verify/20261113T232118Z`): 11 of 13; `demo-rehearsal` (Reporte, Precios) and `tag-live` timed out.
- Run 6 (`.out/verify/20261113T234831Z`): **13 of 13 PASS**; `tag-live` took 80 s against about 25 s before.

`tag-live` failed only inside the full sequence. Every photo hit the 12 s OCR limit.
Alone it passed 4 of 4 runs (11 of 11 photos each), including directly after a full e2e run.
The sidecar alone read a tag in 2-3 s. KPI procedures took 4-37 ms on 60 days of demo data.
The host had 0.7-3 GB free memory with many other sessions running. The cause is not proven; the flake stays open.

## Lesson applied

Parallel integration classes raced while creating a fresh SQL template. The correction was
to build the immutable V027 template first, then run the parallel tests. Separately, the first
full suite exposed legacy missing-till error-code regressions; V027 restores 51514, 51522 and the reused-opening 51502
while retaining the explicit child-till rejection. Targeted SQL regressions passed 7/7; `sales/101` passed after the final ordering correction (exit 0).

Cleanup: removed the three named task scratch databases `SAVIA_T_usd_red`,
`SAVIA_T_usd_migration`, and `SAVIA_T_usd_migration2` (exit 0). Test harnesses remove
finished test clones. Shared template caches remain available for later checks. Final cache: `SAVIA_T_TEMPLATE_3601aca15aa9`.
A single trailing space was removed from V027 during the final run; token comparison confirmed
identical SQL statements. SQL cases used the preceding equivalent template; .NET uses the final
prebuilt template. Both versions have the corrected opening-validation order.
No unrelated database was deleted by enumeration.

No purchase, deployment, push, merge, hook bypass or external message was performed.

## Changed files

- `docs/DATABASE.md`
- `savia/db/migrations/MANIFEST.sha256`
- `savia/db/migrations/V027__usd_cash.sql`
- `savia/db/tests/cash/121_close_till_retry_and_other_closure.sql`
- `savia/db/tests/cash/123_close_document_totals.sql`
- `savia/docs/PLAN.md`
- `savia/docs/design/DOLARES.md`
- `savia/docs/evidence/usd-cash/README.md`
- `savia/src/Savia.Api/Endpoints.cs`
- `savia/src/Savia.Api/ExchangeRateEndpoints.cs`
- `savia/src/Savia.Application/ExchangeRates.cs`
- `savia/src/Savia.Application/ForeignCash.cs`
- `savia/src/Savia.Application/Returns.cs`
- `savia/src/Savia.Application/Sales.cs`
- `savia/src/Savia.Contracts/Cash.cs`
- `savia/src/Savia.Contracts/ExchangeRates.cs`
- `savia/src/Savia.Contracts/Reports.cs`
- `savia/src/Savia.Contracts/Sales.cs`
- `savia/src/Savia.Domain/Errors.cs`
- `savia/src/Savia.Infrastructure/CashStore.cs`
- `savia/src/Savia.Infrastructure/ExchangeRateStore.cs`
- `savia/src/Savia.Infrastructure/SalesStore.cs`
- `savia/src/Savia.Infrastructure/ServiceRegistration.cs`
- `savia/tests/Savia.Tests/ConcurrencyTests.cs`
- `savia/tests/Savia.Tests/PilotEndpointsTests.cs`
- `savia/tests/Savia.Tests/PilotSalesTests.cs`
- `savia/tests/Savia.Tests/SaleAccountingTests.cs`
- `savia/tests/Savia.Tests/UsdAcceptanceTests.cs`
- `savia/tests/Savia.Tests/UsdCashTests.cs`
- `savia/tests/Savia.Tests/UsdFixture.cs`
- `savia/tests/Savia.Tests/UsdVerifyTests.cs`
- `savia/tests/Savia.Tests/VerticalSliceTests.cs`
- `savia/tools/check.py`
- `savia/web/api.mjs`
- `savia/web/screens/cash.mjs`
- `savia/web/screens/denominations.mjs`
- `savia/web/screens/payment-logic.mjs`
- `savia/web/screens/payments.mjs`
- `savia/web/screens/rates.mjs`
- `savia/web/screens/report.mjs`
- `savia/web/screens/sale-view.mjs`
- `savia/web/screens/sale.mjs`
- `savia/web/screens/settings.mjs`
- `savia/web/screens/till-open.mjs`
- `savia/web/screens/usd-logic.mjs`
- `savia/web/tests/usd.test.mjs`

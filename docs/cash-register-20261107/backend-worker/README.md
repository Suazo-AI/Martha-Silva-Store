# Cash backend worker return

Status: PARTIAL. Source candidate only; migration NOT GENERATED and integration incomplete.
Base: `030b64f7cba87c6a0d710892deb9a8493ea8bbf4`. Assigned managed worktree: `C:/Users/Jason/.t3/worktrees/github/t3-49ff92f2`.
Host SUAZO-PC; T3 Code / Codex; model `gpt-6.1-sol`; requested and runtime-exposed effort `high`.
Usage, token totals and provider cost are unreported. No delegates. No commit/staging/push.
Primary owns acceptance; this return is not production readiness.

## Candidate

Exactly three additional modeled tables: CashTills, CashEntries, CashCloses.
Entries/closes are append-only; till provenance is frozen and closure is one-way.
Explicit configuration keys: `InternalSavia:Cash:Currency`, `InternalSavia:Cash:Exponent`.
There is no currency/exponent default. Configuration absence rejects cash admission.
No configuration, account, credential or security setting was changed.

POST contracts under `/internal/api/cash`: `/tills`, `/sales`, `/sales/{saleId}/refunds`, `/tills/{tillId}/close`.
Scopes: `cash.till.open`, `cash.sale`, `cash.refund`, `cash.till.close`.
All four apply session authorization, CSRF, strict numeric JSON and unknown-field rejection.
Open/sell/close require own till. Refund requires Owner/Manager and current paying-cashier access.
Replay rechecks session, role, location and custody without requiring an open till.
Operation GET recovery also rechecks cash custody from the persisted result.

One runner transaction includes stock, sale/reversal, ledger and operation result.
The shared commerce implementation exposes transaction-local sale/reversal cores; cash does not nest runners.
Existing sale -> paying till -> stock lock order is acquired before resource shared reads.
A cashier application lock serializes openings before session shared reads; unique open-till index provides a second constraint.
Original-price quantity refunds use the currently open same-location paying till and persist custodian plus authorizer.
Expected cash sums persisted deltas once. Close retains signed count variance.
Fresh unpaid creation is rejected inside the old runner scope; old recorded-key replay remains reachable.
Paid sales cannot use legacy stock-only cancel/return.
The explicit fingerprint oracle has 23 total / 20 business tables and retains Operations and StockExceptionReviews.
The existing ADO.NET full-row hashing implementation remains intact.

## Executed evidence

SDK preflight: absolute SDK `dotnet.exe --version` returned `10.0.402`, exit 0.
Locked restore from `C:/Users/Jason/.nuget/packages` only, with `--source` and `-p:NuGetAudit=false`: exit 0.
One initial build: exit 1, CS8604 in refund Lines.Select. Corrected validated nullable reference.
First focused test run: exit 1, 157 PASS / 1 FAIL / 0 skipped.
The failure reproduced acceptance of string money `"100"` under web JSON defaults.
Applied JsonNumberHandling.Strict to cash request contracts; retained the rejecting test.
Focused rerun rebuilt successfully without warnings and returned exit 0: 158 PASS / 0 FAIL / 0 skipped.
Filter: InternalCashTests, InternalAcceptanceFingerprintTests, InternalRunnerTests, InternalSessionAntiforgeryTests, InternalCommerceTests.
This is a focused subset, not rediscovery of the full A inventory.
Final integration-gap probe: 4 PASS / 1 FAIL / 0 skipped, exit 1. The existing pending-model check correctly reports True.
Three additional cash-hash negative controls pass; scoped hosting resolves correctly.
The last compile probe builds the additional SQL fault-injection fixtures but selects only the three offline cash-hash tests; see `verification.json`.

Raw logs and TRX: ignored `private-exports/cash-register-20261107/backend-worker/`.
Public source byte bindings: `source-hashes.json`. No raw logs, credentials, TRX or huge manifests are published.
No SQL test was run, including no skipped SQL execution presented as evidence.
No website suite rerun, Docker, database, service, browser/API journey, install, download, deploy or ledger mutation.

## Frozen acceptance accounting

| Criterion | Source / prepared checks | Still unproven |
|---|---|---|
| CASH-01 | Checked money rules, strict JSON, tender boundaries; independent SQL arithmetic fixture | Real persisted arithmetic, all HTTP malformed requests and mutations |
| CASH-02 | Shared transaction-local seam; SQL underpayment and three injected-failure rollback fixtures with full ADO.NET fingerprints | Actual SQL execution and negative controls |
| CASH-03 | Runner replay and custody/recovery checks; prepared sale/refund/close replay after close/price change plus postcommit-loss interceptor | Actual postcommit-loss test execution and HTTP transport test, old unpaid-key fixture, replay security matrix |
| CASH-04 | Cashier lock, filtered unique index, till lock and custody; prepared different-key opening race | Two-cashier isolation, sale/close and refund/close races, different locations |
| CASH-05 | Sum of entries; immutable close and signed variance; prepared later-shift fixture | Real independent full reconciliation, DB mutation controls and restart |
| CASH-06 | Owner/Manager scope, original quantities/prices, paying cash, legacy guards; prepared refund race | Two-manager/two-till race, direct Cashier HTTP denial, late stock failure, exceptional-line refund runtime |
| CASH-07 | Session/role/resource checks, receipt actors/times/currency, independent 23/20 inventory | Full cash unauthorized-write HTTP fingerprint matrix and provenance SQL correlation |
| CASH-08 | Backend routes only | Entire real staff browser -> API -> SQL journey; UI is excluded |

Eight prepared SQL facts in InternalCashSqlTests explicitly call migration-backed fixtures.
They will fail at missing Cash tables until a generated migration is integrated.
Existing legacy SQL sale fixtures still create fresh unpaid sales and require adaptation to the cash rollout contract.
No claim is made that the old SQL suite passes on this candidate.
No runner tools, partition manifests, UI/client tests, global rules, PROJECT-STATUS, DECISIONS or ledger were edited.

## Blocker and resumption

Generator layer: SDK and EF Design 10.0.13 are cached, but the pinned `dotnet-ef` tool is absent.
Primary's local/global tool-list evidence is retained; targeted NuGet dotnet-ef cache lookup found no package.
The Design package contains the library, not an executable `ef.dll` CLI tool.
No generated migration or snapshot was hand-edited. No payment-history backfill.

Owner: primary. First obtain authority for installing `dotnet-ef` version `10.0.13`, or provide that existing supported generator.
With explicit install authority, from the repository root:

```powershell
$cashDotnet = 'C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe'
# This install is a prepared prerequisite, NOT EXECUTED by the worker.
& $cashDotnet tool install dotnet-ef --tool-path private-exports/cash-register-20261107/ef-tools --version 10.0.13
& private-exports/cash-register-20261107/ef-tools/dotnet-ef.exe migrations add FirstCashRegister --context InternalDbContext --project backend/src/Martha.Store.Api --startup-project backend/src/Martha.Store.Api --output-dir Internal/Migrations --no-build
```

Use a freshly built source-bound API assembly before `--no-build`.
Run the generated tool with DOTNET_ROOT pointing to the SDK 10.0.402 directory, preserving/restoring the prior process value.
Review generated Up/Down/snapshot: exactly three additive tables; no backfill or destructive historical changes.
Completion check: pending-model test green, generated migration chain matches 23 explicit tables, fresh Astra/xhigh review, then separately authorized SQL campaign.
Rollback before deployment: discard only this candidate's owned uncommitted source paths; no runtime state exists from this task.
Remaining adversarial tests above must be implemented/executed before primary acceptance, rather than inferred from prepared fixtures.

Lesson: web JSON defaults accept quoted numeric input. Strict per-contract money parsing is required; the failing test caught it and passes after correction.

# Cash fixture adaptation — implementation return

Returned for primary review, then Astra xhigh judgment. Final offline run: **624 Passed, 67 NotExecuted, 0 Failed**, exit 0. All 84 selected focused cases passed inside that final run. SQL persistence and production acceptance remain unproven.

Task: `savia-cash-fixture-adaptation-20261107`. Frozen HEAD confirmed before work: `457a1576cd782874d1b3159c08e958bac96482eb`. Worktree: `C:\Users\Jason\.t3\worktrees\github\t3-50af1896`. Host: `SUAZO-PC`. Provider/harness: Codex in T3. Model: `gpt-6.1-sol`. Requested and exposed reasoning: `high`. Cost and token usage: unknown.

## Review artifacts

- [changes.patch](changes.patch): LF-normalized patch for all eight allowed source files, including the two new helpers/tests.
- [MANIFEST.json](MANIFEST.json): base/current byte lengths and SHA-256 RAW/LF bindings, protected-file bindings, patch binding.
- [RESULT.json](RESULT.json): exact command argument arrays, exits, outcomes, and private log/TRX RAW/LF bindings.
- [run_checks.py](run_checks.py): owned child-process check wrapper. No existing runner was modified.

The patch normalizes CRLF to LF for review. The manifest binds actual on-disk RAW bytes separately. Protected files match frozen Git blobs after LF normalization; checkout CRLF conversion explains their different RAW hashes. No product, migration, generated SQL, historical baseline, ledger, status, or decision file was changed. No staging or commits occurred.

## Acceptance mapping

1. `InternalCashSchemaOracle` composes the immutable historical baseline and existing stock-exception expectations with explicit cash literals. Coverage is exactly 23 application tables, 20 business tables, and 24 tables including EF history. Cash columns, PKs, alternate key, indexes, FKs, checks and collations have independent expected values. Expected values are not derived from EF or migration source. Offline counterexamples cover missing/unexpected schema and wrong cash shape. A design-model test uses EF only as the actual side of the comparison. Catalog SQL is prepared but **NOT RUN**.
2. Private-pilot and release fixtures require four explicit migration IDs, including `20261107221938_FirstCashRegister`. Release coverage now expects 24 total tables. Upgrade assertions retain historical rows and require no cash backfill. The old model-derived baseline remains immutable and separately composed.
3. New successful sales open a till and submit explicit synthetic `USD`, exponent `2`, with exact minor-unit payment assertions. A fresh unpaid sale must reject `cash_payment_required`. Only genuine historical replay/recovery/reversal cases seed pre-cash unpaid records. Branch, role, idempotency, rollback and replay assertions remain present. Paid reversals use cash refunds.
4. N8 retains the earlier unauthorized-write checks. Same-account renewal rejects the old CSRF token while retaining the recoverable key. The refreshed session succeeds and replays that key. Successful-write projections identify the exact independently asserted payment row. All other cash rows and tables stay inside the no-unrelated-write fingerprint. Scope-change success uses the same narrow projection approach.
5. The final Release test invocation rebuilt the affected SQL test sources without executing SQL. Fingerprint, schema, migration, cash and write-projection unit coverage passed. Skipped SQL fixtures are not persistence proof.

## Commands and corrections

Commands were invoked as `python docs/cash-register-20261107/fixture-adaptation/run_checks.py <mode>`. Exact expanded SDK argv and evidence bindings are in RESULT.json. SDK was the existing `10.0.402`; nothing was installed.

| Mode | Exit | Evidence / diagnosis / correction |
|---|---:|---|
| `restore` | 0 | One `dotnet restore ... --locked-mode`. |
| `focused1` | 0 | 82 passed on the intermediate artifact. |
| `focused2` | 1 | Compile error CS0117: stock movement has no `SaleId`. Direct source uses `OperationId = sale.Id`; corrected projection. |
| `focused3` | 0 | 83 passed after correction. |
| `focused4` | 0 | 83 passed after further assertions. |
| `focused5` | 1 | Compile error CS1739: named argument `key` does not exist. Corrected to `idempotencyKey`. |
| `focused6` | 1 | 83 passed, 1 failed. Independent column comparison exposed CR characters in multiline literals. Applied `TrimEntries` to literal splitting. |
| `broad` | 0 | `dotnet test ... -c Release --no-restore --filter Category!=SqlServer`; 624 Passed, 67 NotExecuted. Final correction and all 84 selected cases rechecked here. |

Six focused invocations, one broad invocation, and one locked restore were used. No further test invocation was made. `git diff --check` returned exit 0. TRX aggregate `notExecuted` is zero despite skipped result elements; the reported 67 comes from counting `UnitTestResult outcome="NotExecuted"`.

Before each test child process, the wrapper removed only these six SQL variables from the child environment: `MARTHA_TEST_SQL_CONNECTION`, `MARTHA_INTERNAL_TEST_SQL_CONNECTION`, `SAVIA_INTERNAL_TEST_SQL_CONNECTION`, `SAVIA_INTERNAL_SQL_TESTS_AUTHORIZED`, `SAVIA_INTERNAL_HTTP_SQL_TESTS_AUTHORIZED`, `SAVIA_SQL_TESTS_AUTHORIZED`. It precreated `SAVIA_PILOT_EVIDENCE`. Parent environment was preserved. Raw logs/TRX stay in ignored `private-exports/cash-register-20261107/fixture-adaptation/`; none are included here.

## Remaining checks and ownership

| Pending artifact | Why no correction/runtime attempt | Owner and completion check |
|---|---|---|
| Independent acceptance | Worker return cannot accept itself. | Primary reviews exact source hashes/diff; Astra xhigh judges the reviewed artifact. |
| Schema/catalog SQL and four-migration upgrade | This packet explicitly denies SQL/Docker/runtime execution. No runtime defect is established by offline evidence. | Primary obtains separate runtime authorization, then runs `PrivatePilotReleaseTests` and `InternalReleaseScriptTests` against an isolated authorized SQL database; verify exact schema, history, old-row retention, and empty cash backfill. |
| Cash/security persistence | Same explicit runtime boundary. Prepared SQL is NOT RUN. | Authorized campaign runs `InternalAcceptanceHttpSqlTests`, `InternalCommerceCommandSqlTests`, `InternalBranchScopeSqlTests`, and `InternalStockExceptionSqlTests`. Require real execution of cash payments/refunds, rollback/replay, stale-CSRF rejection, refreshed-session recovery and full cash-inclusive fingerprints. Record source SHA/RAW/LF, authorization, real case counts and cleanup. |
| Staff/golden journey | Old unpaid-create caller is separate scope; UI/product edits are excluded. | Primary routes a separate fixture/journey task, then validates its authorized critical path. |

All compile/unit failures above have fresh successful rechecks in the final broad run. No unresolved offline blocker remains. Historical A552/C77/E2, parent integration's 65 focused passes, and its 607/66 broad result are preserved historical evidence; this return does not relabel them as current SQL acceptance.

Lesson applied: SQL ledger projections must follow actual persisted key semantics, and independent literal oracles must trim transport line endings. The final offline recheck passed both corrections. Check-constraint comparison canonicalizes SQL Server formatting; catalog execution remains necessary to verify actual deployed definitions.

No SQL, Docker, real browser, workflow dispatch, security/account/certificate change, install, staging, commit, push, publication, merge or deployment was performed. Returned is not primary acceptance, SQL proof, cash acceptance or production READY.

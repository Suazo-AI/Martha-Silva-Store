# FirstCashRegister migration worker receipt

Generated `20261107221938_FirstCashRegister` with EF CLI 10.0.13 and SDK 10.0.402 on SUAZO-PC.
The migration was not applied. Primary integration and independent Astra/xhigh review remain pending.

Base HEAD: `030b64f7cba87c6a0d710892deb9a8493ea8bbf4`.
Execution: T3 Code / Codex / `gpt-6.1-sol`; requested and exposed reasoning effort `high`.
Isolation: existing T3-managed `t3-49ff92f2`; no checkout switch or delegates.
Cost and token telemetry are unknown. The single authorized official-NuGet tool install succeeded without a paid service call.

## Verified

- All 15 original RAW/LF bindings remain unchanged, including the original partial receipt. That receipt describes the earlier worker return; this subdirectory records the continuation.
- Generated Up adds exactly `CashTills`, `CashCloses`, `CashEntries`: three primary keys, one custody alternate key, eight restrictive foreign keys, five check constraints, nine indexes (five unique).
- One-open-till, opening-entry, sale-reference and reversal-reference filters are present. Currency/exponent, bigint bounds, entry signs and counted variance checks are present.
- Up contains only CreateTable/CreateIndex operations. Down drops only those three new tables. No historical sale backfill or unrelated schema change appears.
- Snapshot adds only the three cash entities and their relationships. Its inventory matches the independent explicit 23-total / 20-business table oracle.
- Fresh cached `--no-restore` Debug build before generation: exit 0, zero warnings/errors.
- Focused offline tests: **41 passed / 0 failed / 0 skipped**, exit 0. This includes all seven migration cases, 12 fingerprint cases and 22 cash cases.
- Previously failing `Internal_snapshot_matches_the_current_design_time_model_without_a_server`: **Passed** in the fresh TRX.
- Source guards: **30 passed**, exit 0. `git diff --check`: exit 0. Index remains empty.

Commands, counters and log bindings: [verification.json](verification.json).
Final 13 cash source bindings plus three generated files: [source-hashes.json](source-hashes.json).
Reproducible source guards: `python docs/cash-register-20261107/backend-worker/migration/verify_generated.py`.
Raw logs and TRX remain ignored under `private-exports/cash-register-20261107/backend-worker/migration/`.

## Resolved failure and correction

The first apphost generation attempt exited 1: `A compatible .NET SDK was not found`, requesting 10.0.402.
The launcher resolved a different host for metadata collection; the exact SDK build and tool version already worked.
Correction: execute the installed tool DLL through the exact SDK `dotnet.exe`; set `DOTNET_ROOT` and `DOTNET_HOST_PATH` only in that child process.
PATH and the parent environment were unchanged. Corrected generation exited 0. There was one tool install attempt.
Generated migration, designer and snapshot were never hand-edited. No frozen model/product source changed.

## Remaining boundaries and next action

No SQL connection, SQL execution, database update, Docker, service, browser, full website suite, full offline inventory, staging, commit or remote action ran.
The tests generated SQL strings offline with the connection remaining closed; this is not persistence or concurrency proof.
The eight existing cash SQL fixtures remain prepared/compiled and **NOT RUN**, with no skipped SQL test counted as a pass.

Primary owns serial integration of these three generated files with the frozen cash overlay, then the fresh Astra/xhigh review.
Primary also owns the explicitly excluded N8 correction in `InternalAcceptanceHttpSqlTests.cs`; no legacy unpaid fixtures were adapted here.
Completion checks: primary rechecks hashes and focused integration after import; Astra reviews the integrated artifact. Future separately authorized isolated SQL and staff browser/API journeys must prove runtime, atomicity and concurrency criteria.
No source-generation blocker remains in this worker scope. Product integration and production readiness are not accepted by this return.

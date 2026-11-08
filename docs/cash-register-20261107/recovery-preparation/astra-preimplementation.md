# Advisory: extend PrivatePilotReleaseTests

VERIFIED source-only review; implementation remains pending. Extend the existing two recovery methods, not golden-path. Primary retains acceptance. CASH-01?08 remain unchanged.

Task: `savia-populated-cash-recovery-precheck-43ce576-20261108-01`.
Host: `SUAZO-PC`; T3 Code/Codex. Requested and exposed: `codex / gpt-6-astra / xhigh`. Independent provider execution telemetry: unknown. No provider substitution or paid API call.
Worktree: `C:/Users/Jason/.t3/worktrees/github/t3-6db441a6`.
HEAD: `43ce576020100b7d2f9262bfa359f824b86f3b0a`; initially clean; awareness identifies this assigned task. Only this report changed.

## Direct findings and discriminating checks

1. `PrivatePilotReleaseTests.cs:80?90,139?149` compares four legacy projections. Cash schema checks cannot detect lost money rows. Require nonempty, exact cash and linked-commerce rows before backup and after restoration; removing one entry must fail.
2. `PrivatePilotReleaseTests.cs:160?169` reads a supplied database but performs no restart or baseline comparison. A no-op restart or another matching fixture could pass. Require the same-run baseline, resource receipt and observed SQL process transition before admitting restart PASS.
3. `InternalCashModel.cs:31?40` enforces entry custody and references, but a close's FK/amount check does not establish its expected balance from entries. Equality alone can preserve incorrect money. Require independent literal arithmetic and identity joins before freezing the baseline.

These are recovery-proof gaps, not reproduced product failures.

Direct reuse is incompatible: `GoldenPath.Sql/Program.cs:51?67,299?324` accepts only `SaviaInternalTest_Golden_<32 hex>` and uses `MARTHA_TEST_SQL_CONNECTION`. Recovery accepts Pilot/Release names and `MARTHA_INTERNAL_TEST_SQL_CONNECTION` (`PrivatePilotReleaseTests.cs:18?23`). `golden_path.py:970?984,1604?1615` acknowledges creation ownership and drops its database. Do not broaden guards or disable cleanup. Reuse the ADO.NET comparison technique inside the existing recovery fixture; no new runner/framework.

## Frozen implementation acceptance

**A1 ? Populate the migrated source, once.** Retain legacy migration/reapply/down/up/schema/rejection checks. Preserve the four legacy seed records by selecting their explicit identities in `Business`, not arbitrary first rows. Use a separate USD/2 item priced 1250, stock 3/reserved 0, the existing active location, one enabled Cashier and one Manager with valid same-branch synthetic sessions. Use real `InternalCommandRunner` and `InternalCashService.Open/Sell/Refund/Close`, following `InternalCashSqlTests.cs:242?251`; do not call its separate-database factory. Supply consistent fixture time to security/runner/cash. Freeze generated IDs and actual persisted timestamps; derive keys from the run nonce.

- Cashier shift A: open 10000; sell quantity 2, receive 3000, change 500; close counted 12400. Expected 12500, difference -100.
- Cashier shift B: open 2000; Manager refunds quantity 1 of A's original sale, reason recorded; close counted 750. Expected 750, difference 0. Original close remains byte-identical across refund.

Minimum cash footprint: 2 tills, 4 entries, 2 closes, 1 sale/line, 1 reversal/line, 6 successful cash operations. Seed stock through the existing adjustment service; final fixture stock is 2/reserved 0. Two shifts distinguish historical close from refund-paying custody. The shortage detects zeroed/recomputed counts. No extra cashier sentinel: whole-table preservation covers this recovery scope; CASH-08's separate cashier-isolation journey remains required elsewhere.

**A2 ? Independent oracle.** ADO.NET reads must verify quantities/prices, payment 2500, refund -1250, received-minus-change 2500, balances 12500/750 and differences -100/0 without product calculators. Join sale/payment/reversal/lines, till/location/currency/exponent, Cashier custody versus Manager refund actor, close actor/time and six operation result/effect identities. Assert unique references and exact cardinalities, not sums alone.

**A3 ? Exact persistence.** Quiesce writers after successful setup. Freeze all 23 internal tables' per-row hashes and counts, including Operations and Sessions, plus migration/schema facts. Use lossless typed canonical values, explicit nulls, round-trip timestamps, sorted hashes retaining duplicates; avoid delimiter ambiguity. Keep sensitive rows private; publish only safe projections/hashes. Compare every row against the immutable pre-backup baseline after RESTORE and after restart, never regenerate expected data. Bind its hash to nonce, candidate source, source/restored names and fixture identities. Reject missing/extra tables or rows and any changed column.

**A4 ? Real resource chain.** Existing BACKUP/CHECKSUM, VERIFYONLY and actual RESTORE (`PrivatePilotReleaseTests.cs:142?147`) must complete against the approved disposable container. Record creation acknowledgements and exact container/network/volume IDs; names alone are insufficient. Bind backup metadata/backup-set identity, source catalog, unique backup path, new restored catalog and separate data files to that receipt. Set `SAVIA_PILOT_PERSIST_DATABASE` to the receipt's restored database. Capture running?stopped?running for the same container ID, changed SQL start time and successful fresh SQL reads. No reseeding, migrations or replacement container between snapshots. Cleanup only acknowledged owned resources on success/failure; verify absence, including backup storage. Stop dependent stages on failure; no automatic retry.

**A5 ? Offline negative controls, separately labelled.** The comparator must accept an unchanged snapshot and reject a removed refund, duplicate entry, balanced total with altered row identity, lost shortage, changed original close, swapped actor/till, changed operation result, omitted table and extra row. Admission checks must reject stale/wrong-nonce baselines, wrong restored database, missing backup/restore receipts, no-op restart and skipped/absent named SQL results. These are checker tests, never SQL recovery evidence.

**A6 ? Runtime selection.** Keep the plan's six named methods, then its deferred restart method: seven total, zero skips, exact names and source-bound results. Change the two PrivatePilot methods as above and freeze their new bindings. Current changes since `9d01fb6` are documentation only. Since historical `f9ffa45`, CashSql adds the selected cash-read method/helper; existing cash write tests, model and service are unchanged. No concrete reason for a broad historical rerun. ReadTests' offline authorization/query checks cannot replace SQL. Reuse historical passes only after primary equivalence checks.

## Limits and handoff

NOT RUN: tests, builds, SQL connections, BACKUP/RESTORE, containers/restart, browser/API, Windows/security changes, publication or deployment. SQL5 remains D: REVIEW FIRST, DO NOT EXECUTE.

Preparation blocker: money oracle absent; inspected source, no implementation attempted under read-only authority. Primary owns bounded implementation and review of A1?A6. Runtime blocker: qualification/authorization absent; no runtime attempted. Primary/Jason must approve exact resources, deadlines and cleanup before execution. Completion requires real row equality, independent arithmetic, restart evidence, cleanup and primary acceptance.

## Decisive source bindings

Git blob IDs at the HEAD above; aliases in findings refer to these paths.

| Path | Git blob |
| --- | --- |
| backend/tests/Martha.Store.Api.Tests/PrivatePilotReleaseTests.cs | 905d1b3c5b6e2d46a7ab9ebdcfc48a06b83743e6 |
| backend/tests/Martha.Store.Api.Tests/InternalCashSqlTests.cs | 1c3413d4960e5659f3981676330975756853f5e8 |
| backend/src/Martha.Store.Api/Internal/Cash/InternalCashModel.cs | f9214af9fb08901f4b8bd3bb37f2ac4be6d88f5f |
| backend/src/Martha.Store.Api/Internal/Cash/InternalCashService.cs | addf3a2cd69945dd2d5f76febf31cdaed19217da |
| tests/golden-path/GoldenPath.Sql/Program.cs | ac937d7e9fce68d81d0146f18507f3fc4922be16 |
| tests/golden-path/golden_path.py | d982d517e46a66ce87606ad0465d576e9429f02d |
| docs/cash-register-20261107/real-journey/LOCAL-RUNTIME-PLAN.md | bb75bb77c366f169b873d995456eebc71284e1c8 |

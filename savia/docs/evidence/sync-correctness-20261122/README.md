# Sync correctness, 2026-11-22 (S1, S2, S3, S8)

Result: a restored store refuses sale, till opening and receiving until its rebuild lands; outbox ids are stable; a credit's status has one writer; cash counts and closures sync.
Migrations: V036 (recovery lock, stable event ids), V037 (credit status single writer), V038 (cash closures sync).
Decisions: D-036, D-037, D-038 in `docs/DECISIONS.md` at the repository root.
Source: branch `t3/savia-sync-correctness` on `ac80af38`, uncommitted edits.

## Red first, on V035

Every red ran against a clean `git archive ac80af38` export (V035).
S1 and S2 ran before the fix, with the V035 rehearsal and simulator.
S3 and S8 ran after the fix was written, with the new simulator copied into the V035 export.

| Item | Command | Red result | File |
| --- | --- | --- | --- |
| S1 recovery lock | `python savia/tools/rehearsal.py run restore_sale_before_rebuild --identity restricted` | XFAIL: the rebuild of restored A failed every round on Msg 2601 `UX_OpenTill_Register` (a sale before the rebuild opened a second till) | [txt](red-s1-rehearsal-restore-sale-before-rebuild.txt), [json](red-s1-rehearsal-restore-sale-before-rebuild.json) |
| S2 stable outbox ids | `python savia/tools/db/simulator.py scenario restore --seed 1` | RESULT FAIL (1): `CONS conservation on a`, `sale.outbox_event ... expected=1 actual=0` | [txt](red-sim-restore-seed1.txt) |
| S3 one status writer | `python savia/tools/db/simulator.py scenario credit_status` | RESULT FAIL (4): after B spends the whole credit, cloud, A and C still show `active`; R1 diff `credits.Credits Status: cloud=active b=exhausted` (B wrote the issuer's row) | [txt](red-s3-sim-credit_status.txt) |
| S8 cash closures | `python savia/tools/db/simulator.py scenario basic` (C closes its till) | RESULT FAIL (4): R1 diff, `sales.CashCounts`, `CashCountLines`, `CashClosures` missing outside C; CONS `cash.till_status_vs_closure expected=1 actual=0` on cloud, A and B | [txt](red-s8-sim-basic.txt) |

For S3 and S8 the copied simulator reads `credits.Credits` instead of `credits.vw_CreditStatus` (the view is new in V037); that is its only difference from the green simulator.
The 2601 and 51864 mappings in `DbErrors.FromSql` do not exist on V035 (`git show ac80af38:savia/src/Savia.Domain/Errors.cs`), so `DbErrorsTests` is red there by construction; it was not run on V035.

## Green, on V038

| Check | Command | Result | File |
| --- | --- | --- | --- |
| Rehearsal over HTTP, restricted login | `python savia/tools/rehearsal.py run all --identity restricted` | exit 0; `SUMMARY offline_sales=PASS replay=PASS credit_transfer=PASS restore_sale_before_rebuild=PASS hub_restart=PASS controls=PASS`; 349 checks passed, 0 failed; 0 `cash.till_status_vs_closure` | [rehearsal/](rehearsal/) |
| Simulator S1+S2 | `simulator.py scenario restore --seed 1`, `--seed 2`, `--seed 3` | RESULT PASS on each | [1](sim-scenario_restore_seed_1.txt), [2](sim-scenario_restore_seed_2.txt), [3](sim-scenario_restore_seed_3.txt) |
| Simulator S3 | `simulator.py scenario credit_status` | RESULT PASS; every node derives `exhausted`, then `blocked` | [txt](sim-scenario_credit_status.txt) |
| Simulator S8 | `simulator.py scenario basic` | RESULT PASS; 0 `cash.till_status_vs_closure` | [txt](sim-scenario_basic.txt) |
| Simulator regressions | `scenario replay`, `scenario cancel_vs_dispatch`, `random --seed 7 --steps 120` | RESULT PASS | [replay](sim-scenario_replay.txt), [cancel](sim-scenario_cancel_vs_dispatch.txt), [random](sim-random_seed_7_steps_120.txt) |
| Red control | `simulator.py scenario restore_naive` | exit 1 as designed: the hub refuses the push from the restored fork (Msg 51854); CONS 0 on every node | [txt](sim-scenario_restore_naive.txt) |
| T-SQL | `sync/250`, `outbox/080`, `credits/180` (new); `sync/110`, `140`, `200`, `210`, `230`, `credits/030`, `120`, `security/110` (updated) | see `check.py` below | |
| .NET sync | `dotnet test tests/Savia.Tests --filter FullyQualifiedName~SyncWorkerTests` | 8 passed, 0 failed | |
| .NET error codes | `dotnet test tests/Savia.Tests --filter "FullyQualifiedName~DbErrorsTests|FullyQualifiedName~ArchitectureTests"` (added after the full suite run); build and `dotnet format --verify-no-changes` rerun | 6 passed, 0 failed | |
| Web | `node --test savia/web/tests/*.test.mjs savia/web/scanner/*.test.mjs` (repo root); Biome `check web` | 156 pass, 0 fail; Biome 72 files, no fixes | |
| Full suite | `python savia/tools/check.py --isolated` | exit 0, RESULT PASS: rules, T-SQL SUMMARY PASS=154, .NET build, C# format, .NET 201 passed 0 failed, API host login 19 passed 0 failed; container proof SKIP (`--isolated`) | [txt](check-isolated.txt) |

## Limits

- A backup taken before V036 and then migrated is bound on its current fork by the backfill, so it is not locked.
- Returns, credit transfer dispatch and transfer receipt are not locked while recovering.
- The rebuild progress display that D-036 describes is not built; the till shows a wait message only.
- Only the sale, till-opened and receipt events have stable ids; other event types still use NEWID.
- No procedure sets `blocked` or `expired`; tests stand for the issuer's write with a direct UPDATE.
- T-SQL tests cannot restore a database, so `sync.RecoveredSales` is exercised only by .NET and the simulator.
- The rehearsal red for S8 was not run on V035; the S8 red is the simulator's.
- The web test uses a fake DOM: no browser, mobile or accessibility check of the lock message.
- The first `check.py --isolated` run failed 2 tests ([run 1](check-isolated-run1.txt)): `ApiHostLoginTests` still expected 18 synced tables (fixed to 21); `ConcurrencyTests.Parallel_scans_count_each_scan_id_once` failed once while the rehearsal loaded the machine, then passed alone and in run 2. That flake is outside this change and not diagnosed.

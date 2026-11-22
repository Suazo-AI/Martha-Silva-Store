# Hardening 2026-11-21: P2, P5, P6, P7

Source: `155ca23b` plus the uncommitted patch on branch `t3/savia-hardening`.
Local dev SQL container `savia-sqlserver-dev` and SDK 10.0.402 only. Nothing ran on Azure.
No password, connection string or key is recorded here.

## P5: role savia_api_host (V035)

Restricted login: `SAVIA_TEST_SQL_LOGIN=api_host` makes the tests connect as a temporary login that is only in role `savia_api_host`.
Filter: `FullyQualifiedName~Savia.Tests.Sync|FullyQualifiedName~Savia.Tests.VerticalSlice|FullyQualifiedName~Savia.Tests.ApiHostLogin`.

| Run | Result |
| --- | --- |
| sa (baseline) | 18 of 18 pass |
| role login, old grants (V035 with the four migrator grants only) | 9 of 18 fail: `SqlException 229: The INSERT permission was denied on the object 'CashTills'` from `sync.usp_ApplyBatch` |
| role login, V035 | 18 of 18 pass |
| role login, V035 without VIEW CHANGE TRACKING | `Initial_then_incremental_rounds_move_only_new_rows` fails: `The VIEW CHANGE TRACKING permission was denied on the object 'CashTills'` |
| T-SQL `security/100` and `security/110`, old grants | FAIL=2: `synced tables missing a sync grant expected=0 actual=18`; `Msg 229` |
| T-SQL `security/100` and `security/110`, V035 | PASS=2 |

| T-SQL `security/100` and `security/110`, V034 (no V035) | FAIL=2: `role savia_api_host is missing`; `Msg 15151` |

Gap G2 probe (`git show 620cbd00:savia/docs/evidence/gap-register-20261121/probe-hub-api-role.sql`), each on a fresh clone:

| Probe line | V034 | V035 |
| --- | --- | --- |
| HUB-ROLE usp_PlanJson | OK | OK |
| HUB-ROLE usp_ApplyBatch | Msg 229 INSERT denied on `sales.CashTills` | OK, applied 18 |
| HUB-ROLE cursors after role apply | 0 | 18 |
| HUB-ROLE usp_SourceStateJson | OK | OK |
| HUB-ROLE usp_ReadBatch (initial plan) | OK | OK |
| HUB-ROLE usp_ReadBatch (incremental plan) | Msg 229 VIEW CHANGE TRACKING denied on `sales.CashTills` | OK |
| incremental pull rows, role vs dbo | none vs 9 | 9 vs 9, identical batch |

`security/110` runs the same steps as assertions, including "the role reads the same batch as dbo".

Cause: `sync.usp_ReadBatch` and `sync.usp_ApplyBatch` (V032-V034) run `CHANGETABLE` and `MERGE` as dynamic SQL.
Dynamic SQL breaks ownership chaining, so it runs with the caller's own table permissions.

## P2: Application Insights

`TelemetryTests`: red 1 of 2 failed (no `TracerProvider` with a connection string set); green 2 of 2 pass.
The fake connection string points at `127.0.0.1:9`; no data leaves the machine.
The managed-identity branch (`AZURE_CLIENT_ID` set) has no automated test.

## P6 and P7

`dotnet sln Savia.slnx list`: 6 projects before, 7 after (migrator added). `dotnet restore Savia.slnx --locked-mode` passes.
`python savia/deploy/local_proof.py --build`: RESULT PASS, see [local_proof.json](local_proof.json).
It now also checks that the API user is only in `savia_api_host` (`savia_api_host|0`) and that the role covers 18 of 18 synced tables on a migrator-built database.

## Full check

`SAVIA_DOTNET=<SDK 10.0.402> python savia/tools/check.py --isolated` on the final tree: `RESULT PASS`, exit 0.
T-SQL `SUMMARY PASS=151` (baseline 149); `.NET tests on real SQL` 200 of 200 (baseline 195); `.NET sync tests as the API host login` 18 of 18.
An earlier run failed only `C# format` (CRLF in `Hosting.cs` and `Program.cs`); both files are LF now.
The container proof step is skipped under `--isolated`; it ran directly (see P6 and P7).

Integration run 2026-11-21 on a clean worktree at `620cbd00` with this patch only, after `dotnet restore Savia.slnx --locked-mode`:
`python savia/tools/check.py` (full, container proof included): `RESULT PASS`, exit 0; T-SQL 151, .NET 200 of 200, API host login 18 of 18, container proof 75 s.

CI on `ba1a918c` and `1d51d394` (run 44990007781): every step passed except `container proof`, whose failing line was cut from the 12-line tail.
The same proof passes locally on `1d51d394` (`python savia/deploy/local_proof.py --build`: RESULT PASS, roles `savia_api_host|0`, grants 18/18).
`check.py` now prints every FAIL line of a failed step before the tail, so the next CI run names the failing step.

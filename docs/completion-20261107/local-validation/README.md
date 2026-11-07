# Local A evidence and prepared SQL/browser/recovery runtime

Task: `savia-local-A-and-runtime-prep-69d3268-20261107`.
Mode: VALIDATE / PREPARE. Production readiness is not claimed.
Frozen source: `69d3268c63019d8b8299027789962a1089f91a58` (Tony == origin/Tony).
Host: SUAZO-PC. Worktree: `C:\Users\Jason\.t3\worktrees\github\t3-e850e03a`.

## 1. Fresh offline partition A: PASS

SDK: `C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe`,
`--version` = `10.0.402` (host `dotnet` 8.0.422 is not used).

| Stage | Command | Exit | Seconds |
| --- | --- | --- | --- |
| Locked restore | `dotnet restore backend/tests/Martha.Store.Api.Tests --locked-mode` | 0 | 5.278 |
| One Release build | `dotnet build backend/tests/Martha.Store.Api.Tests --no-restore --configuration Release` | 0 | 60.456 (0 warnings) |
| One fresh full A | `dotnet test ... --no-build --no-restore --configuration Release --filter <PARTITIONS.json A, 11424 chars> --logger trx;LogFileName=A.trx` | 0 | 81.141 |
| Exact verifier | `python backend/tests/verify_full_suite.py --manifest docs/local-validation-20261106/PARTITIONS.json --partition A private-exports/completion-A-20261107/results` | 0 | - |

Result: 552/552 Passed, 0 failed, 0 skipped, 195/195 methods, exact multiplicities.
Verifier report: `status=passed`, `missingMethods=[]`, `unexpectedMethods=[]`,
`multiplicityMismatch=[]`, `cases=552`. Unique testId/executionId enforced by the verifier.
This is a fresh single 552 execution, not the historical 551 + focused replacement.

Preparation applied before the run:
`SAVIA_PILOT_EVIDENCE` precreated at `private-exports/completion-A-20261107/pilot-evidence`
(the earlier failure was a missing directory, not a product defect).
Six SQL/persistence variables were removed in the child shell only:
`MARTHA_TEST_SQL_CONNECTION`, `MARTHA_INTERNAL_TEST_SQL_CONNECTION`,
`SAVIA_INTERNAL_TEST_SQL_CONNECTION`, `SAVIA_INTERNAL_SQL_TESTS_AUTHORIZED`,
`SAVIA_INTERNAL_HTTP_SQL_TESTS_AUTHORIZED`, `SAVIA_PILOT_PERSIST_DATABASE`.
No `.env` was loaded. No SQL, container, service or certificate was touched.
Raw TRX, logs and generated release SQL stay private and ignored (`private-exports/`).
Raw TRX SHA256: `75703E343215A2B34EA26063BA46D4B184973719DB7A7E2866CDD0EF68F53E98`.

## 2. Prerequisites verified read-only (do not repeat)

- Docker Linux engine 29.7.2, exit 0.
- `mcr.microsoft.com/mssql/server@sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718` cached.
- `mcr.microsoft.com/dotnet/sdk:10.0.402` cached (`sha256:747cbade5bfd918a175ac32f8f1d931edec2c7d0d5397a3de72eaef1ac1f66d2`).
- No `savia-*` container exists; ports 14333/14337/14338 free. SAVIATEST untouched.
- Preparation syntax check: `python -m py_compile tests/golden-path/golden_path.py tests/golden-path/verify_evidence.py` exit 0. No SQL.

Known gap: the cached SDK image has no python3, node/npm or Google Chrome.
`golden_path.py` requires Linux `pty/fcntl/termios` and `/proc`; native Windows cannot run it.
`browser_path.mjs` launches Playwright with `channel: 'chrome'`, so bundled Chromium is not enough.

Shortest missing-runner route (prepare, do not run): build one disposable runner image from the
cached SDK image and add only `python3`, Node 24, Google Chrome, and
`playwright@1.63.0` (no browser download). It needs network for apt/Chrome/npm, which is an
execution-time authorization item, not a host install.

## 3. Prepared campaign: DO NOT EXECUTE without new runtime scope

`docs/DATABASE.md:50` requires a new execution scope per runtime. Previous approvals are consumed.
This document prepares commands; it does not authorize them.

Fixed inputs:

- Source: `69d3268c63019d8b8299027789962a1089f91a58`.
- SQL image: `mcr.microsoft.com/mssql/server@sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718`,
  `MSSQL_PID=Developer`, `ACCEPT_EULA=Y` (existing CI choice, non-production).
- New owned names: `savia-local-a-<8hex>` (SQL), `savia-local-runner-<8hex>`, `savia-local-net-<8hex>`.
- Network: isolated bridge; SQL published only to `127.0.0.1:14337` (free at preparation time).
- Credentials: `Aa1!$(openssl rand -hex 32)` generated at runtime, masked, passed only through child env
  or a `0600 --sql-env-file`; never in repo, `--out`, logs or chat.
- Databases: created by the tests as `SaviaInternalTest_Pilot_|Release_|Commerce_<32hex>`.
  Pre/post inventory must differ only by those synthetic names, which must all be gone after cleanup.
- Trust: `TrustServerCertificate=true` inside the disposable container connection only, and an
  ephemeral API certificate pinned by SPKI in the private Chrome profile. No host trust store change.
- Budgets: C77 25 min, D 20 min, E 15 min. No automatic SQL retry. One failed path may be retried once.

Order and completion checks:

1. C77 (all C, 77 cases; start with the six `InternalAcceptanceHttpSqlTests` = C1):
   `dotnet test ... --filter <PARTITIONS.json C1 filter>` then the full C filter;
   verify with `python backend/tests/verify_full_suite.py --manifest docs/local-validation-20261106/PARTITIONS.json --partition C <results>`.
   Completion: 77/77 Passed, zero skips, exit 0.
2. D combined journey, only after C77 passes:
   `python3 tests/golden-path/golden_path.py --mode browser --no-build --supply --stock-exception --playwright-directory <pw> --out <private/combined>`
   then `python3 tests/golden-path/verify_evidence.py --source <private/combined> --destination <private/combined-approved>`.
   Completion: real Chrome to HTTPS API to SQL checkpoints pass; no simulated response counts.
3. E2 recovery: run `Real_migration_reapply_throwaway_down_up_and_actual_backup_restore`, then
   `docker stop/start` the owned SQL container, then
   `SAVIA_PILOT_PERSIST_DATABASE=<source DB> dotnet test ... --filter 'FullyQualifiedName~Frozen_fixture_survives_controlled_owned_container_stop_start'`.
   Completion: both cases Passed and data survives the owned restart.

Cleanup (always): retain private diagnostics first, then
`docker rm --force --volumes <owned containers>`, `docker network rm <owned net>`, delete only the
owned evidence copies, and read back container/network absence. Never touch SAVIATEST, host
certificates or unrelated containers. Do not dispatch GitHub Actions.

## 4. Limits

C77, D and E2 remain NOT RUN on this candidate. The six historical SQL failures remain unexplained
by runtime evidence. No SQL inventory, browser, CI or production claim is made here.
Primary owns serial integration and acceptance.

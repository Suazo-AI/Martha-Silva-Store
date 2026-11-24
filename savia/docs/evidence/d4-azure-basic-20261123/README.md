# D4: A-10 hub measurements on Azure SQL Basic

Status: BLOCKED on 2026-11-24 at 01:04 UTC (2026-11-23 local time). No measurement ran.
Task `d4-a10-azure-basic-20261123`, source Tony@7ec3330c, worker model claude-opus-5-5; effort requested high, effective effort not confirmed.

## Result first

- Measured: one login to the temporary database `savia-d4-a10` failed with `SQL error 18456: Login failed for user '<token-identified principal>'.`
- Inferred from `az sql server show` and AZURE.md: the operator account cannot sign in to any database on `sql-savia-bukmlt`.
- Inferred cause: the server accepts Entra ID only, and its only SQL admin is the application identity `id-savia-migrate-bukmlt`. A new database has no user for a person.
- The temporary database and the temporary firewall rule were created, used for one login attempt, and deleted. The readback shows the server as it was at start.
- `savia` was not read, written or changed: Online, Basic, 5 DTU, 2,147,483,648 bytes before and after.
- D4 stays open. Basic is neither proven enough nor proven too small.

## What ran

| Step (UTC) | Command | Result | Raw file |
|------------|---------|--------|----------|
| 01:02:31 | `az sql db list`, `az sql server firewall-rule list`, `az sql server show` | `savia` Online Basic 5; one rule `AllowAllWindowsAzureIps`; `azureAdOnlyAuthentication: true`, admin `id-savia-migrate-bukmlt` (Application) | [baseline-readback.txt](baseline-readback.txt) |
| 01:02 | `az account get-access-token --resource https://database.windows.net/` | token issued (expiry printed only) | |
| 01:03:12 | `az sql db create -n savia-d4-a10 --edition Basic --capacity 5 --max-size 2GB --backup-storage-redundancy Zone` | Online at 01:03:49 | [create.txt](create.txt) |
| 01:03:52 | `az sql server firewall-rule create -n d4-temp-20261123 --start-ip-address <this PC public IP> --end-ip-address <this PC public IP>` | created | [create.txt](create.txt) |
| 01:04:01 | `Savia.Migrator --plan --migrations db/migrations`, `Database=savia-d4-a10;Authentication=Active Directory Default` | `18456 Login failed for user '<token-identified principal>'`, exit 1 | [login-attempt-1.txt](login-attempt-1.txt) |
| 01:04:25 | `az sql server firewall-rule delete`, `az sql db delete --yes` | both failed: `ConnectionResetError(10054)` on the client; resources still listed | [cleanup-readback.txt](cleanup-readback.txt) |
| 01:04:58 | same two deletes, one rerun | both exit 0 | [cleanup-readback.txt](cleanup-readback.txt) |
| 01:05:21 | `az sql db list`, `az sql server firewall-rule list` | `savia`, `master`, `savia-premig-1b1e001-1`; rule `AllowAllWindowsAzureIps` only | [cleanup-readback.txt](cleanup-readback.txt) |

- The login error is a principal error. It is not a firewall error (40615) and not a token error (`AADSTS…`).
- No `AZURE_*` environment variable was set, so `Active Directory Default` used a developer sign-in on this PC (Azure CLI or Visual Studio). Either is a person, not the server admin, so the result does not depend on which one it was.
- The migrator was built with `dotnet build deploy/migrator/Savia.Migrator.csproj -c Release` into a temp folder outside the repository.

## Targets

None was measured. Store-floor targets run on store PCs, not on the hub, so they were out of scope from the start.

| ID | Target | D4 result |
|----|--------|-----------|
| T1-T5, T8, T12 | store-floor operations | out of scope (store PCs) |
| Migrations V001-V064 on an empty Basic DB | time | NOT RUN (login 18456) |
| T9 initial paged push A/B/C to the hub | < 30,000,000 bytes and < 300 s per page | NOT RUN |
| T10 incremental round after 500 sales | < 1 MB and < 10 s | NOT RUN |
| T11 hub size after load | < 2 GB | NOT RUN |
| T6 KPI business, public catalog and order reads on the hub | p95 targets of A-10 and P2 | NOT RUN |
| RTT (`SELECT 1` p50), DTU % avg/max, `sys.dm_exec_query_stats` | report | NOT RUN |

## Unblock options (Jason decides; each changes the task scope)

1. Recommended: a separate temporary SQL server in `mexicocentral`, in a separate resource group, with Jason's account as its Entra admin, holding one Basic database.
   It touches nothing in production. Cost: one Basic database at about $0.18 per day, plus nothing for the server.
   Inference, not measured: Basic limits (5 DTU, 2 GB) are per database, so the numbers should carry over to `savia`.
   Not verified: that this trial subscription may create a second SQL server in `mexicocentral` (it already blocks ACR Tasks).
2. Alternative: the break-glass switch in `CHECKLIST.md` (set an Entra group as admin of `sql-savia-bukmlt` for the session, then switch back).
   It changes production server configuration, and the migrate identity is not the admin while it lasts.
3. Not allowed by this task: enabling SQL authentication, or running `caj-savia-migrate` against a test database.

## Tooling finding for the retry

- `tools/load/sync_measure.py` cannot target Azure as written.
  Each page runs as one cross-database `EXEC` inside a single SQL Server (lines 86-92); Azure SQL Database has no cross-database `EXEC`.
  It also needs `BACKUP`/`RESTORE` (lines 111-113, 183) and the `docker exec` runner in `tools/db/saviadb.py`.
- A retry needs a client relay: read `usp_SourceStateJson` and `usp_ReadBatch` on the local store container, then call `usp_PlanJson` and `usp_ApplyBatch` on the Azure hub, page by page.
  This is closer to the real P9 transport than the A-10 run, but adds the network to every page.
- The hub's base catalog (50,000 products, 250,000 variants; 264 MB of data locally before sync) must be on Basic before the push.
  Options: run the catalog insert of `generate.py` against Azure, or import a bacpac of `SAVIA_SIM_load_hub`. Load time on 5 DTU is unknown.
- `generate.py` and `sync_measure.py` refuse to run unless `SAVIA_SQL_CONTAINER` names a load container; keep that guard for the local side.
- None of this was built: the stop condition applied first.

## Limits

- One login attempt. The two cleanup deletes needed one rerun after a client-side connection reset.
- `az sql db list-deleted` did not list `savia-d4-a10` at 01:05:21; restorable entries can appear later. Inference: a deleted Basic database keeps no billable compute.
- The temporary database existed from 01:03:49 to about 01:05:21 UTC. Inference from the AZURE.md price: Basic bills per hour, so the charge is at most one hour of $0.1771 per day, under $0.01.
- The public IP of this PC was replaced with `<this PC public IP>` in the raw `.txt` files and in this README after capture. Nothing else in the raw files was edited.
- No local Docker container was started; no data was generated.

## Run 2 (2026-11-23): temporary Basic server, relay, scale 0.03

Result: the relay synced all three stores into Azure SQL Basic and the parity check passed for each.
Jason approved a separate temporary server under $1; the production server `sql-savia-bukmlt` was not touched.

Setup:
- Server `sql-savia-d4tmp-11232204`, database `savia-d4b`, Basic (5 DTU, 2 GB), group `rg-savia-d4-temp`.
- Sign-in by Entra access token (`SAVIA_HUB_ACCESS_TOKEN`); no SQL password was created.
- Local store data: container `savia-sqlserver-load`, seed `relay-20261123`, scale 0.03.
- Tool: `savia/tools/load/sync_relay.py` (`hub-load`, `push --store a|b|c --out FILE`, `parity --store X`).

| Step | Pages | Rows | Bytes | Apply s | Wall s |
|---|---|---|---|---|---|
| `hub-load` (58 migrations 103.1 s, fixture 4.9 s, catalog 63.9 s: 1,501 products, 7,503 variants) | - | - | - | - | 212 |
| push C | 1 | 6,204 | 2,682,155 | 79.8 | 81.8 |
| push B | 1 | 9,324 | 4,021,353 | 38.4 | 40.4 |
| push A (largest page 3,580,690 bytes) | 3 | 15,286 | 6,581,771 | 92.6 | 95.7 |
| empty round A | 1 | 0 | 3,628 | 0.9 | 2.35 |

Parity: OK for A (15,286 rows), B (9,324) and C (6,204).
DTU (Azure Monitor, 1-minute maximum, 12 minutes with data): peak 100% in 2 minutes, mean 34.9%.
Storage at the end: 69,074,944 bytes (about 66 MB of 2 GB).

Reading:
- Every page finished well under the 300 s target; the slowest page was C at 79.8 s.
- Apply is about 20 times slower than the local run (about 10 s for about 13 MB). Network and the 5 DTU cap explain it; the two 100% minutes show the cap was reached.
- Incremental rounds are cheap: an empty round costs 3,628 bytes and 2.35 s.
- Extrapolation, not measured: a full-scale first push (about 450 MB) would take about 2 hours once, then incremental rounds.

Raw files: [run2/](run2/) (`hubload.txt`, `push*.json|txt`, `empty.*`, `parity*.txt`, `metrics.json` with the subscription id replaced).

Limits:
- Scale 0.03, not the 50,000-product catalog.
- T10 (a store with 500 sales in one round) was not measured on Azure.
- The temporary group is deleted after this run; see the cleanup line below.
- Cleanup: `az group delete -n rg-savia-d4-temp --yes` (client connection resets, server-side delete completed); at 04:31:32 UTC on 2026-11-24 `az group exists` returned `false` and `az sql server list` listed only `sql-savia-bukmlt`.

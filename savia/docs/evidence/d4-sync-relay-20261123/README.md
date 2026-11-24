# D4 tooling: client sync relay across two SQL servers (local proof)

Date: 2026-11-23.
Mode: BUILD.
Scope: local only; no Azure, no `az`, no remote database was contacted.

## Result

The store and the hub can now live on different SQL servers.
[`tools/load/sync_relay.py`](../../../tools/load/sync_relay.py) carries every sync page through the client.
It runs no cross-database `EXEC` and no `BACKUP` or `RESTORE` on the hub.
A two-container run passed end to end: hub load, push C/B/A, an empty round, parity, a negative control, and a hub-to-A pull.
The relay moved exactly the same rows and bytes as the existing single-server mode on every step.

## What was built

| Item | Where | Notes |
|------|-------|-------|
| Relay page loop | `sync_relay.py` `relay_page`, `relay` | Store `usp_SourceStateJson` -> hub `usp_PlanJson` -> store `usp_ReadBatch` -> hub `usp_ApplyBatch`, until `more=false` |
| Hub connection | `SAVIA_HUB_ODBC` (+ optional `SAVIA_HUB_ACCESS_TOKEN`) | Plain ODBC string; an Entra token goes to the driver in-process as `SQL_COPT_SS_ACCESS_TOKEN` (1256) |
| Store connection | `SAVIA_SQL_CONTAINER=savia-sqlserver-load[n]` | Same guard as `generate.py`; port from `docker port`, sa password from the container environment, kept in-process |
| Per-page metrics | JSON, saved after every page | rows, batch bytes (UTF-8, as in A-10), state/plan/result bytes, state/plan/read/apply seconds |
| Hub base loader | `hub-load` | Migrations (same registry, checksum and transactional envelope as `saviadb.migrate`), test fixture, `generate.Gen.catalog_sql()`, `usp_SetLocalNode` cloud; one plain connection, empty database |
| Reference alignment | `align_reference` (run by `hub-load`) | Copies only the hub-owned synced rows that differ from the local template |
| Parity | `parity --store a/b/c` | Per synced table: count and SHA-256 over store-origin rows, store vs hub; exit 1 on any difference, a missing table, or zero rows compared |
| Test | [`tests/test_sync_relay.py`](../../../tests/test_sync_relay.py) | 6 unit tests + 1 two-server integration test (`SAVIA_RELAY_IT=1`) |

`sync_measure.py`, `generate.py` and `saviadb.py` are unchanged.

## Finding: a loaded hub is not the template hub

`generate.py` builds every node from one backup, so all nodes share the same reference rows.
A hub rebuilt over a plain connection differs in two ways:

- `catalog_sql()` stamps `CreatedAt` from the clock (`DATEADD(day,-90,core.ufn_BusinessNow())`).
- `_fixture.sql` registers items through `usp_RegisterItem`, which draws identifier ids from `NEWID()`.

Push and parity still pass with such a hub.
The hub-to-store pull fails, because the hub sends its own reference rows:

```text
IntegrityError: Cannot insert duplicate key row in object 'catalog.ItemIdentifiers' with unique index
'UX_ItemIdentifier_Global'. The duplicate key value is (barcode, 0000987654321). (2601)
```

Fix in `hub-load`: the catalog `CreatedAt` is pinned to the template's value, so the bulk catalog matches without shipping it.
`align_reference` then copies the remaining 18 fixture rows (7 tables) from the template.
A second alignment pass returns `{}`: every hub-owned synced row equals the template.

## Verification

Environment: two new containers from the pinned image digest of `infra/docker-compose.dev.yml`.
`savia-sqlserver-load` (store, 127.0.0.1:14352) and `savia-sqlserver-relayhub` (hub, 127.0.0.1:14353), SQL Server 2022 16.0.4305.5, `MSSQL_MEMORY_LIMIT_MB=1536`.
The test asserts that `@@SERVERNAME` differs between the two connections.
pyodbc 5.5.0 in a venv under `savia/.out/relay-venv` (git-ignored); ODBC Driver 18 for SQL Server.

Dataset: `generate.py --scale 0.03 --days 3 --tickets 10 --seed relay-20261123` (1,500 products, 7,500 variants, 34 sales per store), exit 0 in 95 s.

| Command | Exit | Key result |
|---------|------|------------|
| `SAVIA_RELAY_IT=1 SAVIA_SQL_CONTAINER=savia-sqlserver-load SAVIA_RELAY_HUB_CONTAINER=savia-sqlserver-relayhub .out/relay-venv/Scripts/python -m unittest tests.test_sync_relay.TwoServerRelayTest -v` | 0 | `Ran 1 test in 112.689s OK`, 0 skipped |
| `.out/relay-venv/Scripts/python -m unittest tests.test_sync_relay` | 0 | `Ran 7 tests OK (skipped=1)`; the skip is the integration test without `SAVIA_RELAY_IT` |
| `python -m unittest discover -s tests -p "test_*.py"` (savia, system Python) | 0 | `Ran 63 tests OK (skipped=2)`; skips: integration and the pyodbc sentinel |
| `SAVIA_SQL_CONTAINER=savia-sqlserver-load python savia/tools/load/sync_measure.py --skip-rebuild --sales 20 --out <scratchpad>` | 0 | existing single-server mode; every step `finished=True`; oracle 0 on a, b, c, hub |
| CLI `sync_relay.py hub-load --seed relay-20261123 --scale 0.03` on a second empty hub database | 0 | 58 migrations 4.6 s, fixture 0.3 s, catalog 1.3 s, align 1.4 s, `aligned_after: {}` |
| CLI `sync_relay.py push --store a` | 0 | 3 pages, 15,286 rows, 6,581,771 bytes, wall 4.3 s |
| CLI `sync_relay.py parity --store a` | 0 | `PARITY OK store_rows=15286` |
| CLI `sync_relay.py parity --store b` (B never pushed to that hub) | 1 | `PARITY FAILED: [inventory].[StockBalances]: store 4530 rows, hub 0 rows; ...` |

Integration run, relay vs the existing local mode on the same data:

| Step | Relay pages / rows / batch bytes | `sync_measure.py` pages / rows / bytes |
|------|------------------------------|-----------------------------------|
| C -> hub | 1 / 6,204 / 2,682,155 | 1 / 6,204 / 2,682,155 |
| B -> hub | 1 / 9,324 / 4,021,353 | 1 / 9,324 / 4,021,353 |
| A -> hub | 3 / 15,286 / 6,581,771 | 3 / 15,286 / 6,581,771 |
| hub -> A | 5 / 32,048 / 12,983,351 | 5 / 32,048 / 12,983,351 |
| empty round A -> hub | 1 / 0 / 3,628 | (not in the smoke run) |

Relay client seconds for A -> hub: read 1.405, apply 2.331, wall 3.82.
State, plan and result JSON added 15,607 bytes to the A push (6,597,378 bytes on the wire in all).
A push pages: 1,514,977 / 3,580,690 / 1,486,104 batch bytes in 1.408 / 1.447 / 0.929 s; the largest page is 3,580,690 bytes.
The empty round moved 0 rows and 8,701 bytes in all in 1.35 s.

Parity after the push: A 15,286, B 9,324, C 6,204 store-origin rows, all tables equal.
Negative control: one `UPDATE inventory.StockBalances SET OnHand=OnHand+1` on the hub (1 row).
`parity --store a` then exited 1 with `[inventory].[StockBalances]: store 7500 rows, hub 7500 rows, checksum differs`.
After the row was restored, parity passed again.
Secret check: a failed connection with a sentinel password exits non-zero, says `connect failed`, and prints no sentinel.

## Not verified

- Azure is unverified by design: nothing here touched Azure SQL Database, 5 DTU, the network, or Entra.
- Token authentication was not exercised: only the token packing and the credential refusal are unit-tested.
- Migrations on Azure: V008, V032, V033 and V034 create procedures that read `sys.database_recovery_status`.
- V036 replaces that read with `sync.CurrentFork`, which has an Azure branch; whether the older procedure bodies are created on Azure is unknown.
- V004 (`ALTER DATABASE CURRENT SET ... SNAPSHOT`) and V008 (`CHANGE_TRACKING = ON`) use `CURRENT`, which Azure is expected to accept; not run there.
- Full scale was not run with the relay: A-10 local push was about 450 MB and 1,037,532 rows in 723 s of wall time.
- The rebuild mode (`--mode rebuild`) is carried over from `sync_measure.py` but was not exercised through the relay.

## Next action

Run the relay against an empty Azure Basic database, scaled first, after Jason authorizes access.

1. The operator needs a database user on the hub; today the login fails with 18456 (see [D4](../d4-azure-basic-20261123/README.md)).
   Creating an Entra user is an account change that needs approval.
2. Get a token in the shell without printing it: `$env:SAVIA_HUB_ACCESS_TOKEN = az account get-access-token --resource https://database.windows.net/ --query accessToken -o tsv`.
3. `$env:SAVIA_HUB_ODBC = 'Driver={ODBC Driver 18 for SQL Server};Server=tcp:<server>.database.windows.net,1433;Database=<db>;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30'`.
4. With `SAVIA_SQL_CONTAINER=savia-sqlserver-load` and the stores generated at `--scale 0.03`: `hub-load`, then `push` C, B, A, then `parity` for each store.
5. Locally that push takes about 10 s of client time for about 13 MB; the ratio on 5 DTU decides whether a full-scale run (about 450 MB, 723 s locally) fits the 300 s page and 2 GB targets.

# Sync paging, rebuild progress, hub catalog and import speed (2026-11-22)

Items S5, the S1 rebuild progress, S9 and P1 of `docs/production-20261122/README.md`; decisions D-036, D-039 and D-041.
Source commit `158e99a6`, uncommitted changes in branch `t3/sync-paging-catalog`.
Migrations V060 and V061.
All runs are local, on SQL Server Developer in Docker; nothing ran on Azure SQL.

## Result

- S5: sync moves in pages of at most 5,000 rows per table and about 19 MB.
  On A-10 data, the rebuild of store A finished after a kill in the middle, with a clean oracle on all four nodes.
  The largest response was 6.75 MB.
- Rebuild progress: `GET /api/v1/sync/status` reports tables done of total, and the till shows it in the recovery message.
- S9: the hub imports and registers catalog items with no stock; a store with a hub refuses catalog writes with `409 catalog.managed_by_hub`.
- P1: three 1,000-row imports over HTTP took 2,512, 1,411 and 1,359 ms.

## What changed

| Item | Where | Behaviour |
|---|---|---|
| S5 | `db/migrations/V060__sync_paging.sql` | `usp_ReadBatch` reads a page by key (`@PageRows` 5,000, `@PageBytes` 19,000,000). The receiver keeps the open pass in `sync.PeerPasses` and `sync.PeerPassTables`, so a new process resumes it. A cursor moves only when its table is finished. A repeated page is skipped; a page out of order is a gap (51852). The final rebuild page lifts the recovery lock in the same transaction. |
| S5 | V060 `usp_ReadBatch` | A store's incremental read skips rows it applied from a peer (`SYS_CHANGE_CONTEXT`), instead of an owner check per row. |
| S5 | `Savia.Application/Sync.cs`, `SyncWorker` | One round runs pages until the plan says done. |
| Progress | `SyncEndpoints.cs`, `web/ui.mjs` | `GET /api/v1/sync/status` returns `rebuild.done` and `rebuild.total` (tables); the till says "Se reconstruye esta sucursal desde la central: 12 de 39 tablas." |
| S9 | `db/migrations/V061__hub_catalog_import.sql`, `Catalog.cs`, `CatalogStore.cs`, `CatalogEndpoints.cs` | On the hub, import and item registration write products, items, barcodes and prices, with no stock and no location. They need the owner role with no branch. A store with a hub refuses catalog writes with `catalog.managed_by_hub` (409). A store with no hub keeps today's behaviour. |
| S9 | `web/screens/prices.mjs`, `web/screens/import.mjs` | A store with a hub shows "El catálogo se gestiona en la central." and calls no API. |
| P1 | V061 `sync.usp_EnqueueEvents` | One call writes every outbox event of an import, over the table type `sync.EventInput`. |
| P1 | V061 `catalog.usp_ImportCatalog` | The preview refuses two rows of one product with the same size and color. |

## Red first

| Test | Red output | File |
|---|---|---|
| T-SQL `sync/290_paging` | `a fresh plan asks for page 1 expected=1 actual=NULL` | [red-290-first-page.txt](red-290-first-page.txt) |
| T-SQL `sync/290_paging`, late page 1 | `late page 1: no pass reopened expected=0 actual=1` | [red-290-late-page.txt](red-290-late-page.txt) |
| T-SQL `sync/290_paging`, peer rows | `an applied row carries the sync context expected=1 actual=0` | [red-290-context.txt](red-290-context.txt) |
| T-SQL `catalog/156`, `catalog/157` | 156: `Msg 52001`; 157: `two rows repeat one variant expected=2 actual=0` | [red-catalog-hub.txt](red-catalog-hub.txt) |
| T-SQL `catalog/158` | `Msg 52001` | [red-item-values-hub.txt](red-item-values-hub.txt) |
| T-SQL `outbox/090` | `Msg 1087` (no table type yet) | [red-enqueue-events.txt](red-enqueue-events.txt) |
| web `catalog-central.test.mjs` | `✖ a store with a hub shows the central catalog on prices and import, and calls no API` | [red-web-catalog-central.txt](red-web-catalog-central.txt) |
| web `sync-notice.test.mjs` | expected `/12 de 39/` | [red-web-progress.txt](red-web-progress.txt) |
| V061 runs a second time (rehearsal `schema_skew` re-applies the newest migration) | `Msg 2714 ... There is already an object named 'CK_ImportBatches_Store'` | [red-v061-rerun.txt](red-v061-rerun.txt), green: [green-v061-rerun.txt](green-v061-rerun.txt) |
| S5 on A-10 before V060 | rebuild did not finish in 900 s; batches of 93-229 MB | [load-a10-20261121](../load-a10-20261121/README.md) |

Written after the code, so not red first: `HubCatalogTests` and the two paging tests in `SyncWorkerTests`.
The first run of `Rebuild_larger_than_a_page_resumes_after_a_lost_page_and_reports_progress` failed on its own setup: the backup had no `sync.LocalNode`, so the restored copy had no recovery lock ([dotnet-rebuild-test-setup-fail.txt](dotnet-rebuild-test-setup-fail.txt)).
The test now provisions the node before the backup, as `Restored_branch_the_hub_never_saw_refuses_sales_until_it_rebuilds` does ([dotnet-rebuild-test-pass.txt](dotnet-rebuild-test-pass.txt)).

## A-10 sync measurement

Command: `python tools/load/sync_measure.py` against the A-10 container `savia-sqlserver-load` (50,000 products, 250,000 variants, three stores with history).
Output: [green-a10-sync.txt](green-a10-sync.txt).

| Step | Pages | Rows | Bytes | Largest page | Read | Apply | Wall |
|---|---|---|---|---|---|---|---|
| c → hub | 40 | 213,749 | 93.4 MB | 6.72 MB | 12.96 s | 40.85 s | 79.5 s |
| b → hub | 60 | 313,753 | 136.3 MB | 6.73 MB | 24.66 s | 81.89 s | 152.2 s |
| a → hub | 101 | 514,197 | 222.3 MB | 6.75 MB | 35.73 s | 126.35 s | 235.0 s |
| hub → a | 212 | 1,077,522 | 439.1 MB | 6.18 MB | 67.37 s | 205.04 s | 874.5 s |
| 500 sales at a, then a → hub | 1 | 2,508 | 1.36 MB | 1.36 MB | 4.08 s | 1.40 s | 6.0 s |
| empty round hub → a, cold | 1 | 0 | 3,668 B | | 3,240 ms | 154 ms | 3.8 s |
| empty round hub → a, warm (simulators running) | 1 | 0 | 3,668 B | | 397 ms | 50 ms | 0.8 s |
| rebuild of a, killed after 3 pages | 3 | 15,010 | 4.18 MB | 1.40 MB | 0.71 s | 1.04 s | 4.2 s |
| rebuild of a, resumed by a new process | 313 | 1,578,717 | 658.5 MB | 4.48 MB | 79.04 s | 96.44 s | 344.3 s |
| empty round hub → a, after the rebuild (simulators running) | 1 | 0 | 3,668 B | | 597 ms | 41 ms | 1.0 s |

- Oracle after the rebuild: 0 violations on hub, a, b and c.
- The resumed rebuild did not repeat pages: 15,010 + 1,578,717 = 1,593,727 rows.
- Largest HTTP response in the whole run: 6.75 MB, under the 20 MB limit.
- Before the context filter, the push after the 500 sales read in 33.4 s; after it, 4.1 s.
- Hub space after the three pushes: 1,033 MB used of a 1,096 MB file.

## Simulator

`python tools/db/simulator.py scenario <name> --seed 1`, default page size: basic, replay, restore, credit_status and cancel_vs_dispatch all `RESULT PASS` (`sim-*.txt`, rerun on the final V061 bytes).
With `--page-rows 3`, so every table runs in many pages:

- basic: PASS in 107 pages ([sim-basic-page-rows-3.txt](sim-basic-page-rows-3.txt)).
- restore: PASS in 22 rebuild pages; the restored store refuses a sale with 51864 and the final page lifts the lock ([sim-restore-page-rows-3.txt](sim-restore-page-rows-3.txt)).

## P1 import timing

Command: `python tools/load/api_bench.py --sections import --label p1-20261122` on the A-10 container.
Output: [p1-import.txt](p1-import.txt).
Before the run, CPU was 2.10% on the load container and 2.36% on the dev container; no other SQL container ran.

| Batch | Preview | Commit | Dev container CPU during the commit |
|---|---|---|---|
| 0 | 266 ms | 2,512 ms | 1.95% |
| 1 | 134 ms | 1,411 ms | 3.03% |
| 2 | 113 ms | 1,359 ms | 1.81% |

Every response was 200; every commit is under the 3 s target.

## Focused tests

- T-SQL: `catalog/150`, `155`, `156`, `157`, `158`; `outbox/090`; 11 `sync/2*` tests including `290` ([green-db-focused.txt](green-db-focused.txt)).
- .NET: `HubCatalogTests`, `LocalCatalogRejectTests`, `ArchitectureTests`, `OwnerDecisionsRound4Tests`, `SyncWorkerTests`, `SyncTransportTests` and the sync status tests.
- Rehearsal: `python tools/rehearsal.py run all --identity restricted`: offline_sales, replay, credit_transfer, restore_sale_before_rebuild, hub_restart, controls, reference_data, schema_skew and the new hub_catalog all PASS ([rehearsal/summary.json](rehearsal/summary.json)). `run all` now takes its list from `SCENARIOS`; before, it skipped `hub_catalog`.
- Full gate: `python tools/check.py --isolated` RESULT PASS: T-SQL 181 PASS, .NET 242 of 242 and 33 of 33 as the API host login.
- Web: `node --test "savia/web/tests/*.test.mjs" "savia/web/scanner/*.test.mjs"`: 175 of 175 pass.

## Limits

- Empty round under 500 ms: not proven. Warm reads took 397 ms before the rebuild and 597 ms after it. Both ran while simulator scenarios used the dev container on the same host, so load was not controlled. The load container was removed afterwards, so the reading was not repeated.
- A-10 ran on SQL Server Developer in Docker, not on Azure SQL Basic (5 DTU, 2 GB). The hub used 1,033 MB after the three pushes.
- A page that fails on a foreign key (547) drops the open pass, so the next round starts the pass again.
- A row changed after the pass version waits for the next round.
- The hub import writes no stock. Stock enters a store only by receiving.

# A-10 slow paths P1-P4: before and after

Status: measured on 2026-11-22, local Docker only, same machine and same data before and after.
Source: Tony@ac80af38 plus the uncommitted migrations V039-V042 and the code changes of this task.
Data: the A-10 database `SAVIA_SIM_load_a` (50,000 products, 250,000 variants, 250,000 stock rows) restored from the same backup for each run.

## Result first

- P3 search: PASS. Text search p95 is 157.9 ms (target 300 ms); it was 1,907.8 ms.
- P4 paging: PASS. No response is above 1 MB; the largest page is 162,105 bytes. The full catalog and all stock page through without an error.
- P1 import: PARTIAL. No 503 in 6 of 6 recorded commits of 1,000 rows (pass).
- The 3 s commit target is not met: the 6 recorded commits took 7.3 to 15.2 s.
- In one earlier probe, two warm commits took 2.2 s; the cold first commit took 4.7 s.
- P2 KPI business: FAIL. p95 is 1.9 to 2.4 s (target 1 s); it was 6.5 to 10.0 s. Logical reads fell from 8.2 M to 67 k per call. The results equal the old procedure.

## Before and after (API, one client on loopback)

| Path | Target | Before | After | Result |
|------|--------|--------|-------|--------|
| `GET /catalog/search` (200 mixed terms) | p95 < 300 ms | p95 1,907.8 ms, p50 1,455.4 ms | p95 157.9 ms, p50 58.8 ms | PASS |
| search "M12345" (SKU) | | p95 2,177.0 ms | p95 133.9 ms | |
| search "LD004321" (code) | | p95 2,360.1 ms | p95 109.1 ms | |
| search "zzqx" (no match) | | p95 2,054.3 ms | p95 143.4 ms | |
| search "Vestido Seda Noche" | | p95 1,603.9 ms | p95 199.8 ms | |
| search "Aniversario" | | p95 1,287.2 ms | p95 26.1 ms | |
| `GET /reports/kpi/business` day | p95 < 1 s | p95 6,510.8 ms | p95 2,288.7 ms, p50 1,742.9 ms | FAIL |
| same, week | p95 < 1 s | p95 7,166.2 ms | p95 1,944.6 ms, p50 1,465.8 ms | FAIL |
| same, month | p95 < 1 s | p95 9,965.4 ms | p95 2,410.2 ms, p50 1,721.1 ms | FAIL |
| `GET /catalog/items` | ≤ 1 MB per response | no answer in 120 s (3 of 3 timeouts) | first page 89-141 ms, 160 KB | PASS |
| all catalog pages | | not possible | 501 pages, 50,001 products, 43.9 s, page p95 176.8 ms, largest 162,105 bytes | PASS |
| `GET /stock` | ≤ 1 MB per response | one 51,000,001-byte response in 2.6 s | first page 31-49 ms, 102,000 bytes | PASS |
| all stock pages | | not possible within 1 MB | 500 pages, 250,000 rows, 19.3 s, page p95 82.9 ms, largest 102,002 bytes | PASS |
| import preview, 1,000 rows | | 3 of 3 `503 db.busy` at 30 s | 140-333 ms, 200 | PASS |
| import commit, 1,000 rows | < 3 s, no 503 | 3 of 3 `503 db.busy` at 30 s | 6 of 6 200 in 7,305-15,211 ms; probe: 4,665 ms cold, then 2,157 and 2,180 ms | no 503: PASS; under 3 s: FAIL |
| checkout (`POST /sales`), regression check | | p95 108.7 ms | p95 81.5 ms (run 1), 173.8 ms (run 2, under load) | run 1 faster; run 2 slower, not separated from load |
| 100 receiving scans, regression check | | p95 86.4 ms | p95 81.6 ms (run 1), 108.2 ms (run 2) | no regression found |

## Before and after (SQL, from `sql_stats.py` and the procedure statistics)

| Query | Before | After |
|-------|--------|-------|
| `sales.usp_KpiBusiness`, mean of all calls | 8,225,618 reads, 24,421.6 ms CPU, 5,091.5 ms elapsed | 66,960 reads, 4,386.2 ms CPU, 1,704.2 ms elapsed (run 1) |
| search "M12345" | 1.51 M reads, 1,886 ms | 8,803 reads, 83 ms |
| search "zzqx" | 2,130 ms | 80 ms |
| search "Blusa" | 358 ms | 1,943 reads, 9-10 ms |
| `catalog.usp_ListSaleCatalog` | 3.4 M reads, 8,456 ms (whole catalog) | 16.5 k reads, 40 ms (first page); mean of 504 pages 17,039 reads, 57.6 ms |
| stock list | 853 ms (all rows) | 4 ms (first page) |
| stock page at row 200,000 | 1,275 ms with one shared plan | 33 ms with `OPTION(RECOMPILE)`; 501 rows, 0 rows differ |
| `catalog.usp_ImportCatalog`, mean of 6 calls | 2,028,975 reads, 29,870.6 ms CPU (time-outs) | 175,558 reads, 4,642.2 ms CPU, 5,300.8 ms elapsed (run 1); 176,328 reads, 4,260.4 ms CPU, 6,132.8 ms elapsed (run 2) |

Raw numbers:

- [api.json](api.json): labels `before` and `after`. The `after` search and KPI sections are from run 1; lists, writes and procedures are from run 2.
- [after-run1.txt](after-run1.txt): the full run 1 output, with the run 1 writes and the KPI procedure mean.
- [after-run2.txt](after-run2.txt): the run 2 output (lists and writes after the stock fix).
- [probe-import-quiet.json](probe-import-quiet.json): the import probe after the identifiers trigger change.
- [sql-stats-before.json](sql-stats-before.json), [sql-stats-after.json](sql-stats-after.json): plans and reads per query.

## What changed

- V039: the import checks duplicates for the whole batch in one set-based pass. The SKU join uses BIN2, so it seeks the SKU index.
- V040: `sales.usp_KpiBusiness` reads stock, receipts, returns, sales and the last movement once per item into temporary tables. It no longer runs one subquery per product.
- V041: a table `catalog.ItemSearch` holds one lower-case, accent-free search key per item. Triggers keep it current. A whole SKU or code is found by an index seek first.
- V042: `catalog.usp_ListSaleCatalog` takes an optional page size and continuation key. Without them it returns the old one-column result.
- API: `GET /catalog/items` and `GET /stock` return at most 500 rows per page (D-041). The body stays a JSON array. The next page is in the `Link` header. A bad key returns 422 `page.after`.
- Web: `savia/web/api.mjs` loads every page, so the offline till still holds the full catalog.

## P2: why KPI business still misses 1 s

- The procedure must read every stock row (250,000), every item (250,000) and every movement of the branch (253,000) once.
- It also sorts 250,000 items for the slow-sellers list.
- These scans cost about 1.1 to 1.6 s of SQL time on this machine. The fixed cost does not depend on the period.
- A trial index on `inventory.StockMovements(LocationId, ItemId, CreatedAt)` saved about 9,000 of 66,000 reads. It also adds cost to every sale. It is not in V040.
- A second restructure (one pass over movements, items joined later) was not faster and used more CPU. It was reverted.
- To reach 1 s needs a different design: a stored daily summary per item, or a cached report. Both are larger changes and need a decision.
- The T-SQL test `db/tests/sales/250_kpi_business_equals_v030.sql` proves the new results equal the V030 procedure. A separate check on load_a compared 16 period and date pairs: all equal.

## P1: why a commit can take more than 3 s

- The commit still registers each row through `usp_RegisterProduct`, `usp_RegisterItem` and `usp_ApplyMovement`. Each call writes its sync event.
- A fully set-based commit must rebuild those sync events. Sync code is outside this task, so this was not changed.
- In the probe `usp_RegisterItem` took 1.4 ms per row and a warm commit took about 2.2 s.
- During the recorded runs, other agents' containers used 74-143% CPU (rehearsal) and 118-237% CPU (dev). Per-row time rose to 4.5-7.3 ms.
- That contention is a likely cause of the slower commits, but this is an inference: no controlled quiet benchmark was run.
- The first identifiers trigger updated the search table through the view: 7.7 ms per row. It now deletes and inserts, as the items trigger does.

## Method

1. Restore `SAVIA_SIM_load_a` from the A-10 backup into the container `savia-sqlserver-load`.
2. For "after", apply V039-V042 with the migrator.
3. Run `python tools/load/sql_stats.py --label <before|after> --out docs/evidence/performance-20261122/sql-stats-<label>.json` for the SQL table.
4. Start the API (Release build) and run `python tools/load/api_bench.py --label <before|after> --out docs/evidence/performance-20261122/api.json`.
5. After the stock paging fix (`OPTION(RECOMPILE)`), the database was restored and migrated again. Only the `lists` and `writes` sections ran again; the `search` and `kpi` sections of "after" are from the first run.

## Limits

- Local Docker on one PC, one client. These are not Azure SQL Basic numbers.
- Other workers used the same PC during the "after" runs. Their load and the code change are not separated in the write and import numbers.
- Before and after were measured hours apart. CPU contention differed between them.
- The offline till is proven to page through the catalog by the web contract tests. A real till on a real device was not run.
- Search no longer folds ligatures (`æ`, `ß`); `Latin1_General_100_CI_AI` folded them. Spanish accents and `ñ` are folded.

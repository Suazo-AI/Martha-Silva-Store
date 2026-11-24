# A-10 load test: 50,000 products and 250,000 variants

Status: measured on 2026-11-22 between 02:42 and 05:15 UTC (2026-11-21 local time), source Tony@155ca23b, local Docker only.
Targets were fixed before any measurement (2026-11-22, about 03:00 UTC); they are unchanged below.

## Result first

- Store-floor operations pass at full scale: scan lookup p95 32 ms, receipt p95 9 ms, checkout p95 195 ms, day report p95 28 ms, 100 scans p95 20 ms.
- Four things fail and block a 50k-product store:
  1. Catalog import of 1,000 rows takes 28 s of SQL CPU per call; 2 of 3 commits hit the 30 s command timeout (`503 db.busy`).
  2. Business KPIs take 5 to 8 s per call (8.27 M logical reads, 14 to 17 s CPU); one call took 30 s.
  3. Text search p95 is 3.9 s; a search with no early match reads 1.52 M pages.
  4. `GET /catalog/items` never finished in 120 s; it builds one 72 MB JSON document.
- Sync does not fit one batch: the initial push of store A is 221,973,498 bytes, 7.4 times the 30,000,000-byte request limit.
- A rebuild of store A from the hub did not finish in 900 s (T9 FAIL); the incremental round after 500 sales was 1.36 MB and 11.9 s (T10 FAIL, small margin).
- On 1 CPU and 2 GB, lookup stays at p95 25 ms (T12 PASS); KPI business grows to 18 to 28 s, close to the 30 s timeout.
- One batch exceeds 30 MB at about 68,000 rows (438 bytes per row). The 300 s timeout is not the first limit on this hardware.
- The import cause is proven: one `COLLATE` clause. The probe fix cuts a 1,000-row preview from 28,093 ms to 949 ms CPU.

## Pass or fail per target

| T1 | T2 | T3 | T4 | T5 | T6 | T7 | T8 | T9 | T10 | T11 | T12 | T13 |
|----|----|----|----|----|----|----|----|----|-----|-----|-----|-----|
| PASS | FAIL | PASS | PASS | PASS | FAIL (business), PASS (team) | FAIL | PASS | FAIL | FAIL | PASS | PASS | 7 queries flagged |

## Targets (declared before measuring)

All latency targets are for one client on loopback, against a local SQL Server 2022 container.
They are not Azure numbers.

| ID | Operation | Target |
|----|-----------|--------|
| T1 | Lookup by code (`GET /catalog/lookup`) | p95 < 300 ms |
| T2 | Text search (`GET /catalog/search`) | p95 < 500 ms |
| T3 | Checkout (`POST /sales`, 1 to 3 lines) | p95 < 800 ms |
| T4 | Receipt lookup (`GET /sales/{id}`) | p95 < 300 ms |
| T5 | Day report (`GET /reports/day`) | p95 < 1,000 ms |
| T6 | KPIs (`GET /reports/kpi/business`, `/team`) | p95 < 2,000 ms |
| T7 | Catalog import of 1,000 rows (preview + import) | each call < 10 s; hard limit 30 s (`SqlGateway` CommandTimeout) |
| T8 | Receiving: 100 scans of one code | p95 < 300 ms; median of last 10 <= 2x median of first 10 |
| T9 | Sync rebuild of one store from the hub | one batch < 30,000,000 bytes and < 300 s |
| T10 | Sync incremental round after 500 sales | < 1 MB and < 10 s per pull |
| T11 | Hub database size after full load | < 2 GB (Azure SQL Basic cap) |
| T12 | Constrained container (`--cpus=1 --memory=2g`) | T1 p95 < 500 ms |
| T13 | DTU risk flag | a store request with > 1,000 logical reads or > 50 ms CPU is flagged |

## Setup

- Container `savia-sqlserver-load`: same pinned image digest as `savia/infra/docker-compose.dev.yml`, port 127.0.0.1:14342, own volume `savia_load_data`.
  It was removed after the run.
- SQL Server `max server memory` 3,072 MB for the unconstrained runs.
- Host: Windows 11, Docker Desktop (WSL 2), one machine shared with other agents' work; numbers are indicative, not a benchmark.
- API: `Savia.Api.dll` (Debug build, .NET 10.0.402) as branch A (`Savia__Node__Kind=Branch`, `Savia__Pilot__LocalCatalog=true`) on 127.0.0.1:5191.
  One client, keep-alive, loopback. Passwords for the three fixture logins were random per run and never printed.
- Data: synthetic only, deterministic seed `a10-20261121`.

### Dataset (`generate.py`, 320 s)

| Item | Count |
|------|-------|
| Products | 50,000 (+1 fixture) |
| Variants (`catalog.Items`) | 250,000 (+3 fixture), 5 per product, S/M/L x NEG/BLA/ROJ |
| Barcodes | 250,000 (+4 fixture) |
| Stock balances A / B / C | 250,000 / 149,822 / 99,845 (coverage 100 / 60 / 40 %) |
| Units on hand A / B / C | 875,782 / 524,577 / 349,472 |
| Goods receipts A / B / C | 500 / 300 / 200 (500 lines each) |
| Sales per store | 2,215 over 60 days through `sales.usp_PostSale`, 0 failed; Mon-Thu 30, Fri 45, Sat 55, Sun 40 tickets per day |
| Tills | 120 per store (2 per day; count from `sync.json`), each counted and closed |
| Conservation oracle | clean on A, B and C after generation |
| Store DB size (data) | A 776 MB, B 584 MB, C 456 MB, hub 264 MB before sync |

Full output: [generate.txt](generate.txt).

## Commands

```bash
cd savia
export SAVIA_SQL_CONTAINER=savia-sqlserver-load SAVIA_DOTNET=C:/Users/Jason/.dotnet-sdk-10.0.402/dotnet.exe
python tools/load/generate.py                                   # 320 s; dataset above
python tools/load/api_bench.py --label unconstrained            # reads; crashed at /catalog/items (see limits)
python tools/load/api_bench.py --label unconstrained --sections lists,writes
# restore SAVIA_SIM_load_a from presync_a.bak, then on a fresh API:
python tools/load/api_bench.py --label unconstrained_writes_clean --sections writes
python tools/load/import_fix_probe.py                           # on SAVIA_SIM_load_b
python tools/load/sql_stats.py --label unconstrained            # SET STATISTICS IO/TIME/XML
python tools/load/sync_measure.py --cap 900
# constrained: max server memory 1400 MB, docker update --cpus=1 --memory=2g --memory-swap=2g, restart
python tools/load/sql_stats.py --label constrained
python tools/load/api_bench.py --label constrained --n 30 --reads-only --sections lookup,search,receipt,reports,kpi
```

## API results (unconstrained)

Latency is client wall time in ms; the first 3 calls of each series are warm-up and not counted.
Read latencies are in [api-unconstrained-reads.txt](api-unconstrained-reads.txt) and constrained ones in [api-constrained.txt](api-constrained.txt) (the first run crashed before writing `api.json`).
Write latencies are from the clean rerun (`unconstrained_writes_clean` in [api.json](api.json)).

| Operation | n | p50 | p95 | max | Target | Result |
|-----------|---|-----|-----|-----|--------|--------|
| Lookup by code | 200 | 10.4 | 32.4 | 48.2 | T1 p95 < 300 | PASS |
| Search, mixed terms | 200 | 2,175.7 | 3,863.3 | 5,715.5 | T2 p95 < 500 | FAIL |
| Search "M4" (many early matches) | 10 | 387.8 | 619.9 | 619.9 | T2 | FAIL (p95) |
| Search "Blusa" | 10 | 461.6 | 623.4 | 623.4 | T2 | FAIL (p95) |
| Search "M12345" (one product) | 10 | 2,532.6 | 2,768.8 | 2,768.8 | T2 | FAIL |
| Search "zzqx" (no match) | 10 | 2,613.0 | 2,962.8 | 2,962.8 | T2 | FAIL |
| Receipt lookup | 200 | 5.8 | 9.0 | 21.4 | T4 p95 < 300 | PASS |
| Sales history page (25) | 50 | 15.2 | 23.3 | 32.6 | none | info |
| Day report | 60 | 21.7 | 27.9 | 30.0 | T5 p95 < 1,000 | PASS |
| KPI business, day | 20 | 7,495.1 | 29,988.2 | 29,988.2 | T6 p95 < 2,000 | FAIL |
| KPI business, week | 20 | 5,322.7 | 6,311.4 | 6,311.4 | T6 | FAIL |
| KPI business, month | 20 | 6,701.8 | 8,103.6 | 8,103.6 | T6 | FAIL |
| KPI team, day / week / month | 20 each | 20.5 / 34.3 / 22.0 | 34.6 / 114.2 / 41.2 | 114.2 | T6 | PASS |
| Checkout (`POST /sales`, 1-3 lines) | 200 | 64.8 | 194.6 | 276.1 | T3 p95 < 800 | PASS |
| Receiving, 100 scans of one code | 100 | 12.4 | 19.8 | 334.2 | T8 p95 < 300 | PASS |
| Receiving drift: median first 10 / last 10 | | 13.4 | 14.6 | | T8 <= 2x | PASS |
| Import 1,000 rows, preview | 3 | 26,520 / 28,334 / 28,863 | | | T7 < 10 s | FAIL |
| Import 1,000 rows, commit | 3 | 30,401 (503) / 30,411 (503) / 28,214 (200) | | | T7 < 30 s | FAIL (2 of 3 timed out) |
| `GET /catalog/items` (unpaged) | 3 | timeout | | > 120,000 | none | FAIL: no response in 120 s |
| `GET /stock` (unpaged) | 2 | 10,191 | | 10,191 | none | info: 51,000,001 bytes |

The KPI business 30 s value is one sample of 20 (p95 equals max at n=20).
The same day's SQL cost is 3.5 s elapsed; the typical API cost is the p50 of 5.3 to 7.5 s.

## SQL cost per query (SET STATISTICS IO/TIME, warm cache)

From [sql-stats-unconstrained.json](sql-stats-unconstrained.json), on `SAVIA_SIM_load_a`.
CPU can exceed elapsed because the plan runs in parallel.

| Query | Logical reads | CPU ms | Elapsed ms | T13 flag |
|-------|---------------|--------|------------|----------|
| `catalog.usp_LookupByScan` | 22 | 1 | 1 | no |
| Search "Blusa" (inline SQL) | 135,354 | 1,125 | 338 | yes |
| Search "M12345" | 1,520,887 | 4,866 | 2,160 | yes |
| Search no match | 1,520,797 | 4,890 | 1,964 | yes |
| `sales.usp_GetSaleDetail` | 62 | 0 | 1 | no |
| `sales.usp_GetDayReport` | 681 | 6 | 9 | no |
| `sales.usp_GetReturnsByKind` | 0 | 0 | 0 | no |
| `sales.usp_SearchSales` page 1 | 12,861 | 10 | 12 | yes (reads) |
| `sales.usp_KpiBusiness` day | 8,272,477 | 14,203 | 3,532 | yes |
| `sales.usp_KpiBusiness` month | 8,273,717 | 16,633 | 3,750 | yes |
| `sales.usp_KpiBusiness` year | 8,273,803 | 17,025 | 3,760 | yes |
| `sales.usp_KpiTeam` month | 5,100 | 10 | 12 | yes (reads) |
| `catalog.usp_ListSaleCatalog` | 3,474,259 | 7,000 | 11,341 | yes |
| `/stock` query (`vw_StockAvailable`) | 12,322 | 1,105 | 1,517 | yes |
| `sales.usp_PostSale` (DMV average, 203 calls) | 318 | 14.6 | 40.2 | no |
| `receiving.usp_RecordScan` (DMV average, 100 calls) | 53 | 2.0 | 3.7 | no |
| `catalog.usp_ImportCatalog` 1,000 rows (DMV average, 6 calls) | 2,973,420 | 28,245 | 28,544 | yes |

## Sync results (full scale)

From [sync.json](sync.json); `tools/load/sync_measure.py --cap 900`.
Each pull runs the same chain as the P9 transport, server-side: `sync.usp_SourceStateJson` and `sync.usp_ReadBatch` on the source, `sync.usp_PlanJson` and `sync.usp_ApplyBatch` on the target (V032 to V034).
Bytes are the UTF-8 length of the batch JSON. Each pull is one batch, because the procedures have no paging.
Order: push C, B and A to the hub; pull hub to A; post 500 sales at A; incremental round; then restore A and rebuild it from the hub.

| Step | Rows | Bytes | Read s | Apply s | Wall s | T9 / T10 | Result |
|------|------|-------|--------|---------|--------|----------|--------|
| C to hub (initial) | 212,423 | 93,087,006 | 43.9 | 53.4 | 102.0 | 30 MB / 300 s | FAIL bytes (3.1x) |
| B to hub (initial) | 312,295 | 135,920,438 | 13.5 | 101.1 | 121.5 | 30 MB / 300 s | FAIL bytes (4.5x) |
| A to hub (initial) | 512,814 | 221,973,498 | 196.3 | 215.4 | 499.9 | 30 MB / 300 s | FAIL bytes (7.4x) and time |
| Hub to A (first pull: B and C data) | 524,718 | 229,006,079 | 114.3 | 251.1 | 396.0 | 30 MB / 300 s | FAIL bytes (7.6x) and time |
| A to hub after 500 sales | 2,504 | 1,356,956 | 6.3 | 5.1 | 11.9 | T10 < 1 MB, < 10 s | FAIL (1.36 MB, 11.9 s) |
| Hub to A, nothing new | 0 | 1,384 | 5.5 | 0.2 | 6.2 | T10 | PASS (but 5.5 s to read nothing) |
| Hub to A rebuild (`@Mode='rebuild'`) | not finished | not finished | | | > 901.8 | T9 | FAIL: killed at the 900 s cap |

- T9 FAIL: the rebuild did not finish in 900 s on this machine.
  Inference from the two halves measured above: a rebuild of A carries about 1,037,000 rows and about 451,000,000 bytes (A's own 221,973,498 plus the 229,006,079 from B and C), 15 times the limit.
- T10 FAIL, small margin: 500 sales produce 2,504 rows (sale, line, tender, balance and movement for each) and 1.36 MB.
  The 6.3 s read for 2,504 rows, and 5.5 s to read zero rows, come from the per-row owner filters in `usp_ReadBatch` over the full tables.
- T11 PASS: hub used data after all three initial pushes is 813 MB (file 840 MB), under the 2 GB Basic cap.
  Stock movements (574 bytes per row in JSON) and balances (285 bytes) are 95 % of the bytes; sales tables are small.
- Oracle after sync: B and C clean; A 240 and hub 360 rows of `cash.till_status_vs_closure` only (the replicated-till finding in hot spot 7). No stock or money mismatch.

## Constrained run (`--cpus=1 --memory=2g`)

This run does NOT emulate Azure SQL Basic 5 DTU.
It only shows how cost scales when SQL Server has 1 CPU and 2 GB (memory swap 2 GB, `max server memory` 1,400 MB).
Setup: `docker update --cpus=1 --memory=2g --memory-swap=2g savia-sqlserver-load`, then restart (cold cache).
The database is the post-sync state of store A (it now also holds B and C data), so reads differ slightly from the unconstrained run.
SQL numbers are from [sql-stats-constrained.txt](sql-stats-constrained.txt) (printed lines; the run stopped before its JSON was written, see below).

| Query | Reads, unconstrained | Reads, constrained | Warm elapsed ms, unconstrained | Warm elapsed ms, constrained |
|-------|----------------------|--------------------|-------------------------------|-----------------------------|
| `usp_LookupByScan` | 22 | 22 | 1 | 1 |
| Search "Blusa" | 135,354 | 108,329 | 338 | 2,273 |
| Search "M12345" | 1,520,887 | 1,511,534 | 2,160 | 7,867 |
| Search no match | 1,520,797 | 1,511,444 | 1,964 | 6,871 |
| `usp_GetSaleDetail` | 62 | 41 | 1 | 0 |
| `usp_GetDayReport` | 681 | 2,363 | 9 | 13 |
| `usp_SearchSales` page 1 | 12,861 | 17,854 | 12 | 15 |
| `usp_KpiBusiness` day | 8,272,477 | 7,527,415 | 3,532 | 27,890 |
| `usp_KpiBusiness` month | 8,273,717 | 7,529,919 | 3,750 | 22,266 |

- Parallel queries lose most: KPI business goes from 3.5 s to 22 to 28 s on one CPU, close to the 30 s command timeout.
  Search goes from 2 s to 7 to 8 s. Seek-based queries do not change.
- T12 PASS: API lookup by code with the constrained container: n=30, p50 16.1 ms, p95 24.6 ms, max 26.1 ms, 0 errors (target p95 < 500 ms).
- Not measured: the remaining constrained queries (`usp_KpiTeam` onward) and the constrained API series after lookup.
  The `usp_KpiTeam` call ended with a client `TimeoutExpired` reported as "after -1490 seconds": the host clock jumped (the Windows host was likely suspended for about 35 minutes, 04:31 to 05:07 UTC; this is an inference from the negative timeout).
  It is not evidence that `usp_KpiTeam` is slow; unconstrained it reads 5,100 pages in 12 ms.
- Constrained API series (client ms, from the bench log; the bench was stopped at 05:15 UTC to stay inside the time box):

| Operation | n | p50 | p95 | max | Unconstrained p95 |
|-----------|---|-----|-----|-----|-------------------|
| Lookup by code | 30 | 16.1 | 24.6 | 26.1 | 32.4 |
| Search, mixed terms | 30 | 3,813.7 | 5,639.0 | 6,116.8 | 3,863.3 |
| Search "zzqx" (no match) | 2 | 6,620.5 | | 6,620.5 | 2,962.8 |
| Receipt lookup | 30 | 7.4 | 11.4 | 15.8 | 9.0 |
| Sales history page | 50 | 18.2 | 23.9 | 41.6 | 23.3 |
| Day report | 60 | 37.3 | 60.6 | 61.5 | 27.9 |
| KPI business, day | 3 | 17,714.6 | | 18,103.1 | 29,988.2 (p50 7,495.1) |
| KPI team, day | 3 | 14.8 | | 16.0 | 34.6 |

  The per-term search and KPI series have n=2 to 3; read them as single observations, not percentiles.
  The bench process and the API were stopped after `kpi_team[day]`; KPI week and month were not measured constrained.

## Hot spots and proposed fixes

Ranked by risk to a 50k-product store. No product code was changed; each fix is a proposal.

1. **Catalog import: SKU check cannot use its index (T7 FAIL, proven).**
   - Evidence: `usp_ImportCatalog` (V025) checks `EXISTS(SELECT 1 FROM catalog.Items i WHERE i.Sku=r.Sku COLLATE DATABASE_DEFAULT)`.
     `catalog.Items.Sku` is `Latin1_General_100_BIN2`; the database default is `SQL_Latin1_General_CP1_CI_AS`.
     The explicit collation stops a seek on `UQ_Items_Sku`, so every import row scans 250k items.
   - Proof: [import-fix-probe.json](import-fix-probe.json) copies the procedure with only `COLLATE Latin1_General_100_BIN2` and previews the same 1,000 rows.
     CPU 28,093 ms to 949 ms; reads 2,890,049 to 767,049; same preview (1,000 valid, 0 errors).
   - Fix: compare with the column collation (`COLLATE Latin1_General_100_BIN2`) in a new migration.
     The unique index is already BIN2, so duplicate detection keeps the same meaning as the constraint.
     The remaining 767k reads come from the per-row `(SELECT COUNT(*) FROM #r x WHERE x.Sku=r.Sku)`; replace it with one `GROUP BY Sku HAVING COUNT(*)>1`.
2. **Business KPIs: per-product correlated subqueries (T6 FAIL).**
   - Evidence: `usp_KpiBusiness` (V030) per-table reads for one month call: `StockMovements` 4,574,014, `Locations` 2,005,516, `SaleLines` 1,024,730, `Items` 632,731.
     The `sellThrough` block runs two correlated subqueries for each of the 50,001 products (all history, not the period).
     The `staleItems` block runs `MAX(CreatedAt)` over movements for each of the 250,000 stock rows.
   - Fix: aggregate once, set-based: received and sold by `ProductId` with one `GROUP BY` over movements and sale lines joined to the branch locations, then `TOP (50)`.
     Compute last movement per item with one `GROUP BY ItemId` before the `TOP (100)`.
     Index `inventory.StockMovements(LocationId, ItemId) INCLUDE (CreatedAt, OnHandDelta, Kind, SourceType)` if the plan still scans.
     If the owner screen tolerates it, cache sell-through and stale items once per day.
3. **Text search: leading-wildcard scan (T2 FAIL).**
   - Evidence: `CatalogStore.SearchAsync` uses `LIKE '%text%'` with `COLLATE Latin1_General_100_CI_AI` on four columns plus `EXISTS` on identifiers, ordered by `p.Name, i.Sku`.
     Plan: `PK_Items` scanned (251,003 rows) and `IX_Products_Name` scanned (51,001 rows); 1.52 M reads when no early match.
   - Fix: route by input shape first: digits only, or an SKU pattern, goes to `usp_LookupByScan` or a `LIKE 'prefix%'` seek on `UQ_Items_Sku` (BIN2 prefix seek).
     For words, keep one narrow search table (`ItemId`, normalized lower-case accent-free text) maintained by the catalog procedures and scan only that table (about 250k x 80 bytes, about 2,500 pages instead of 1.5 M reads).
     A full-text index is the alternative if Azure SQL Basic allows it for this database; it supports word prefixes, not inner substrings.
4. **`GET /catalog/items`: unpaged 72 MB response (no target; blocks any POS that loads it).**
   - Evidence: `usp_ListSaleCatalog` returns 72,097,334 bytes of JSON for 250k variants; SQL cost 3.47 M reads, 7 s CPU, 11.3 s elapsed.
     SQL waited on `ASYNC_NETWORK_IO` while the API took over 120 s (3 of 3 calls), so most of the time is in .NET string concat, parse and re-serialize.
     Plan: `PK_Sizes` scanned 753,006 rows (per-variant lookups).
   - Fix: do not ship the whole catalog to the POS; page it (`after` key + `limit`) or serve only changes since a version.
     Join sizes and colors once instead of per variant.
     Stream the JSON from SQL to the response without the `string.Concat` + deserialize round trip.
5. **`GET /stock`: unpaged 51 MB (info).**
   - Evidence: 10.2 s, 51,000,001 bytes; `PK_Items` and `IX_StockBalances_Location_Pool` scanned.
   - Fix: require `item` or paging; the screen never needs 250k rows.
6. **Sync: one batch per table set is 3 to 7 times the request limit.** See the paging answer below.
   - Evidence: `usp_ReadBatch` for store A: 196 s for 512,814 rows; owner filters are correlated subqueries per row.
   - Fix: page by row count (5,000) and resume from the last key; see below.
7. **Oracle finding, not a performance issue: `cash.till_status_vs_closure` fires on every replicated closed till after sync.**
   - Cause: `sales.CashTills` is in `sync.SyncTables`, but `sales.CashClosures` is not (ADR-001 marks it 'S').
   - Fix: add `sales.CashClosures` to `sync.SyncTables`, or make the oracle skip tills owned by other nodes.

## Paging threshold

- Average row size at full scale: 438 bytes (stock movements 574, sales 702, sale lines 584, balances 285).
- One batch passes 30,000,000 bytes at about 68,000 rows on average, or about 42,700 rows if a page is all sales headers (the widest rows).
- Time is not the first limit here: read plus apply ran at 0.3 to 0.8 ms per row locally, so 300 s binds at about 375,000 rows.
  Azure SQL Basic will be slower by an unknown factor; the byte limit is the safe number to design for.
- Proposal: page every batch at 5,000 rows per table and stop adding tables once the batch passes 20 MB (new `@MaxRows` on `usp_ReadBatch`, plus a per-table resume key in the plan; the next round continues from it).
  - Worst case 5,000 x 702 bytes = 3.5 MB per page, 12 % of the limit.
  - Local cost about 2 to 4 s per page; it stays under 300 s even if Azure is 50 times slower.
  - A store A rebuild becomes about 208 pages; the first push of A about 103 pages.
- Lists for screens: page `GET /catalog/items` and `GET /stock` at 500 rows; one 500-item page is about 145 KB of JSON (72,097,334 bytes / 250,000 x 500).

## DTU risk (estimate, not a measurement)

- The constrained Docker run does NOT emulate Azure SQL Basic 5 DTU. A DTU is a blended CPU, data IO and log IO quota; Docker caps only CPU and memory.
- Microsoft publishes no conversion from logical reads or CPU ms to DTU, so the risk below is a ranking by T13, not a latency forecast.
- Low risk (under 1,000 reads and 50 ms CPU): lookup (22 reads), receipt (62), day report (681), checkout (318 reads, 14.6 ms CPU), scan (53 reads).
- High risk: KPI business (8.27 M reads, 14 to 17 s CPU), import (2.97 M reads, 28 s CPU), catalog list (3.47 M reads), search (0.14 to 1.52 M reads), sync read and apply (minutes per batch).
- Inference: a call that needs 14 s of CPU on this machine will not finish inside the 30 s command timeout on a 5 DTU database. Treat T6, T7 and search as blockers for Azure Basic until fixed and remeasured there.

## Limits

- Local Docker on a shared Windows host; one client; no concurrency test (several cashiers at once were not measured).
- Debug build of the API; Release may be faster on the .NET side (it does not change the SQL costs).
- The constrained run is not an Azure measurement; Azure SQL Basic was not used (packet rule: no Azure).
- Sync was measured server-side (the same procedure chain the P9 transport runs) through cross-database `EXEC`, not over HTTP. The 30 MB comparison uses the UTF-8 length of the batch JSON; HTTP framing is not included.
- The search per-term series has n=10 and the KPI series n=20, so their p95 is close to the max.
- The first unconstrained bench run crashed at `/catalog/items` (client 120 s timeout); its read latencies are kept as printed lines, not JSON.
- The first writes run was contaminated by 3 abandoned `/catalog/items` requests and by synthetic barcodes with a wrong EAN-13 check digit (a bench input bug, fixed); its numbers are not used.
- Synthetic data: names, prices and the sales rhythm are invented; there are no returns, discounts or USD tills in the history.
- The Windows host was probably suspended for about 35 minutes during the constrained run (inference from a negative client timeout); constrained SQL stats from `usp_KpiTeam` onward were not measured.
- `api.json` has no `constrained` label: the bench was force-stopped; its printed lines are in [api-constrained.txt](api-constrained.txt).
- The rebuild size (about 1,037,000 rows, about 451 MB) is inferred from the two measured halves, not measured; the rebuild was not diagnosed (slow apply vs. blocking) before the 900 s kill.
- Plan XML is parsed with the standard-library `xml.etree.ElementTree`; the input comes only from the local SQL Server container.
- Watch item: after sync, store A's day report reads 2,363 pages instead of 681, because `PK_Sales` is scanned for all 7,145 sales (A plus replicated B and C); it grows with every replicated sale.

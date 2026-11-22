# Money and speed, 2026-11-22

Task `savia-money-and-speed-20261122`: checklist rows W4 (seam), P1 and P2 of `docs/production-20261122/README.md`.
Source: branch Tony at `fcf14a42`. Migrations V057, V058 and V059.

## Result

| Row | Status | Evidence |
|---|---|---|
| W4 seam: money taken is never invisible | Met | Red then green in SQL, .NET and web tests. |
| P2: business KPIs p95 under 1 s on A-10 | Met | HTTP p95 0.50, 0.53 and 0.67 s; equal to V040 by test. |
| P1: import of 1,000 rows under 3 s | Not proven | Same rows and events as V039 by test; HTTP 2.1 to 7.0 s on a saturated host. |

## W4: card captures go to review (V057)

`webstore.usp_RecordCapturedPayment` records every verified card capture.
A capture the order cannot take goes to `payment_review` with its real amount and currency in `webstore.PaymentReviews`.
Before, the capture failed with 51706 and the order stayed reserved: the money was on no screen.
Staff accept the money (order paid, stock reserved again) or mark it refunded with a bank reference (order cancelled).
The manual staff payment keeps its V050 behaviour.

| Check | Red (before code) | Green |
|---|---|---|
| `db/tests/webstore/170_card_capture_review.sql` | `red-170.txt`: Msg 2812, procedure missing | 18/18 webstore SQL tests |
| `db/tests/webstore/180_payment_review_resolution.sql` | `red-180.txt`: Msg 2812 | same run |
| .NET vertical slice, 12 tests | `red-dotnet.txt`: 5 failed of 6 run | `green-dotnet.txt`: 12/12 |
| `web/tests/web-orders.test.mjs` | `red-web.txt`: missing export | `green-web.txt`: 12/12 |

## P2: business KPIs in one pass (V058)

`sales.usp_KpiBusiness` reads sales, returns and stock once per call instead of once per product block.

| A-10, HTTP, n=20 | Before p50 / p95 (ms) | After p50 / p95 (ms) |
|---|---|---|
| day | 892 / 1,099 | 357 / 502 |
| week | 902 / 1,530 | 357 / 532 |
| month | 928 / 1,735 | 445 / 671 |

SQL elapsed per call fell from 1,032 ms to 405 ms (`bench-before.txt`, `bench-after.txt`).
On a date with no sales (2027-03-01), the costliest statements sum to about 435 ms (day) and 526 ms (month).

`db/tests/sales/250_kpi_business_equals_v030.sql` compares V058 with V040 for day, week and month, byte for byte.
It passes on V040 (`p2-250-on-v040.txt`) and on V058 (`p2-250-on-v058.txt`).
Two mutants of V058 fail it: no fallback date (`p2-mutant-no-fallback.txt`) and no SKU (`p2-mutant-no-sku.txt`).

Design deviation: the packet asked for a daily summary per item.
A-10 has 256,653 item-days for 256,655 stock movements, so a summary would read almost as many rows as the source.
It would also add a write to every movement path. The one-pass read meets the target without new writes.

## P1: set-based import commit (V059)

V039 called `usp_RegisterProduct`, `usp_RegisterItem` and `usp_ApplyMovement` once per product or row.
V059 writes products, items, barcodes, balances, movements and batch rows with one statement each.
Events keep the V039 order and payloads. `sync.usp_EnqueueEvent` is still called once per event, over one forward cursor.

`db/tests/catalog/155_import_commit_equals_v039.sql` imports one 65-row file through a copy of V039 and through V059.
It compares the rows, movements, balances, search rows and outbox events of both, with ids replaced by business keys.

| Check | Output |
|---|---|
| Red on V039 | `p1-155-red-on-v039.txt`: commit calls no per-row procedure, expected 0, actual 3 |
| Green on V059 | `p1-catalog-green-v059-cursor.txt`: 13/13 catalog tests |
| Mutant: item status rule | `p1-mutant-status.txt`: FAIL as intended |
| Mutant: event order | `p1-mutant-event-order.txt`, `p1-mutant-event-order-cursor.txt`: FAIL as intended |
| Mutant: balance actor | `p1-mutant-balance-actor.txt`: FAIL as intended |

Timing, 1,000 new products of one item each (the `api_bench` shape):

| Measure | V039 | V059 |
|---|---|---|
| HTTP import, 3 batches (ms) | 6,578 / 3,748 / 4,933 | 6,976 / 2,148 / 6,613 |
| SQL CPU per import, run in turn from sqlcmd (ms) | 2,241 / 2,763 | 2,023 / 2,013 |
| SQL CPU per call in `api_bench`, 3 previews + 3 imports (ms) | 2,019 | 1,619 |

During the V059 HTTP run, host CPU was 83 to 97 % on 8 logical CPUs, and the dev container used 54 to 144 %.
The V039 run had the dev container at about 2 %. Wall-clock times on this host are not comparable between runs.
The target is therefore not proven. CPU per import fell by about 10 to 25 %.
The remaining cost is per event: 2,001 single-row outbox inserts through `usp_EnqueueEvent`, about half of V059's CPU.
A set-based outbox write would remove most of it, but it would copy rules that the sync area owns.

`bench-after.txt` is the first V059 run (event lookup by number, 0.8 ms each). `bench-after-import2.txt` is the final V059.

## Found, not fixed

Import validation does not check `UQ_Items_Product_Variant`.
Two rows of one product with the same size and color pass preview and then fail the commit with `db.duplicate`.
This is V039 behaviour; V059 keeps it.

## Final checks

- `python tools/check.py --isolated`: RESULT PASS. T-SQL 171/171, .NET on real SQL 231/231, sync as API host 31/31, rules 9/9.
- `node --test "savia/web/tests/*.test.mjs" "savia/web/scanner/*.test.mjs"`: 169/169.

## Not run

- An HTTP import bench on a quiet host.
- QA in a browser of the review buttons (jsdom only).

# Cash-journey CI runtime: attempts, root causes, final PASS (2026-11-10)

Date: 2026-11-10. One authorized attempt per Jason, three total.

## Attempt 1 — smoke leg fails in new `cash-snapshot` helper (FAIL)

Run: https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42835672385
Dispatch: `golden-path.yml --ref Tony` with `supply_receipt=true stock_exception=true`.
Local SHA at dispatch: `ad088697fe73a55767060eef1f958193461bf47e` (local == origin/Tony, verified).

Result: job failed 1m27s, all steps to the end of `api_unpaid.unassigned` PASS
(smoke passed `sql.migrate_release`, `owner.*` seeds with on-hand 30, readiness, role refusals),
then the harness aborted inside the `smoke` mode step:

```
FAIL: camino dorado (smoke) en 14 s — herramienta SQL 'cash-snapshot' falló: JsonReaderException / see_private_logs
```

The browser phase never started: the failure is in the API-only first leg, before browser checkpoints.

## Root cause (source-level; the harness hides output in private logs)

`tests/golden-path/GoldenPath.Sql/Program.cs:299 CashSnapshot` reads `FOR JSON PATH` via a
`Json` local that concatenates `reader.GetString(0)`. SQL Server `FOR JSON PATH` emits **no
result row** for zero matching rows, so `JsonDocument.Parse("")` threw, wrapped as
`JsonReaderException`. At that smoke point zero rows are normal: nothing had
happened, `Operations Scope LIKE 'cash.%'` is empty and the first table read that way
(`CashCloses`/`CashEntries`/`CashTills`...) fails before sale receipts exist.

This code is part of the `real-cash-v1` protocol preparation (2026-11-08, runtime NOT RUN);
attempt 1 was its first real execution: the fix is `tests/golden-path/GoldenPath.Sql/Program.cs`
(`Json` returns the literal `[]` when the reader yields no rows), all three `JsonDocument.Parse`
call sites live inside that same helper. Build with the frozen SDK 10.0.402: 0 warnings, 0 errors.
Committed `e33c8e23e57afb2f127a240daf4caacb67f04280`.

## Attempt 2 — smoke passes; CI plumbing was missing `--cash` (FAIL)

Run: https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42871128120 (SHA `e33c8e2`).
The smoke leg now runs to completion further along the protocol; the **C6 browser step** refused to
start with a harness parse error:

```
golden_path.py: error: current frontend requires --cash; historical unpaid browser protocol is not executable acceptance
```

The workflow's browser step predates the cash-first rollout and never passed `--cash`.
Fix: `.github/workflows/golden-path.yml` browser step now seeds `receipt_args=(--cash)` before
adding the two dispatch inputs. Committed `85eb3e78108bd8d522459db8d76ffbd0398826a1`.

## Attempt 3 — full cash journey PASS (SUCCESS)

Run: https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42871771138 (2m55s, exit 0).

- All 31 ordered browser checkpoints PASS through the oracle table, including:
  `cash_open`, sale quantity 2 for USD 59.00 with USD 60.00 tender, `receipt_reload`,
  `stock_after_sale`, `response_loss_committed` (CDP-discarded committed HTTP 200 with the
  original pending key kept), `recover_after_reload` (real GET returns the exact original
  receipt; no replay POST), `repeated_reload`, `stock_after_recovery`, `logout`,
  six supply checkpoints (partial receipt, lost response, recovery, reload), five
  stock-exception checkpoints (sale, reload, dual-person review, review reload), and the
  eight cash tail checkpoints: `cash_second_till`, `cash_refund_refused`,
  `cash_refunded`, `cash_closed_short`, `cash_later_till`, `cash_later_refund`,
  `cash_later_close`, `cash_logout`.
- Oracle table is internally consistent: sales `0→1→2`, sale operations `0→1→2`,
  on-hand `30→27→25`, zero `Σmov≠saldo`, zero negative stock, zero duplicate keys,
  session counts consistent, and every step's SQL counts match the expected invariants.
- `verify_evidence.py` approved the sanitized evidence; two artifacts were published
  (`savia-golden-path-42871771138-1`, `savia-browser-path-42871771138-1`).

## Limits

- Only the JSON-empty case changes; snapshots with rows keep byte-identical output.
- The workflow change is plumbing only: no oracle, threshold, or evidence rule touched.
- The successful evidence is CI-published; local Windows still cannot run the Linux-only harness.
- Nothing here authorizes production, deployment, or merge to main; the browser run
  used synthetic identities only and composed a disposable owner console on the pinned SQL digest.
- Not verified in this scope: the separate owner recovery stage (Windows Integrated
  Security, trusted encrypted SQL, ACL/SID evidence); remains a separate Jason decision.


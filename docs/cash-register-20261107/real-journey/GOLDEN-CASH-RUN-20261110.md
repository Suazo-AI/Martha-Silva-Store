# First cash-journey CI runtime attempt: failure, root cause, fix

Date: 2026-11-10. One authorized attempt per Jason.

## Attempt 1 — `SAVIA golden path` on `Tony` merged dispatch inputs (FAIL)

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
`JsonReaderException`. At that smoke point zero rows are normal: the request nothing had
happened, `Operations Scope LIKE 'cash.%'` is empty and the first table read that way
(`CashCloses`/`CashEntries`/`CashTills`...) fails before sale receipts exist.

This code is part of the `real-cash-v1` protocol preparation (2026-11-08, runtime NOT RUN);
attempt 1 was its first real execution.

## Fix (one call site, no behavior change beyond zero-row reads)

`tests/golden-path/GoldenPath.Sql/Program.cs` — `Json` helper now returns the literal `[]`
when the reader yields no rows (`if (!await reader.ReadAsync()) return "[]";`). All three
`JsonDocument.Parse` call sites live inside that same helper; no other `FOR JSON` reader
exists in the project. Build with the frozen SDK 10.0.402: 0 warnings, 0 errors.

## Limits

- Only the JSON-empty case changes; snapshots with rows keep byte-identical output.
- Verifying offline: no local browser harness; Windows cannot run the Linux-only harness.
- The live verification of the fix is a second CI dispatch. Per policy it needs a separate Jason authorization.

# CP4 simulator run, 2026-11-20

## Result

The simulator now runs every scenario to its oracles.
`basic`, `cancel_vs_dispatch` and three random seeds pass R1 (identical replicas) and CONS (zero conservation violations on every node).
`restore_naive` fails as designed: it is the red control.
`restore` proves that spent credit does not come back, but it fails CONS on one open finding (below).

## Changes

| File | Change | Why |
| --- | --- | --- |
| `db/migrations/V031__oracle_replicated_sales.sql` | `sale.outbox_event` expects 1 event only for sales this node originated | ADR-001 D5: the outbox is local and never synced, so a replicated sale has no event on the receiver |
| `db/tests/audit/030_conservation_oracle_replicated_sale.sql` | New test: replicated sale is clean; own sale without its event is still a violation | Red before V031 (`expected=0 actual=1`), green after |
| `tools/db/simulator.py` | Skip computed columns in the row copy | MERGE failed on `ForeignChangeNioMinor` |
| `tools/db/simulator.py` | Setup converges once before the scenario | B requested A's credit before B had it (51722); the scenario aborted |
| `tools/db/simulator.py` | Print each business rejection | Rejections were silent, which hid the abort cause |

V031 keeps the old rule when `sync.LocalNode` is empty or a sale has no `OriginNodeId`.
The API passes its configured node as `OriginNodeId`; no app path sets `sync.LocalNode`, so the hub keeps the old rule.

## Runs

Run from the repository root with the `savia-sqlserver-dev` container.

| Command | Result | Output |
| --- | --- | --- |
| `python savia/tools/db/simulator.py scenario basic` | PASS, R1 59 rows | [sim-basic.txt](sim-basic.txt) |
| `... scenario cancel_vs_dispatch` | PASS; late dispatch wins, dispatch after a seen cancel is refused (51726) | [sim-cancel_vs_dispatch.txt](sim-cancel_vs_dispatch.txt) |
| `... scenario restore` | FAIL 1: `sale.outbox_event` on A; the 4 restore checks pass | [sim-restore.txt](sim-restore.txt) |
| `... scenario restore_naive` | FAIL as intended: `credit.conservation expected=120000 actual=170000` on the cloud, R1 differs, FK abort on A | [sim-restore_naive.txt](sim-restore_naive.txt) |
| `... random --seed 1 --steps 120` | PASS, R1 176 rows | [sim-random-1.txt](sim-random-1.txt) |
| `... random --seed 7 --steps 120` | PASS, R1 122 rows | [sim-random-7.txt](sim-random-7.txt) |
| `... random --seed 42 --steps 120` | PASS, R1 169 rows | [sim-random-42.txt](sim-random-42.txt) |

Other checks on the same tree:

- `python savia/tools/db/saviadb.py test`: 144 PASS.
- `python savia/tools/check.py`: T-SQL 144 PASS, .NET build and format PASS, .NET tests 184 of 185.
  The one failure, `Spec17_quick_verification_preserves_pilot`, came from V031 missing in `MANIFEST.sha256` (now accepted, rules 9 of 9).
  It still fails locally only because of another agent's uncommitted web files (`photo-decode*.mjs`, `etiqueta.mjs`), which this commit does not include.
- `python -m unittest savia/tests/usd_change_migration_recovery.py`: 2 OK.
- `python savia/tools/db/no_physical_delete.py`: 0 physical deletes on 18 synced tables.

## Open finding: recovered own sales lose their local event

After A is restored and rebuilt from the cloud, a sale that A posted after the backup comes back as a row, but its outbox event was lost with the restore.
The oracle still expects one event, because A originated the sale.
ADR-001 says the outbox feeds webhooks, notices and real time; nothing reads it yet.
Decision for P9 recovery design, not taken here:

1. Recovery re-creates the event, and consumers deduplicate on `(AggregateId, EventType)`. `usp_PostSale` uses `NEWID()` today.
2. Or recovery records the recovered rows locally, and the oracle expects 0 events for them.

The oracle stays strict until then. A blanket "0 or 1 events" rule would stop detecting a sale posted without its event.

## Acceptance status

- A-05 (no double spend of a transferred credit): passes in 3 random seeds and `cancel_vs_dispatch`; simulator only, not production transport.
- A-09 (an old backup does not revive spent rights): the credit checks pass; the run fails on the outbox finding above.
- A-04 (a retried sync repeats no effect): not proven. The random run does not replay or duplicate a sync batch.

## Not tested

- The production sync transport (P9 hub endpoints and the branch worker) does not exist; the simulator copies rows between local databases.
- Azure SQL as the cloud node in the simulator.
- Retries, duplicated batches and crashes mid-apply (A-04).

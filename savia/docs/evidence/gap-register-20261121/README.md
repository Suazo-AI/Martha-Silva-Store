# Evidence: gap register 2026-11-21

Base: `Tony@155ca23b`, worktree copy, no commit. Register: [GAPS-20261120.md](../../deploy/GAPS-20261120.md#gap-register-2026-11-21).
Database: local Docker `savia-sqlserver-dev` (SQL Server 2022 Developer, port 14340). Disposable clones only; all dropped.

## Baseline

| File | Command | Exit | Result |
| --- | --- | --- | --- |
| `restore.txt` | `dotnet restore Savia.slnx -v q` (SDK 10.0.402) | 0 | needed: the worktree had no `obj/` and `check.py` builds with `--no-restore` |
| `check.txt` | `python savia/tools/check.py` | 0 | `RESULT PASS`; T-SQL `PASS=149`; .NET 195 passed, 0 failed |
| `sim-replay.txt` | `python savia/tools/db/simulator.py scenario replay` | 0 | pass |
| `sim-basic.txt` | `... scenario basic` | 0 | pass |
| `sim-cancel_vs_dispatch.txt` | `... scenario cancel_vs_dispatch` | 0 | pass |
| `sim-restore.txt` | `... scenario restore` | 1 | fails only `sale.outbox_event ... expected=1 actual=0` on node a |
| `sim-restore_naive.txt` | `... scenario restore_naive` | 1 | hub refuses with `Msg 51854` (expected guard) |
| `sim-random-1.txt` | `... random --seed 1 --steps 120` | 0 | pass |
| `sim-random-7.txt` | `... random --seed 7 --steps 120` | 0 | pass |
| `sim-random-42.txt` | `... random --seed 42 --steps 120` | 0 | pass |

`sim-exits.txt` holds the exit codes as the runs wrote them.

## Probes

Each probe ran on disposable clones of the test template (`saviadb.clone`), named `SAVIA_T_gapreg_*`, dropped after the run.

| SQL | Output | Question | Answer |
| --- | --- | --- | --- |
| `probe-hub-api-role.sql` | `probe-hub-api-role.txt` | Can the role the migrator grants (`deploy/migrator/Program.cs:167-172`) run the hub sync procedures? | No. Apply: `Msg 229` INSERT denied on `CashTills`. Incremental read: `Msg 229` VIEW CHANGE TRACKING denied. Plan, state and initial read pass. dbo control applies 18 tables. |
| `probe-push-unsynced-parent.sql` | `probe-push-unsynced-parent.txt` | Does a sale to a customer created offline at a store apply on the hub? | No. `Msg 547 ... FK_Sales_Customer`; hub keeps 0 of 2 sales. Control with the customer row on the hub: 2 sales apply. |
| `probe-synced-fk-to-unsynced.sql` | `probe-synced-fk-to-unsynced.txt` | Which foreign keys point from synced tables to tables that do not sync? | 35 child-to-parent pairs, 9 parent tables. |

## Deviations

- `savia/tools/check.py:21` pins `C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe`, which does not exist. Only SDK 8.0.422 is on `PATH`. The run set `SAVIA_DOTNET=C:/Users/Jason/.dotnet-sdk-10.0.402/dotnet.exe`.
- Live hub readback: NOT RUN. No hub URL is recorded in the repository, and the API has no version endpoint (`Hosting.cs:71-72`).
- Read-only GitHub reads: `gh run list` for `savia-azure.yml` (14 runs, all `pull_request`).
- No Azure CLI, no authentication, no POST, no paid API.

# Sync completion, 2026-11-22

Task `savia-sync-completion-20261122`: rows S4, S5, S6 and S7 of `docs/production-20261122/README.md`, plus the open points of S1 and S3.
Source commit `fcf14a42`. Migrations V052 to V054 (V055 and V056 unused).

## Result

| Item | State | Evidence |
| --- | --- | --- |
| S1/S3 recovery lock: returns and transfers (D-036) | Built. DB-tested. | V052; `db/tests/sync/260_recovery_lock_returns_transfers.sql` |
| Credit status writer: issuer procedures (D-038) | Built. DB-tested. Simulator `credit_status` passed earlier in this task. | V052; `db/tests/credits/180_status_single_writer.sql`, `190_issuer_status_procedures.sql` |
| S4 reference data and customers (D-039, G1) | Built. DB-tested. Rehearsal written, not run. | V053; `db/tests/sync/270_reference_data_and_customers.sql`; scenario `reference_data` |
| S5 paging (D-041, G13) | Not built. | See "Not run". |
| S6 schema skew (D-041, G14) | Refusal kept (51856). Store status route and till banner compile; only the banner text function is tested. Rehearsal `schema_skew` written, never executed. | `GET /api/v1/sync/status`; `web/tests/sync-notice.test.mjs`; scenario `schema_skew` |
| S7 node provisioning (D-040, G3) | Built. DB- and unit-tested. Rehearsal written, not run. | V054; `Savia.Migrator --provision-node`; `docs/sync/PROVISIONING.md`; `db/tests/sync/280_provision_node.sql`; `tests/Savia.Tests/NodeProvisioningTests.cs` |

## Red first

| File | What failed before the change |
| --- | --- |
| `red-lock-credit-status.txt` | Returns and transfers ran under the recovery lock; issuer procedures missing. |
| `red-s4-reference-data.txt` | The reference tables were not in `sync.SyncTables`; a customer created at a store did not travel. |
| `red-s7-provision-node.txt` | `sync.usp_ProvisionNode` did not exist (Msg 2812). |
| `red-s6-sync-notice.txt` | The web test against the old `web/ui.mjs`: no `syncNotice` export. |

## Green

Run sequentially on the shared dev container, disposable databases only:

| Command | Result |
| --- | --- |
| `python tools/db/saviadb.py test sync` | PASS=15 (100 to 280) |
| `python tools/db/saviadb.py test credits` | PASS=19 |
| `python tools/db/saviadb.py test security` | PASS=2 |
| `python tools/db/saviadb.py test crm` | PASS=1 |
| `dotnet test` filter `NodeProvisioningTests` | 5 of 5 |
| `node --test savia/web/tests/*.test.mjs` (from the repo root) | 152 of 152 |
| `npx biome check web` | no findings |
| `python tests/test_rehearsal.py` | 15 OK |
| `python tools/db/simulator.py scenario <name> --seed 1` for basic, replay, restore, credit_status, cancel_vs_dispatch | each `RESULT PASS`: R1 and CONS on four nodes (V052 to V054 applied) |
| `python tools/rules.py --accept-migrations` | 9 of 9 rules; V052 to V054 added to `MANIFEST.sha256` |
| `npm ci`, then `python tools/check.py --isolated` | `RESULT PASS`, exit 0; DB tests PASS=172; .NET sync tests as the API host login 27 of 27; pilot stop and container proof skipped by `--isolated` |

## Not run

- Rehearsals `reference_data`, `schema_skew` and the `controls` credential phase (revoke 401, rotate 200, old secret 401): written, never executed. The same holds for the harness `migrate` helper.
  Blocker, seen twice: with the dev container and another worker's `savia-sqlserver-load2` up, starting `savia-sqlserver-rehearsal` stalls every `docker exec` on the host.
  The run stops at "setup: 4 databases".
  `docker exec savia-sqlserver-dev echo ok` timed out (exit 124) while the rehearsal container was up and returned `ok` right after `rehearsal.py down`.
  A 1536 MB SQL memory cap on the rehearsal container did not help, so it was not kept.
- `rehearsal.py run all`: same blocker.
- `SyncStatus`, the `SyncWorker` recording, `GET /api/v1/sync/status` and the `showSyncNotice` call in `web/app.mjs` compile and pass lint, but no test calls them.
- S5 paging: needs a fourth SQL container (`savia-sqlserver-load`, A-10 data), and the host cannot take a third one today.
  Changing `usp_ReadBatch`, `usp_ApplyBatch` and `usp_PlanJson` without that measurement would put the green sync tests at risk.
  Rebuild progress ("tables done of total") in the till waits for paging; without pages it has nothing to count.

## Decisions and limits

- Reference data: the hub owns it; a store owns the customers it creates. Duplicate documents are listed by `crm.vw_DuplicateCustomerDocuments`, never merged. `CustomerCode` stays NULL for synced customers.
- Not synced: staff, branches, locations, registers and nodes. Every database is provisioned with them.
- One hub node, and one node per branch (51865 `sync.node_mismatch`): the V053 owner expressions read the node with a scalar subquery.
- Credential rotation has no overlap: one credential row per node, so the store gets 401 until its secret is updated.
- `--provision-node create` refuses a node that already has an active credential; use `rotate`.
- The schema rule is still equality of the newest applied migration. The migrator applies files in order and refuses a changed one, so equal newest versions mean equal ledgers. N-1 is not built.
- `GET /api/v1/sync/status` is open to any signed-in staff member of the store. For `sync.unreachable` it returns the HTTP client's exception message.
- The store-side status lives in memory: after a restart the till shows nothing until the first round ends.
- No HTTP route creates a customer; the rehearsal uses `crm.usp_CreateCustomer` (`sql:no-http-route`).
- A catalog write made at a store is refused by the hub (51851), so the store keeps it alone.
- `catalog.Categories` references itself; one batch applies it whole. Paging must keep a parent before its child.

## Azure SQL Database rules

No procedure in V052 to V054 reads `sys.database_recovery_status`, queries another database, uses `msdb`, SQL Agent, `BACKUP`/`RESTORE`, server-scoped DMVs or `USE`.
One exception, as instructed: V052 lines 12 to 15 hold the guarded bootstrap of `sync.CurrentFork`, which reads `sys.database_recovery_status` only when this branch's V036 lacks the view. The primary removes it at merge.
The rehearsal harness still uses `BACKUP` and `RESTORE` locally, as tests may.

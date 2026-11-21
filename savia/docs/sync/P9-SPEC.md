# P9: sync transport for SAVIA v2

Task `savia-p9-sync-20261120-run2`, then the primary's review fixes (V034). Mode BUILD. Source `Tony@2ad4713`.
Revenue link: the hub runs in Azure, but no store can connect until this transport exists.
Reference algorithm: `savia/tools/db/simulator.py` (ADR-001 D5, critique F1, F5, F6, F8).

## Result in one paragraph

The branch is always the client; the hub never calls a branch.
Every sync rule lives in SQL procedures (V032), so the simulator and the .NET transport run the same code.
C# only authenticates the node, moves JSON and schedules the worker.
A batch carries full row state, never a delta, and the receiver's cursor decides what is new.
A duplicate, retried or late batch therefore changes nothing.

## Roles and flow

Two directions per sync round, as in the simulator's `sync_round`.

Push (the hub receives what the branch owns):

1. Branch: `sync.usp_SourceStateJson` reads its own fork, current version and minimum valid versions.
2. Branch to hub: `POST /sync/v1/push/plan` with that state. The hub runs `sync.usp_PlanJson` against its cursors for this branch.
3. Branch: `sync.usp_ReadBatch` with the plan, inside one `SNAPSHOT` transaction, filtered to rows the branch owns.
4. Branch to hub: `POST /sync/v1/push` with the batch. The hub runs `sync.usp_ApplyBatch`.

Pull (the branch receives what others own):

1. Branch to hub: `GET /sync/v1/state`. The hub returns its own source state.
2. Branch: `sync.usp_PlanJson` against its cursors for the hub.
3. Branch to hub: `POST /sync/v1/pull` with the plan. The hub runs `sync.usp_ReadBatch` for this branch: every row the branch does not own.
4. Branch: `sync.usp_ApplyBatch` locally.

## Endpoints (cloud node only)

| Method and path | Body | Answer |
| --- | --- | --- |
| `GET /sync/v1/state` | none | hub source state JSON |
| `POST /sync/v1/push/plan` | branch source state JSON | plan JSON for the branch's push |
| `POST /sync/v1/push` | batch JSON | `{changed, applied, skipped}` |
| `POST /sync/v1/pull` | `{plan, fork}`; `fork` is the branch's current fork, used by a rebuild | batch JSON for the branch |

A branch node does not map these routes (404, `node.wrong_kind` behaviour as other cloud-only routes).

## Payload format

Source state: `{"node": guid, "fork": guid, "version": bigint, "schema": "V0NN", "tables": [{"t": "[s].[n]", "min": bigint|null}]}`.

Plan: `{"peer": sender guid, "fork": guid, "version": bigint, "mode": "normal|rebuild", "tables": [{"t": "[s].[n]", "a": "initial|recover|reinit|incremental|rebuild", "f": bigint|null}]}`, one entry per synced table.

Batch: `{"node": guid, "fork": guid, "to": bigint, "schema": "V0NN", "mode": "normal|rebuild", "tables": [{"t", "a", "f", "rows": [...]}]}`.
Rows are the full current state of each row, every non-computed, non-rowversion column, as `FOR JSON ... INCLUDE_NULL_VALUES`.
Tables appear in the apply order of `sync.SyncTables` (parents first).

## Node authentication

Header: `Authorization: SaviaNode <nodeId>.<secret>`; the secret is 32 random bytes in base64url.
The hub stores only `SHA-256(secret)` in `sync.NodeCredentials`, one active credential per node.
The hub compares hashes in fixed time, requires an enabled branch node, and takes the peer identity from the credential only.
The body's `node` field must equal the authenticated node, or the call is refused.
The secret reaches the branch through configuration (`Savia:Sync:NodeSecret`, an environment variable or a secret store), never Git.

Tradeoff: SHA-256 is enough for a 256-bit random secret and costs nothing per call; PBKDF2 only helps low-entropy passwords.
Tradeoff: one credential per node allows revoking one store without touching the others; a shared secret would not.
Not chosen: mutual TLS. It is stronger, but Container Apps ingress and branch PCs make certificate rotation the larger risk for a pilot.

## Cursor handling

The receiver keeps `(fork, version)` per sender and table in `sync.PeerCursors` (V008, F1).
`sync.usp_PlanJson` classifies each table with the same rules as `sync.usp_ClassifyCursor`.
`sync.usp_ApplyBatch` applies every table in topological order and advances every cursor in one transaction (simulator behaviour; F8 paging is a limit below).

## Idempotency (A-04)

The receiver checks each table of a batch against its cursor before applying it:

| Cursor vs batch | Meaning | Action |
| --- | --- | --- |
| same fork, cursor version >= batch `to` | duplicate or late batch | skip the table, no error |
| same fork, incremental `f` > cursor version | gap: changes would be lost | refuse the batch (51852) |
| batch fork differs from the cursor fork and the batch is incremental | batch made against another fork | refuse (51852) |
| batch fork is retired (a pre-restore batch arriving late) | stale fork | refuse (51853) |
| hub: batch fork is new for this branch and no rebuild was served for it | restored branch skipped recovery | refuse (51854) |
| otherwise | new state | MERGE, then advance |

MERGE writes only when a column differs, so reapplying the same state counts 0 changes.
A per-peer application lock serialises two concurrent batches from the same sender.

## Ownership

`sync.SyncTables` holds the synced tables, their apply order and the SQL that names each row's owner node (ADR-001 ownership map).
A T-SQL test requires it to match `sys.change_tracking_tables` exactly.
The hub refuses a push batch when any row's owner is not the authenticated branch, or the owner cannot be resolved (51851).
A branch refuses a normal pull batch that carries a row it owns itself (51851); a rebuild batch may.
V034: both checks also run on the row already stored under each key, because MERGE matches on the key alone. The hub refuses a key whose stored row belongs to another node; a branch refuses a normal pull that would rewrite a stored row it owns (T-SQL `sync/240`).

## Recovery after restore

A restore changes the database's `recovery_fork_guid` (V008 evidence).
Each round starts with `POST /sync/v1/push/plan`; after a restore the hub classifies the branch's tables as `recover`.
The worker then pulls in `rebuild` mode before any normal pull: the hub sends every row, including the branch's own, and the hub's copy wins.
A normal pull first would leave out the branch's own rows, and rows of other branches that point to lost rows would fail on a foreign key every round (review 2026-11-20).
The 51854 refusal on push stays as a second trigger.
Only then the worker pushes the full state of its own rows.
The hub refuses any push from a new fork of a branch until that fork applied a rebuild the hub served (51854).
Proof of the apply (V033): each served rebuild carries a fresh token (`sync.PeerRebuilds.Token`, field `rebuild`).
The branch records the token in `sync.AppliedRebuilds` in the same transaction that applies the rebuild, and every later push from that fork carries it.
A push from a new fork without the token of the latest served rebuild is refused, so a lost rebuild answer does not open the hub (V032 accepted it once the rebuild was only served).
The hub closes the `restore_naive` path for a node that skips the rebuild. Limit: the token proves the node received the rebuild, not that it applied it; a node that received it and skipped the apply can still present it.
Serving the rebuild also retires every other fork the hub knew for that branch (`sync.RetiredForks`), so a batch read before the restore and delivered later is refused (51853), even between the rebuild and the recovery push.
An incremental batch whose fork differs from the cursor, or that starts after the cursor, is a gap (51852).

## Failure modes

| Failure | Effect | Why it is safe |
| --- | --- | --- |
| Network drops before the hub commits | nothing applied | the worker repeats the round from a fresh plan |
| Hub commits, answer lost | the worker repeats | the cursor already moved; the next plan sends nothing old |
| Same batch delivered twice | second is skipped | cursor >= `to` |
| Old batch delivered after a newer one | skipped | cursor >= `to` |
| Crash in the middle of apply | the transaction rolls back | cursors advance in the same transaction |
| Sender restored from backup | refused until rebuild | fork check |
| Change Tracking cleaned up past the cursor | `reinit`: full state of owned rows | `usp_ClassifyCursor` |
| Wrong or missing credential | 401 | no SQL write runs |

## Open questions for Jason

1. Outbox events for recovered own sales (cp4 finding). Recommendation: recovery records the recovered sale ids locally, and the oracle expects no local event for them; consumers never receive a second event. The oracle stays strict until then.
2. Recovering node may not redeem credits, dispatch transfers or sell (ADR-001 D5). Recommendation: a `sync` recovery flag set when the fork changes and cleared by the rebuild, checked inside the sale, till, credit and transfer procedures. Not built in P9 run 2. Evidence that it matters: a sale before the rebuild opens a second till and the rebuild then fails on `UX_OpenTill_Register` (later rounds not tested) ([evidence](evidence/dotnet-sync-restore-sell-before-rebuild-red.txt)).
3. Paging (F8). Recommendation: page by key when a table sends more than 5,000 rows, cursor still advanced once at the end. P9 sends one batch per round.
4. Credential issue path. Recommendation: the hub owner runs a one-time provisioning command that writes the secret to a file for the store PC; Jason approves who holds it.
5. Schema skew (F12). Recommendation: accept a batch only when both nodes report the same latest migration until an N-1 rule is proven by test.
6. Credit status has two writers (review 2026-11-20, critique F2). `credits.Credits` belongs to the issuing branch, but `usp_RedeemCredit` (V009) sets `Status='exhausted'` at the redeeming branch, which differs after a transfer. That change never travels and the issuer's copy overwrites it. Recommendation: derive the status from the allocations, or record exhaustion as an immutable row owned by the redeeming branch. Not fixed; no simulator seed covers a full redemption after a transfer yet.
7. Same-fork version regression. `usp_PlanJson` plans `recover` when the sender's version is below the cursor on the same fork, and `usp_ApplyBatch` skips that batch as late. Whether Change Tracking can go back without a fork change (copy or re-attach) is not proven. The worker then rebuilds every round, which makes the case visible but does not resolve it. Not fixed.

## Acceptance

| Check | Test | State |
| --- | --- | --- |
| Duplicate batch repeats no effect | simulator `replay`; T-SQL `sync/210`; .NET `SyncTransportTests.Duplicate_push_changes_nothing` | PASS |
| Late (out-of-order) batch does not regress rows | simulator `replay`; T-SQL `sync/210`; .NET `SyncWorkerTests.Late_batch_from_an_earlier_round_changes_nothing` | PASS |
| Crash before commit then retry | simulator `replay`; .NET `SyncWorkerTests.Dropped_push_is_delivered_by_the_next_round` | PASS |
| Hub commits, answer lost, retry | simulator `replay`; .NET `SyncWorkerTests.Retry_after_a_lost_answer_repeats_no_effect` | PASS |
| Pre-restore batch arriving after recovery is refused | simulator `replay`; T-SQL `sync/230`; .NET restore test | PASS |
| Ownership violation refused | T-SQL `sync/220`; .NET `SyncTransportTests.Hub_refuses_rows_owned_by_another_node` | PASS |
| Unauthenticated node refused | .NET `SyncTransportTests.Hub_refuses_a_call_without_a_valid_node_credential` | PASS |
| Initial and incremental sync through HTTP | .NET `SyncWorkerTests.Initial_then_incremental_rounds_move_only_new_rows` | PASS |
| Lost rebuild answer keeps the hub closed to the restored fork | T-SQL `sync/230`; .NET `SyncWorkerTests.Lost_rebuild_answer_does_not_open_the_hub_to_the_restored_fork` | PASS (red on V032) |
| Restore then recover through HTTP | .NET `SyncWorkerTests.Restored_branch_rebuilds_from_the_hub_before_it_pushes` | PASS with the known outbox gap pinned; FAIL when a sale precedes the rebuild (open question 2) |
| Existing scenarios unchanged | simulator `replay`, `basic`, `cancel_vs_dispatch`, seeds 1/7/42 (120 steps) on V034; `restore` FAIL only on the known outbox finding; `restore_naive` refused with 51854 as designed | PASS on V034 ([evidence](evidence/)) |
| A key that exists keeps its owner (push and pull) | T-SQL `sync/240` | PASS on V034 (red on V033: 2601 instead of 51851) |
| Restored branch rebuilds before any normal pull | .NET `SyncWorkerTests.Restored_branch_rebuilds_before_any_normal_pull` | PASS (red before the worker fix) |

## Limits

- Tests run as `sa`; dynamic SQL and Change Tracking permissions under a restricted host role are unverified.
- One transaction per batch: no paging; sync procedure timeout 300 s; Kestrel request body limit 30 MB.
- Hub restore (F15) is not tested.

## Progress

- 2026-11-20 increment 1: this spec written. Baseline `python savia/tools/check.py` started before any edit.
- 2026-11-20 environment: Docker Desktop was stopped; started it, `savia-sqlserver-dev` came up. NuGet restore run once (`dotnet restore Savia.slnx`). The baseline `check.py` failed only on those two causes.
- 2026-11-20 increment 2: `simulator.py` split `pull()` into `read_batch` and `apply_batch`, added scenario `replay`.
  Command: `python savia/tools/db/simulator.py scenario replay`. Result: exit 1, RED on the pre-P9 code ([evidence](evidence/sim-replay-red.txt)).
  Green already: duplicate batch (0 changes), crash before COMMIT (nothing applied, retry applies), lost acknowledgement (next plan resends nothing).
  Red 1: a late batch older than the cursor raises 51808. No row moves back, but a worker would retry it forever.
  Red 2: a batch read before A's restore and delivered after A recovered is accepted. It revives a sale lost with the restore on the cloud, relays it to B and C, and breaks `stock.onhand_vs_movements` on cloud, B and C (expected 495, actual 496); R1 fails.
  Next: V032 makes a late batch a no-op and refuses a batch from a retired fork.
- 2026-11-20 increment 3: `db/migrations/V032__sync_transport.sql` holds the sync rules: `sync.SyncTables` (18 tables, apply order, owner SQL), `NodeCredentials`, `RetiredForks`, `PeerRebuilds`, `fn_TableShape`, `fn_PeerAllowed`, `usp_SourceStateJson`, `usp_PlanJson`, `usp_ReadBatch`, `usp_ApplyBatch` and three credential procedures. Errors 51850-51863.
  A hub rebuild for a target fork also retires the target's other forks, so an old in-flight batch cannot land between the rebuild and the recovery push.
  Command: `python savia/tools/db/saviadb.py test sync/2`. Result: 4 PASS (`200` table list, `210` duplicate/late/gap/transaction, `220` ownership/peer/pair/schema, `230` 51854 before rebuild and 51853 after).
  First run: 3 FAIL with Msg 3930 (a THROW inside the procedures left a doomed transaction open). Fix: TRY/CATCH with ROLLBACK in `usp_ReadBatch` and `usp_ApplyBatch`.
  `simulator.py` now calls the procedures; its own copy of the owner filters and MERGE was removed.
  Command: `python savia/tools/db/simulator.py scenario replay`. Result: exit 0, RESULT PASS, R1 57 rows, CONS 0 on all nodes, 94 s.
  Next: all scenarios rerun in the background into `evidence/`; then `rules.py --accept-migrations` after V032 is final; then the .NET hub endpoints.
- 2026-11-20 simulator background run (partial, still running): `replay`, `basic`, `cancel_vs_dispatch` exit 0. `restore` exit 1 only on the known outbox finding: `FAIL CONS conservation on a / sale.outbox_event ... expected=1 actual=0`; CONS 0 on cloud, b and c ([evidence](evidence/sim-restore.txt)).
- 2026-11-20 increment 4 code (built, not yet run): `Savia.Application/Sync.cs` (`ISyncStore`, `ISyncHub`, `NodeCredential`, `SyncHubService`, `BranchSync`), `Savia.Infrastructure/SyncStore.cs` (`SyncStore`, `HttpSyncHub`), `Savia.Api/SyncEndpoints.cs` (`SyncNodeFilter`, `/sync/v1/*` on the cloud only, `SyncWorker`), errors 51850-51863 in `Savia.Domain/Errors.cs`.
  Command: `dotnet build Savia.slnx`. Result: Build succeeded, 0 warnings.
  Tests written: `SyncTransportTests` (401 cases, duplicate push, foreign row and wrong peer), `SyncWorkerTests` (initial/incremental, lost answer, dropped push, late batch, restore then rebuild).
  Next: run them with `--filter "FullyQualifiedName~Sync"` after the simulator run ends.
- 2026-11-20 simulator background run finished: `replay`, `basic`, `cancel_vs_dispatch`, `random --seed 1|7|42 --steps 120` RESULT PASS. `restore` RESULT FAIL (1) only on the known outbox finding on a. `restore_naive` RESULT FAIL, refused by the hub with Msg 51854, as designed ([evidence](evidence/)).
- 2026-11-20 increment 4/5 .NET run 1: `dotnet test tests/Savia.Tests --no-restore --filter "FullyQualifiedName~Savia.Tests.Sync"`. Result: 7 passed, 1 failed.
  The failure is a real recovery gap: a sale made after the restore and before the first rebuild opens a second till; the rebuild then fails on `UX_OpenTill_Register` (2601). Whether every later round repeats it was not tested ([evidence](evidence/dotnet-sync-restore-sell-before-rebuild-red.txt)).
  It needs the recovery lock of open question 2 (no local sales until the rebuild ran). Not fixed in P9. The test now follows the documented order: rebuild, then sell.
  The restored branch also lacks the `sales.sale_posted` outbox event of the sale the rebuild brought back (same finding as simulator `restore`). The test pins that exact single violation; the oracle stays strict.
  Rerun of the restore test: 1 passed ([evidence](evidence/dotnet-sync-restore.txt)).
- 2026-11-20 increment 6 acceptance: `python savia/tools/rules.py --accept-migrations` (V032 added to MANIFEST.sha256; RULES PASS 9 of 9).
  Command: `python savia/tools/check.py`. Result: exit 0. Rules 9/9, T-SQL SUMMARY PASS=148, .NET build PASS, C# format PASS, .NET tests on real SQL 193 passed, 0 failed ([evidence](evidence/check-full.txt)).
  Not run: the `SyncWorker` hosted loop and its configuration gate (tests drive `BranchSync` directly); a .NET test that relays a row from the hub to a branch in normal mode (the simulator covers relay); restricted SQL role; hub restore.
  Next: Jason answers the open questions (recovery lock, outbox for recovered sales, credential issue path); the primary reviews and integrates.
- 2026-11-20 restore guard hole (found in review): V032 accepted a push from the restored fork once the hub had served a rebuild, even when the branch never applied it.
  Red first: `SyncWorkerTests.Lost_rebuild_answer_does_not_open_the_hub_to_the_restored_fork` failed on V032 ([evidence](evidence/dotnet-sync-lost-rebuild-red.txt)).
  Fix: `V033__sync_rebuild_token.sql` (rebuild token, `sync.AppliedRebuilds`); V032 stays as accepted. `sync/230` now also asserts that a push without the token, or with a wrong token, is refused with 51854.
  `SyncWorker` now logs and survives any exception in a round, not only refusals and network errors.
  Commands: `python savia/tools/db/saviadb.py test sync/2` (SUMMARY PASS=4); `dotnet test tests/Savia.Tests --filter "FullyQualifiedName~Savia.Tests.Sync"` (9 passed, 0 failed, [evidence](evidence/dotnet-sync-v033.txt)); `python savia/tools/rules.py --accept-migrations` (V033 added; RULES PASS 9 of 9).
- 2026-11-20 simulator rerun on V033: `replay` RESULT PASS; `restore` RESULT FAIL (1) on `CONS conservation on a`, the known outbox finding; `restore_naive` refused by the hub with Msg 51854, as designed ([evidence](evidence/sim-v033-replay.txt), [restore](evidence/sim-v033-restore.txt), [restore_naive](evidence/sim-v033-restore_naive.txt)).
  Not rerun on V033: `basic`, `cancel_vs_dispatch`, random seeds. V033 recreates `usp_ReadBatch` and `usp_ApplyBatch`, which every scenario calls, so their V032 PASS does not cover V033.
  Next: full `python savia/tools/check.py`.
  `restore` detail: the only violation is `sale.outbox_event ... expected=1 actual=0` on a; CONS 0 on cloud, b and c.
- 2026-11-20 increment 6 acceptance on V033: `python savia/tools/check.py`. Result: exit 0. Rules 9/9, T-SQL SUMMARY PASS=148, C# format PASS, .NET tests on real SQL 194 passed, 0 failed ([evidence](evidence/check-full-v033.txt)).
  Next: Jason answers the open questions (recovery lock, outbox for recovered sales, credential issue path); the primary reviews and integrates.
- 2026-11-20 primary review: Codex gpt-6-astra was no longer offered; Jason chose a fresh Claude reviewer. It reported 3 major and 4 minor findings ([P9-REPORT](P9-REPORT.yaml) lists the child's own limits).
  Fixed, red first: (1) a push could reuse another branch's key with its own owner value and MERGE moved the row; `sync/240` failed with 2601 on V033 ([evidence](evidence/sql-240-red-v033.txt)). (2) A restored branch pulled in normal mode before it learned it must rebuild, so a foreign key to a lost row could block every round; the new .NET test failed on the old worker ([evidence](evidence/dotnet-rebuild-first-red-v033.txt)).
  Also fixed: the rebuild retires old forks under the apply lock before its snapshot read; `CHANGE_TRACKING_CURRENT_VERSION()` is read first in the snapshot (not proven by a two-session test); a bad `HubUrl` logs and turns sync off, and a bad `IntervalSeconds` logs and uses 60 seconds, instead of stopping the branch host (not covered by a test). CI run on `4a207848`: rules 9/9, T-SQL SUMMARY PASS=149, .NET 195 passed.
  Not fixed: open questions 6 and 7.
  Commands: `python savia/tools/rules.py --accept-migrations` (V034 added; 9 of 9); `python savia/tools/db/saviadb.py test sync/2` (SUMMARY PASS=5); `dotnet test tests/Savia.Tests --filter "FullyQualifiedName~Savia.Tests.Sync"` (10 passed).
- 2026-11-20 acceptance on V034: `python savia/tools/check.py` exit 0: rules 9/9, T-SQL SUMMARY PASS=149, C# format PASS, .NET 195 passed, 0 failed ([evidence](evidence/check-full-v034.txt)).
  Simulator on V034: `replay`, `basic`, `cancel_vs_dispatch`, `random --seed 1|7|42 --steps 120` RESULT PASS; `restore` RESULT FAIL (1) only `sale.outbox_event ... expected=1 actual=0` on a; `restore_naive` refused with Msg 51854 as designed ([evidence](evidence/)).
  Next: Jason answers open questions 1, 2 and 4; then the recovery lock, the credential provisioning command and a deploy of the hub image with V032-V034, each with his approval.

# Minimum local proof: preparation, not authorization

Source: `9d01fb66caf9f5a94561b909bb34529a954126e0`.
Primary accepted the corrected cash proof preparation and exact-SHA no-SQL CI.
[Acceptance and limits](corrections/ACCEPTANCE.json).
SQL5 remains **D: REVIEW FIRST, DO NOT EXECUTE**. Production remains **NO-GO**.

## Outcome

Prove that a cashier can open a till, sell, recover a lost response, refund and close.
Prove that saved money records survive backup/restore and a real SQL restart.
Use the existing tests and golden-path harness. Do not build another runner.

## Minimum work, in dependency order

| Stage | Required proof | Current gap and next action |
| --- | --- | --- |
| 1. Qualify runtime | Frozen source, SDK 10.0.402, Python, Node 24, Chrome, Playwright 1.63.0, OpenSSL, Linux PTY and /proc | The cached SDK image does not establish browser prerequisites. Freeze an exact existing environment or dependency/image proposal before requesting execution. |
| 2. Finish SQL corrections | Four previously failed methods, plus the changed cash-read and N8 cases below | The old five-test plan is pinned to 550b104. Bind the revised selection to current source. Reuse unaffected historical 23 security and 39 business passes only after equivalence checks. |
| 3. Prove the real cash journey | Existing browser mode with cash, supply and stock-exception flags; 31 ordered checkpoints and independent SQL oracles | Source preparation is accepted. Actual browser/API/SQL execution is NOT RUN. |
| 4. Prove money recovery | Populate CashTills, CashEntries and CashCloses with linked sales/refunds. Compare immutable records after actual backup/restore and an owned-container restart | The current recovery fixture checks four legacy projections. Obtain a bounded source-only review, then extend an existing fixture or the existing harness. |
| 5. Owner recovery | Windows Integrated Security, trusted encrypted SQL, controlled console, ACL/SID and contention proof | Separate runtime. Windows Application Control blocked DLL loading with 0x800711C7. Use a supported policy resolution; Linux password-auth tests cannot replace Windows evidence. |

Stages 2 and 3 can use isolated databases after runtime qualification and explicit authority.
Stage 4 must use a proven populated fixture before its backup and restart assertions.
Owner recovery can be prepared independently. Its Windows prerequisites do not block the disposable cash trial.

## Proposed SQL selection: not dispatched

Use prefix `Martha.Store.Api.Tests.` for each method.

1. `InternalBranchScopeSqlTests.BS21_25_Operations_http_checks_persisted_scope_and_actor_before_returning_result`
2. `InternalBranchScopeSqlTests.BS28_Cashier_cannot_read_purchase_costs_through_any_supply_get`
3. `InternalReleaseScriptTests.Release_script_upgrades_empty_and_first_migration_databases_and_preserves_synthetic_rows`
4. `PrivatePilotReleaseTests.Real_migration_reapply_throwaway_down_up_and_actual_backup_restore`
5. `InternalCashSqlTests.Cash_reads_follow_persisted_money_and_preserve_history_without_configuration`
6. `InternalAcceptanceHttpSqlTests.N8_missing_wrong_or_stale_csrf_is_rejected_without_writes_and_a_valid_pair_still_works`

After the prepared source database exists and its ownership is verified, perform one real owned-container restart.
Then run `PrivatePilotReleaseTests.Frozen_fixture_survives_controlled_owned_container_stop_start`.
The last method currently verifies legacy data. Do not label it populated Cash recovery without extending its fixture and assertions.
This is a proposed minimum selection, not a fresh seven-case PASS or permission to run it.

## Reuse and recovery constraints

The existing `GoldenPath.Sql` `cash-snapshot` command reads persisted rows independently through ADO.NET.
It checks the exact 23-table inventory and records full-row hashes outside Sessions.
It can inform the recovery comparison; confirm its database-name guard and safe projections before reuse.
The golden-path harness currently drops its owned database during cleanup.
Do not disable cleanup or keep a database by accident to reuse it for recovery.
Prefer extending the existing recovery fixture if that avoids changing the accepted cash journey.
Require a positive populated-data restoration and a negative control that detects a missing or changed money row.
Record the actual backup, restore and stop/start outcomes. Test names do not prove those actions occurred.

## Runtime request must be concrete before Jason approves

- Pin the final source SHA, relevant source hashes and the qualified tool/image versions.
- Use fictitious data, generated test database names, loopback-only ports and nonce-owned resources.
- Pin the SQL image to the cached digest `sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718`.
- State exact container CPU/memory limits, total deadlines and stage stop conditions.
- Capture resource IDs at creation. Clean only owned IDs and confirm absence after failure or success.
- State any required image build, download or installation. None is authorized by this document.
- Preserve native SQL, Windows certificates, accounts, policy and services.
- Keep private credentials and raw diagnostics out of Git. Publish only sanitized outcomes.
- Use one attempt per approved stage. No automatic retry or dependent dispatch after a failed prerequisite.

The old SQL5 container/total limits were 25/35 minutes. They do not authorize the broader cash journey.
Do not request a rubber-stamp approval while the browser environment or populated recovery fixture is unqualified.

Owner: primary prepares and integrates; bounded Sol/high executes approved work; Astra/xhigh reviews material risks.
Completion: fresh real persisted-row evidence, verified cleanup and primary acceptance within the approved scope.
No merge, deployment, real payments or production acceptance is implied.

The source-only recovery review is accepted for [bounded implementation](../recovery-preparation/IMPLEMENTATION.md).
It extends the two existing recovery methods and preserves this seven-method runtime selection.
No runtime authority is added.

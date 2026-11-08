# Minimum SQL rerun: four corrections and one deferred restart

Status: **PREPARED ONLY. New runtime authorization pending.**
Jason selected **D: review the detailed plan first; do not execute yet**. See the [readable plan](review.html).
Host: SUAZO-PC. Test source: `550b10456c10a2857da930913b397bd1a96949d2`.
Later documentation-only commits may carry this plan only while all tested inputs remain identical to that source.
[Astra review](astra-judge.md) and [primary acceptance](PRIMARY-ACCEPTANCE.json) support this bounded scope.

## Target and limits

- One new nonce-owned disposable SQL Server 2022 Developer container, no native SQL or existing database.
- Cached image `sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718`; no pull/install.
- Unique name `savia-sql-correction-<nonce>`, ownership label and captured ID.
- Loopback `127.0.0.1:14339:1433` only; require the port to be free before creation.
- Two CPUs, 2 GiB RAM; no host mounts or volumes. Fictitious generated `SaviaInternalTest_*` databases only.
- Existing test EULA convention and encrypted test connections with trust limited to this owned server.
- No Windows/native SQL certificate, account, service, firewall or global trust change.
- Existing SDK `10.0.402` at `C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe`.
- One locked offline restore, one Release build, one execution per method. No source edits or automatic retries.
- Readiness at most 120 seconds; container lifetime at most 25 minutes; worker at most 35 minutes, including cleanup.
- On failed preparation or a failed method, preserve diagnostics, stop dependent execution and clean up the captured resource.

## Exact execution

Run the four fully qualified methods once with one OR filter. Each prefix is `Martha.Store.Api.Tests.`:

1. `InternalBranchScopeSqlTests.BS21_25_Operations_http_checks_persisted_scope_and_actor_before_returning_result`
2. `InternalBranchScopeSqlTests.BS28_Cashier_cannot_read_purchase_costs_through_any_supply_get`
3. `InternalReleaseScriptTests.Release_script_upgrades_empty_and_first_migration_databases_and_preserves_synthetic_rows`
4. `PrivatePilotReleaseTests.Real_migration_reapply_throwaway_down_up_and_actual_backup_restore`

Use `dotnet test backend/tests/Martha.Store.Api.Tests/Martha.Store.Api.Tests.csproj -c Release --no-build --no-restore --filter <exact-four-method-filter> --logger trx`.
SQL connection and authorization flags belong only to this child process. Precreate private `SAVIA_PILOT_EVIDENCE`.
Record the resolved command arguments and exits without publishing credentials.

Require four unique successful result identities, no skipped/missing/extra cases and a successful release receipt before the next stage.
Read the generated source database from that receipt; do not guess a database or reuse a previous run's receipt.
Confirm the captured container ID, ownership label and image before an actual `docker stop <captured-id>` and `docker start <captured-id>`.
Wait for that database to be ONLINE and its expected fixture to be readable within the remaining budget.
Set `SAVIA_PILOT_PERSIST_DATABASE` to that receipt's source database in the child only.
Then run exactly once:

`Martha.Store.Api.Tests.PrivatePilotReleaseTests.Frozen_fixture_survives_controlled_owned_container_stop_start`

The test itself does not restart Docker. Preserve evidence of the actual stop/start plus the post-restart assertion.
Finally remove only the captured owned container after rechecking ownership. Verify its absence even on failure.
This cleanup is the rollback for the disposable run; no preexisting data is changed.

## Evidence and limits

Keep raw TRX, logs, release receipt and generated connection values in ignored private exports.
Publish sanitized method outcomes, source bindings, command exits, durations, actual restart and cleanup readback.
Report **23 historical security passes + four fresh passes + one fresh pass** only if all conditions hold.
Keep the business39 result historical. Do not label the full security28 or business39 a new execution.

The current backup/restart fixture preserves four legacy business projections. It does not prove populated Cash-row recovery.
The unintegrated Cash reads/UI, real browser/API/SQL journey, emergency Owner recovery and production acceptance remain separate.
No browser journey, deployment, merge, external workflow, real payment or production action is authorized by this prepared plan.

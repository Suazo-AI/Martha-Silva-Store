# Astra SQL correction review

**ACCEPT WITH LIMITS.** No blocking defect found in the four-file test correction at `550b10456c10a2857da930913b397bd1a96949d2`. Recommend **four failed methods plus one deferred restart**, not a blanket security28 retry, subject to the evidence and dependency conditions below. This is worker advice; primary retains acceptance and integration. No runtime authority is granted.

Task: `savia-sql-correction-review-550b104-20261107-01`. Mode VALIDATE.
Host: SUAZO-PC, Windows; T3 Code / Codex / `gpt-6-astra`. Requested effort `xhigh`; runtime and agent-awareness expose `gpt-6-astra/xhigh`. Internal reasoning, token/cache/cost telemetry are unknown.
Managed worktree: `C:/Users/Jason/.t3/worktrees/github/t3-931a8332`; branch `t3/review-sql-corrections`; base/HEAD is the SHA above. Startup and pre-mutation awareness identified this task here. No other worktree was read.
Required instructions loaded. Review ran 2026-11-08 UTC within 30 minutes; three of four permitted focused invocations used.

**Source findings and independent checks**

- `InternalBranchScopeSqlTests.cs:24?31,280?304`: the new regression uses the actual OperationsHost and `MapPrivateSavia`, requests HTTP admission, and throws if a SQL context is requested. `AddInternalCash(builder.Configuration)` matches production registration. Removing that registration in scratch reproduced `Failure to infer one or more parameters` / `service UNKNOWN`. Corrected source passes. BS21_25 and BS28 retain their original status, actor, branch and non-disclosure assertions. Admission does not prove cash-handler execution or cookie authentication.
- `InternalCashSchemaOracle.cs:126?184`: only digit tokens with one terminal dot are normalized. Quoted values remain unchanged. Prefix NOT accepts a LIKE subtree and produces the same node as infix NOT LIKE. Comparison/arithmetic grouping, AND/OR grouping, signed bounds and collation survive canonicalization. Unsupported fractional/exponent forms fail closed. This is a bounded comparison grammar, not a general SQL interpreter.
- Fresh corrected checks passed **38/38**, zero skips: the existing 34 cases plus four independent probe methods. Probes rejected **73 individual semantic mutations**, including each affected bound/operator occurrence, boolean changes, arithmetic reversal, missing/double negation, collation and literal changes. Additional probes cover 11 numeric forms, grouping/precedence and all five unique fixture names. No acceptance collision was reproduced for the reviewed expressions.
- Expected cash shapes remain fixed independent constants, rather than values regenerated from the tested EF model. Shared `InternalCashWriteProjection`, `InternalLegacySaleFixture` and `InternalCashFixture` bodies are unchanged. Product, migration, release script, project and dependency-lock bytes are unchanged from `f9ffa452bae7fc11a4a578ce24b57ecb72add139`.

**Evidence freshness and limits**

Verified imported outcome identities/counts: security **23 Passed / 4 Failed**, business **39 Passed**, zero skips, unique normalized test/execution IDs, and exact equality with recorded method filters. Both sets' eight historical source bindings match Git blobs. All six imported document LF hashes and four correction source bindings match. Security failures remain visible in original artifacts; release failures stop at schema assertions before BACKUP. Restart remains NOT RUN.

The original private TRX/logs and captured schema are absent from this assigned worktree. Their primary verification receipts were inspected, not independently re-executed or re-hashed here. Primary's `641 Passed / 67 NotExecuted` and repository-check exit 0 remain recorded evidence, not fresh judge runs.

**Provenance limit, not a reproduced product defect:** the fixture is linked by correction README and original/primary manifests to schema SHA256 `f0c726bc6c84710c690e56d9a395eeb98ab74b9ac2304b430df05c8026aa124f`. No allowed original bytes exist here. Primary must confirm the five fixture strings equal that file's allowlisted `check_definitions` before claiming independently verified capture provenance. Do not copy a full schema dump. This check needs no SQL rerun.

**Smallest sufficient SQL set for this correction**

All names have prefix `Martha.Store.Api.Tests.`. Run exact method equality filters, once, on the frozen corrected candidate:

1. `InternalBranchScopeSqlTests.BS21_25_Operations_http_checks_persisted_scope_and_actor_before_returning_result`
2. `InternalBranchScopeSqlTests.BS28_Cashier_cannot_read_purchase_costs_through_any_supply_get`
3. `InternalReleaseScriptTests.Release_script_upgrades_empty_and_first_migration_databases_and_preserves_synthetic_rows`
4. `PrivatePilotReleaseTests.Real_migration_reapply_throwaway_down_up_and_actual_backup_restore`
5. `PrivatePilotReleaseTests.Frozen_fixture_survives_controlled_owned_container_stop_start`

Require four fresh passes with zero skips first. Only after successful backup/restore and its fresh receipt, perform the authorized owned-container stop/start and run method 5 against that receipt's exact fixture database. The restart method itself does **not** restart Docker. Preserve container identity, observed stop/start, database readiness, receipt/source binding and cleanup absence evidence. A method PASS alone cannot prove restart. Stop dependent execution on failure; no automatic retries.

No additional existing SQL methods are necessary solely for this patch. OperationsHost has only the two affected SQL callers. The changed parser is used by the two release methods and restart. The 23 passing security cases comprise eight other branch cases, six HTTP acceptance cases, two real-program authentication cases and seven security cases. None uses the changed blocks. The 39 business cases use unchanged services/fixtures, including eight cash cases.

Reuse is conditional on retained original raw identity/outcome verification, unchanged relevant test bodies/assertions/fixtures, product/migration/release bytes, pinned SDK/dependencies and equivalent SQL image/configuration. A new commit number alone does not invalidate evidence. Changed dependencies, uncertain identity, unexplained failures, configuration drift or shared-state contamination require reassessing and rerunning affected cases. Keep the ledger as **23 historical + 4 fresh + 1 fresh**, never one fresh 28/28 run.

This recommendation supersedes the correction README's older **whole security28** proposal for this test-only delta; frozen documents remain untouched. Jason must separately authorize any runtime.

Future Cash UI/read-service work has separate acceptance: actor/branch isolation before paging, current-session permissions, money/recovery contracts and the real browser/API/SQL journey. Reassess N1/N3/N4/N5/N8 and branch HTTP cases if shared authorization or routing changes. Rerun affected cash/commerce cases if write semantics or shared fixtures change. These five tests do not pre-approve that work. Current backup/restart business assertions cover four legacy projections, not populated cash-payment rows (`PrivatePilotReleaseTests.cs:82?89,132?169`). Cash-row recovery claims need dedicated fixture/assertions.

**Fresh offline evidence**

Scratch: `private-exports/astra-judge-550b104/` in this worktree. Exact dotnet argument arrays/exits are in `red-result.json`, `green-result.json`, `green-fresh-result.json`. SDK `10.0.402`; locked restore used existing cache and an empty local source, with NuGet audit disabled. SQL connection/authorization variables were absent.

| Command suffix after `python private-exports/astra-judge-550b104/run.py` | Outcome | Exit | Seconds |
|---|---|---|---|
| `red` | Scratch rollback: 28 pass / 6 expected fail | 1 | 117.469 |
| `green` | Stale red assembly: 28 pass / 6 fail; invalid correction evidence | 1 | 6.609 |
| `green-fresh` | Separate artifacts directory: 38 pass / 0 fail / 0 skip | 0 | 82.438 |

Verification failure resolved: incremental compilation reused red outputs after target substitution. Red-source stack paths and missing probe methods exposed it. Separate outputs produced all four new probe methods and passed. Lesson: isolate mutation-build outputs before comparing results.

TRX SHA256: red `1e1a149cb1af11b3b2bc0faac726186cb374f4f951464b6f62bbbd932d5b0080`; final `6107dd3dcfeec45c57bfaf9dcbe4262179cdf2b0679828909fff67054b6d3473`.

Reviewed RAW SHA256; first three files are under `backend/tests/Martha.Store.Api.Tests/`:

| File | SHA256 |
|---|---|
| `InternalBranchScopeSqlTests.cs` | `b9430130e1cbec3798951423ed64113beac27ab63e3d77c38a41c8c779948666` |
| `InternalCashSchemaOracle.cs` | `230a1056916c2f84323adbb5b9f55becc67122748585f1c6d146c018f9f3faf8` |
| `InternalCashSchemaOracleTests.cs` | `dc3ba33d63acbfabbbdcfc1d3a66739d13881d2f76c3624298a50c20e24c24b5` |
| `backend/tests/fixtures/cash-checks.sqlserver2022.json` | `365275ce58783553af53398c54974c93542860f2dfde116aa3bc1d1dc78344e6` |

NOT RUN: SQL/Docker, full suite, browser, network/CI polling, installs, services/accounts/certificates, custom validation runner, stage/commit/push/merge/deploy or external messages. Production readiness is not accepted. Next owner: primary verifies capture provenance, imports this report serially and prepares a separately authorized five-method runtime packet.

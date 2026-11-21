# F8 correction recheck

**ACCEPT WITH LIMITS.** The F8 source correction addresses the scheduling-only overlap defect and missing session assertions. No material defect remains identified within this bounded review. Acceptance covers preparation only. Actual contention/control proof and current integrated-build qualification remain pending. The primary retains final acceptance.

Task: `savia-owner-f8-cd5231a-astra-20261108-01`. Mode: VALIDATE; source-only GUIDANCE using `juez-de-rama` and canonical `security-audit`. No children.

Host: `SUAZO-PC`; T3 Code / Codex / `gpt-6-astra`. Requested and runtime-exposed reasoning: `xhigh`. Internal effort measurement, token/cost telemetry: unknown.

Managed worktree: `C:/Users/Jason/.t3/worktrees/github/t3-a3751377`, branch `t3/review-f8-recovery-evidence`. Verified HEAD: `85d5872ecb379e42e8ed59de346bf60933207c53`. Initial and pre-report Git status: clean. Trusted agent-awareness checks succeeded at start and immediately before report creation. Only this task was identified in this worktree; other harness activity remains unknown.

## Verified bindings

Private inputs: `C:/Users/Jason/MARTHA-SILVA/test-runs/owner-recovery-primary-20261108/f8-correction-inputs`. Implementation was read there, not assumed present in this checkout.

- Corrected `CANDIDATE.json` RAW: `cd5231a2fa373a50435f2cede2cdfe14a5dd33959e706a7031f8f62b7a5c9c56`.
- Original candidate RAW: `699cd91ddec454f7207c4be3d0ae7d4ad07607e9c29416b96e20a6483bd77f3d`.
- Specification LF: `5beee5493a2e3bb900c1b9d62968ace5b665b64f729a943150ab04c20e1c47ff`.
- Original canonical review RAW/LF: `19ce79eb37e06ef6551d57b2e7c05722a2957f6362766979466584817bc28461`.
- Revised `backend/tests/Martha.Store.Api.Tests/InternalOwnerRecoverySqlTests.cs` RAW/LF: `40695cb9fafb263c492487f2819d4471203b472d6052f62cbaee6793c714bd9e`.
- Its original RAW/LF: `84d17f0a8e4949468c07e281a7da89cff5ca3073d68ac3fc5006ed6ec62e29c6`.

All ten corrected source lengths and RAW/LF bindings match. All ten original source bindings also match. Path sets are identical; exactly one source differs, the SQL test file above. The other nine are byte-identical. The corrected root contains those ten sources and its manifest only. All nine historical evidence RAW hashes match and retain their original manifest bindings.

Verification used trusted PowerShell file reads, `Get-FileHash`, SHA256 over UTF-8 CRLF-to-LF normalization, inert JSON/XML reads, and `git diff --no-index -- <original-test> <corrected-test>`. Diff exit 1 denotes the expected difference. Hash checks exited 0. An initial comparison used the wrong original-manifest field spelling; correction to `RAW_SHA256`/`LF_SHA256` verified every original binding. No input mismatch remains.

## Frozen checks

References: T = revised SQL test file; R = unchanged private `InternalOwnerRecoveryService.cs`; F = unchanged private `InternalOwnerRecoveryFixture.cs`; S = baseline `InternalSecurityService.cs`.

1. **Actual SQL overlap:** T:87-142 retains all four operations. T:173-195 requires the contender's request, the recovery blocking session, current database, `LCK_M_*` wait, and current statement containing bracketed `Staff`. Statement offsets restrict inspection to the executing statement. Scheduling alone cannot satisfy this predicate. This observes a Staff-related lock wait, not an independently decoded target key; attribution also relies on the isolated fixture and inspected operation paths.

2. **Attribution/control/permissions:** T:97-115 identifies recovery connections through a single new database-filtered session around each awaited `Inspect`. Non-recovery contenders use `@@SPID` on the explicitly opened EF connection. R:43-50 and F:30 disable pooling/reconnect retries. No other fixture work runs during session capture. T:129 holds admission before the actual operation; T:137 requires the same predicate to reject that condition before admission. Missing session visibility fails `Assert.Single`; missing request/text visibility returns no match or throws. The positive assertion therefore fails closed. No grants or privilege fallback exist. Existing DMV visibility is a runtime prerequisite, not permission to provision it.

3. **Serial winner:** T:99-100 holds `before-commit`, after R:113-117 revokes sessions and saves Staff under the uncommitted transaction. This avoids treating an update lock as excluding shared readers. R:94-119 and S:15-18,93-97,124-128 support serialization and stale-version/old-password rejection. The 20-second hold watchdog, 150-ms negative window, eight-second positive window, two-second DMV command timeout, and budget-plus-two-second cancellation fail the test on missing evidence. They are not measured runtime guarantees.

4. **Failure cleanup:** T:144-149 releases admission and recovery gates, then awaits every started task before connection/context/service disposal and fixture database cleanup. A missing loser still joins the winner. Faulted joins propagate failure after all tasks settle. No operation retry was added.

5. **Sessions and preservation:** T:117-121 captures the three seeded target sessions and two unrevoked principals. T:151-163 requires committed recovery, exact journal version, unchanged session IDs, preserved old session versions, every session revoked, fresh revocation timestamps for both revocable IDs, replacement-password acceptance, old-password rejection, and rejection of both old principals. F:39-47 establishes meaningful initial identities. F:102-105 excludes only allowed fields from preservation; T:152 retains the unchanged independent comparison, including unrelated data and already-revoked timestamps.

6. **Scope/compile review:** The diff changes only F8 fixture orchestration, assertions and DMV helpers. Product behavior, permissions and dependencies are unchanged. Static inspection against `net10.0`/xUnit 2.9.3 found no concrete C# compile defect in task typing, nullable disposal, LINQ ordering, async commands or assertions. Compilation was not performed.

7. **Limits:** Historical XML counters remain separate: `1-red.trx` 84 PASS/1 FAIL; `2-green.trx` 89/89; `4-green.trx` 38/38. These do not qualify this correction or its integration with HEAD.

## Pending and next action

NOT RUN: target code/parsers, builds/tests, SQL/API/browser/Docker, network, installs, accounts/ACL/security changes, recovery, backup/restore, workflow/GitHub or Git mutations. SQL5 remains **D: REVIEW FIRST, DO NOT EXECUTE**.

No unresolved input-access blocker. The managed security skill was absent; the explicitly authorized canonical fallback loaded successfully. No product correction was attempted or needed in this report-only scope.

Primary next action: verify this report and integrate serially, preserving the separate build and authorized SQL gates. Closure requires fresh integrated-build evidence and actual positive/negative contention evidence for all four cases. This review grants no runtime authority. Lesson applied: SQL request evidence replaces task-start signals; final state assertions remain independently required.

Only retained output is this report. Final report hashes and Git status are returned separately.

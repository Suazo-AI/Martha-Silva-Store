**REVISE.** One concrete defect remains in the new offline authorization guard. The two exact mutations from the prior review are now rejected. The corrected SQL/C# fixtures otherwise satisfy the frozen preparation checks by source inspection. SQL is **NOT RUN**. This advisory return is not primary acceptance or production readiness.

Task: `savia-pr7-return-fixture-recheck-ba8ff2b-20261116-01`; mode VALIDATE. Host: `SUAZO-PC`, T3 Code/Codex. Requested and runtime-exposed identity: `codex / gpt-6-astra / reasoningEffort xhigh`. Harness declaration and awareness agree. Provider-effective telemetry beyond those declarations, token/cache/reasoning usage and cost are unknown. No delegates or additional provider calls were made.

Workspace: `C:/Users/Jason/.t3/worktrees/github/t3-d112c3cc-d6dd600fbb05e41c`. Canonical checkout remained read-only. HEAD stayed `ba8ff2ba10935e99fc268ebbe5eae130f72c1cca`.

**Numbered dispositions**

1. **SQL134: source PASS.** [134_credit_return_validation.sql:123](C:/Users/Jason/.t3/worktrees/github/t3-d112c3cc-d6dd600fbb05e41c/savia/db/tests/sales/134_credit_return_validation.sql:123) changes only the explanatory comment and catch to `51538`. Git's normalized diff is exactly two removed/two added lines. All financial assertions at lines 136–146 remain intact.

2. **Reversal-lock observation: source PASS, runtime unproved.** [ReturnRetrySafetyTests.cs:55](C:/Users/Jason/.t3/worktrees/github/t3-d112c3cc-d6dd600fbb05e41c/savia/tests/Savia.Tests/ReturnRetrySafetyTests.cs:55) retains the winner's outer transaction after the procedure's nested commit. Separate winner, contender and observer connections are opened. Lines 112–128 require contender `WAIT`, winner `GRANT`, exclusive APPLICATION modes, matching database/entity/description/partition, exact session IDs and the winner as blocker. The reversal prefix is checked. Winner release occurs only afterward. Completion without observation, unrelated waits and a six-second observation timeout fail visibly. V029 uses `@LockOwner='Transaction'` and the shared namespace. DMV visibility is explicitly a runtime prerequisite in the worker packet. A permission exception propagates; absent visibility cannot qualify as a pass.

3. **Six schedules/images/cleanup: source PASS.** The six InlineData cases cover exact/changed credit and outcome retries, plus mixed endpoints in both directions. Mixed calls use separate registers/tills. Line IDs are loaded before winner writes; contender construction performs no SaleLines pre-read. The snapshot compares all columns of all sales/inventory/credits/accounting/sync tables, ordered by full primary keys. UsdFixture creates a USD child with 10000 minor units. Duplicate, returned-quantity, outbox, credit, USD aggregate and conservation assertions remain. Failure cleanup cancels the contender, rolls back a live transaction, drains its task and disposes sessions before fixture database cleanup. Commands have bounded timeouts. No concrete stranded-task path was established from source; actual cancellation/rollback remains untested.

4. **Refreshed authorization: source PASS.** [SQL172:169](C:/Users/Jason/.t3/worktrees/github/t3-d112c3cc-d6dd600fbb05e41c/savia/db/tests/sales/172_return_retry_safety.sql:169) independently disables staff, deactivates access and deletes access for actor/approver. Credit uses distinct cashier and manager subjects. Outcome has one supervisor actor. Every case requires `51529` and exact unchanged financial/sync/audit images. The separate approval-permission revocation remains. Another supervisor replays at lines 194–199 with exact image equality, including original attribution. `_fixture.sql:62–76` supplies enabled staff and active branch access; supervisorA can approve returns. These are prepared runtime controls, not observed authorization results.

5. **Two-original-line ordering: source PASS.** [SQL172:223](C:/Users/Jason/.t3/worktrees/github/t3-d112c3cc-d6dd600fbb05e41c/savia/db/tests/sales/172_return_retry_safety.sql:223) posts two distinct numbered sale lines at 120000 each with a 240000 card tender. It reads actual generated SaleLine IDs, requires two originals and distinct ascending/descending JSON, returns both lines, then replays reversed input. Both endpoints must preserve exact images and conservation. This is actual fixture construction, not a label-only claim.

6. **Offline guards: PARTIAL; P2 finding F1.** [test_return_retry_safety.py:34](C:/Users/Jason/.t3/worktrees/github/t3-d112c3cc-d6dd600fbb05e41c/savia/tests/test_return_retry_safety.py:34) detects credit with `'sales.usp_PostCreditReturn' in proc`. The actual declaration is `[sales].[usp_PostCreditReturn]` at V029:164. Consequently it selects only `@ActorId`; `@ApprovedBy` is never checked. A bounded probe removed only `WHERE a.StaffId=@ApprovedBy AND s.IsEnabled=1`'s enabled predicate. The real positive test, `test_shared_lock_and_enabled_staff`, still passed. This is a source-guard false negative, not a demonstrated SQL authorization bypass. The same probe independently confirmed rejection of the exact prior split-namespace and remove-all-enabled mutations. Those successes do not rely on a mutation test failing itself. **Correction owner: primary.** Recognize the actual procedure spelling and add an approver-only omission control. Closure requires baseline acceptance and direct positive-guard rejection of that mutation. No source fix was allowed here.

7. **Compilation: recorded PASS, not rerun.** Worker RESULT binds this final C# hash and records cached restore/build exit 0. PRIMARY's two private-log hashes match the actual logs. Build log says `Build succeeded`, `0 Warning(s)`, `0 Error(s)`, `00:00:12.39`. SDK path ends `.sdk-10.0.402`; restore used local packages, locked mode and disabled NuGet audit. Ten public packet evidence hashes also verified. Compilation proves neither locking nor authorization behavior.

**Observed commands and limits**

Two permitted suites were attempted once:

```text
python -m unittest discover -s savia/tests -p test_return_retry_safety.py -v
python -m unittest discover -s savia/tests -p test_rules.py -v
```

Both PowerShell wrappers exited **1**. `$ErrorActionPreference='Stop'` converted unittest's normal stderr progress into `NativeCommandError` before `$LASTEXITCODE` capture. Only an initial `... ok` was visible; complete counts and Python subprocess exits are **unknown**. This is a reviewer capture failure, not an established candidate test failure. No retries were made. Worker-recorded 8/8 and 10/10 remain recorded evidence only.

The third and final permitted offline invocation was:

```text
python -B private-exports/astra-return-recheck/positive_guard_probe.py
```

Its actual subprocess exit was **1**, captured through `System.Diagnostics.Process.ExitCode`. Baseline accepted; split namespace rejected; all-enabled omission rejected; approver-only omission incorrectly accepted. [Probe and exact result](C:/Users/Jason/.t3/worktrees/github/t3-d112c3cc-d6dd600fbb05e41c/private-exports/astra-return-recheck/positive-guard-result.json). The probe invoked only the real positive guard and blocked subprocess execution inside it. No SQL was parsed or executed. Originals were unchanged.

The three-invocation limit is reached. The original wrapper errors and probe failure are retained under `private-exports/astra-return-recheck/`. Full-suite reruns need a subsequent bounded task with correct stderr capture. No required read was denied. Awareness ran at start and before import. A wildcard source lookup returned Windows error 123; exact-file lookup resolved it. SQL, Docker, services, installs/downloads, builds, browser, workflows, Git publication, merge and deployment were NOT RUN.

**Integrity and exact changed paths**

REVIEW RAW SHA256: `ac9f762bc0c1aaa59b9dedc6c680118a680d088d6ba874548e5ed8a97df6161a`.
Archive RAW SHA256: `2a65122436f781b15cdd1eb001faeff99832d1ec56c8ecba42d2820b4031b69d`.
Archive membership equaled the six explicit allowlisted paths before writing. All six RAW/LF bindings verified after import and at close:

| Imported path | RAW SHA256 (LF identical unless stated) |
|---|---|
| `savia/db/migrations/V029__return_retry_safety.sql` | `6041e3880fb4cb02c595504e394701e52408e426767c67c2b575914402b353cc` |
| `savia/db/migrations/MANIFEST.sha256` | `2e878b9e3c3eea5c1135ad0f1c2ac22a24f771aa5e41cba66665be79691eefe0` |
| `savia/db/tests/sales/172_return_retry_safety.sql` | `1c816dfdf60c45a8e71865222d3718f9d0ca552075fc73dddba15e11567a47ee` |
| `savia/tests/Savia.Tests/ReturnRetrySafetyTests.cs` | `3fe76573de23dd884534e6fb2d8414737ef2344221f70d9e319b1acceee68b37` |
| `savia/tests/test_return_retry_safety.py` | `1a919e950ff349ed514a98d90a60bbd4d6fbdf663192d0f99a8ce42f301f4e66` |
| `savia/db/tests/sales/134_credit_return_validation.sql` | `a243bc9d3c05e9e12744a02fd31193caaf62cee9566acd748d4772d57127575c`; LF `c331b7564647612297ba977ee872dc40aa625c4a6b618d6296333d98a7639fca` |

Only these six imports and `docs/merge-readiness-20261116/corrections/returns/sql/fixture-revision/astra-recheck.md` change the nonignored worktree. Temporary evidence stays under the ignored private path. V029/MANIFEST match the prior frozen snapshot. HEAD is unchanged. Index RAW SHA256 remains `65c9a85cec9893419c2aa94bcc7485a025a1bb11c329a6806b343ef047baa82f`; staged diff is empty. `git diff --check` exits 0.

Runtime remains blocked by explicit scope, not a failed SQL attempt. Primary/Jason own later runtime authority and DMV readiness. Completion then requires SQL134, SQL172 and six C# cases with observed waits, exact images and cleanup. No runtime correction was attempted because it was prohibited.

Lesson: mutation sensitivity must target each intended subject; procedure-name spelling can silently omit one authorization guard.

**Next action:** primary corrects F1 in the Python guard and verifies the approver-only mutation before accepting this fixture revision.

PR https://github.com/Suazo-AI/Martha-Silva-Store/pull/7, head ba8ff2ba10935e99fc268ebbe5eae130f72c1cca, checks and reviews NOT REFRESHED by reviewer.
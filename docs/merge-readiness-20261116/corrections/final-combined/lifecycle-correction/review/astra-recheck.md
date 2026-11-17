# REVISE — bounded lifecycle recheck

Task `savia-pr7-lifecycle-recheck-ba8ff2b-astra-20261116-01`; mode VALIDATE. **CF1 and PRIMARY-BROWSER-01 close within the frozen scope. CF2 retains one P2 visibility defect at logout.** Primary owns acceptance. No product correction was made.

Host `SUAZO-PC`; T3 Code/Codex; requested and runtime-exposed `gpt-6-astra/xhigh`. Harness declaration and agent-awareness agree. Tokens, subscription usage and cost are unknown. Managed checkout `C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04`, branch `t3/savia-lifecycle-review`, HEAD `ba8ff2ba10935e99fc268ebbe5eae130f72c1cca`.

## Material finding: CF2-R1, P2 — logout hides the cleanup warning

The new no-argument method correctly writes only fixed text at [savia/web/app.mjs:65](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/web/app.mjs:65). Retirement-safe delivery to the notice node works. User-visible delivery across logout does not.

[savia/web/index.html:14](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/web/index.html:14) contains `#notice` at line 29 inside `#shell`. [savia/web/app.css:48](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/web/app.css:48) forces hidden elements to `display: none !important`. Logout clears the actor/token and calls `route()` at [savia/web/app.mjs:214](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/web/app.mjs:214). The unauthenticated route hides `#shell` at [savia/web/app.mjs:145](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/web/app.mjs:145). A subsequent cleanup failure therefore writes into a hidden subtree. The next route clears that text at [savia/web/app.mjs:144](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/web/app.mjs:144) before showing the authenticated shell.

Reproduction sequence derived from these sources: start a cashier return; obtain temporary approval; hold its POST; log out; reject temporary-approval logout. The fixed warning is written but remains invisible during login and is erased at the next route. This is a reporting defect, not a demonstrated authorization bypass or duplicate financial write.

**Evidence limit:** the visibility effect is source-confirmed, not a fresh full-router/browser reproduction. All four permitted test invocations were already consumed. The independent logout probe proves safe message delivery only. The supplied browser fixture puts `#notice` outside any shell at [docs/merge-readiness-20261116/corrections/final-combined/lifecycle-correction/browser/harness.html:1](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/docs/merge-readiness-20261116/corrections/final-combined/lifecycle-correction/browser/harness.html:1) and does not boot login/router; its passing count cannot refute this finding.

Owner: primary. Minimal next correction: retain the fixed no-argument cleanup channel, but render its notice on a surface visible across authenticated and unauthenticated routes. Preserve ordinary stale-message suppression. Add a real-shell logout regression with delayed failed cleanup. Close this finding only when the fixed warning is visible after logout without private data, extra POST, or repeated revocation. No correction was attempted because this packet authorizes review only.

## Eight frozen checks

| Check | Disposition and direct evidence |
|---|---|
| 1. Inherited initial context | PASS. Actual root/route declarations preserve inherited actor and live role getters. Fresh suite and independent routed probes exercise normal entry. `return.mjs:285`. |
| 2. Direct draft cancellation | PASS. Restores editable entry, zero cancellation POST, retired form inert; a fresh legitimate attempt succeeds. `return.mjs:163`. |
| 3. Replay-confirm cancellation | PASS. Same result through cancellation of replay confirmation. Actual route guard used independently. `return.mjs:231`. |
| 4. Safe cleanup notice across boundaries | PARTIAL / REVISE. Fixed text, ignored arguments, single revocation, and delivery after navigation/account/logout pass. Full-shell logout visibility fails by source chain above. `app.mjs:65`; `return.mjs:121`. |
| 5. Stale effects | PASS. Ordinary stale notifications, held valid lookup, late POST and retired/replacement modal effects remain suppressed. Independent probes cover actual route guards; suite covers late approval/modal cases. |
| 6. Uncertainty | PASS. Verified ordinary GET and valid POST clear old warnings at `return.mjs:179,209`. Five invalid GET shapes/statuses and malformed/wrong-status POST preserve intent and warning. Exact exchange GET remains unresolved. |
| 7. Fences and identity | PASS. Independent actor, token, scope, hash and disposal cases block late receipt effects. Immutable replay bodies match. Suite also exercises storage ownership, competing mounts and locks. |
| 8. Strict recovery/SQL contracts | PASS at unchanged-source and offline level. All 14 unchanged bindings match the prior archive byte-for-byte. Receipt/ownership validators remain strict. Reuse prior SQL/workflow adjudication; no SQL execution qualification. |

## Fresh execution and sensitivity

Exactly four Node invocations ran, without retries or installs. Child commands:

```text
node --test savia/web/tests/*.test.mjs
node --test private-exports/astra-lifecycle-recheck/independent.test.mjs
node --test --test-name-pattern CF1 private-exports/astra-lifecycle-recheck/context-reverted.test.mjs
node --test --test-name-pattern CF2 private-exports/astra-lifecycle-recheck/cleanup-reverted.test.mjs
```

| Invocation | Actual child exit | Result | Wall seconds |
|---|---:|---|---:|
| Web suite | 0 | 117/117 PASS | 0.656 |
| Independent offline cases | 0 | 19/19 PASS | 0.282 |
| Context inheritance reverted in scratch | 1 | 3/3 expected failures | 0.219 |
| Cleanup channel reverted in scratch | 1 | 1/1 expected failure | 0.219 |

All runs had zero skips/cancellations. The first inline Python wrapper saved stdout, stderr and child exit before its final console print failed with `UnicodeEncodeError: 'charmap' codec can't encode character '\u2714'`. Wrapper exit was 1; Node exit was 0. Existing output was inspected with explicit UTF-8; no test reran.

Remaining invocations used `python -X utf8 -B private-exports/astra-lifecycle-recheck/run_probe.py <label> <child-command>`; labels were `independent`, `context-reverted`, and `cleanup-reverted`. Their wrapper exits equal the child exits. [Runner](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/private-exports/astra-lifecycle-recheck/run_probe.py), [probe construction](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/private-exports/astra-lifecycle-recheck/prepare_probes.py), and [independent assertions](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/private-exports/astra-lifecycle-recheck/independent-cases.js) preserve reproduction details.

Context reversion caused missing initial/cancelled forms and `Cannot read properties of undefined (reading 'staffId')`. Cleanup reversion produced an empty notice instead of the fixed warning. These are target assertion failures, not import/setup failures. Mutants used ignored scratch files and unchanged absolute imports. Frozen product bytes never changed.

Evidence: [suite exit](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/private-exports/astra-lifecycle-recheck/web-suite.json), [117-test log](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/private-exports/astra-lifecycle-recheck/web-suite.txt), [19-probe result](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/private-exports/astra-lifecycle-recheck/independent.json), [CF1 negative control](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/private-exports/astra-lifecycle-recheck/context-reverted.txt), [CF2 negative control](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/private-exports/astra-lifecycle-recheck/cleanup-reverted.txt).

## Supplied browser evidence and boundaries

Inspected runner assertions, fixture, raw result records and audit. Run 2 records 22/22, child exit 0, 15.125 seconds, desktop 1280×900/DPR1 and mobile 390×844/DPR2. All 18 served RAW/LF hashes and all 17 source bindings independently match this checkout. Records contain zero external requests and eight expected synthetic console events. Truncated-response, 404 and logout-500 paths in the runner explain those events. Loopback closure is supplied evidence, not a newly opened/closed service.

Run 1 remains 21/22, exit 1; desktop draft cancellation timed out. Run 2 explicitly waits for `dialog[open] #confirm-no`. Product hashes agree across the records. Supplied ffprobe audit covers two AFTER videos; this reviewer viewed neither videos nor screenshots. Original BEFORE is absent. Browser results support PRIMARY-BROWSER-01 in the real-module fixture, not complete router/login acceptance.

NOT RUN: browser, network, full router/login, real API, SQL, Docker, services, .NET/build, aggregate, workflows, exact-SHA CI, physical devices, production, GitHub operations, staging, commits/hooks, push, merge or deployment. The earlier aggregate's `WinError 1314` remains an environment gap, not retried or weakened. Primary owns exact-candidate aggregate/SQL/CI qualification under separate authorization. This source review waives none of those gates.

## Frozen custody and handoff

Archive RAW SHA256 `96443a326e1a54b73c0a393c4059410f9ced563182e30a960c3226bc18a0e9cc`. Verified 38 exact allowlisted entries, sizes, RAW hashes and CRC before hydration. Absolute/traversing/duplicate/symlink entries and escaping destinations were rejected. All 17 source RAW/LF bindings match. Prior archive comparison found only `app.mjs`, `screens/return.mjs`, and `tests/return-lifecycle.test.mjs` changed.

Pre/post checks preserve all 38 hydrated entries, 79 web files, HEAD and index. Index SHA256 `61435cd985a157c6c80f5fbdcf57b99f6f52184c1f7d1845c2710d80925681e9`. `git --no-optional-locks diff --check` exits 0. Only this assigned report was added outside ignored scratch after hydration. [Baseline](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/private-exports/astra-lifecycle-recheck/baseline.json) and [final custody receipt](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/private-exports/astra-lifecycle-recheck/closeout.json) retain exact checks.

Supplementary source hashes: `savia/web/index.html` = `73492e675e3ed2886308b700672e0c4e33022a761c1ccf5f2d9c84a2ddf19b64`; `savia/web/app.css` = `7170934adb17dce102714b9097cfe510f563ef625f6d7002a373f86c8ce8d6ad`.

Lesson: a notice recorder proves delivery, not visibility across shell state. Applied by inspecting actual HTML, CSS and routing after passing probes. Next action: primary adjudicates CF2-R1 and corrects/tests the logout surface before closing check 4. Worker return remains advisory.

## Compact source bindings

All values below were checked before and after probing. RAW and LF values are separate where line endings differ.

| Source | Bytes | RAW SHA256 | LF SHA256 |
|---|---:|---|---|
| [.github/workflows/golden-path.yml](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/.github/workflows/golden-path.yml) | 10879 | `ac232cbd55a4df86a90661ce907c067d041916e5d729122660067ba1615e3fc9` | `e9b63cd3c06dd67e26ba36fe3ad298908c95b2e1a0b8ab7cbd43ed6662c33622` |
| [dev/savia-staff-ui/cash.test.mjs](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/dev/savia-staff-ui/cash.test.mjs) | 26330 | `c9d7c550bb7e39b0a7eadcead62daede16f43e9e968e4cfbf62527b4fd65ed61` | `2993c86ba4517ad3a87d729fc9e51bc0c8bfdf3c8b64eebf5a5a69d698f4a258` |
| [savia/db/migrations/MANIFEST.sha256](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/db/migrations/MANIFEST.sha256) | 2803 | `2e878b9e3c3eea5c1135ad0f1c2ac22a24f771aa5e41cba66665be79691eefe0` | `2e878b9e3c3eea5c1135ad0f1c2ac22a24f771aa5e41cba66665be79691eefe0` |
| [savia/db/migrations/V029__return_retry_safety.sql](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/db/migrations/V029__return_retry_safety.sql) | 23115 | `6041e3880fb4cb02c595504e394701e52408e426767c67c2b575914402b353cc` | `6041e3880fb4cb02c595504e394701e52408e426767c67c2b575914402b353cc` |
| [savia/db/tests/sales/134_credit_return_validation.sql](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/db/tests/sales/134_credit_return_validation.sql) | 8837 | `a243bc9d3c05e9e12744a02fd31193caaf62cee9566acd748d4772d57127575c` | `c331b7564647612297ba977ee872dc40aa625c4a6b618d6296333d98a7639fca` |
| [savia/db/tests/sales/172_return_retry_safety.sql](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/db/tests/sales/172_return_retry_safety.sql) | 20807 | `1c816dfdf60c45a8e71865222d3718f9d0ca552075fc73dddba15e11567a47ee` | `1c816dfdf60c45a8e71865222d3718f9d0ca552075fc73dddba15e11567a47ee` |
| [savia/tests/Savia.Tests/ReturnRetrySafetyTests.cs](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/tests/Savia.Tests/ReturnRetrySafetyTests.cs) | 9916 | `3fe76573de23dd884534e6fb2d8414737ef2344221f70d9e319b1acceee68b37` | `3fe76573de23dd884534e6fb2d8414737ef2344221f70d9e319b1acceee68b37` |
| [savia/tests/test_return_retry_safety.py](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/tests/test_return_retry_safety.py) | 6498 | `6a180e8c8d27900a203bd94c338260863dc45e157c1e351302eceff02af9a9f5` | `6a180e8c8d27900a203bd94c338260863dc45e157c1e351302eceff02af9a9f5` |
| [savia/web/app.mjs](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/web/app.mjs) | 7838 | `09d362dac9be0de1f726f8643a480c4545dd95a18f85edfae1497d41571c33d1` | `09d362dac9be0de1f726f8643a480c4545dd95a18f85edfae1497d41571c33d1` |
| [savia/web/api.mjs](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/web/api.mjs) | 13384 | `d30bf2f0bee090cb505c64a1f672cc83c253444f3878ffa6f7ee46dee45b59c6` | `b0a2fe70bddb20de4b0745c06257bf05c9e60afd1d16611a6b1ed748133367f6` |
| [savia/web/screens/return.mjs](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/web/screens/return.mjs) | 27875 | `69198b30c9e16e221cc8c589ca9ebefc20b8dcfa148ab44268624f86d9f66cda` | `69198b30c9e16e221cc8c589ca9ebefc20b8dcfa148ab44268624f86d9f66cda` |
| [savia/web/screens/return-intent.mjs](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/web/screens/return-intent.mjs) | 6818 | `96f95f5c45ee6d9edf0478b78dcce20d180b379429745ebe4624c6c79c6bb049` | `96f95f5c45ee6d9edf0478b78dcce20d180b379429745ebe4624c6c79c6bb049` |
| [savia/web/screens/sale-logic.mjs](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/web/screens/sale-logic.mjs) | 4180 | `ba169c19e3aa25187c4749dacde347c1c8bab32c98472aebe0b136be111138fc` | `ba169c19e3aa25187c4749dacde347c1c8bab32c98472aebe0b136be111138fc` |
| [savia/web/uuid-logic.mjs](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/web/uuid-logic.mjs) | 493 | `8e93aa30b7239fc7576e1cb29cf991c11a1d951475b1cc56219047fa6ef97813` | `8e93aa30b7239fc7576e1cb29cf991c11a1d951475b1cc56219047fa6ef97813` |
| [savia/web/tests/uuid.test.mjs](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/web/tests/uuid.test.mjs) | 2484 | `0e2bf69aeb4b95e993669984a99c6889d5b77f90b051808c6be251b5445012bd` | `0e2bf69aeb4b95e993669984a99c6889d5b77f90b051808c6be251b5445012bd` |
| [savia/web/tests/return-lifecycle.test.mjs](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/savia/web/tests/return-lifecycle.test.mjs) | 30399 | `6ea8a64e3dd8f79506639040efc0953bd4cd2600deea0ead61e8e198595aa686` | `6ea8a64e3dd8f79506639040efc0953bd4cd2600deea0ead61e8e198595aa686` |
| [tests/test_golden_path_workflow.py](C:/Users/Jason/.t3/worktrees/github/t3-80792ac5-69e7587d57b03c04/tests/test_golden_path_workflow.py) | 11438 | `813d700f335162fe03476dd9a133f9b079cb739f5c3359fce295862d96c215b2` | `813d700f335162fe03476dd9a133f9b079cb739f5c3359fce295862d96c215b2` |

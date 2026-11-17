# REVISE ? frozen combined correction review

Task: `savia-pr7-combined-astra-ba8ff2b-20261116-01`. Mode: VALIDATE. Two material product findings remain. No product or test implementation was changed. Primary acceptance remains separate.

Host `SUAZO-PC`; T3 Code, Codex harness/provider; requested and runtime-exposed model `gpt-6-astra`, reasoning `xhigh`. Runtime declaration and agent-awareness agree. The optional thread metadata lookup returned `thread_not_found`; it did not trigger fallback. Actual tokens, subscription debit and cost are unknown.

Managed worktree: `C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670`. Branch `t3/review-savia-combined-corrections`. HEAD `ba8ff2ba10935e99fc268ebbe5eae130f72c1cca`.

## Material findings

### CF1 ? P1: copying the context breaks initial returns and cancellation recovery

Source: [savia/web/app.mjs:151](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/app.mjs:151) creates the screen context with `Object.create(ctx)`. Actor `me` and role accessors therefore remain inherited. [savia/web/screens/return.mjs:282](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/screens/return.mjs:282) passes `{...ctx,isCurrent:current}` to `syncTill`. Object spread omits those inherited properties.

With an open till, [savia/web/screens/till-open.mjs:90](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/screens/till-open.mjs:90) reads `ctx.me.staffId` and throws `Cannot read properties of undefined (reading 'staffId')`. The initial return screen shows the error instead of the editable form. This breaks the adopted ordinary-return requirement before any POST.

The same copy occurs at [savia/web/screens/return.mjs:162](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/screens/return.mjs:162) and [savia/web/screens/return.mjs:228](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/screens/return.mjs:228). After either draft cancellation route, remount reaches [savia/web/screens/return.mjs:117](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/screens/return.mjs:117) and [savia/web/sale-recovery.mjs:8](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/sale-recovery.mjs:8) without `me`. The draft is removed and POST count stays zero, but the editable form never returns. The first route suppresses its own exception after setting `retired`; the second rejects during `finally`.

Fresh reproduction: [initial-context.json](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/private-exports/astra-final-combined/initial-context.json) has 1 failing test, exit 1. [app-context.json](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/private-exports/astra-final-combined/app-context.json) has two failing cancellation cases plus CF2, exit 1. Both import frozen product code and use synthetic DOM/HTTP with the prototype shape derived from app.mjs. This is offline integration evidence, not a browser run.

Minimal correction: preserve inherited properties and accessors at all three context handoffs, for example a child context with its own lifecycle override. Keep the existing session, actor and navigation fences. Add tests using the actual app context shape. The current fixture has own `me` and `isApprover` at [savia/web/tests/return-lifecycle.test.mjs:141](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/tests/return-lifecycle.test.mjs:141), which hides this regression.

Closure: initial mount with an open till renders the form. Both draft cancellation paths restore edits with zero POST. Late callbacks cannot submit the cancelled attempt. A normal return still confirms. Primary must include this route in independent browser qualification.

### CF2 ? P2: retired approval cleanup failures are silently discarded

Source: [savia/web/screens/return.mjs:121](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/screens/return.mjs:121) starts single-shot revocation and reports failure through `ctx.notify`. Retirement correctly starts cleanup without waiting for a held POST. However, [savia/web/app.mjs:135](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/app.mjs:135) advances the route generation before unmount, and [savia/web/app.mjs:153](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/app.mjs:153) drops every notification once that screen is stale.

Consequently, failed temporary-session logout after navigation cannot reach the user. This violates adopted acceptance check 6 in [the correction contract](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/docs/merge-readiness-20261116/corrections/returns/ui-review/corrections/PLAN.md:34). It is a cleanup-reporting defect; this review does not claim an authorization exploit.

Fresh reproduction: [app-context.json](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/private-exports/astra-final-combined/app-context.json) holds POST, retires the route, returns logout HTTP 500, and records one revoke call with zero notices. The durable intent remains `sending`; no approval credential is persisted. The existing test at [savia/web/tests/return-lifecycle.test.mjs:309](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/tests/return-lifecycle.test.mjs:309) uses an unconditional notification recorder and misses the app guard.

Minimal correction: provide a retirement-safe channel for generic cleanup failure reporting without exposing credentials or another actor's attempt. Preserve normal stale-screen notification suppression and single-shot revocation.

Closure: a source-shaped routed-context test observes safe failure reporting after retirement while POST remains held. Late approval and failed logout remain single-shot. No foreign attempt details or credentials appear.

## Bounded adjudication

- SQL guard P2 is closed at source/probe level. [savia/tests/test_return_retry_safety.py:29](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/tests/test_return_retry_safety.py:29) normalizes bracketed procedure names, maps actors explicitly and fails closed on unknown names. Deleting only `ApprovedBy`'s `IsEnabled=1` is rejected with `enabled staff and active access missing: @ApprovedBy`. Unknown procedure is rejected with `unexpected return procedure: sales.usp_UnknownReturn`. Five independent checks passed, including baseline, split namespace and ActorId removal. No SQL executed.
- F1/F2: strict exact POST 200 acknowledgement, unresolved exchange GET, immutable identity/money/line validation and a legitimate different current approver are supported by [savia/web/screens/return.mjs:175](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/screens/return.mjs:175) and [savia/web/screens/return-intent.mjs:68](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/screens/return-intent.mjs:68). Fresh selected positives passed. API status opt-in preserves its default body-only contract at [savia/web/api.mjs:121](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/api.mjs:121).
- F3: durable state/readback and draft-only cancellation remain guarded. CF1 prevents usable cancellation recovery. Sending/unresolved records are retained; these findings do not authorize new identities after uncertainty.
- F4: immutable monetary summaries and receipt links survive remount without optional refresh dependencies at [savia/web/screens/return.mjs:135](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/screens/return.mjs:135). Fresh selected tests passed. Missing legacy currency stays unresolved instead of receiving invented expectations. CF1 still blocks initial ordinary return entry.
- F5: mount/session fencing, late-token cleanup and independent single-shot revocation are present. CF2 leaves cleanup reporting incomplete.
- Staff ordering at [dev/savia-staff-ui/cash.test.mjs:63](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/dev/savia-staff-ui/cash.test.mjs:63) now gates the actual asynchronous digest seam. It checks one digest and zero dispatch before release. A delay is not its ordering oracle.
- Golden automatic flags at [.github/workflows/golden-path.yml:44](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/.github/workflows/golden-path.yml:44) enable both required cash scenarios. Manual rejection at line 54 agrees with [tests/golden-path/golden_path.py:1660](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/tests/golden-path/golden_path.py:1660). No workflow or real journey ran.
- UUID fallback at [savia/web/uuid-logic.mjs:2](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/uuid-logic.mjs:2) uses cryptographic bytes with version/variant bits. API export remains available; sale logic imports the pure helper. Two fresh selected UUID/seller tests passed. No role-policy change or financial-invariant relaxation was adopted.

## Fresh commands and evidence

Working directory is the managed worktree above. Each command ran through [run_probe.py](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/private-exports/astra-final-combined/run_probe.py), which captures the actual child exit using Python subprocess with explicit UTF-8. Four invocations consumed; none remain.

```text
python -X utf8 -B private-exports/astra-final-combined/run_probe.py guard python -X utf8 -B private-exports/astra-final-combined/guard_probe.py
python -X utf8 -B private-exports/astra-final-combined/run_probe.py app-context node --test private-exports/astra-final-combined/app-context-probe.test.mjs
python -X utf8 -B private-exports/astra-final-combined/run_probe.py initial-context node --test private-exports/astra-final-combined/initial-context-probe.test.mjs
python -X utf8 -B private-exports/astra-final-combined/run_probe.py focused-contracts node --test --test-name-pattern "F1|F2|F4|uuid|seller ticket" savia/web/tests/return-lifecycle.test.mjs savia/web/tests/uuid.test.mjs
```

| Invocation | Actual exit | Fresh result |
|---|---:|---|
| [guard.json](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/private-exports/astra-final-combined/guard.json) | 0 | 5 checks, 5 passed |
| [app-context.json](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/private-exports/astra-final-combined/app-context.json) | 1 | 3 tests, 0 passed, 3 failed |
| [initial-context.json](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/private-exports/astra-final-combined/initial-context.json) | 1 | 1 test, 0 passed, 1 failed |
| [focused-contracts.json](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/private-exports/astra-final-combined/focused-contracts.json) | 0 | 9 tests, 9 passed, 0 failed |

All Node invocations had zero skips/cancellations. Guard mutations occurred in memory only. Probe scripts and complete captured output remain in ignored private-exports. Failed probes are product evidence, not PowerShell stderr-wrapper failures.

## Attribution, boundaries and handoff

The supplied [combined RESULT](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/docs/merge-readiness-20261116/corrections/final-combined/RESULT.json) records primary integrated web 110/110, guard 9/9 and rules 10/10. The separate [worker result](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/docs/merge-readiness-20261116/corrections/returns/ui-review/corrections/worker/RESULT.json) records its own web 110/110. Those runs are supplied evidence, not fresh execution by this reviewer. Worker negative controls cover their selected protections but omit inherited context and route-guarded notifications.

Earlier golden 108, cash 58/staff 223, compiled SQL fixture and cached build evidence remain historical and scoped. Unchanged SQL review checks 1?5 and 7 from [Astra SQL recheck](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/docs/merge-readiness-20261116/corrections/returns/sql/fixture-revision/astra-recheck.md) are retained against matching source bindings. Cached build success is not SQL execution.

NOT RUN: SQL, build, browser, actual combined real journey, CI, network or external mutation. Independent Sol/high browser results were unavailable and are not claimed. SQL authority remains consumed. Initial encoding and two mistaken read paths were corrected as inspection issues; no test was retried for those failures.

Owner: primary orchestrator. Next action: correct CF1/CF2 locally, add app-shaped regressions, then combine the separate browser return before requesting publication. Real SQL and current CI remain separate qualification gates. No correction was attempted because this packet permits review only. Four-probe limit is reached. A returned worker is not primary acceptance.

Lesson: preserve prototype-based app contexts in lifecycle overrides and exercise the routed notification boundary. This review applied that distinction in focused probes without changing product files.

## Source custody

Archive RAW SHA256: `ac0465e96c6a0f2a5b95023d0bc1cc3b46d7a96235dad2f665ac581fb0a742e9`.
REVIEW RAW SHA256: `0583483e6b9378d206e80385f91db3429c830d60db73b624b4fc43e9bdc4e19c`.
Index RAW SHA256: `0a46ef613601297c6525664040ce5273979b31589f3a66aae5f7e612e2a80d86`.

Bootstrap validated 53 exact unique regular entries, byte sizes and RAW/LF hashes before extraction. Absolute/traversal paths, symlinks and escaping destinations were rejected. [bootstrap.json](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/private-exports/astra-final-combined/bootstrap.json) records all 17 source bindings. [closeout.json](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/private-exports/astra-final-combined/closeout.json) records final 53-entry integrity, all 17 source hashes, unchanged HEAD/index, evidence hashes and diff check. Only this report was added outside ignored scratch after bootstrap.

| Frozen source | RAW SHA256 | LF SHA256 |
|---|---|---|
| [.github/workflows/golden-path.yml](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/.github/workflows/golden-path.yml) | `ac232cbd55a4df86a90661ce907c067d041916e5d729122660067ba1615e3fc9` | `e9b63cd3c06dd67e26ba36fe3ad298908c95b2e1a0b8ab7cbd43ed6662c33622` |
| [dev/savia-staff-ui/cash.test.mjs](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/dev/savia-staff-ui/cash.test.mjs) | `c9d7c550bb7e39b0a7eadcead62daede16f43e9e968e4cfbf62527b4fd65ed61` | `2993c86ba4517ad3a87d729fc9e51bc0c8bfdf3c8b64eebf5a5a69d698f4a258` |
| [savia/db/migrations/MANIFEST.sha256](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/db/migrations/MANIFEST.sha256) | `2e878b9e3c3eea5c1135ad0f1c2ac22a24f771aa5e41cba66665be79691eefe0` | `2e878b9e3c3eea5c1135ad0f1c2ac22a24f771aa5e41cba66665be79691eefe0` |
| [savia/db/migrations/V029__return_retry_safety.sql](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/db/migrations/V029__return_retry_safety.sql) | `6041e3880fb4cb02c595504e394701e52408e426767c67c2b575914402b353cc` | `6041e3880fb4cb02c595504e394701e52408e426767c67c2b575914402b353cc` |
| [savia/db/tests/sales/134_credit_return_validation.sql](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/db/tests/sales/134_credit_return_validation.sql) | `a243bc9d3c05e9e12744a02fd31193caaf62cee9566acd748d4772d57127575c` | `c331b7564647612297ba977ee872dc40aa625c4a6b618d6296333d98a7639fca` |
| [savia/db/tests/sales/172_return_retry_safety.sql](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/db/tests/sales/172_return_retry_safety.sql) | `1c816dfdf60c45a8e71865222d3718f9d0ca552075fc73dddba15e11567a47ee` | `1c816dfdf60c45a8e71865222d3718f9d0ca552075fc73dddba15e11567a47ee` |
| [savia/tests/Savia.Tests/ReturnRetrySafetyTests.cs](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/tests/Savia.Tests/ReturnRetrySafetyTests.cs) | `3fe76573de23dd884534e6fb2d8414737ef2344221f70d9e319b1acceee68b37` | `3fe76573de23dd884534e6fb2d8414737ef2344221f70d9e319b1acceee68b37` |
| [savia/tests/test_return_retry_safety.py](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/tests/test_return_retry_safety.py) | `6a180e8c8d27900a203bd94c338260863dc45e157c1e351302eceff02af9a9f5` | `6a180e8c8d27900a203bd94c338260863dc45e157c1e351302eceff02af9a9f5` |
| [savia/web/app.mjs](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/app.mjs) | `c0f673d033ccad4d153835eccfec16ce505fbacf22ea0acc7377ea6fa2d58129` | `c0f673d033ccad4d153835eccfec16ce505fbacf22ea0acc7377ea6fa2d58129` |
| [savia/web/api.mjs](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/api.mjs) | `d30bf2f0bee090cb505c64a1f672cc83c253444f3878ffa6f7ee46dee45b59c6` | `b0a2fe70bddb20de4b0745c06257bf05c9e60afd1d16611a6b1ed748133367f6` |
| [savia/web/screens/return.mjs](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/screens/return.mjs) | `b16fdac727c33391c52df88813b8a404e6e09d8511804541aa4f274828644fe1` | `b16fdac727c33391c52df88813b8a404e6e09d8511804541aa4f274828644fe1` |
| [savia/web/screens/return-intent.mjs](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/screens/return-intent.mjs) | `96f95f5c45ee6d9edf0478b78dcce20d180b379429745ebe4624c6c79c6bb049` | `96f95f5c45ee6d9edf0478b78dcce20d180b379429745ebe4624c6c79c6bb049` |
| [savia/web/screens/sale-logic.mjs](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/screens/sale-logic.mjs) | `ba169c19e3aa25187c4749dacde347c1c8bab32c98472aebe0b136be111138fc` | `ba169c19e3aa25187c4749dacde347c1c8bab32c98472aebe0b136be111138fc` |
| [savia/web/uuid-logic.mjs](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/uuid-logic.mjs) | `8e93aa30b7239fc7576e1cb29cf991c11a1d951475b1cc56219047fa6ef97813` | `8e93aa30b7239fc7576e1cb29cf991c11a1d951475b1cc56219047fa6ef97813` |
| [savia/web/tests/uuid.test.mjs](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/tests/uuid.test.mjs) | `0e2bf69aeb4b95e993669984a99c6889d5b77f90b051808c6be251b5445012bd` | `0e2bf69aeb4b95e993669984a99c6889d5b77f90b051808c6be251b5445012bd` |
| [savia/web/tests/return-lifecycle.test.mjs](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/savia/web/tests/return-lifecycle.test.mjs) | `d3514ec44a4e626aa5f0e092eed8769ce3cf6adc042a16a82e250ddcb85fac19` | `d3514ec44a4e626aa5f0e092eed8769ce3cf6adc042a16a82e250ddcb85fac19` |
| [tests/test_golden_path_workflow.py](C:/Users/Jason/.t3/worktrees/github/t3-96024fcb-839c638c0fe0e670/tests/test_golden_path_workflow.py) | `813d700f335162fe03476dd9a133f9b079cb739f5c3359fce295862d96c215b2` | `813d700f335162fe03476dd9a133f9b079cb739f5c3359fce295862d96c215b2` |

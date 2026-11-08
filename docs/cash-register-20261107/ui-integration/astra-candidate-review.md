# REVISE — frozen cash UI integration candidate

The candidate has useful cash implementation and passing focused checks. Existing CI browser invocations are incompatible, and neither workflow runs the new cash browser journey. Resolve F1–F2 before accepting this increment. F3 is a bounded private-view cleanup defect, not demonstrated server authorization bypass.

Task: `savia-cash-ui-judge-39161ef-overlay-20261108-01`. Mode: VALIDATE.
Primary retains acceptance, correction and integration ownership. Production remains NO-GO.

## Identity and source binding

Requested/effective exposed runtime: Codex through T3 Code, `gpt-6-astra`, `xhigh`, SUAZO-PC, Windows/PowerShell. Harness context and fresh agent-awareness agree. Token usage, hidden settings and cost are unexposed.
Tool-managed worktree: `C:/Users/Jason/.t3/worktrees/github/t3-a9bb7897`; branch `t3/a9bb7897`; initially clean.
HEAD: `39161ef8c5afcac1f7c9502cc5f38439608a8d70`.
No substitution or nested agents.

Reviewed canonical overlay at `C:/Users/Jason/MARTHA-SILVA/github`, not this worktree's old product files. All **16/16 RAW hashes and byte lengths** matched CANDIDATE.json; final recheck also matched. Inspected service/runner/access dependencies and workflow definitions have no diff from the parent.

RAW SHA256 bindings:

- CANDIDATE.json: `68a68810d0a2d313976feed05c9e2cf262d0a714be065d76226d425881af7634`.
- PLAN.md: `5b7d20c47d8afb04719eb77777a35516d46945e15c2de1766134038c34cbe258`.
- astra-contract-review.md: `a86064047bf9ef699aa90b3ea6d20fff9ef7ad22837edda89f80b3107217bd48`.
- Original worker RESULT.json: `613a1ef160f14e725384e61dd310e47e6c0d9b67c57ea4d9fc305386aa6eee95`; original base `550b10456c10a2857da930913b397bd1a96949d2`.

Paths below are relative to the canonical checkout. U=`dev/savia-staff-ui`; B=`backend/src/Martha.Store.Api/Internal`.

## Material findings

**F1 — P1: existing browser commands fail against this candidate.**
`tests/browser-mock-validation.mjs:126–155,301–310`; U/`index.html:118`; U/`app.mjs:608`.

Fresh-sale cases still omit required tender, expect `#sale-recover`/`#sale-receipt`, and supply unpaid commerce receipts. The mounted application now uses cash routes, cash receipts and cash recovery. The default mock handles only `/commerce/sales`; unmatched `/cash/sales` returns 501. This is fixture incompatibility, not evidence that the product's cash sale is broken.

Primary supplied a real bounded Chrome run with `MARTHA_BROWSER_TEST_MATCH='Multiarticle cart'`: **0 PASS / 2 FAIL**, 1440px and 390px, exit 1 reported by primary. I read its original JSON and verified all eight source hashes. Both failures wait 5000ms for hidden/disabled `#sale-recover`. Page errors, external requests and network failures are each zero.
Evidence: private `C:/Users/Jason/MARTHA-SILVA/test-runs/cash-ui-primary-20261108/legacy-multiarticle/browser-results.json`, SHA256 `6c4d099fc7f3b3212adac7ba5881f4195bee8d6c80d3b20695adccb59609da49`.

There is a second concrete fixture defect at line 310: the N5 override calls `currentActor()`, defined only inside `setup()` at line 60. My offline execution of that exact context-handler statement produced `ReferenceError: currentActor is not defined`.

Smallest correction: migrate affected fresh-sale cases to cash tender/routes/receipts/recovery and fix the override's local dependencies. Preserve explicitly seeded historical unpaid recovery cases. Do not restore fresh unpaid sales or delete failing coverage. Primary should rerun the two failing cases, the N5 fresh-sale case, then both complete workflow browser commands on corrected bytes.

**F2 — P2: cash browser coverage is absent from both CI workflows.**
`.github/workflows/staff-ui-candidate.yml:60–62` and `.github/workflows/savia.yml:44–46` invoke only the old driver and supply driver. Neither invokes `tests/browser-cash-validation.mjs`.

The unit-test glob does include cash tests; cash is not wholly untested in CI. However, fixing F1 alone still leaves opening, tender/change, refund, close and cash reload recovery without their new browser gate. This is independent of the held SQL campaign.

Smallest correction: primary adds the existing cash driver to both workflows, using their installed Playwright and isolated evidence directories, and retains its artifacts. Verify failure propagation and both viewports. Workflow edits/dispatch were outside this review's authority.

**F3 — P2: `clear()` retains private paying-till DOM.**
U/`cash.mjs:192–200,232–235`; U/`index.html:104,108`.

`showRefund()` puts cashier ID, balance and till ID into options. `clear()` resets the form but never removes `cash-paying-till` options or `cash-page` text. Form reset does not erase options.

My jsdom probe loaded a synthetic manager's refund context, called `clear()`, replaced the actor and called `start()`. The old `123.456 NIO`, cashier UUID and till UUID remained. Panel and refund section were unhidden; the selector was disabled. No refund read for the new actor supplied those values.

Bound: this proves the exported component lifecycle violates private-view cleanup. Normal successful top-level logout navigates to a fresh page; I did not reproduce cross-account disclosure through that full browser route. No write or server permission bypass was observed.

Smallest correction: clear all server-derived options, paging and labels on reset. Add a lifecycle assertion for empty private DOM immediately after clear and after actor/version replacement. Primary owns correction and retest; review-only scope prohibited product edits.

## Frozen eleven-check accounting

| Check | Assessment and evidence |
|---|---|
| 1. D031–034 / CASH01–08 | Preserved in source. Four write contracts remain unchanged; cash-first, own custody, manager refund and paying-shift history remain explicit. Full operational CASH acceptance is not claimed. |
| 2. Monetary authority | Offline PASS. Server configuration and recorded exponent feed receipts. BigInt parsing/sums, exponent 0–6 and 9e12 bounds are enforced. Legacy unpaid amounts use explicit minor units. |
| 3. Current access/isolation/paging | Source and offline tests support it. Serializable reads validate persisted session, role and location; own inaccessible till denies. Paying tills filter enabled eligible custodians and use opening-time/ID ordering. 103-row test and SQL translation are offline, not live persistence proof. |
| 4. Durable intents/strict receipts | Focused PASS. Four scope/key/body envelopes persist before dispatch and survive uncertainty/reload. Receipt checks bind actors, original lines, currency and arithmetic. No duplicate durable SQL effect was independently exercised here. |
| 5. Rejections versus uncertainty | Focused PASS. First definitive predispatch rejection unlocks; durable business rejection requires recovery. Unknown, malformed, conflict and storage failures retain references. |
| 6. Renewal/private state | Epoch/version checks and pending-byte retention pass focused tests. F3 prevents an unqualified cleanup acceptance. No stale-response bypass reproduced. |
| 7. Quantity refund | Source/fixture PASS. Original prices/quantities/reason, current Owner/Manager checks and matching paying till remain. Prior close is read-only. Real concurrent persisted reconciliation remains held. |
| 8. Confirmed money display | Source and historical mocked Chrome evidence support total, tender, change, balance, counted and difference. No invented production success observed. |
| 9. Legacy/supply/stock | Separate unpaid recovery and paid stock reads are preserved in source. Worker selected legacy1/supply1 and focused regressions are historical evidence. F1 means broader browser compatibility is not green. |
| 10. Tests/browser/controls | PARTIAL. Fresh 56/56 cash tests pass; meaningful historical mutants and source-bound desktop/mobile cash evidence exist. F1–F2 block CI coverage acceptance. |
| 11. Proof boundaries | PASS as reporting boundary. Mocks/offline checks are separate from real API/SQL and independent persisted-row reconciliation. SQL5 remains HELD. |

## Verification and limits

Reviewer used **2/3 permitted focused invocations**, no retries: one inline `node --input-type=module -` probe for DOM cleanup, required tender and exact line-310 scope; then `node --test C:/Users/Jason/MARTHA-SILVA/github/dev/savia-staff-ui/cash.test.mjs` with cached `NODE_PATH`. Both exited 0. The latter passed **56/56**, zero failures/skips. The probe asserted the defects' presence, not their correction. No scratch files were created.

Compiled serving correction is supported by direct source and original TRX hashes: red **1 PASS/1 FAIL** (expected Unauthorized, actual NotFound), then green **93/93**, no skips, including byte-exact cash/supply serving. Explicit EmbeddedResource plus authenticated route are present. This proves test authentication/compiled hosting, not persisted sessions.

Primary repository.log hash matches `c7049495ab53668c3bf022b91b827aefc745ae65ac576c3fa32518d108955919`; terminal summary says all automated checks passed. Primary reports exit 0 and staff221/221. This does not exercise the failing browser command.

Verified hashes of selected original worker summaries and all six recording files. Final cash browser evidence reports 2/2 and one open/sale/refund/close effect per viewport. Its five changed UI files match canonical RAW bytes; unchanged styles.css differs only by CRLF/LF. Do not describe all six as RAW-identical to canonical. Recordings were not replayed; visual/human acceptance remains unverified. Historical negative-control reports record six detected mutants; I did not rerun them.

NOT RUN: full legacy browser suite, browser UI, .NET rerun, SQL/Docker, installs, services, accounts, real data/payments, CI dispatch, commit/push/deploy. No access denial. One text read failed default cp1252 decoding; explicit UTF-8 resolved it.

Only this report changes. No product, canonical, worker, index or branch mutations. No active Owner-worker files read.
Permitted stop: bounded verdict delivered. Primary must correct F1–F3 and verify affected paths before acceptance.
Lesson: a green unit/repository run cannot establish compatibility of a separately invoked browser driver. Preserve that driver's actual failing evidence and its explicit correction check.

**Verdict: REVISE.** F1, F2, F4 and stale401 close within the supplied and independently observed evidence. F3's initialization race is corrected, but frozen check 7 still fails: a retired sale lookup can overwrite the shared dialog. One residual P2; no P0/P1 established. Primary retains acceptance.

Task: `savia-ux-corrections-4f700e5-astra-20261116-01`.
Base/HEAD: `2c96904f49d2df913850bc13cf53b3b03ceebacf`.
Reviewed immutable **tree**: `4f700e5489f3da5acad5b79be40eb21397f5228d`; not a commit or published SHA.
Previous tree: `72dcf2f00b94f2987691db6915fbf4149b8804b1`.
Host: SUAZO-PC / Windows / T3 Code / Codex. Requested and harness-exposed model/effort: `gpt-6-astra/xhigh`; agent-awareness agrees. Provider-side effort telemetry, token usage and cost are unknown. No delegates.

**Disposition**

| Item | Decision and evidence |
| --- | --- |
| F1 ? P2, recovery blocked by till discovery | CLOSED within scope. [app.mjs:170](C:/Users/Jason/.t3/worktrees/github/t3-c5fa6d87-895e3546cf39148d/savia/web/app.mjs:170) skips shell till synchronization for Venta. [sale.mjs:1065](C:/Users/Jason/.t3/worktrees/github/t3-c5fa6d87-895e3546cf39148d/savia/web/screens/sale.mjs:1065) renders pending recovery before `startSale`. Inspected eight full-shell assertions require recovery and receipt confirmation with zero `/cash/` calls and zero POST. Original identity checks remain at `sale.mjs:76?78` and `sale-recovery.mjs:123?125`. The configured held/failing dependencies are deliberately never reached. |
| F2 ? P2, demo reset strands marker | CLOSED within scope. [boot.mjs:106](C:/Users/Jason/.t3/worktrees/github/t3-c5fa6d87-895e3546cf39148d/savia/demo/site/boot.mjs:106) gates reset on confirmation, validates the seeded origin/staff/node/branch/location, and compares unchanged raw bytes before deletion (:108?115). Fresh offline callback probe: **10/10, exit 0**. Cancel preserves all storage; only owned valid marker clears; five foreign scope fields, malformed JSON, invalid record and marker replacement survive. Uses actual fake API/seed/recovery helpers; confirmation/reload are stubbed. Inspected browser evidence independently covers role re-entry and four reset assertions. |
| F3 ? P2, delayed initialization | Original initialization defect CLOSED within tested schedules. [app.mjs:150](C:/Users/Jason/.t3/worktrees/github/t3-c5fa6d87-895e3546cf39148d/savia/web/app.mjs:150), :190?192, [sale.mjs:46](C:/Users/Jason/.t3/worktrees/github/t3-c5fa6d87-895e3546cf39148d/savia/web/screens/sale.mjs:46), :154?159 and [till-open.mjs:87](C:/Users/Jason/.t3/worktrees/github/t3-c5fa6d87-895e3546cf39148d/savia/web/screens/till-open.mjs:87) guard route, actor, token, DOM, handle and till writes. Inspected 18 assertions cross three dependency stages with navigation/logout/account change. **Overall stale-callback requirement remains REVISE**, as detailed below. |
| F4 ? P2, supervisor redraw unlocks ticket | CLOSED within scope. [sale.mjs:450](C:/Users/Jason/.t3/worktrees/github/t3-c5fa6d87-895e3546cf39148d/savia/web/screens/sale.mjs:450) reapplies the busy lock after balance/payment refresh and recreated ticket controls. Approval recomputation at :702?707 precedes persistence and POST at :724?727. Inspected [sale-ux.browser.mjs:223](C:/Users/Jason/.t3/worktrees/github/t3-c5fa6d87-895e3546cf39148d/savia/web/tests/sale-ux.browser.mjs:223) exercises held approval-adjusted POST, disabled recreated controls, unchanged body/marker, one POST and confirmation; all three appear in the final 41-check result. Not independently browser-rerun. |
| stale401 | CLOSED within scope. [api.mjs:120](C:/Users/Jason/.t3/worktrees/github/t3-c5fa6d87-895e3546cf39148d/savia/web/api.mjs:120) compares captured and active tokens **after** error parsing. Logout disables global unauthorized notification at :144. Fresh 91-test suite includes delayed headers/body, delayed logout and existing current-session 401 handling. No backend/session protocol change. |

**Residual F3b ? P2: retired lookup opens another screen/account's shared dialog.**

Reproduction uses the **actual unmodified sale module and its real UI/API/scanner/payment dependencies**, with a minimal offline DOM and fictional fetch responses. Mount A, call `handleScan('AMBIGUOUS')`, hold `/catalog/lookup`, unmount, replace the current screen/dialog sentinel, then navigate, clear the token, or replace actor/token with B. Release two lookup matches.

In all **three retired cases**, the shared dialog opens and its sentinel is replaced with A's size picker. The active control opens normally. The replacement screen remains intact and POST count stays **0**. The probe exits **1** because all three isolation expectations fail; this is a product failure, not an execution error.

Cause: [sale.mjs:629](C:/Users/Jason/.t3/worktrees/github/t3-c5fa6d87-895e3546cf39148d/savia/web/screens/sale.mjs:629) awaits lookup without rechecking `current()`/`locked()`. The multi-result branch at :636?641 calls `choose`; [sale.mjs:530](C:/Users/Jason/.t3/worktrees/github/t3-c5fa6d87-895e3546cf39148d/savia/web/screens/sale.mjs:530) has no entry guard. Real [ui.mjs:97](C:/Users/Jason/.t3/worktrees/github/t3-c5fa6d87-895e3546cf39148d/savia/web/ui.mjs:97) clears the shared `#modal-body` and calls `showModal`. Router handle invalidation cannot cancel this already-running continuation.

This violates the existing check 7, not an expanded feature requirement. No duplicate sale, permission bypass, or real-data exposure was demonstrated. Primary owns correction: check currency after awaited lookup and before shared-modal writes; retain valid active lookup behavior. Closure: hold an ambiguous lookup through navigation/logout/account switch and prove the replacement dialog/content/focus stays untouched, with no POST. Review authority excludes product fixes; none attempted.

**Original ten checks**

The [frozen specification](C:/Users/Jason/.t3/worktrees/github/t3-c5fa6d87-895e3546cf39148d/docs/savia-ux-20261116/sale-preimplementation.md) is unchanged. No criterion was relaxed.

| Checks | Adjudication |
| --- | --- |
| 1?2: seller attribution/reassignment | Prior bounded acceptance retained; relevant logic unchanged by corrections. Fresh Node suite and inspected mounted evidence remain consistent. |
| 3?4: disclosures, money and approval separation | No new exception found. Preserve original offline/mocked limits; no payment/SQL acceptance implied. |
| 5: final payload and locks | F4 closes the prior exception; supplied held-POST evidence supports the corrected redraw. |
| 6: durability before POST | Prior bounded acceptance retained; fresh recovery tests pass. |
| 7: scope/session/stale isolation | **REVISE F3b**. Initialization and stale401 improvements do not cover an already-running ambiguous lookup. |
| 8: dependency-free original receipt lookup | F1 closes the prior exception; source and supplied full-shell checks support closure. |
| 9: uncertainty/no repost | Prior bounded acceptance retained; recovery source unchanged. No automatic repost added. |
| 10: actionable accessible feedback | Prior limited keyboard/source acceptance retained. No new visual, recording or complete accessibility verification. |

**Fresh independent execution**

Exactly three test processes; binary Python subprocess capture persisted each actual child exit before Unicode output. No retry.

1. `node --test savia/web/tests/*.test.mjs savia/web/scanner/scanner.test.mjs` ? **91 pass, 0 fail, 0 skip; exit 0**.
2. `node private-exports/savia-ux-20261116-astra-recheck/stale-lookup-probe.mjs` ? active control passes; three retired isolation checks fail; **exit 1**.
3. `node private-exports/savia-ux-20261116-astra-recheck/reset-isolation-probe.mjs` ? **10/10; exit 0**.

Probe sources and binary receipts remain in this worktree's ignored [private scratch](C:/Users/Jason/.t3/worktrees/github/t3-c5fa6d87-895e3546cf39148d/private-exports/savia-ux-20261116-astra-recheck). No primary private logs were accessed.

Inspected history is separate: corrections `CHECKS.json` records primary 91 Node, Biome64, rules9, build, shell30, mounted41+keyboard20 and entry3/71, all exit0. Browser fixtures and result assertions were inspected; browsers were not rerun. Final viewports are 1440x900 and 390x844. Original shell red has 11 failures among14; expanded30 was not wholly run red. F4/stale401 red exits are supplied historical receipts, not fresh observations. The earlier judge's88-pass output lacks a retained Node exit and is not promoted to the final91 result.

**Integrity and remaining gates**

Read-only Git identity/path checks and `git diff --check 2c96904f49d2df913850bc13cf53b3b03ceebacf 4f700e5489f3da5acad5b79be40eb21397f5228d` passed, exit0. Exactly108 delta paths were materialized from blobs:19 source/test and89 owned docs/evidence. All28 manifest LF bindings match with BOM retained. RAW matches16/19 sources and5/9 artifacts; remaining differences are CRLF normalization. All108 materialized files match their tree blobs byte-for-byte.

Historical `primary/CANDIDATE.json` and `primary/CHECKS.json` match the previous tree. The copied prior review retains SHA256 `864385f3aadba6ea65889035f75b04d9a76bd439be7f9eba30cb9dc03d76edb7`.

Final source/overlay readback is108/108; HEAD unchanged. Managed-worktree index SHA256 remains `573948cb4458f5b489d0fa0aa6c6dd6ff7bf703ae98fbc7e6636fd23d6792a41`. Only this report is newly public beyond the authorized overlay; report RAW/LF hashes accompany the return receipt. No staging, branch changes, commits, other-worker/canonical-checkout access, or product fixes.

Primary owns the existing Windows `WinError 1314` verification gap; no security correction or redundant root-suite retry was attempted. Linux gate on the eventual exact SHA remains pending. [savia-v2.yml:8](C:/Users/Jason/.t3/worktrees/github/t3-c5fa6d87-895e3546cf39148d/.github/workflows/savia-v2.yml:8), :63?74 confirms a qualifying Tony push starts disposable SQL. Primary must resolve runtime authority before publishing; do not weaken CI.

No install, network, browser/server, SQL, Docker, accounts/security changes, CI, push or deploy was run. Real persistence, physical devices, multi-tab behavior, complete accessibility and production remain outside this evidence. Stop: bounded review returned with all three test processes consumed. Next action: primary corrects F3b and verifies its closure. This is neither primary acceptance nor production READY.

Lesson: route guards do not cancel continuations that write the shared modal; test the delayed operation through its eventual UI effect.

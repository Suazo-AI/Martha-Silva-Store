# REVISE — combined UX review

Task: `savia-ux-combined-72dcf2f-astra-20261116`. Four P2 findings; three reproduced offline, one established by the source path. No P0/P1 established. Primary owns corrections, integration and final acceptance.

Base: `2c96904f49d2df913850bc13cf53b3b03ceebacf`.
Candidate: **tree** `72dcf2f00b94f2987691db6915fbf4149b8804b1`, not a commit or published SHA.
Host: SUAZO-PC, Windows; T3 Code / Codex. Harness runtime and agent-awareness both report `gpt-6-astra/xhigh`. Provider-side effort telemetry, tokens and cost are unknown. No delegation or additional model request.

## Findings and closure checks

**F1 — P2: the shell still blocks receipt recovery on till dependencies.**

[app.mjs:147](C:/Users/Jason/.t3/worktrees/github/t3-e0cda32b-a0fe93f531ff9ff2/savia/web/app.mjs:147) awaits `syncTill(ctx)` before mounting Venta. Every role allowed to use Venta is an approver. [till-open.mjs:81](C:/Users/Jason/.t3/worktrees/github/t3-e0cda32b-a0fe93f531ff9ff2/savia/web/screens/till-open.mjs:81) requests registers and potentially a till summary without handling failure. A pending sale therefore cannot reach Consultar recibo when that dependency fails or hangs, even if its receipt endpoint works.

The exact route-function probe injected a registers failure: **1 syncTill call, 0 sale mounts**. The existing mounted recovery test bypasses this shell. This is an unmet frozen check 8, not a claim that the old routing prerequisite was newly introduced.

Primary: let pending recovery render before till discovery. Close with a full-shell reload holding/failing registers and till-summary requests while receipt GET succeeds. No till opening or retransmission may occur.

**F2 — P2: confirmed demo reset strands the new recovery marker.**

[boot.mjs:104](C:/Users/Jason/.t3/worktrees/github/t3-e0cda32b-a0fe93f531ff9ff2/savia/demo/site/boot.mjs:104) resets fictional API state and the token, but not `savia.sale.pending.v1`. [demo/api/index.mjs:17](C:/Users/Jason/.t3/worktrees/github/t3-e0cda32b-a0fe93f531ff9ff2/savia/demo/api/index.mjs:17) reseeds only `savia.demo.v1`. The next Venta mount finds a marker whose original receipt was erased.

Actual fake API plus actual recovery helpers reproduced **receipt GET 200 before reset, 404 afterward, identical marker retained**. Re-entering the original role cannot resolve it; switching roles quarantines it. Repeating reset cannot repair it. This breaks the combined demo reset outcome.

Primary: reset the demo-owned recovery state only on confirmed reset. Preserve Cancel, unrelated storage and real-sale quarantine. Close with a pending fictional sale → Cancel → confirmed reset → role re-entry sequence.

**F3 — P2: a delayed sale mount overwrites another actor's screen.**

[sale.mjs:147](C:/Users/Jason/.t3/worktrees/github/t3-e0cda32b-a0fe93f531ff9ff2/savia/web/screens/sale.mjs:147) awaits `openTillPanel` inside `replace(root, ...)`, then writes without checking `current()`. The router does not receive the unmount handle until [app.mjs:165](C:/Users/Jason/.t3/worktrees/github/t3-e0cda32b-a0fe93f531ff9ff2/savia/web/app.mjs:165). Its earlier unmount call therefore cannot cancel a mount still awaiting initialization.

The actual sale module, with an offline minimal DOM and deferred till-panel dependency, reproduced: start actor A mount; switch context/token to B; render B's screen; resolve A's dependency; **A's old till panel replaces B's screen**. This fails frozen check 7. No authorization bypass or real sale was demonstrated.

Primary: guard every awaited mount completion and invalidate pending mounts at route/session changes. Close with delayed till initialization across navigation, logout and account switch; the replacement screen and current handle must survive.

**F4 — P2: supervisor adjustments recreate enabled controls while POST is pending.**

Source path: [sale.mjs:169](C:/Users/Jason/.t3/worktrees/github/t3-e0cda32b-a0fe93f531ff9ff2/savia/web/screens/sale.mjs:169) disables existing controls once. If approval changes the total, [sale.mjs:690](C:/Users/Jason/.t3/worktrees/github/t3-e0cda32b-a0fe93f531ff9ff2/savia/web/screens/sale.mjs:690) calls `drawTicket()`. That replaces ticket controls with new quantity buttons/inputs and line-discount inputs without disabled state ([sale.mjs:355](C:/Users/Jason/.t3/worktrees/github/t3-e0cda32b-a0fe93f531ff9ff2/savia/web/screens/sale.mjs:355)). POST then starts without reapplying the lock.

This fails the disabled-editing portion of check 5. The immutable body and guarded `update()` still protect submitted line data; duplicate charging is not established. This finding is source-proven, not freshly browser-reproduced.

Primary: carry busy state into every redraw. Close by changing a discount through approval, holding POST, and verifying all recreated ticket controls remain disabled.

## Frozen acceptance adjudication

PASS below means bounded source/offline evidence plus inspected supplied browser evidence, not production acceptance.

| Check | Verdict and evidence |
| --- | --- |
| 1. Exact active seller default | PASS: canonical GUID comparison against active seller list; unmatched/loading/failed lists block selling. SQL V018 filters enabled branch sellers. |
| 2. Deliberate reassignment | PASS: invalid saved assignments remain invalid; explicit replacement preserves separate lines; three-seller cap; SELLER still lacks Venta. |
| 3. Advanced options/approval values | PASS: native disclosures retain inputs; reason reveal/focus and scanner focus checks covered. |
| 4. Money/request invariants | PASS within offline scope: unchanged money/payment modules; durable body tests cover split tenders, credit, USD and 100% discount. Approval remains separate from cashier Authorization. |
| 5. Final attempt and locks | REVISE F4; final recomputed body is persisted, but recreated controls escape the visual lock. |
| 6. Durability before POST | PASS: strict validation, write/readback and existing-marker guard; denial/corruption block sending. |
| 7. Scope/session/stale isolation | REVISE F3; stored origin/staff/node/branch/location/till quarantine is otherwise present. |
| 8. Dependency-free lookup/original identity | REVISE F1. Mounted lookup checks original sale/cashier/till. Fresh wrong-cashier negative control retained the marker and showed no confirmation. |
| 9. Uncertainty/no repost | PASS within single-context mocked scope: response loss, malformed/empty success, 5xx and later GET rejection remain pending; ancillary failure preserves confirmation. No automatic repost path. |
| 10. Accessible actionable feedback | PASS within supplied keyboard evidence and source: alerts, plain next actions and valid inline diagnostic disclosure. Full accessibility NOT RUN. |

Navigation/history PASS: 14 Owner menu routes through seven choices; unchanged permissions/landing; history uses authoritative `receiptNumber` with truthful fallback. Demo entry/cancel/expiry evidence remains useful; combined reset REVISE F2.

The 16-file delta contains no dependency change. Native modules preserve existing styling. Inspected final mobile sale and desktop receipt screenshots support that limited visual conclusion. The supplied 26-reference/six-deeper-read inventory was inspected, not re-fetched.

## Verification and limits

Validated and materialized exactly **96 paths** from Git blobs: 16 source/test files plus task documentation. All **16 LF hashes** match CANDIDATE; **13 RAW hashes** match. The three differences are CRLF normalization in `banner.css`, `verify.py`, `app.css`. Every materialized blob matches the tree. Real login/etiqueta Git blobs are unchanged. Index unchanged; no branches, commits or remote actions.

Exactly three test invocations:

1. `node --test savia/web/tests/*.test.mjs savia/web/scanner/scanner.test.mjs`: **88 pass, 0 fail, 0 skip** in saved output. Node exit was not retained: the Python output wrapper failed with `UnicodeEncodeError` while printing U+2714. No retry. [Log](C:/Users/Jason/.t3/worktrees/github/t3-e0cda32b-a0fe93f531ff9ff2/private-exports/savia-ux-20261116-astra/web.log).
2. `node private-exports/savia-ux-20261116-astra/integration-probe.mjs`: **exit 0**, two defects reproduced. [Source](C:/Users/Jason/.t3/worktrees/github/t3-e0cda32b-a0fe93f531ff9ff2/private-exports/savia-ux-20261116-astra/integration-probe.mjs).
3. `node --experimental-vm-modules private-exports/savia-ux-20261116-astra/mount-probe.mjs`: **exit 0**, stale-mount reproduction and wrong-cashier negative control completed. [Source](C:/Users/Jason/.t3/worktrees/github/t3-e0cda32b-a0fe93f531ff9ff2/private-exports/savia-ux-20261116-astra/mount-probe.mjs).

Reused supplied combined browser 38+20 and demo 71 checks, with inspected test code. No fresh browser, full suite, installs, services, SQL, Docker, real API/payments, physical devices, multi-tab concurrency or CI. Private primary logs were not accessed. Known `WinError 1314` fixture failure was not repeated; primary owns Linux gate and runtime-publication authority.

No product fixes attempted: review authority expressly excludes them. Primary owns F1–F4 and their closure checks. Stop: bounded review complete, three-invocation budget consumed.

Lesson: test recovery through the actual router and demo reset boundary; direct screen mounts do not prove integrated lifecycle behavior.

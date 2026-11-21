# Sale UX candidate — returned with verification limits

Task: sale UX 20261116. Mode BUILD. Primary owns serial integration and acceptance.
Host SUAZO-PC; T3 / Codex `gpt-6.1-sol`, high effort. Usage unknown.
Assigned worktree: `C:/Users/Jason/.t3/worktrees/github/t3-44978f2c-d7f6d1110cd15176`.
Frozen HEAD: `2c96904f49d2df913850bc13cf53b3b03ceebacf`. No commits, staging, pushes or canonical imports.

## Candidate

Changed product paths: `savia/web/screens/sale.mjs`, `savia/web/ui.mjs`, new `savia/web/sale-recovery.mjs`.
New tests: `savia/web/tests/sale-recovery.test.mjs`, `savia/web/tests/sale-ux.browser.mjs`.
Exact original/candidate hashes: [source-bindings.json](source-bindings.json).
No API, CSS, roles, app, history, demo, dependency, SQL or backend changes.

Seller default uses case-insensitive canonical GUID equality with the actor.
Loading, failed, empty and unassigned sellers block additions and charging.
Restored invalid assignments require deliberate reassignment; duplicate garment lines survive.
Native disclosure hides ticket options, line discounts and shared-sale controls.
Errors retain announced text; inline diagnostic buttons work inside existing paragraphs.

Final body is frozen after approval/payment recomputation.
An explicit localStorage record is written and read back before POST.
Its schema allows request fields only, including money/FX/references, and excludes credentials.
Sending and unknown outcomes lock inputs, scanning, parking and further POSTs.
The origin-local marker binds actor, node, branch, location and original till.
Account switches quarantine the record; mounted callbacks check actor, token and mount identity.
Recovery checks the marker before till/catalog/FX work.
Consultar recibo matches sale/cashier/original till and displays server receipt totals plus frozen change.
Unknown lookup stays pending with manager handoff. GET 404 never releases it.
Only an explicit first domain rejection releases a sent attempt. No automatic retransmission exists.

## Evidence

[baseline-race.json](baseline-race.json): actual frozen module, one retained POST; editing quantity 1→2 and received money re-enabled Cobrar. No second POST was sent.
The initial fixture omitted register discovery; corrected it before the retained sale BEFORE captures.
Frozen module snapshot is `baseline.mjs`; only import paths are adapted to the fixture.

- `node --test savia/web/tests/*.test.mjs`: 64/64, exit 0, [suite.txt](suite.txt). Ran before later disclosure/recovery corrections.
- `node --test savia/web/tests/sale-recovery.test.mjs`: final 5/5, exit 0, [recovery-tests-final.txt](recovery-tests-final.txt).
- `python docs/savia-ux-20261116/sale/run-browser.py`: final 38/38, exit 0, [mounted-final.txt](mounted-final.txt).
- `node --check savia/web/screens/sale.mjs` and `git diff --check`: final exit 0.

Mounted checks include denied storage, corruption, loss before/after commit, malformed/empty success, 5xx, 404, permission changes, stale completion, inactive restored seller, duplicate lines, maximum three sellers, supervisor cancel/expiry, approval-adjusted body, separate approval header and ancillary receipt failure.
Node checks exercise actual money/body implementations with split cash/card/transfer/credit, USD/change, references, stock notes and 100% discount.
Existing API tests verify cashier Authorization separately from X-Savia-Approval.
One node run initially failed because its corruption fixture shared a mutable scope object; corrected the fixture and passed the failed path.
Two browser evaluation transport errors were corrected before the retained runs.
Conservative focused-invocation allowance exhausted; no further assertions run.

## Visual evidence and limits

`capture.py`: four WebM recordings and eight PNGs, BEFORE/AFTER at 1440×900 and 390×844.
Matching sequence: select actor seller → add fictional blouse → enter 100 → scroll to Cobrar.
Names: `before-desktop.webm`, `before-mobile.webm`, `after-desktop.webm`, `after-mobile.webm`; PNGs use the same prefixes.
Actual AFTER ticket screenshots visually inspected. One newly inserted non-UTF8 accent was repaired and captures regenerated; logic assertions predate this encoding-only correction. Final syntax/diff checks passed.
Existing SAVIA CSS is unchanged. No invented palette or redesign.

NOT RUN: physical Enter/Space plus scanner-wedge coexistence, final full suite after integration, SQL/API persistence, real payments, production, comprehensive accessibility/performance. Multi-tab storage interleaving is unqualified.
Mocked browser HTTP is not real server evidence. Unknown writes cannot be guaranteed terminal resolution.
Browser session `sale-44978` closed. Loopback server port 58982 stopped (Ctrl-C, server exit 1). No owned resources remain running.

Next action: primary serially integrates these owned files, runs the final full suite and physical keyboard/scanner checks under a fresh allowance, then sends combined bytes to independent Astra/xhigh review.
Lesson applied: Windows default text encoding damaged a new accent; preserve explicit UTF-8 and inspect actual pixels.

# Legacy browser correction

Worker result: **50/50 PASS, exit 0**, Chrome 156.0.8078.80, synthetic HTTP only.
Primary integration and independent acceptance remain pending. No SQL or production proof.

## Scope and source

Task `savia-cash-legacy-browser-correction-39161ef-20261108-01`.
Requested/effective exposed identity: Codex / gpt-6.1-sol / high, T3 Code, SUAZO-PC.
No substitution or nested agents. Tokens and cost are unknown.
Base: `39161ef8c5afcac1f7c9502cc5f38439608a8d70`.
Immutable INPUTS.json RAW: `30fddb277662bc6dcac6e628c879217d13555ec2543a80fab30f52af285ccfed`.
Nine inputs verified before overlay. Eight UI inputs remain RAW/LF identical after execution.
Every final RAW/LF binding is in [RESULT.json](RESULT.json).

Deliver only `tests/browser-mock-validation.mjs` and this directory.
Other worktree differences are required input overlay, not worker product changes.
Canonical checkout, workflows, ledger, Owner work, Git index and external state were untouched.
No commit, stage, push or install.

## Correction

Fresh sales provide tender 300.00 NIO, use `/cash/sales`, strict paid receipts and `cash.sale` recovery.
Pending checks bind original key, path, exact body, rawBody and SHA256.
Double submit, multiarticle body, money validation, session denial, changed identity/version,
held original bytes, no duplicate POST and exact N5 stock changes remain asserted.
Explicit legacy pending/receipt fixtures retain `savia.sale.*`, unpaid recovery and commerce reads.
All original named case declarations remain unchanged; expanded count remains 50.

N5's duplicate context override called setup-scoped `currentActor` outside its scope.
Its route also returned no handled flag. The shared context now uses `tillFor(state)` and actual fixture identity.
The initial N5 run stopped with `Route is already handled!` after two passes.
Removing the duplicate override resolved both defects. Corrected N5 passed 8/8, then full passed 50/50.
Lesson: a fulfilled intercepted route must return handled=true; reuse the shared context.

Cash success receipts are not persisted by the frozen UI after another reload.
`confirmedReload` therefore validates the authoritative paid commerce read and checks no replay;
it does **not** claim automatic cash receipt redisplay. The uncertain first reload still recovers the original
cash operation and displays its receipt. Seeded legacy automatic restore assertions remain.
Primary must review this explicit adaptation before accepting integration.

## Fresh evidence

Five browser invocations; one whole-driver run. No automatic retry loop.

| Run | PASS / FAIL | Exit | Result |
| --- | --- | --- | --- |
| Multiarticle desktop/mobile | 2 / 0 | 0 | Corrected failing cases |
| Initial N5 | 2 / 0 before crash | 1 | Duplicate route handling defect |
| Corrected N5 | 8 / 0 | 0 | Held bytes, fresh stock, legacy and logout |
| Full driver | 50 / 0 | 0 | All original cases |
| Wrong-tender recovery control | 0 / 2 | 1 | Expected failure, both viewports |

Full run: zero uncaught page errors, zero external requests, zero unexpected network failures.
Intentional `net::ERR_FAILED` at cash-sale aborts and `net::ERR_ABORTED` at logout navigation are classified.
The negative control changes only recovered receivedMinor from 30000 to 29999 in a disposable driver.
Both real-browser cases refuse the bad receipt. Main driver and all UI inputs remain exact.

Command prefix: `node tests/browser-mock-validation.mjs C:/Users/Jason/AppData/Roaming/npm/node_modules/@playwright/cli/node_modules/playwright <evidence-directory>`.
Focused selectors: `MARTHA_BROWSER_TEST_MATCH='Multiarticle cart'` and `'N5'`; unset for full.
Negative control substitutes the private disposable driver path.
Private raw JSON/screenshots and disposable code are under this worktree's ignored
`private-exports/legacy-browser-correction-20261108/`. RESULT records exact paths, hashes and commands' selectors/exits.
The output directories were moved from unignored `test-runs/` after completion; original embedded output paths are historical.
Every owned loopback origin was verified closed. All five Node invocations exited; no persistent service remains.

## Acceptance and next action

Checks 1-6: worker-verified within mocked Chrome scope, with the receipt-reload adaptation disclosed above.
The route-handling blocker is resolved by fresh N5 and full proof.
Primary acceptance is pending; its owner is the primary.
Next: review the test delta, integrate serially with the separate privacy correction, then rerun affected checks and both workflows.
SQL5, Docker/.NET, real payments/accounts, CI dispatch, deployment and production acceptance were NOT RUN.

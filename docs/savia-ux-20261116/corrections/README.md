# SAVIA UX: integrated lifecycle corrections

Status: historical 19-path candidate reviewed with one residual P2. The residual is corrected locally; fresh review and acceptance pending.
Base: `2c96904f49d2df913850bc13cf53b3b03ceebacf`.
Previous reviewed Git tree: `72dcf2f00b94f2987691db6915fbf4149b8804b1` (not a commit).
Host/runtime: SUAZO-PC / T3 Code / Codex / `gpt-6.1-sol/max`.
Only fictional data and local HTTP fixtures were used. No SQL or production service was used.

The [second Astra review](astra-recheck.md) closed F1, F2, F4, stale 401 and F3 initialization within limits.
It found an additional delayed catalog lookup that opened the shared size picker after the screen was retired.
[The residual correction](lookup/README.md) adds two lifecycle guards, 7/7 offline cases and 8/8 actual-shell browser scenarios.
Its final web suite passes 98/98; lint checks 65 files. The 91-test results and 19-path manifest below retain their historical meaning.

## Findings and corrections

| Finding | Reproduction and correction | Fresh closure evidence |
| --- | --- | --- |
| F1: shell waits for till dependencies before recovery | Full shell failed to mount recovery with registers/summary held or failed. Venta now mounts its recovery state before those dependencies. | Eight full-shell checks: receipt lookup succeeds with the original identity; no till opening, cash dependency or POST. |
| F2: demo reset leaves its pending sale behind | Original reset erased the fictional receipt but retained the marker. Confirmed reset now clears only an unchanged, valid marker owned by the seeded demo scope. | Cancel preserves all storage; confirmed reset permits role re-entry; a real-origin quarantine marker survives byte for byte. Four checks. |
| F3: an awaited old mount overwrites a replacement screen | Original delayed initialization replaced a new route/account. Route, token and actor generation now guard async mounts, notifications, till writes, scanner handles and session completion. | Three delay stages crossed with navigation/logout/account switch: 18 full-shell checks. Replacement DOM, till, parked ticket and scanner handle remain current. |
| F4: approval redraw enables ticket controls during POST | Original supervisor discount redraw failed the held-POST lock assertion. Every redraw now reapplies the busy lock. | Three mounted checks: all recreated controls stay disabled, body and marker remain identical, and one sale confirms. |

The original 14-check full-shell red run had 11 failures and exit 1. `red.json` preserves that first result.
Its four recovery modes, stale initialization cases and reset failures are actual reproductions.
The final expanded 30-check run is green; the expanded matrix was not all run against the original source.
The F4 red run exited 1 on the recreated-control assertion. Its original raw log is archived privately.

An additional F3-related API race was reproduced after the four corrections: a retired session's 401 could invalidate the new session.
Two new tests held the old response before headers and during error-body parsing. Both failed on the previous implementation, exit 1.
The shared API now notifies unauthorized only when the captured request token still equals the active token.
Logout responses do not trigger global unauthorized handling. Current-session expiry remains covered by the existing contract test.
Both new tests pass inside the final 91-test run.

## Final verification

`CHECKS.json` contains the process receipts and actual log hashes. Raw logs stay in ignored `private-exports/`.
`CANDIDATE.json` binds the 19 source/test paths and the supplied current browser result files.
Git tree identity is supplied separately in the independent review packet to avoid a self-referential manifest.

| Check | Final result |
| --- | --- |
| Web and scanner Node tests | 91/91 PASS; zero failures/skips; exit 0 |
| Existing Biome web gate | 64 files; no fixes; exit 0 |
| Architecture rules | 9/9; exit 0 |
| Demo build | exit 0 |
| Full-shell correction browser | 30/30; exit 0; browser and two servers closed |
| Mounted sale and desktop/mobile keyboard browser | 41 mounted + 20 keyboard checks; exit 0; browser and two servers closed |
| Demo entry browser tests | 3/3 tests with 71 browser checks; exit 0; server stopped |

The mounted sale/keyboard run covers 1440x900 and 390x844. It includes Enter/Space, scan-to-add, explicit seller, cash/change and receipt lookup.
The integration fixtures exercise actual app/router modules with fictional HTTP responses.
These checks establish browser behavior under the observed schedules. They do not establish real persistence, all schedules, multi-tab safety or physical-device acceptance.
Historical worker and primary manifests were retained. `browser-before-corrections.json` preserves the original primary mounted evidence.
The current `primary/browser.json`, demo `real-browser.json` and their screenshots are attributed to the final primary runs.
The first Astra report is copied without editing to `../astra-combined-review.md`.
Its original 88-pass summary has no retained Node exit because its output wrapper failed during Unicode printing. It is not the final primary 91/91 result.

## Remaining boundaries and handoff

| Blocker | Evidence and attempted correction | Owner, next action and completion check |
| --- | --- | --- |
| Independent acceptance | Second review closed the earlier findings except a delayed catalog lookup. The residual correction now passes its reproduced red path. | Primary sends the new immutable tree to Astra/xhigh; close only after adjudicating its findings. |
| Required repository gate on Windows | Existing root check reached three symlink fixture errors, `WinError 1314`. No security setting was changed; the failure was not redundantly rerun. | Primary verifies the existing Linux gate on the exact published SHA. |
| Publication triggers SQL runtime | Existing `savia-v2.yml` starts disposable SQL for a Tony push touching this area. This UX batch has no SQL runtime authority. | Primary resolves the scoped runtime authority before push, then reads back remote SHA and applicable CI. Do not skip or weaken CI. |

No commit, push, merge, deploy, SQL, Docker, account change or new dependency was performed for these corrections.
Unrelated working files and the canonical Git index remain outside the review overlay.
Production readiness, complete accessibility, physical hardware, real payments and real-user usability remain unproven by this increment.

Lesson applied: recover through the full shell and test each awaited session boundary. Keep uncertainty lookup-only and preserve original sale identity.

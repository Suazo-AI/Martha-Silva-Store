# Gallery primary review ? 2026-11-07

Status: AWAITING independent Astra/xhigh recheck. S-LEGACY remains open.
No commit, push, issue write, merge or deployment in this increment.

## Candidate and ownership

- Primary: SUAZO-PC / T3 Code / Codex / gpt-6.1-sol / xhigh.
- Executor: OpenCode `opencode/deepseek-v4.1-flash-free`, requested high; effective reasoning unexposed.
- Frozen worker: `C:/Users/Jason/.t3/worktrees/github/t3-8de63f6e`, base `c5ee743242cb2d360ef4c4e94a61548e1180748b`.
- Integrated candidate: canonical checkout, HEAD `7bce17f65b6a49b64443349d76f3a98b76e4b347` plus the exact overlay in `primary/CANDIDATE.json`.
- The intervening commit changes the staff supply BOM and its documentation. Six gallery sources match the worker under LF normalization (`primary/IMPORT.json`).
- Preserve unrelated modifications to `AGENTS.md` and `docs/DECISIONS.md`. Neither is part of this candidate.
- Native Codex owns the independent SQL campaign. This task did not use SQL, Docker, .NET, services or its test data.

## Earlier rejection

The original judge rejected absence-of-feature assertions, insufficient real-keyboard observations, self-comparing responsive hints, and inaccurate evidence claims.
Report: `C:/Users/Jason/.t3/worktrees/github/t3-e18fd1f5/docs/gallery-contracts-20261107/astra-judge.md`.
RAW SHA256: `50b69c56d7491668a5e104ced4ca297afccfdddcae9f416d12e6eb1d92d239a7`.
The primary independently reproduced the old `sizes=1px` blind spot before correction.

## Worker evidence, kept separate

`RESULT.json`, root `browser-contracts.json`, and `controls/logs/` describe worker invocations.
Worker reports baseline 14/14; bad-sizes 11/14, exit 1; no-activation 4/14, exit 1; Chrome 2/2.
The in-memory controls and their logs were inspected. Worker hashes for all three test/control scripts match.
Root evidence is historical; it is not attributed to the corrected primary browser script.
Two equivalent controls originally had no saved logs. The primary ran and saved them below.
The root README count was corrected from eleven to ten failing cases for 4/14. Raw worker evidence remains in its worktree.

## Primary corrections and fresh evidence

A source read found that the worker browser driver swallowed media-key assertion failures.
The primary removed that catch and now requires media reachability, Space activation, Shift+Tab return, and visible keyboard focus.
The output directory is configurable so fresh evidence does not overwrite historical results.

| Exact command | Result | Evidence |
|---|---|---|
| `node docs/gallery-contracts-20261107/controls/check-variant.cjs tabindex-zero` | 14/14, exit 0 | `primary/tabindex-zero.log` |
| `node docs/gallery-contracts-20261107/controls/check-variant.cjs valid-measured-sizes` | 14/14, exit 0 | `primary/valid-measured-sizes.log` |
| `node tests/gallery-browser-contracts.cjs` | 2 viewports, 0 failures, exit 0 | `primary/browser/browser-contracts.json`, `primary/browser.log` |
| `git diff --check -- tests/desktop-gallery.cjs` | exit 0 | primary command result |

Environment for DOM controls: `MARTHA_JSDOM_PATH=C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules/jsdom`.
Browser: installed Chrome 156, headless. `GALLERY_PORT=18434`; `GALLERY_OUTDIR=C:/Users/Jason/MARTHA-SILVA/github/docs/gallery-contracts-20261107/primary/browser`.
The script closes its Chrome and local HTTP server in `finally`; no unrelated process was stopped.
Fresh runs preserve zoom open/source/Escape/focus-return proof, real keyboard activation, visible next focus after focused-photo scroll, media-key isolation and resource responses.
Desktop: 720w WebP, HTTP 200, 86,518 bytes. Mobile DPR2: 1024w WebP, HTTP 200, 140,962 bytes.
Both runs recorded zero blocked requests, failed requests or HTTP errors.

## Acceptance and remaining work

| Requirement | State and next check |
|---|---|
| Equivalent attributes and resource hints accepted; broken activation and 1px rejected | Worker negatives inspected; primary equivalent controls freshly pass; judge rechecks sensitivity |
| DG01/DG03 focus, DG04 resources, DG06/DG10 native or custom keyboard outcomes | Bounded Chrome evidence present; judge evaluates whether assertions prove the stated contract |
| Geometry, wrap/video, resize, pending navigation, identity and commerce | Fourteen DOM cases preserved; independent review pending |
| Accurate dispositions, artifact binding, gallery screenshots | Worker and primary evidence separated; exact overlay frozen |
| S-LEGACY closure | NOT accepted yet; primary must adjudicate the returned review and update disposition evidence |
| Issue #4 | No write performed. Prepare a concrete disposition body after technical acceptance; retain the repository's external-write gate |
| Publication and integrated checks | NOT RUN; follow serial integration and Tony publication rules after acceptance |

No production-readiness claim, physical-device, screen-reader, Safari/Firefox, native BFCache, full-suite/631, backend/SQL, CI or deployment claim is made here.

## Lesson

A browser test must fail when its required observation fails. Recording an assertion error inside a passing result can hide a regression.
Small primary corrections removed that path and were exercised on both agreed viewports.

Next owner: a fresh independent `gpt-6-astra/xhigh` review of `primary/CANDIDATE.json` and the actual overlaid scripts.
Primary owns final acceptance and continuation; a returned review does not close the overall project.

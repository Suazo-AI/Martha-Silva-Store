# Delayed catalog lookup: final lifecycle correction

Status: locally verified candidate; fresh Astra/xhigh review and primary acceptance pending.
Base: `2c96904f49d2df913850bc13cf53b3b03ceebacf`.
Previous reviewed tree: `4f700e5489f3da5acad5b79be40eb21397f5228d` (not a commit).
Host/runtime: SUAZO-PC / T3 Code / Codex / `gpt-6.1-sol/max`.

## Failure and minimal correction

The [second Astra review](../astra-recheck.md) reproduced a catalog lookup returning after navigation, logout or account switch.
The old callback opened the shared size picker and could take focus from the replacement screen.
This concerns catalog lookup, not receipt recovery. Receipt recovery remains lookup-only.

The primary reproduced the actual defect before changing product code: 1 PASS / 6 FAIL, exit 1.
The active-screen control passed. Three held responses and three retained old-card clicks failed the retired-modal assertion.
The product delta from the previous review is exactly two `if (locked()) return;` guards in `savia/web/screens/sale.mjs`:

- Check again after awaiting `api.lookup(text)`.
- Check before `choose()` can open the shared modal, including retained old-card handlers.

Existing `locked()` includes busy state, unmount and current session/context checks.
The final guard does not rely only on matching the route name.

## Direct proof

| Command | Fresh result | Claim and limit |
| --- | --- | --- |
| `node --test savia/web/tests/sale-lifecycle.test.mjs` | red 1/7 then green 7/7; exits 1, 0 | Actual sale/UI/API/scanner modules; minimal offline DOM; fictional HTTP |
| `node --test savia/web/tests/*.test.mjs savia/web/scanner/scanner.test.mjs` | 98/98; exit 0; zero failures/skips | Final integrated Node regression suite |
| `node node_modules/@biomejs/biome/bin/biome check web` from `savia` | 65 files; exit 0 | Final formatting/static lint |
| `python savia/tools/build_demo.py` | exit 0 | Final demo build |
| `python -X utf8 docs/savia-ux-20261116/corrections/lookup/browser.py` | 8/8; exit 0 | Actual app/router/DOM/modal in Chrome with fictional HTTP |

At 1440x900 and 390x844, the active lookup opens the two-size picker, focuses its control and adds one chosen item.
The other six scenarios hold the lookup, navigate/logout/change account, and wait for its real promise to complete after releasing it.
They compare the replacement screen, operator, token, dialog contents and focus. No sale POST occurs.
The owned browser session and HTTP server are closed in `finally`; both closures are recorded.

`browser.json` contains scenario readbacks. `CHECKS.json` contains process exits, durations and private raw-log hashes.
`CANDIDATE.json` binds final source and artifact bytes. Historical manifests remain unchanged.
Git tree identity is supplied separately to the reviewer, avoiding a self-referential manifest.

Two test setup errors are retained and do not count as product results:
an initial offline fixture awaited an intentionally open modal; an initial browser evaluation returned the intentionally held promise.
The primary corrected test dispatch to continue without awaiting those held operations. Final assertions wait for completion after release.
The browser setup failure has exit 1, zero completed scenarios and a private raw-log hash in `CHECKS.json`.

## Reused evidence and remaining boundaries

The previous 30 shell checks, 41 mounted sale checks, 20 keyboard checks, entry 3/3 with 71 browser checks and architecture 9/9 are reused.
Their original source/result attribution is retained. They were not rerun after these two guards.
The final 98-test suite and eight targeted browser scenarios cover the changed paths and the active-screen control.
The earlier review closed F1, F2, F4, stale 401 and F3 initialization within its stated limits.

| Blocker | Evidence, attempted correction and result | Owner and completion check |
| --- | --- | --- |
| Residual independent acceptance | Actual red reproduced; two guards pass offline and Chrome | Primary: new Astra/xhigh review of the frozen final tree, then adjudicate findings |
| Root Windows repository gate | Earlier `python tests/check.py` reached three symlink fixture errors, `WinError 1314`; no security change or redundant rerun | Primary: verify existing Linux gate on exact published SHA |
| Publishing starts SQL runtime | A Tony push touching this area triggers `savia-v2.yml`; this UX scope does not authorize SQL runtime | Primary/Jason: resolve that execution scope before push; then verify remote SHA and CI |

No new dependency, SQL, Docker, real account mutation, commit, push, merge or deploy was performed.
No new product decision or permission is required for these reversible local corrections.
Real persistence, all possible schedules, multi-tab behavior, physical devices and production readiness are not established here.

Lesson applied: check lifecycle after an awaited response and before mutating shared UI. Verify the resulting dialog and focus.

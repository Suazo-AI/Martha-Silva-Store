# N5-COV browser return ? 2026-11-05

Worker result: RETURNED. Astra/high accepted with two minor findings; primary corrected both. Opus critic and final process acceptance remain pending. No reproduced product defect.
Base: `1e353d45cd0eb2ad8e79589f410ac191c1368b06`.
Host: SUAZO-PC / Windows; Codex harness, gpt-6.1-sol, high reasoning.
Requested and effective model/effort match session runtime metadata. T3 supplied this worktree; worker created no checkout.

## Verified

- Focused N5: 8 PASS, 0 FAIL, exit 0.
- Full browser suite: 50 PASS, 0 FAIL, exit 0, including existing pending-sale, actor/version/scope, 401, CSRF and late-response coverage.
- Staff Node suite: 102 PASS, 0 FAIL, 0 SKIP, exit 0. Count includes nested tests; not 102 business scenarios.
- Chrome 156.0.8078.80, Node v24.18.0. Real Chrome and frontend bytes; mocked HTTP only.
- Both browser runs recorded zero uncaught page errors and zero external requests.
- Six staff entry/module/style SHA256 hashes match focused/full/current bytes. Git product diff is empty; no deletions from the original test harness.
- Both browser commands returned only after browser.close() and server.close() completed. Scoped Node process readback found no remaining browser-mock-validation.mjs process.

## Frozen acceptance dispositions

1. PASS. `N5 held operation recovery...` creates an uncertain sale through a deliberately aborted POST, reloads, and holds the actual recovery GET. Native click and synthetic form submit generate zero additional sale POSTs. Pending raw bytes remain identical, including original key, body and actorVersion. Release yields the original receipt/key, removes pending and leaves exactly one total POST. The initial POST is setup, not a submit during the hold.
2. PASS. `N5 discarded 404 receipt...` waits for actual 404 discard and absence of pending, fills a two-article cart (quantities 2 and 3), and submits one fresh UUID key with the exact price-free body. One POST returns a valid two-line receipt with a new saleId and total 27500 minor units. Server-mocked stock changes from 10/10 to 8/7. A fresh inventory GET and rendered rows are checked. Reload restores only the new reference, with no second POST and no repeat lookup of the obsolete reference. No earlier pending operation existed in this case; new-key proof is one generated UUID on one POST.
3. PASS at the reachable invalidation boundary; same-generation newer-sale race DISMISSED. `N5 late old receipt 404...` holds old receipt GET and observes disabled submit plus zero POSTs after synthetic submit. Native logout starts while GET is held. Its response is held to preserve the same live document. Release old 404 and await response completion plus browser animation turns. The newer cleared/hidden state and retained storage reference remain unchanged. No private receipt/stock reappears. Complete logout, perform native login, and observe second-generation 404 discard and an enabled fresh sale. Storage is never deleted manually to manufacture reachability.

The third case does not claim an old callback ran against a newer pending sale. That constructed state is unreachable through this UI: `app.mjs:544-574` keeps busy true while start awaits restoreReceipt; `app.mjs:445` disables controls; `app.mjs:576-578` rejects synthetic submit while busy/pending. Navigation does not start a second commerce instance (`app.mjs:347-350`). The reachable generation transition is logout (`app.mjs:353-355`), which calls clearPrivateView (`app.mjs:150-152`) then commerce.clear (`app.mjs:461-464`). Logout also increments the HTTP client's epoch (`login.mjs:117`). The old response is rejected by that epoch check before its 404 is processed (`login.mjs:38-39,56`); restoreReceipt rethrows the resulting 401 (`app.mjs:511`). The browser therefore verifies the combined logout protections, not the isolated gone branch or generation guard at `app.mjs:514-516`. We did not call clear/start from a test, delete storage, import/mount a second app, or fabricate newer pending state.

## Commands and evidence

Run from this worktree. Playwright directory is `C:/Users/Jason/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright`.

```powershell
$env:MARTHA_BROWSER_TEST_MATCH='N5'
node tests/browser-mock-validation.mjs C:/Users/Jason/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright docs/n5-browser-20261105/focused
# exit 0, 8/8
# Separate child process, without MARTHA_BROWSER_TEST_MATCH:
node tests/browser-mock-validation.mjs C:/Users/Jason/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright docs/n5-browser-20261105/full
# exit 0, 50/50
$env:NODE_PATH='C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules'
node --test dev/savia-staff-ui/*.test.mjs
# exit 0, 102/102, no skip
```

`focused/browser-results.json` and `full/browser-results.json` contain source hashes, runtime records, assertion details and expected request failures. Logs are sanitized synthetic output. Full suite images are supplemental existing harness artifacts, not visual acceptance.

Focused expected failures: one deliberately aborted sale (`net::ERR_FAILED`) and one logout navigation cancellation (`net::ERR_ABORTED`). Full expected failures: ten aborted sale requests in response-loss/recovery tests and three logout navigation cancellations. No other failed request paths/errors were recorded. The latter cancellations occur during document navigation; neither indicates a failed business assertion.

## Harness issue, lesson and limits

Initial shell redirection failed before Node launched: `Could not find a part of the path` for focused.log. Cause: the evidence parent did not exist. Created the owned directory and invoked the test once. Shortest path: create the log destination before redirecting. All three new scenarios passed on unchanged product on their first actual execution. Teardown took additional time after the last PASS line; we awaited exit 0 rather than inferring completion from the line.

NOT RUN: tests/check.py (broader than this frozen test-only packet), real API, SQL, Docker, physical devices, production, CI, operational acceptance, critic/judge review. No installs, product fixes, commits, staging, push, PR, deployment or canonical checkout writes. No API/SQL/device acceptance is implied. Runtime cleanliness means zero uncaught page errors; this harness does not collect every console message.

No remaining execution blocker. Next: primary independently reviews these exact bytes, obtains approved critic/judge disposition, then integrates serially. Primary owns PLAN.md, ledger, PROJECT-STATUS and publication. Worker report is not acceptance.

## Primary integration and evidence versions

The primary imported the bounded files serially into Tony after Astra's review.
The initial-stock check now compares exact cells `10/0/10` for both articles.
The original worker `RESULT.json`, focused/full results and logs remain frozen.
Their hashes describe the original worker test and README, not the corrected copy.
`worker-test.patch` reproduces that original test from the base SHA;
`worker-README.md` preserves the original README bytes.
`primary-review.md` and the integration verification record distinguish the
corrected candidate's focused rerun from the original 50/50 and 102/102 runs.
No product source changed. Independent critic review remains pending.

## Public evidence package

The first commit attempt was blocked by the existing `.log` filename policy in
`tools/progress.py`. No commit or push occurred during that attempt.
Primary removed all nine raw logs from the index and archived them outside the
repository at `C:/Users/Jason/MARTHA-SILVA/test-runs/n5-browser-20261105/raw-logs/`.
No filter was weakened and no raw log was renamed to bypass it.
[EXECUTION-SUMMARY.json](EXECUTION-SUMMARY.json) records reviewed totals, log hashes
and archive locations. Browser result JSON, command/exit records and synthetic
screenshots remain in the public evidence package. Frozen `RESULT.json` and
`worker-README.md` refer to the original worker checkout; their log paths are not
included in the public package. Completion check: normal hook accepts this
allowlisted package, remote SHA matches and exact-SHA Linux CI is inspected.
Owner: primary. Independent Opus review remains pending.

Exact-source publication/CI follow-up: [PUBLICATION.md](PUBLICATION.md).
The published test source passed Linux portable CI; independent Opus review remains pending.

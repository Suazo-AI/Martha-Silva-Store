# Client session-transition proof

Returned for primary verification on base `030b64f7cba87c6a0d710892deb9a8493ea8bbf4`.
Host: SUAZO-PC. T3 Code / Codex / gpt-6.1-sol, requested and exposed effort high.
Provider billing, tokens, cache and actual internal reasoning usage are unavailable.

`NODE_PATH=C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules node --test dev/savia-staff-ui/session-transition.test.mjs`
passed 13/13, zero failures, skips or cancellations. Initial run also passed 13/13.
Two focused revisions followed: replace microtask-count draining with an event-loop checkpoint;
then assert the real auth rejection separately from the mount guard. Both passed 13/13.
No existing website suite was repeated. Product files remain byte-identical to HEAD.

## Acceptance mapping

1. One combined case seeds sale, supply and stock-review references in the same sessionStorage.
   Outer JSON whitespace is intentional: getItem equality detects normalization or rewriting.
   Original keys, bodies, actor versions and existing actor identity representations survive logout,
   same-account login and destruction/remount of all three real mount modules.
   Sale actor identity uses its existing per-actor storage namespace; no session ID is added.
   The real createStaffClient and its embedded createAuthClient perform every business call.
   A second real createAuthClient performs the login-page exchange against the shared synthetic cookie state.
   Sale remount performs its existing GET recovery, answered 404. No mount sends an automatic business POST.
2. Each operation has an old CSRF-renewal gate and two business-response gates.
   The HTTP gate holds the fetch response until after logout/login and remount.
   The auth layer must reject it as unauthorized before returning it to the mount.
   The mount gate holds a successfully parsed and validated real-client result before delivery to the old mount.
   This isolates each mount generation guard from the auth guard, with the same account/version in both sessions.
   Releasing work preserves the complete current DOM, verified session and sessionStorage, with no extra POST.
   The CSRF gate is released after a new login and must reject without a POST.
   A fresh explicit continuation afterwards must use a new-session token.
   Gates select the interleaving; one setImmediate checkpoint drains their downstream promise continuations.
   There are no elapsed-time sleeps, browser calls or network dependency downloads.
3. Three named cases fail renewal with 503. All three exact pending references remain and no POST is sent.
   A later explicit retry succeeds with its original key/body and a fresh current-session token.
   Two immediate retry clicks produce exactly one POST and one simulated committed key.
   Only that operation's pending reference is removed. The other two remain exact.
4. Eight disposable negative controls produced 14 expected failing test cases, each process exit 1.
   They remove auth/mount guards, automatically resend, rewrite a reference/key, or omit renewal.
   `negative-controls.json` records each exact mutation, test filter, counts, hashes and private log hash.
   `python docs/session-csrf-20261107/client/negative-controls.py` exits 0 only when all eight are detected.
   Each control copies the real modules and test into ignored private-exports and restores the copied bytes in finally.
   The tracked product files are never mutated. Their original bytes are checked again after all controls.

## Limits and handoff

No product defect reproduced. No product fix, staging, commit, push, ledger edit, SQL, Docker,
installation, credential access, security configuration, browser, CI or deployment was performed.
The simulated cookie/session numbers, CSRF tokens and idempotency map prove client behavior only.
They do not prove server CSRF validation, persistent idempotency, SQL writes or production readiness.
Backend 55/55 source-bound framework evidence is historical and was not rerun by this worker.
N8 SQL, real browser/API/SQL journey and Astra/xhigh acceptance remain outside this assignment.

Primary owns independent acceptance and serial integration of the new test and this evidence directory.
Next: inspect these artifacts and verify their hashes on the candidate, then submit the integrated candidate to Astra/xhigh.
Raw logs and disposable fixtures remain ignored under `private-exports/session-client-20261107/`.
Result and compact raw/LF bindings are in `RESULT.json` and `HASHES.json`.

Lesson applied: a stale HTTP response can be masked by a mount guard. Hold a real validated result
at a separate mount boundary, then remove each guard independently to prove the test can observe it.

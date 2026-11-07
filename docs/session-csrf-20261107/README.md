# SEC-CSRF: session protection

Status: implementation and client proof imported; Astra review and SQL acceptance pending.
Source reviewed: `584fcaa6a11a09c1dbdcc97df3205d3e85a0b8d8`.
Host: `SUAZO-PC`. Primary: T3 Code / Codex / `gpt-6.1-sol`, requested/exposed `xhigh`.

## Decision

On 2026-11-07 Jason selected: "Sí: renovar la protección en cada sesión (recomendado)".
After logout and same-account login, a mutation token from the previous authenticated session must fail.
A fresh token for the current session must work. Repeated tokens within one valid session remain valid.
Anonymous login protection, secure cookies, authorization and persisted session checks remain required.

Pending sale, supply receipt and stock review references must retain their original bytes, keys and bodies.
Changing session must not automatically submit or repeat an uncertain write.
This decision authorizes the application change. It grants no SQL runtime, host trust, merge or deployment scope.
It is recorded here because `docs/DECISIONS.md` contains an unrelated uncommitted D-030; that content is preserved.

## Primary adjudication before implementation

The independent [Astra/xhigh review](astra-preimplementation.md) is accepted as a viable design with required conditions.
The original report SHA256 is `6dd379d035edb7d6afe0c060cd4a5bf30a27dec2fc31e0ff75d8d5c727a73ad2`.
The public copy removes only one final empty line to satisfy `git diff --check`.
Its LF SHA256 is `e5fe25f6c223ea7e8b1cb0dc060965979c7f20343b84616596a0fe6b95f58c17`.
Primary verified the report bytes and the existing registration, filters, client renewal and test seams directly.
The report is source review, not an executed regression or independent implementation acceptance.

1. Replace the framework additional-data provider after `AddAntiforgery`; assert the resolved provider type.
2. Bind authenticated tokens to the authoritative single, valid `savia:session` claim; invalid identities fail closed.
3. Preserve anonymous login tokens. Both the common filter and Directory's direct validator must enforce session binding.
4. Keep account, antiforgery cookie and other claims constant in an offline real-framework S1/S2 regression.
5. Preserve existing client behavior unless a test demonstrates a necessary correction.
6. Extend N8 for real same-account login and full-table no-write fingerprints. Keep SQL execution separately gated.

## Frozen acceptance

Offline TestServer uses real antiforgery and ephemeral DataProtection, with fixture-selected principals only.
The stale S1 token must fail under S2 without reaching either mutation handler; this must be red before the provider.
The original S1 token must work under S1; fresh S2 tokens must work repeatedly under S2, including two issued tokens.
Include anonymous, cross-user, missing/invalid/duplicate session claim, mixed identities, old no-additional-data token,
missing/wrong cookie, missing/duplicate header and HTTP controls. Check invalid token generation as well as validation.
Use synthetic fixtures only. Responses and captured logs must not disclose token, cookie, password or invalid-claim values.

N8 must retain all existing controls. With the same account and a new persisted session, reject the old token with 400,
not an authentication/role failure. Compare the complete independent fingerprint immediately around the rejected write.
With a fresh token, the original key/body must produce exactly one expected write, stock effect and explicit replay.
Include Owner/Directory's separate validation path. These SQL checks are prepared, not run without a new exact scope.

Client regression: logout/relogin preserves sale/supply/review references and keys; no automatic business POST;
late old-session replies and CSRF renewals cannot change current state. Mocks prove only their client scope.
Do not add session IDs to idempotency keys or pending reference identity/version fields.

Keep A552/C77/E2 and their historical manifests unchanged. This increment has a new source/build and test inventory.
The local runtime preparer owns different paths and resources; it must not silently consume this new candidate.

## Latest execution diagnosis, 2026-11-07

The GLM worker is now confirmed `interrupted`, with no active run or pending request.
Its worktree at `87ff7991967b2f9f2bd98cf447be5d0e843337c8` is clean; there is no candidate to integrate.
OpenCode's own log records `AI_APICallError: Free usage limit reached.` for `glm-5.3-flash-free`
at `2026-11-07T19:41:33.551Z`. This supersedes the earlier unknown-cause/cancellation-request state below.
T3 recorded successful prompt submission, but did not surface the stream error as a terminal failure before cancellation.
The stopped session export contains zero assistant parts and reports zero input/output/reasoning tokens; billing remains unknown.
Read-only diagnostics used existing T3 traces and OpenCode session export. No raw conversation or private log is published.
[Sanitized observations, limitations, owner and completion check](../completion-20261107/opencode-execution-diagnosis.json).

Primary stopped the stale run and verified the clean checkout. No retry, account change, upgrade or model substitution occurred.
Administrator access does not address this observed upstream rejection. Reset time and other free-model availability remain unknown.
Jason authorized temporary Codex `gpt-6.1-sol/high` execution: "Sí, usar Codex Sol/high temporalmente (recomendado)".
Astra/xhigh remains the sole judge. The executor route changes; implementation and runtime limits remain in force.
Primary also accepted the independent cash design and retained its frozen controls.
Session-CSRF implementation, focused red/green proof and downstream SQL/browser verification remain pending.

## Verification and next action

Verified: report hash; direct source inspection; decision and acceptance recorded. No product bytes changed.
Documentation checks: `python tests/test_delivery_status.py` 24/24; `python tools/delivery_status.py --check`
validates all 39 items; `python tests/test_progress.py` 23/23; `python tools/export_progress.py --verify`
preserves all 15 historical evidence hashes. Every command exited 0.
A scoped comparison confirms only SEC-CSRF changed in the ledger and its `done_when` is unchanged.
The original imported report matched the reviewer hash; its public derivative is disclosed above.
The initial staged check rejected that final blank line; removing it is the only report edit.
`git diff --check` and the staged check passed after that correction.
NOT RUN for this increment: builds, tests, SQL, browser, CI or deployed runtime.
Next: bounded Codex `gpt-6.1-sol/high` implementation in a managed worktree, then primary verification and fresh Astra/xhigh.
Use locally cached dependencies only. Security reproduction must use an OS-enforced, offline sandbox with bounded resources.
If that cannot be provided, preserve the candidate and identify the exact missing control; do not claim a runtime pass.
SQL gate and production remain open. A pre-review cannot close them.

Lesson: hold the account and cookie constant to distinguish session binding from cookie rotation.

## Historical bounded assignment, 2026-11-07

The approved GLM/high assignment was dispatched at `19:38:39.530 UTC` on `87ff799`.
The primary recovered that timestamp from its own recorded dispatch, without polling the running child.
At `20:08:52 UTC`, more than 30 minutes had elapsed since dispatch; the child's exact first-tool start remains unknown.
The primary requested cancellation to bound orchestration time. T3 returned `cancel_requested`, not a terminal result.
No implementation, cleanup, failure cause or free worker slot is inferred from that acknowledgement.
The independent Astra/xhigh cash review has a separate 15-minute budget and was not cancelled.

Owner: primary. Next: consume the supported terminal notification, inspect any returned source and owned-resource cleanup,
then integrate useful bytes or diagnose the failed execution layer before another bounded assignment.
Do not poll or start a replacement while termination is unconfirmed. SQL and production remain unverified.
The session-CSRF acceptance checks above remain unchanged; the project goal stays active.

## Primary integration, 2026-11-07

The Sol/high worker returned four source changes and four public evidence files from `70e7549`.
Primary imported them into canonical `Tony` over `92b9068` after checking destination drift.
All 4 changed-source, 112 compiled-export and 17 unchanged-client LF bindings matched the worker files.
The unchanged export and client inputs also matched the current canonical checkout.
[Exact import receipt](primary-integration.json) includes both CSRF and independent runner imports.

Primary parsed the original private TRX files, rather than relying on their reported labels.
The stale-session regression failed twice before the provider, with unexpected HTTP 204 instead of 400.
The final framework/security run passed 55/55, with zero failed or unexecuted cases.
Both original TRX hashes match the frozen worker result. No security runtime was repeated by primary.
The initial green failure was an anonymous Directory assertion expecting 400 instead of its existing 401;
the worker records that correction separately. The initial failure is not hidden or counted as a pass.

The application now adds the authenticated session claim to framework antiforgery validation.
The client implementation is unchanged. Existing client checks do not yet close the frozen combined
logout/relogin test for sale, supply and stock-review pending references.
Next: complete that focused client proof, then obtain a fresh Astra/xhigh verdict on the integrated candidate.
N8 SQL, a complete real journey, CI for the new SHA and production remain unverified.
No new SQL, Docker campaign, account change, installation, merge or deployment was executed by primary.

Canonical checks completed so far: staff 152/152 with zero skips; local-runner controls 39/39;
`python tests/test_progress.py` 23/23; `python tools/export_progress.py --verify` preserved 15 hashes.
The complete `python tests/check.py` also exited 0: staff 152/152, localization 17/17,
reproducible build, catalog/media, headers, snapshot, portable regressions, HTML and JavaScript checks passed.
The private log and its hash are recorded in the import receipt. No dependency installation was needed.
These are offline checks; none closes N8 SQL or the combined client acceptance gap above.

## Combined client proof, 2026-11-07

Primary imported one new test and five public evidence files from `030b64f`.
The worker is terminal with no active run. Its five unchanged product inputs match canonical LF bytes.
Primary verified all declared artifact hashes and the original private final log hash.
All eight negative-control logs match their recorded hashes and counts: 14 expected failures, each process exit 1.
The disposable mutated files match their original RAW hashes after restoration. Product source was not changed.

Primary ran `node --test dev/savia-staff-ui/session-transition.test.mjs` with the existing jsdom cache.
Result: 13/13 PASS, zero failures, cancellations or skips, exit 0 in 12.032 seconds.
Sale, supply and stock-review references retain exact bytes across same-account logout/login and remount.
Separate HTTP, mount-result and CSRF gates exercise old-session work after the new session is established.
Explicit continuation uses the original key/body and a fresh token; failed renewal sends no business POST.
These assertions use real client and mount modules with simulated HTTP, cookies and persistence.

[Primary import and command evidence](client/PRIMARY.json) keeps historical controls separate from the fresh run.
[Client scope and reproducible controls](client/README.md) records the test limits.
The earlier combined-client gap is now covered locally, subject to independent Astra/xhigh acceptance.
Next: review the frozen integrated candidate. N8 SQL, real browser/API/SQL and production remain NOT RUN.
No new SQL, Docker, installation, account mutation, merge or deployment occurred in this integration.

## Implementation review and N8 correction, 2026-11-07

Astra/xhigh returned REVISE on `6708709`: one P2 in the successful-write SQL oracle, no product-code defect.
Primary confirmed that excluding entire tables could hide unrelated row changes.
The [original judge report](astra-implementation-judge.md) is preserved byte-for-byte.
The client's fresh 13/13 and historical negative controls are accepted within their simulated-HTTP scope.

Primary replaced the exclusions with identified insert rows and one precisely normalized stock change.
Fresh build and focused oracle/schema checks: 33/33 PASS, zero skips, exit 0.
The controls reproduce the old blind spot and detect existing-row corruption under the new projection.
[Source-bound correction, exact counters and remaining gates](n8-correction/README.md).

The full repository check on `6708709` also passed: exit 0, 405.609 seconds.
It precedes the C# test-only oracle correction and is recorded separately in [client PRIMARY](client/PRIMARY.json).
Next: fresh Astra/xhigh recheck of the correction. Real N8 SQL remains NOT RUN; production remains NO-GO.

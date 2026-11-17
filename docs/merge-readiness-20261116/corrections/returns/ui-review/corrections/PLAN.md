# Return UI correction contract

Base: `ba8ff2ba10935e99fc268ebbe5eae130f72c1cca`. Primary: T3/Codex on SUAZO-PC.
Mode BUILD. Objective: make the frozen durable-return candidate usable without releasing uncertain financial operations.

## Primary disposition

Adopt F1–F5 from [the independent review](../astra-ui-review.md).
The primary inspected the actual helper, recovery/send path and API response handling.
The reviewer reproduced F1 and four F2 variants. F5 remains a source-derived finding.
This disposition authorizes bounded local corrections, not runtime or production acceptance.

F1/F2 are product defects in the unaccepted overlay. F3–F5 are recovery, usability and temporary-session defects.
The existing SQL fixture revision remains independent. V029 must not change in this UI task.

## Frozen input and ownership

- `../REVIEW.json`: SHA256 `d35556e6c3f05eaa405c44efa6fc633b8b2a670eb3acfa14e6c39f3aacf4f95d`.
- `../review-overlay.zip`: SHA256 `a80eeb8f2ef8ccb0222cdab1035ac22c11ed2209919998a66d2954695f5dcfe8`.
- Verify the archive and its exact eight entries before extracting into the managed worktree.
- Mutation scope: `savia/web/api.mjs`, `savia/web/screens/return.mjs`, `savia/web/screens/return-intent.mjs`, `savia/web/tests/return-lifecycle.test.mjs`.
- Additional focused return/API test files under `savia/web/tests/` and one focused browser test under the owned evidence directory are permitted.
- Preserve the other four overlay files exactly: `app.mjs`, `uuid-logic.mjs`, `screens/sale-logic.mjs`, `tests/uuid.test.mjs`.
- Evidence belongs only under `docs/merge-readiness-20261116/corrections/returns/ui-review/corrections/worker/`.
- Primary performs serial integration and final acceptance. No canonical product edits by the worker.

## Acceptance checks

1. Complete an initial and explicitly replayed exchange from a strictly validated acknowledgement of the captured POST. Require HTTP 200, exact endpoint/body and the still-owned durable record under its exclusive lock. GET alone must never confirm an exchange.
2. Share strict reversal validation across ordinary GET and POST acknowledgement. Require an object, exact identities/kind/status/outcome/reason/currency, positive safe-integer total, exact unique unordered line identities/quantities/pools/amounts, appropriate credit ID, valid timestamp and valid actor/supervisor IDs. Validate currency against authoritative data captured before dispatch. Do not invent missing expectations for older records.
3. Independently reject malformed kind, currency, actor and timestamp. Also reject unsafe or mismatched amounts, duplicated/extra/missing lines, wrong credit/till/reversal IDs, invalid supervisor and wrong HTTP status. Valid ordinary credit/cash/transfer returns must still complete. A different currently authorized replaying supervisor need not match the original approver.
4. Cancel only an exactly owned, never-sent draft under its exclusive lock. Verify removal before re-enabling edits. Support draft remount. A competing tab, late confirmation or late approval cannot submit a cancelled attempt. Never offer discard for sending/unresolved, including after 404, rejected replay, timeout or navigation. Persist sending before POST.
5. Derive monetary confirmation from immutable captured data. Show returned amount/outcome, exchange due/back and tender/reference. After verification retain monetary results and receipt links across reload. Optional cash/stock refresh failure cannot invalidate a verified acknowledgement. Preserve keyboard activation and ordinary return behavior.
6. Track temporary approval at mount scope. Begin single-shot revocation on retirement and terminal paths without waiting for held POST/lookup. Revoke late approval tokens. Report cleanup failure without persisting or exposing credentials. Test held requests and failed logout.
7. Preserve exact durable body/IDs, owner scope and readback, Web Locks, recovery before dependencies, all navigation/account/session fences, foreign-scope privacy, and legacy recovery. Storage errors/competition cannot silently clear or regenerate an uncertain intent. No automatic POST.
8. Reproduce old failures with focused checks, then run affected tests and one final complete `node --test savia/web/tests/*.test.mjs`, with exact exit/counts and zero unexplained skips. Include targeted negative controls that detect the changed protections; restore source bytes exactly.
9. Attempt real-browser before/after evidence of this local candidate using existing dependencies only. Use fake HTTP, desktop/mobile and keyboard. A synthetic DOM is not browser proof. If tooling is absent, record exact prerequisite and do not install or claim visual acceptance.
10. Bind all final source and evidence paths with RAW/LF hashes. Preserve SQL/product paths outside ownership, HEAD and index. Report every unresolved check and its next action.

## Limits and stop conditions

Executor: `codex/gpt-6.1-sol`, explicit `reasoningEffort: high`, managed worktree. No nested delegates.
Budget: current approved subscription allowance; no paid API calls. Maximum 60 minutes, ten focused test invocations, one final complete web suite, and two browser scenario invocations. Syntax/hash/diff checks do not consume test invocations. Preserve failed evidence; no blind retries.
Use existing installations only. No network dependency installation, SQL, Docker, services outside owned loopback test servers, workflow dispatch, commit, push, merge, deploy or external messages.
Before changing the UI, follow the existing UI evidence rule. Never label reconstructed before evidence as original.
Stop at acceptance, budget, uncertain billing, denied access or a prerequisite that cannot be resolved within this scope. Save the exact checkpoint.

## Backend dependency

The exact-POST route is conditional on installed V029 and its atomic immutable financial identity.
SQL runtime must separately prove authorization before replay, zero-write equivalence/conflict, closed-till replay, contention and rollback of all financial rows.
UI tests cannot close that dependency. SQL runtime remains NOT RUN and needs its own authorized packet.

Lesson applied: recovery needs an authoritative completion route as well as protection against uncertain outcomes.

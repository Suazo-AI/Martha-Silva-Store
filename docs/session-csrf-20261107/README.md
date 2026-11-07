# SEC-CSRF: session protection

Status: decision adopted; implementation and runtime acceptance pending.
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
Next: bounded OpenCode/DeepSeek high implementation in a managed worktree, then primary verification and fresh Astra/xhigh.
Use locally cached dependencies only. Security reproduction must use an OS-enforced, offline sandbox with bounded resources.
If that cannot be provided, preserve the candidate and identify the exact missing control; do not claim a runtime pass.
SQL gate and production remain open. A pre-review cannot close them.

Lesson: hold the account and cookie constant to distinguish session binding from cookie rotation.

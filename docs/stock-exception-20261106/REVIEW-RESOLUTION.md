# Stock review corrections after Gemini REVISE

Source reviewed by Gemini: `e48b5accd6ba45473e64a949e993db497ed93b1e`.
Primary: SUAZO-PC, T3 Code / Codex, `gpt-6.1-sol/xhigh`.
Status: corrected candidate awaiting Astra adjudication and exact-SHA Linux CI.
Production remains NO-GO. No SQL, Docker, deployment or certificate changes occurred.

## M1: disputed business interpretation; server policy preserved

D-027 requires a reviewer different from the person who registered the exception.
It separately requires a responsible person and next review date for unresolved causes.
It does not restrict that follow-up person to Owner/Manager or exclude the cashier.

The server restricts the **reviewer** to Owner/Manager and rejects self-review, including Owner.
It requires the **follow-up responsible actor** to be enabled and authorized for the sale location.
These are separate actors with separate checks.

Gemini's proposed extra role and different-person restriction for the follow-up actor is not adopted.
No server authorization was weakened. The original REVISE report is preserved unchanged.
Astra must adjudicate this objection against D-027 and the direct server code.

Sources: `docs/DECISIONS.md` D-027; `InternalStockExceptions.cs:72-85`;
`InternalCommandRunner.cs:32`; `InternalBranchAccess.cs:27-35`.
The original frozen acceptance check 3 is unchanged.

## M2: reproduced and corrected

Two regression tests failed against the original product: invalid responsible UUID and past review date reached transport.
Chrome also demonstrated the invalid-UUID HTTP 400 lockup on desktop and mobile before product edits.

New submissions validate fields and future review dates before writing a pending reference.
Invalid fields stay editable and produce no POST or pending reference.

A 400/403/404/409 response alone never proves that an earlier attempt had no effect.
The client queries the existing operation endpoint with the same actor, scope and idempotency key.
Only a completed, structurally valid rejection releases the pending reference for correction.
The command runner rolls back rejected actions to its savepoint before recording that outcome.
A corrected submission gets a new key.

A matching committed outcome instead confirms the original review.
Missing, denied, malformed or mismatched outcomes preserve the original pending bytes and key.
This conservative state needs an authorized operator to restore access or reconcile the original operation.
No manual-storage-deletion button or automatic abandonment was added.

Retries accept a once-valid review deadline after it passes, so an older committed review remains recoverable.
Session invalidation still prevents late success or late rejection from removing pending state.

## L1: response contracts corrected

Shared validation checks review IDs, actor IDs, evidence, outcome, open cause and review dates.
List reads reject malformed entries and duplicate review IDs.
POST and recovered success must match the original line, reviewer, evidence, outcome, responsible actor and date.
The UI uses the same validator before acknowledging a review.

## Fresh evidence

| Check | Result | Boundary |
| --- | --- | --- |
| Original invalid-field regression tests | 2 failures, exit 1 | Product negative signal, after fixing NODE_PATH |
| `node --test dev/savia-staff-ui/*.test.mjs` | 146/146, zero skipped, exit 0 | Final staff sources; jsdom and simulated transport |
| `node docs/stock-exception-20261106/primary/browser-review-before.mjs <installed-playwright>` | Desktop/mobile lockup observed, exit 0 | Actual Chrome; original product; HTTP mocks |
| `node docs/stock-exception-20261106/primary/browser-review-after.mjs <installed-playwright>` | Desktop/mobile corrected flow, exit 0 | Actual Chrome; final product; HTTP mocks |

Each corrected Chrome flow verifies invalid-field editing, durable rejection, correction, response loss and reload recovery.
One sale POST and three review POSTs produce one simulated review: rejected attempt, lost success, exact replay.
No page exceptions, external requests or horizontal overflow were observed.

Before and after recordings use the same viewports and the same sale-to-review path.
The after sequence adds the repaired branches, so these are not identical timed replays.
Selected recordings and source bindings are listed in [REVIEW-CHECKS.json](primary/REVIEW-CHECKS.json).

Harness/environment failures are retained in private logs: omitted NODE_PATH, an early request-count assertion and a PowerShell encoding error.
They are not counted as product negative controls. A metadata script also stopped on `KeyError: additional_checks`; the receipt-only correction completed afterward.

Historical Linux runs `42183825853` and `42183825849` both succeeded on exact SHA `e48b5ac`.
Those runs do not cover the corrected UI. Fresh CI must bind the new published SHA.
The Windows aggregate gate has the recorded symlink-fixture `WinError 1314`; use automatic Linux CI without changing host security.

## Remaining gates and next action

- Primary publishes only the listed source/evidence paths to Tony and verifies remote SHA.
- Astra rejected M1 and confirmed the M2 recovery design on `45aba76`, then required J1/J2 corrections below.
- Targeted independent review must confirm those corrections against the new frozen sources and unchanged acceptance checks.
- Primary reads completed no-SQL Linux CI for that same SHA before accepting preparation.
- Real SQL persistence, concurrency and browser/API/SQL remain NOT RUN for this increment.
  The earlier one-run runtime authorization is consumed. After review, primary prepares one exact campaign for Jason's approval.
- Existing legacy malformed or inaccessible pending records remain an operator reconciliation task; uncertain outcomes must not be discarded.
- C2, C9, C10, payment integration and operational acceptance remain separate. This report closes none of them.

Lesson applied: a reviewer must separate a reproduced defect from an added business-policy assumption.
Validate before persisting intent; use durable server evidence before releasing uncertain work.

## Astra J1/J2 corrections

Primary accepts the [Astra REVISE report](astra-judge-candidate.md) on `45aba761a9bc3d9faa6a1e940368df07af9770bf`.
Its M1 disposition resolves the policy dispute: the follow-up responsible person need not be the reviewer or have the reviewer's role.
Backend authorization remains unchanged.

J1 reproduced: a valid uppercase UUID was rejected when a successful response used lowercase.
Two additional tests reproduce an existing uppercase pending request failing direct replay and completed-success recovery.
J2 reproduced: unrelated or ordinary sale-line reviews were displayed under the requested sale.
The focused red command produced five failures and one passing control, exit 1:

`node --test --test-name-pattern='UUID equality|uppercase pending|review list' dev/savia-staff-ui/stock-exception.test.mjs`

`client.mjs` now compares validated line, reviewer and responsible UUIDs semantically.
It preserves the original request body and idempotency key exactly, including case.
Different UUIDs still fail validation. No pending-record migration or manual storage deletion is required for valid uppercase requests.

`app.mjs` binds listed reviews to exceptional lines in the loaded sale before displaying evidence.
It clears prior evidence and selected lines during lookup, so failed validation cannot leave an earlier sale presented as the new result.
Multiple exceptional lines, case variants and historical reviewers remain valid.

`NODE_PATH=tests/frontend-deps/node_modules node --test dev/savia-staff-ui/*.test.mjs` completed **152/152**, zero skips, exit 0.
The actual Windows invocation and private raw-log hashes are in [JUDGE-CHECKS.json](primary/JUDGE-CHECKS.json).

The same browser driver ran before and after the product change at 1440x1000 and 390x844.
It captures an uppercase request, simulated response loss, reload, exact replay, foreign/ordinary list rejection and valid historical reviews.
Before: both defects observed. After: confirmation succeeds and invalid lists remain hidden.
Both runs recorded zero page exceptions and zero external requests. Chrome and fixture servers closed.
Replay observation waits for the response body and two frames; it does not prove every possible scheduler ordering.
Unit tests independently cover direct and recovered success and exact pending identity.

One initial before-browser attempt checked the POST count before the asynchronous retry reached the route.
The driver now installs the response wait before clicking. That harness failure and its partial recording are excluded from product red evidence.
The successful before recording is the original product, not a reconstructed baseline.
Four selected recordings and source hashes are bound in the receipt; no raw logs or failed clips are published.

Predecessor Linux CI `42186722956` and `42186722928` completed successfully on `45aba76`.
The new published SHA still needs completed no-SQL CI and targeted Astra review.
SQL persistence/concurrency and real browser/API/SQL remain NOT RUN for this increment.
Primary will prepare the exact isolated campaign after acceptance; Jason must authorize that new runtime.
Production remains NO-GO. No deployment, migration apply, trust change, real data or payment occurred.

Lesson applied: validate identifier identity separately from identifier spelling; preserve retry payload bytes.

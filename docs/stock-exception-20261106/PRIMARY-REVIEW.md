# Stock exception candidate: primary review

Status: REVIEW. This freezes implementation for independent advice. It does not accept STOCK-EXCEPTION, TECH-TRIAL or production.

Base: `9597f19d0e1621c2b3984f8bf8878a0f7d58d906`. Primary: SUAZO-PC / T3 Code / Codex / gpt-6.1-sol / xhigh.
Worker: Sol/high in T3-managed t3-92a93a5c. The primary verified all 31 returned RAW source hashes and canonical preimages before serial import.

## What changes

A cashier can record physical delivery with available stock 0 only by entering a reason and size. The sale retains quantity, SKU, location, actor and timestamp. The transaction creates no fictional receipt, cost, balance or movement. Ordinary stock guards remain.

A different authorized Manager or Owner records review evidence, outcome, responsible actor and a future review date. The cause stays open. The server rejects self-review, including an Owner. Reviews are append-only. IDs remain manual inputs in this technical trial.

## Primary correction and evidence

The primary found a replay regression in the returned request DTO. Added nullable fields changed the fingerprint of an ordinary sale. The legacy-format comparison failed before correction (1 failed, exit 1). Conditional null-field omission now preserves the old fingerprint while binding non-null exception fields. The subsequent backend suite passes. No generated migration bytes were hand-edited.

Primary also added a manual, default-false `stock_exception` workflow input. It requires `supply_receipt=true` before runtime starts. Both new flags remain false on automatic runs. This prepares execution; it grants no runtime authorization.

Primary verification:

| Check | Result | Boundary |
| --- | --- | --- |
| `dotnet test backend/tests/Martha.Store.Api.Tests --no-restore --filter 'Category!=SqlServer'` | 543 passed, 58 skipped, exit 0 | No SQL; skips are not passes |
| `node --test dev/savia-staff-ui/*.test.mjs` | 133 passed, 0 skipped, exit 0 | DOM / mocked HTTP |
| `python -m unittest discover -s tests -p 'test_golden_path*.py'` | 46 passed, exit 0 | Offline protocol, refusal and cleanup checks |
| `dotnet build tests/golden-path/GoldenPath.Sql --no-restore --configuration Release` | exit 0; 0 warnings/errors | Compilation only |
| `node docs/stock-exception-20261106/primary/browser-stock-record.mjs <installed-playwright>` | desktop1440x1000 and mobile390x844 PASS | Actual Chrome; mocked HTTP; no SQL |

The Chrome run loses a sale response and recovers after reload with one sale POST. It loses a review response and retries the same key/body: two review POST attempts produce one simulated review. No page errors, external requests or horizontal overflow were observed. Recordings show the candidate after integration. No before-change recording was captured; this is an explicit process gap, not a reconstructed baseline.

The first primary release-check invocation omitted `SAVIA_PILOT_EVIDENCE` and failed with `Worker evidence path required`. An explicit private evidence directory resolved that environment failure; the full no-SQL run above passed.

Historical worker evidence remains separate: backend542/79 skipped; staff133; harness44; four negative controls killed and exactly restored. Worker browser50/50 and supply8/8 describe earlier UI bytes. They are not reruns of the integrated candidate. The worker's final feature-specific Chrome run binds its final UI bytes.

## Frozen acceptance checks for independent review

1. No artificial inventory, cost, receipt or movement; ordinary balances and reservation guards stay intact.
2. Exceptional sale, returns and cancellation stay atomic and idempotent. Ordinary pre-upgrade replay keeps its fingerprint.
3. Review requires another authorized actor, branch access, evidence, outcome, responsible authorized actor and future review date. Appended evidence cannot be edited or deleted.
4. UI preserves exact pending key/body, rejects duplicate submits and mismatched receipts, and ignores late replies after session invalidation.
5. Migration and release script match the generated model and preserve old business rows. No migration has been applied here.
6. Existing 17 real-browser checkpoints and four identity oracles remain. Five new checkpoints inspect exception/review accounting and identity. SQL tests are prepared, not executed.
7. Workflow inputs are explicit and default false; invalid combinations refuse before Docker/API/SQL. Existing cleanup and evidence sanitization gates remain.
8. Every claim binds to current sources or is labeled historical, mocked, skipped or NOT RUN.

## Blockers and shortest routes

| Blocker | Evidence / correction attempted | Owner and completion check |
| --- | --- | --- |
| SQL persistence, concurrency and combined journey | Not executed: earlier one-run runtime authorization is consumed. Three new SQL tests and a 22-checkpoint browser journey are prepared. | Primary freezes/reviews, then Jason authorizes one exact campaign. Require zero relevant SQL skips, SQL identity/accounting oracles and verified cleanup. |
| Windows repository gate | Worker ran once: three symlink-fixture errors `WinError 1314`; no privilege or security changes. | Primary checks automatic no-SQL Linux CI on the exact published SHA; full applicable gate must exit 0. |
| Independent acceptance | Worker returned, primary found and fixed a regression; no critic/judge has accepted these bytes. | Gemini Argon/high critic, then Astra/high judge. Primary resolves material objections and owns final acceptance. |
| Before-change video absent | Primary captured after-only desktop/mobile recordings; no invented before evidence. | Primary retains the limitation. Capture a real baseline before any later UI change. |
| Cache deletion blocked | Automatic approval rejected local cache deletion with `blocked by policy`. Caches stay ignored and were excluded from import. | Contained; no deletion bypass or additional permission required. |

Production remains NO-GO. This increment does not close C2, C9, C10, payments, deployment or operational acceptance.

[Import map](IMPORT.json) preserves public copies and private raw-log locations. [Current source bindings](CANDIDATE.json) use RAW and LF hashes. Original worker receipts remain unchanged. Primary logs and commands are indexed in [primary/CHECKS.json](primary/CHECKS.json).

## Follow-up after Gemini REVISE

The original [Gemini report](gemini-critic-candidate.md) remains unchanged.
Primary reproduced and corrected the invalid-field pending lockup and added strict review contracts.
The responsible-person role restriction is disputed because D-027 distinguishes that person from the independent reviewer.
Server policy is unchanged pending Astra adjudication.

Fresh staff results: **146/146**, zero skipped. Actual Chrome desktop/mobile verifies the corrected review path with HTTP mocks.
Before/after recordings, original failures, conservative 4xx reconciliation and remaining gates are in [REVIEW-RESOLUTION.md](REVIEW-RESOLUTION.md).
The old backend and harness counts above remain historical. They were not reattributed to these changed UI bytes.
Preparation remains under review; production remains NO-GO.

## Follow-up after Astra REVISE on 45aba76

The original [Astra report](astra-judge-candidate.md) is imported byte for byte.
Primary accepts its rejection of M1: D-027 distinguishes the independent reviewer from the follow-up responsible person.
No backend authorization policy changed.

Primary reproduced J1/J2 with five failing assertions and one passing valid-list control.
UUID matching now compares validated identities without case sensitivity and does not rewrite persisted pending bytes.
Reviews must belong to an exceptional line of the loaded sale before evidence is shown.
The view clears earlier evidence when another lookup begins.

Final staff: **152/152**, zero skipped. Chrome desktop/mobile verifies the same before/after actions with synthetic HTTP.
Both direct replay and completed-success recovery confirm existing uppercase pending requests in unit tests.
Different IDs remain rejected; historical reviewers and multiple exceptional lines remain accepted.

Linux CI runs `42186722956` and `42186722928` succeeded on predecessor `45aba76`.
They do not cover J1/J2. New exact-SHA CI and targeted independent adjudication remain pending.
See [resolution](REVIEW-RESOLUTION.md) and [receipts](primary/JUDGE-CHECKS.json).
SQL, real browser/API/SQL, C2/C9/C10 and production acceptance remain open.

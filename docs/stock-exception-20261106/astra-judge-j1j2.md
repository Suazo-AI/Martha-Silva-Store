# ACCEPT WITH LIMITS

Task: `savia-stock-judge-j1j2-139c389-20261106`. Mode: VALIDATE. Date: 2026-11-06.
J1/J2 are closed within the reviewed frontend scope. Primary retains final acceptance after exact-SHA CI. Production remains **NO-GO**.

Source: `139c3898d1e76e66a07b89f179e50508672df473`, verified managed-worktree HEAD.
Predecessor: `45aba761a9bc3d9faa6a1e940368df07af9770bf`.
Host: SUAZO-PC. Harness: T3 Code / Codex.
Requested: `codex / gpt-6-astra / reasoningEffort high`.
Runtime-exposed effective model/effort: `gpt-6-astra / high`, from runtime context and awareness metadata. Internal computation is not independently observable.
Usage tokens/cache/reasoning/USD: unknown; no receipt exposed.
Checkout: `C:/Users/Jason/.t3/worktrees/github/t3-65da3d75`.

## Disposition

**J1: ACCEPT.** `client.mjs:100,114-118` compares validated UUID identities case-insensitively. It does not mutate requests or persisted records. Line, reviewer and responsible-actor case variants pass; genuinely different identities fail.

The two seeded uppercase-pending tests exercise actual client transport and UI recovery after response loss. Direct replay and completed-success lookup both confirm. Both POST attempts retain the original key and JSON body exactly. Pending storage remains byte-identical while uncertain, then clears only on matching confirmation.

**J2: ACCEPT.** `app.mjs:658-669` clears previous evidence and selected lines when lookup begins. Before rendering, every returned review must belong to the loaded sale's exceptional-line set, using case-insensitive identity. Foreign and ordinary lines fail with an empty evidence panel and disabled submission. Multiple exceptional lines and historical reviewers pass. Existing receipt validation supplies valid line UUIDs; review validation precedes membership checks.

**M2 and guards: preserved.** The diff leaves durable-rejection reconciliation, original-key lookup, role guards, actor/version checks and late-response protection unchanged. Focused tests freshly pass uncertain 400/403/404/409 retention, malformed/mismatched recovery, corrected fresh-key submission, duplicate submission, and late success/rejection after invalidation. J2 lookup cannot execute while pending and cannot release pending state.

**M1 remains rejected.** Backend policy is unchanged. Reuse the predecessor's adjudication; no new responsible-person role restriction is introduced.

No material objection remains within J1/J2. This is advisory frontend acceptance, not integrated persistence proof.

## Frozen checks

1. Unchanged; reuse accepted static inventory/accounting and reservation-guard review. No expanded reservation-policy claim.
2. Unchanged; reuse accepted atomicity/idempotency design and legacy-fingerprint checks. SQL proof remains NOT RUN.
3. Unchanged; reuse authorized independent-reviewer, branch-access and append-only review checks, including M1 disposition.
4. Previously REVISE; now PASS within focused DOM/mocked-HTTP evidence. J1/J2 are corrected without weakening pending identity or invalidation guards.
5. Unchanged; reuse static model/migration/release bindings. Migration application remains NOT RUN.
6. Unchanged; 17 existing checkpoints/four identity oracles plus five stock checkpoints remain prepared. SQL tests remain NOT RUN.
7. Unchanged; reuse explicit default-false workflow inputs, prerequisite refusal, cleanup and sanitization review. No dispatch occurred.
8. PASS with boundaries below. All 33 LF bindings independently match HEAD blobs and current files.

## Evidence and limits

Fresh judge command, exit 0: `node --test --test-reporter=tap dev/savia-staff-ui/stock-exception.test.mjs`, with `NODE_PATH=C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules`. Result: **28/28, zero failures, zero skips**. Inspected assertions and direct implementation, not only test names.

Reused primary evidence from `primary/JUDGE-CHECKS.json`: all five raw-log hashes and four recording hashes match. Direct log inspection confirms focused red **5 failed/1 passed** and final staff **152/152, zero skipped**. The initial browser request-count timing failure remains excluded from product-red evidence.

Both browser result documents and the original judge report match their recorded RAW hashes as Git blobs. Local CRLF checkout copies differ in RAW hashes but match after LF normalization. All ten before/after browser source bindings match their respective Git sources, including documented CRLF expansion for HTML.

Inspected browser driver and result data: same actions at 1440x1000 and 390x844, two attempts, one simulated review, uppercase recovery and invalid-list rejection. These are primary-run actual-Chrome/HTTP-mock observations. Recordings were hash-checked, not visually replayed. No browser/full-suite rerun by this judge. A log-summary UnicodeEncodeError was resolved by ASCII-safe output; no product failure or security change.

CI `42188326094` and `42188327840` was in_progress at dispatch; not queried or claimed passed. Predecessor CI does not transfer. Primary must verify completed applicable results against this exact source SHA before acceptance.

SQL persistence/concurrency and real browser→API→SQL remain **NOT RUN**. Prior SQL authorization is consumed. Primary must prepare the exact isolated campaign; Jason must authorize it before execution. Require SQL identity/accounting proof and verified cleanup. C2/C9/C10, payments and production remain open/NO-GO. No Docker/API startup, migration, deployment, trust change, real data or external message occurred.

Only created path: `docs/stock-exception-20261106/astra-judge-j1j2.md`. SHA-256 accompanies the handoff to avoid self-reference. No children, installs, index changes, commits or pushes.

Next action: primary imports this report serially and reads exact-SHA CI. Lesson applied: compare UUID identity semantically while preserving retry bytes exactly; bind displayed evidence before rendering.

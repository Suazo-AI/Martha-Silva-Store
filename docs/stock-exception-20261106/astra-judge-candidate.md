# REVISE — independent advisory judgment

Task: `savia-stock-judge-45aba76-20261106`. Date: 2026-11-06.
Primary retains final acceptance. Production remains **NO-GO**.

Frozen source: `45aba761a9bc3d9faa6a1e940368df07af9770bf`, verified as managed checkout HEAD.
Reviewed predecessor: `e48b5accd6ba45473e64a949e993db497ed93b1e`.
Host: SUAZO-PC. Harness: T3 Code / Codex. Model: `gpt-6-astra`.
Requested reasoning: high. Effective reasoning: high reported by runtime context and awareness metadata; provider-internal computation is not independently observable.
Checkout: `C:/Users/Jason/.t3/worktrees/github/t3-f68619bd`.
Usage tokens/cache/reasoning/USD: unknown; no usage receipt exposed.
No children, installs, index changes, commits, pushes or runtime dispatches.

## Verdict and findings

**M1: Gemini objection rejected.** D-027 (`docs/DECISIONS.md:172-176`) requires a different reviewer. It separately requires a responsible person and next review date. It does not require that follow-up person to be Manager/Owner or different from the cashier.

`InternalStockExceptions.cs:69-90` rejects sale-actor self-review and requires location access for the responsible actor. `InternalBranchAccess.cs:27-35` requires an enabled actor and applicable branch access. `InternalCommandRunner.cs:32,61-73` restricts execution to Manager/Owner and revalidates the persisted session within the transaction. No backend change for M1 is warranted. Frozen check 3 is preserved.

**M2: original invalid-input defect corrected; recovery design sound within its stated limits.** `app.mjs:668-674` validates UUID/text/date and future time before persisting intent. Raw 400/403/404/409 cannot release it. `client.mjs:74-84` queries the original key at `GET /internal/api/operations/commerce.stock.review` and requires a completed failed envelope with null value before signaling rejection.

`InternalHosting.cs:59-74` binds lookup to current actor, scope and key, with current role and branch authorization. `InternalCommandRunner.cs:103-123` rolls failed actions back to the savepoint, clears tracked changes, then commits only the durable failure record. Pre-action denials and interrupted commits do not establish that durable rejection. The client correctly retains those uncertain attempts.

Once-valid past-now requests remain replayable: server replay precedes the action's future-date check; frontend request validation does not reject past dates during replay. `app.mjs:635,649-657` prevents late success/rejection from removing pending state after invalidation. Unknown, denied and malformed recovery retain original bytes. Corrected submissions generate a fresh key only after proven rejection. However, the new validator introduces the following blocking defect.

**J1 — Medium, REVISE: valid uppercase responsible UUID becomes an unrecoverable UI pending review.**

Evidence: `client.mjs:99` accepts UUIDs case-insensitively, but `readStockReview`, lines 113-116, compares identifier strings case-sensitively. `app.mjs:670` preserves manually entered UUID case. The backend request and response use `Guid` (`InternalStockExceptions.cs:19,26`), whose normal serialized spelling is lowercase.

Direct adversarial execution used the actual client and jsdom UI with synthetic HTTP. Input `ABCDEFAB-0000-0000-0000-000000000088` passed validation. A successful response containing `abcdefab-0000-0000-0000-000000000088` produced `response`, not confirmation. After HTTP 200: `posts=1`, `pending=true`, form disabled. After reload/replay: `posts=2`, pending unchanged, identical key and body, still unconfirmed. Separate client probes rejected both direct success and completed-success recovery. These probes exited 0 because they successfully observed the defect; they are not passing product acceptance tests.

Consequence: a valid manual entry can commit a review while permanently locking that session's form. This is the same user-visible class of bottleneck M2 intended to remove.

Owner: primary/frontend implementer. Fix UUID equality semantically after validation, without rewriting persisted pending bodies. Completion: an existing uppercase pending request must confirm from both direct replay and recovered success; different UUIDs must still fail; no duplicate committed review or changed key/body. No product correction attempted here because judge mutation authority covers only this report.

**L1: substantially corrected, but not fully closed. J2 — Low: list results lack sale-line binding.**

`client.mjs:58-64` validates structure and duplicate IDs; `app.mjs:659-663` displays every returned review without checking its `saleLineId` against the loaded sale's exceptional lines. A direct mocked client probe returned a structurally valid review for line `10000000-0000-0000-0000-000000000099`; the requested sale's line was `10000000-0000-0000-0000-000000000006`. The client accepted it.

Consequence: a malformed/misrouted list can show unrelated review evidence under the selected sale. This is a response-defense gap, not proof of a backend authorization leak: `InternalStockExceptions.cs:99-105` filters the real query by sale. POST/recovered success binds the requested line, reviewer, responsible actor, trimmed evidence/outcome and date; the response has no separate saleId. Open cause and date ordering are checked. No authorization weakening was found.

Owner: primary/frontend implementer. Completion: reject foreign or ordinary sale-line reviews before displaying evidence; accept valid reviews across the selected sale's exceptional lines. Preserve duplicate detection and historical reviewer identities. Correction not attempted under report-only authority.

## All eight frozen checks

1. **Static PASS; runtime limited.** Exceptional allocation writes no artificial stock, cost, receipt or movement. Ordinary ledger guards remain (`InternalStockExceptions.cs:56-67`, `InternalCommerceService.cs:RecordSale`, `InternalStockLedger.cs`). Available-zero includes fully reserved stock; preserve Gemini's documented reservation risk before expanding the trial. No new reservation policy inferred.
2. **Static PASS; SQL NOT RUN.** Serializable command transaction, scoped replay and exceptional return/cancellation avoid fictional replenishment. Conditional null omission in `InternalCommerceModels.cs:92-93` preserves ordinary fingerprints; dedicated legacy comparison remains in `InternalStockExceptionTests.cs:48-56`.
3. **PASS with runtime limit.** Independent authorized reviewer, branch access, required evidence/outcome/responsible/date and append-only API remain. M1 adds unsupported policy and is rejected.
4. **REVISE, J1/J2.** Pending retention, duplicate-submit and invalidation protections remain; successful confirmation and list binding need corrections above.
5. **Static PASS; application NOT RUN.** Generated migration adds nullable sale fields and a constrained review table, preserving existing rows. Model/snapshot/release bindings match the manifest and remain unchanged from Gemini's reviewed backend. No regeneration or migration application performed by this judge.
6. **Prepared, NOT RUN.** Existing 17 checkpoints/four identity oracles remain, with five stock checkpoints and stock identity/accounting oracle (`golden_path.py`, `GoldenPath.Sql/Program.cs`, `oracles.md`). Three stock SQL tests remain unexecuted.
7. **Static PASS.** Explicit default-false inputs and supply prerequisite precede runtime in `golden-path.yml`; no-SQL workflow retains offline guards. Existing cleanup/sanitization paths remain. No dispatch performed.
8. **PASS with labels.** All 33 manifest LF hashes independently match both HEAD blobs and current files. Historical, simulated and unexecuted layers remain separate below.

## Verification and gaps

Fresh judge checks: clean initial Git status; exact HEAD; Python SHA-256 comparison of 33 bindings; direct code/policy inspection; focused `node --test --test-reporter=dot dev/savia-staff-ui/stock-exception.test.mjs` completed 22 tests successfully using existing canonical jsdom dependencies. No full suite/browser rerun.

All nine `REVIEW-CHECKS.json` raw-log hashes and four recording hashes match. Direct log inspection confirms two original invalid-input failures and final historical staff **146/146, zero skips**. These are primary-run evidence, not this judge's full-suite run. Recorded Chrome results report desktop1440x1000/mobile390x844, one simulated review, fresh-key correction and same-key/body response-loss recovery. Recordings were hash-checked, not visually replayed here. Before/after sequences differ as documented.

Historical primary backend543/58 skips and harness46, plus predecessor CI success, do not establish SQL or current-SHA acceptance. Current CI `42186722956` and `42186722928` was in_progress in the task packet; not queried or claimed passed here. Primary must read completed exact-SHA results.

An initial judge log-summary command hit `UnicodeEncodeError` on Windows stdout. Explicit UTF-8 resolved it; hashes and counts were then verified. This was a reporting-environment failure, not a product negative control. No access-control bypass occurred.

NOT RUN: SQL persistence/concurrency, real browser→API→SQL, migrations, Docker/API startup, full repository suite, deployment, payments, production and operational acceptance. Prior SQL authorization remains consumed. Windows `WinError 1314` remains historical; use exact-SHA Linux CI without weakening security. C2/C9/C10 remain open.

Next action: primary fixes J1/J2, adds focused regressions, freezes new bindings and obtains targeted re-review; read CI for the resulting SHA. Any SQL campaign still requires Jason's separate authority. Lesson: UUID identity is case-insensitive; pending payload bytes must remain unchanged during recovery.

Only changed path: `docs/stock-exception-20261106/astra-judge-candidate.md`. Its SHA-256 is supplied with the handoff to avoid a self-referential hash.

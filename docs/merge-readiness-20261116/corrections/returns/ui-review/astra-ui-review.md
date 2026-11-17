# REVISE — advisory, not primary acceptance

Task: savia-pr7-return-ui-completion-astra-ba8ff2b-20261116-01. Mode VALIDATE.
The exchange POST acknowledgement route is conditionally sound. The current overlay cannot complete exchanges and needs the corrections below.

SUAZO-PC; T3/Codex; effective gpt-6-astra/xhigh confirmed by runtime and agent-awareness. Managed branch: t3/review-return-ui-completion. Token, cost and remaining allowance telemetry: unknown. Used only this approved session; no delegates or provider changes.

## Frozen sources and bindings

Base HEAD: ba8ff2ba10935e99fc268ebbe5eae130f72c1cca; initially clean.
Canonical inputs: C:/Users/Jason/MARTHA-SILVA/github/docs/merge-readiness-20261116/corrections/returns/.
ADOPTION.md SHA256: 661bc04c4a4ac2064a5580288a7de7979a9ac84c0322ee717073ae9a5fb619ea.
ui-review/REVIEW.json SHA256: d35556e6c3f05eaa405c44efa6fc633b8b2a670eb3acfa14e6c39f3aacf4f95d.
review-overlay.zip SHA256: a80eeb8f2ef8ccb0222cdab1035ac22c11ed2209919998a66d2954695f5dcfe8.
Exactly eight entries passed allowlist, containment, duplicate/symlink exclusion, raw/LF hash and extracted readback checks.

Paths below are relative to this managed checkout. SHA256 values bind the reviewed bytes:

| Overlay path under savia/web/ | Raw and LF SHA256 |
|---|---|
| app.mjs | c0f673d033ccad4d153835eccfec16ce505fbacf22ea0acc7377ea6fa2d58129 |
| screens/return.mjs | 2ef7b896b0f01cc37b0c25a27519ba8b68770833616d5fe1cd943cc88cb70da2 |
| screens/return-intent.mjs | 397bc81c7c35f1ed94e10b1bcb02fa7893ea7470cd2f4126d1d7d6aae5d26a27 |
| tests/return-lifecycle.test.mjs | 64cfddbaff6f98fe3a1f5ce2eeb3b036ade5c2ef356dbca995da98daf46dc2a1 |
| api.mjs | 3878b2a1ccd8f873cda3de73c0876c4ab1451f637630b0937a0d843263591a1a |
| uuid-logic.mjs | 8e93aa30b7239fc7576e1cb29cf991c11a1d951475b1cc56219047fa6ef97813 |
| screens/sale-logic.mjs | ba169c19e3aa25187c4749dacde347c1c8bab32c98472aebe0b136be111138fc |
| tests/uuid.test.mjs | 0e2bf69aeb4b95e993669984a99c6889d5b77f90b051808c6be251b5445012bd |

Canonical savia/db/migrations/V029__return_retry_safety.sql was read only:
6041e3880fb4cb02c595504e394701e52408e426767c67c2b575914402b353cc.
Its independent SQL review remains separate.
Required AGENTS, orchestration, task-completion, PROTOCOL, OUTPUT, coordination, UI and evidence-first instructions loaded. No source access gap. No earlier review conclusions used.

## Findings and minimum corrections

**F1 / P1 — successful exchanges never finish.**
return.mjs:164–169 checks only reversalId, changes to unresolved, then invokes lookup.
Lines 139–142 throw for every matching exchange. Replay follows the same path.
Offline probe 3 supplied a complete HTTP 200 SaleReversal and matching GET: one POST, unresolved, no finish button.
Primary/UI owner: implement the conditional POST acknowledgement path below. Close with successful initial/replayed exchanges and retained GET uncertainty.

**F2 / P1 — malformed ordinary receipts can confirm.**
return-intent.mjs:62–70 omits kind, currencyCode, actorId and createdAt validation.
Probe 2 changed each independently to cancel, USD, not-a-guid and invalid; all four matched.
return.mjs:143 then permits confirmed and eventual deletion.
Primary/UI owner: use one strict reversal validator for ordinary GET and POST acknowledgement. Close with malformed-field negatives and valid ordinary returns.

**F3 / P2 — cancellation strands never-sent drafts.**
return.mjs:496–503 reserves and disables before confirmation; 150–151 returns on cancel.
Recovery offers lookup/replay, while finishIntent requires confirmed (return-intent.mjs:51–53).
Primary/UI owner: permit cancellation only of an exactly matching, owned draft under the exclusive lock; verify removal before restoring editing.
Also offer that action after draft remount. Cancelled confirmation/approval must retire that attempt so late approval cannot submit; revoke any late token.
Never discard sending/unresolved after 404, rejection, timeout or navigation. Persist sending before invoking POST. Close with cancellation, remount and competing-tab tests proving zero POST.

**F4 / P2 — financial confirmation/result regressed.**
return.mjs:148 replaces the original amount/outcome confirmation with generic text; 127–133 shows only an operation ID and recovery controls.
Base return.mjs:356–369 and 435–462 contained outcome, amount, references, credit ID, exchange receipt, cash and stock detail.
Primary/UI owner: derive confirmation from the immutable snapshot; show return value, outcome and exchange due/back amount and tender/reference.
After verification, retain an explicit monetary result and receipt links across reload. Optional live cash/stock refresh failure must not invalidate an acknowledged return.
Close with credit/cash/transfer/exchange result assertions and keyboard flow.

**F5 / P2 — approval cleanup depends on a pending request settling.**
return.mjs:120 only retires/closes the modal. Token cleanup is local to sendPending finally, after POST and lookup (152–175).
A hung request therefore delays logout after retirement; logout failure is swallowed.
Primary/UI owner: track temporary approval at mount scope and initiate single-shot cleanup on retirement and terminal paths, independently of POST completion.
Keep uncertainty and report cleanup failure without storing credentials. Test held POST/lookup retirement and failed logout. This is a static finding; probe 1 did not execute.

## Exchange completion adjudication

ReturnsEndpoints.cs:13–15 awaits ReturnsService.ReturnOutcomeAsync.
savia/src/Savia.Application/Returns.cs:48–50 awaits the store, reads the sale, then returns the requested reversal.
Therefore a valid acknowledgement from that exact POST can attest execution of its full immutable request, provided V029 is actually installed and its guarantees hold.
SaleReversal lacks exchangeSaleId, tenders and settlement linkage (Savia.Contracts/Sales.cs:24–26; V028:298–305). GET alone remains insufficient.

Minimum acknowledgement validation:

- Require HTTP 200 from the captured sale/endpoint/body request. api.mjs:121–125 currently discards status; expose/check it narrowly.
- Recheck mount/session/scope and exact durable record under its lock before confirming.
- Require a non-array object; matching reversalId/tillId, kind return, status approved, exact settlementKind/reason and immutable expected currency.
- Require safe integer creditMinor equal to the positive expected total; exact unique unordered line IDs, quantities, pools and per-line amounts, with no missing/extra lines.
- Require the exact creditId for credit, null otherwise; valid createdAt, actorId and approvedBy consistent with the existing supervisor contract.
- Do not compare the supervisor to the cashier owner scope or require the original supervisor to equal a replaying supervisor.

Persist verified confirmation before exposing completion. Malformed/absent responses remain pending. An explicit replay must preserve endpoint/body/IDs and obtain its own valid acknowledgement. No automatic resend. Legacy unverifiable replay remains rejected; GET cannot upgrade an exchange.

V029:38–67,79–80,113–159 supplies the proposed identity, replay and transaction structure. Runtime must prove complete normalized identity, current authorization before replay, unchanged rows on replay, 51538 conflicts, closed-till replay, concurrent requests, and atomic reversal/exchange/tenders/settlements/stock/outbox rollback. Include exchange-ID collisions and failures inside V028.usp_PostSale. These are unverified backend dependencies, not established UI defects.
ReturnsStore.cs:18 and 42–47 passes authenticated supervisor attribution; V029:80 uses that actor as ApprovedBy. No new attribution requirement is proposed.

## Preserved protections and remaining evidence

Source supports durable exact-body reservation/readback, owner scope, equality checks and origin Web Locks (return-intent.mjs:10–59).
Recovery precedes dependencies (app.mjs:170–172; return.mjs:193–201).
Mount/session fences surround confirmation, approval, POST and lookup; foreign recovery is generic (return.mjs:117–191).
404, absent matches, errors and late responses do not release sending/unresolved. Temporary credentials are not persisted. Real multi-tab locking and browser keyboard behavior remain unverified.

Three focused offline attempts; no full-suite rerun:

1. node_repl dynamic data-URL probe: loader rejected “Unsupported import specifier”; no assertions ran; OS exit not applicable. Cleanup conclusion remains static; no retry of that probe.
2. node_repl direct import of the actual return-intent.mjs: four malformed variants accepted; completed without assertion error; OS exit not applicable.
3. node --input-type=module, stdin harness using test fixture lines 1–166 without registering tests: five assertions, exit 0, reproduced HTTP-200 exchange dead end. Synthetic DOM/HTTP only.

Read-only git rev-parse HEAD, git status --short, git branch --show-current, git show ba8ff2ba10935e99fc268ebbe5eae130f72c1cca:savia/web/screens/return.mjs and git diff --numstat: exit 0.
python C:/Users/Jason/AI-OS/bin/agent-awareness.py --workspace "C:/Users/Jason/.t3/worktrees/github/t3-7ad0a62c-15340015fbaea701" ran before extraction; exit 0. Python stdin archive verifier/extractor: exit 0; eight bindings passed.

NOT RUN: network, SQL, Docker, services, browser/recordings, build/install, full suites, Git mutation/publication, PR checks/reviews. No implementation correction was attempted because this assignment permits only extraction and this report. Canonical files were not changed.

Next: primary serially applies F1–F5, verifies the combined overlay with focused closure checks, and obtains separately authorized SQL proof before accepting the acknowledgement guarantees. Retain 404-before-late-commit, account/navigation switches, storage failure/competition and same-body replay regressions. Lesson: a recovery guard must have an authoritative completion path; passing uncertainty tests alone cannot prove a usable financial flow.

PR https://github.com/Suazo-AI/Martha-Silva-Store/pull/7, head ba8ff2ba10935e99fc268ebbe5eae130f72c1cca, checks and reviews not refreshed by reviewer.

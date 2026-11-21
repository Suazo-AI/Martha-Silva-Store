# What remains before SAVIA and the storefront can ship

Current disposition: [accepted process plan and exact ledger changes](process-acceptance.md). The inventory below is the original audit; seven TONY reviews and C1 settings are now closed. STOCK-EXCEPTION, TECH-TRIAL and store remediation remain explicit. Production stays NO-GO.

2026-11-06. Primary assessment, pending independent process criticism and judgment.
Host: SUAZO-PC. T3 Code / Codex / gpt-6.1-sol, xhigh.
Baseline: `Tony@a77f705a6fd6a2778e4112c21aaa72ab8e478015` plus the explicit test-only LF correction in this publication.
This document changes no acceptance criterion, permission, business decision or ledger status.

**We have working components and substantial test evidence. We do not yet have an accepted, recoverable business operation.**
The internal SAVIA system and the public Martha Silva shop have separate release requirements.
Merging newer code into main cannot fill missing functions, establish fiscal correctness, or prove operational recovery.

## What is already decided

Do not ask Jason to choose these again.

- D-023: a sale must contain multiple articles. This increment is implemented and has bounded acceptance.
- D-024: SAVIA replaces the used SISFAIN workflows. Connecting to SISFAIN is not the goal.
- D-022/D-025: SUAZO-PC coordinates acceptance and hosts the selected synthetic trial. This does not select the production host.
- D-026/D-027: record a physical-garment stock exception; review it at day close. Never fabricate stock, receipts or reconciliation.
- D-028: protect main with required checks and retain the deployment boundary.
- D-029: use a guided synthetic walkthrough with Martha to establish operational facts.
- Keep Jason's frontend and Denis's images, as recorded in [SELECTED-REFERENCE](../hardening-20261106/combined/SELECTED-REFERENCE.md). D-030 is absent from committed DECISIONS; no uncommitted decision is claimed.
- D-008/D-009: cards are required for public-store production. A catalog-only release needs a separate business decision.
- The standing critic is Gemini 4 Argon/high. The judge is GPT-6 Astra/high. The primary accepts or rejects their advice.

Authority: [DECISIONS](../DECISIONS.md). The current decisions file contains unrelated local edits; this publication does not stage or modify them.

## Evidence already available

| Evidence | What it demonstrates | What it does not demonstrate |
| --- | --- | --- |
| [Isolated SQL acceptance](../sql-ci-20261106/README.md), run 42163110947 at 708bdbb | 602 backend passes including 76 SQL tests; backup/restore, restart and disposable-container cleanup | The newly extended receipt browser journey, target-store recovery or operator acceptance |
| [Supply preparation acceptance](../supply-real-20261106/PREPARATION-ACCEPTANCE.json) | Primary verified 21 current source bindings; accepted Gemini/Astra preparation review with limits | Execution of the prepared Browser → API → SQL receipt journey |
| [No-SQL CI](../supply-real-20261106/CI-852.json), run 42169677581 at 8523523 | Helper compilation; staff 124/124; browser mocks 50/50 and 8/8; .NET 526 PASS, 0 FAIL, 55 SKIPPED | SQL execution or a zero-skip aggregate claim |
| [Combined frontend review](../hardening-20261106/combined/primary-review.md) | Local build, focused guards, desktop/mobile simulated checkout and bounded recordings | Real payment, public-order authority or deployment acceptance |
| [Linux correction](../hardening-20261106/combined/CI-IMAGE-LF-FIX.json), run 42170897865 at a77f705 | Publication integrity/build job passed; the next exact-layout test exposed a CRLF-specific expectation | A completed green aggregate. The new test-only correction needs its automatic Linux readback |

These results are separate, dated observations. Do not add them together as one end-to-end production test.

## Complete remaining work inventory

The first column identifies the release affected. P0 precedes the next serious trial. P1 precedes real production. P2 is conditional or deferred.
Rows can share a ledger item. This is a map of unfinished work, not a claim that each row is an independent project.

| Priority / release | Remaining work | Why it matters | Owner, next action and completion evidence |
| --- | --- | --- | --- |
| P0 / both | Close the current integrated candidate: Linux aggregate and bounded storefront critic/judge | The exact published combination must build and pass its applicable checks | Primary owns the LF test correction. Read the automatic Linux result for its exact SHA. Reuse unchanged reviews; adjudicate the narrow delta. Do not repeat a full product review for a comment/hash correction. |
| P0 / SAVIA | Run the prepared real supply receipt journey | Mock responses cannot establish that a receipt changed durable stock once | Primary requests one concrete `golden-path.yml` run with `supply_receipt=true`, after candidate checks. Require 17 browser checkpoints, the persisted identity/stock oracles, response-loss recovery without repost, and cleanup. Preparation is accepted; runtime is NOT RUN. |
| P0 / SAVIA, C1 | Implement the adopted physical-garment exception and close review, D-026/D-027 | A cashier can hold an actual garment while recorded stock is zero. The agreed operation currently has no demonstrated supported path | One Sol/high worker owns the bounded feature and tests. Preserve nonnegative stock constraints. Freeze exception identity, authorization, review states and audit evidence. Primary accepts only a complete UI → API → durable record → different-person review path. Do not solve this by removing stock guards. |
| P0 / SAVIA, C2 | Establish the used SISFAIN workflow and a replacement matrix | A promotional video cannot specify the store's actual tender, fiscal, closing and equipment rules | Jason coordinates the already selected walkthrough. Record observed, declared and unknown facts separately. Map each used flow to SAVIA code, a test and any gap. Technical work that does not depend on those facts continues. |
| P0 / SAVIA | Establish cash, change, till close, refunds and payment/document correctness for the agreed trial | A recorded sale with `paymentStatus: not_processed` is not proof of collected cash, settlement or an authorized fiscal document | Primary uses C2 facts to identify missing behavior. Run a synthetic business day with independent expected money, inventory and audit results. Build only the demonstrated missing paths. Existing offline admin models are rehearsal evidence, not SAVIA acceptance. |
| P1 / SAVIA, C9 | Resolve target-environment certificate trust under a scoped investigation | The earlier connection stopped on an untrusted chain before SQL queries. The recovery drill cannot start safely | Jason/administrator approves the prepared investigation if this target remains selected. Preserve encryption and certificate validation. Identify the actual certificate/issuer and prepare a reversible correction before a new connection. Previous authorization is consumed. |
| P1 / SAVIA, C9 | Restore the target environment and measure recovery time/data loss | CI restore tests do not measure how fast the actual installation can resume work or which transactions survive | Primary/admin runs the reviewed G0–G9 procedure with authority. Require checksum, restore as a new database, transaction oracles, measured RTO/RPO and cleanup. RTO is recovery time; RPO is tolerated lost work. |
| P1 / SAVIA, P-HOST | Select the production host and an accountable operator | TLS, backups, costs and network failures depend on where the system runs | Jason selects a concrete local/cloud option using cost, connectivity, ownership and recovery needs. The SUAZO-PC trial decision does not settle production hosting. Record one target before setting it up. |
| P1 / SAVIA, P-SEC | Configure real staff accounts, production TLS and secret lifecycle | Test identities and temporary certificates do not establish production access control | Owner/admin applies the target-specific setup after hosting. Verify least privilege, revocation, secret storage/rotation and HTTPS using synthetic accounts. No secrets enter Git or agent reports. |
| P1 / SAVIA, P-OPS | Activate scheduled backups, monitoring, alerts and incident/rollback procedures | A system must detect failures and recover when no agent is watching | Named operator owns schedules and alerts. Verify a backup, a restored result, an alert received by its owner and one rollback. Configuration files alone do not close the gate. |
| P1 / SAVIA, P-OWNER | Test loss of the final Owner account | The business must not lose administrative control after a password/account failure | Jason chooses the emergency recovery policy. Recommendation: two active Owners plus a controlled administrator procedure. Exercise recovery with synthetic accounts and retain an audit trail. |
| P1 / SAVIA, C10 | Perform the selected supervised operator trial | Agents cannot prove that a cashier can use the system unaided on the store's equipment | After its prerequisites, the selected coordinator records five unaided tasks, 30 synthetic sale timings, p95 submit→receipt ≤1 second and physical count reconciliation. Keep the existing acceptance criteria; do not substitute mock timings. |
| P1 / SAVIA, C12/P-GO | Integrate to main and conduct a controlled release | Tony publication, main integration and deployment are different actions with different effects | Primary prepares the reviewed diff, required-check readback, migration/backup/rollback and release packet. Jason approves merge/deployment when concrete. Verify exact main and deployed SHA plus a safe smoke test. Publishing to Tony is already authorized. |
| P1 / public shop, S-PAY | Choose an eligible merchant/card provider and implement payments | The shop cannot charge a card with its current simulated checkout | Jason supplies merchant country, currency and account constraints. Select an eligible provider, then test approvals, declines, timeout, signed callbacks, duplication and reconciliation in its sandbox. Live merchant activation remains separate. |
| P1 / public shop, S-BACKEND | Add authoritative public orders and connect approved stock/order rules | Browser-local demo orders are not durable business records; the internal API is not automatically the public backend | One backend owner implements the approved order/payment boundary, concurrency and recovery rules. Verify browser → API → durable order/payment/stock results, including retries. Use the existing stack rather than a new orchestration framework. |
| P1 / both | Define and exercise the supported devices, accessibility and degraded network conditions | A few desktop/mobile mock checkouts do not establish usability on actual low-end equipment | Primary freezes a realistic device/network envelope with business input. Exercise key flows, keyboard/zoom, relevant accessibility checks and degraded/reconnected operation. Record exact devices and measured limits. No promise of every device or every connection. |
| P1 / public shop | Confirm business/legal/fiscal facts and production content | Sample prices, contact details, refunds, data handling or receipt labels can mislead customers | Owner and qualified local adviser confirm applicable facts. Primary implements approved copy and data handling, then verifies displayed and charged values match. Fiscal acceptance is not an agent opinion. No new legal conclusion is asserted in this audit. |
| P1 / public shop | Configure the actual public destination and truthful search metadata | Preview `noindex` is intentional. Publishing sample stock or wrong canonical URLs creates a different problem | After business facts and release authority, verify the selected Jason destination, domain/TLS, canonical/indexing/sitemap and truthful product data. Preserve the other publications. Preserve the committed selected reference. |
| P1 / SAVIA replacement | Establish initial inventory and any required migration/reconciliation | Replacing an existing system must not invent opening balances or lose agreed records | C2 identifies what must transfer. Prepare a sanitized mapping and a synthetic dry run now. Require approved opening counts, totals and rollback before importing real data. A trial can remain synthetic. |
| P1 / security policy, SEC-CSRF | Close the same-user token/session policy | The old session cookie is rejected, but a token may survive the same user's new session. The ledger records a policy choice, not privilege escalation | Jason decides or explicitly accepts the recommendation to bind tokens to the session. If changed, require focused adversarial red/green checks. This is not evidence of a currently confirmed critical vulnerability. |
| P2 / setup, API-BRANCH | Provide a supported one-branch creation procedure | Production setup currently needs direct SQL/EF; an operator needs a controlled procedure | Recommendation: a reviewed, tested administrator script while D-014 remains one branch. Build an Owner endpoint before actual multi-branch scope. Record the decision and test its guardrails. |
| P1 / evidence | Reconcile the seven `TONY-*` items still in review | Implemented work can remain administratively open. A status label cannot stand in for acceptance | Primary checks the existing [fix packet](../sprint-20261104/TONY-PR2-FIXES.md), current sources and relevant evidence once. Accept, reject or assign a precise missing check for STATUS01/02/03, WF01, HC01/02 and STOCKDOC. Do not assume seven missing features or reimplement them. |
| P1 / verification | Disposition the legacy assertion failures under the selected frontend | P-LEGACY is done for classification only. Classification does not make the tests pass | Primary uses the existing [19-case classification](../p-legacy-20261104/CLASSIFICATION.md) and issue #4. Fix actual regressions, replace obsolete expectations with approved contracts and document environment exclusions. Keep required checks honest; never hide a failure to get green. |
| P2 / deferred | Leave PIPE-AI optional and freeze unrelated agent/skill infrastructure | A PR narrator and more agents do not complete a sale, recover a database or charge a card | Defer. Revisit only when a measured delivery bottleneck justifies it. This is not a production blocker. |

Canonical inventory: [ledger](../pipeline/ledger.json). Its C1 `done_when` still emphasizes branch settings while `why/prep` also require the stock mechanism. Resolve that mismatch explicitly; do not silently remove either requirement.

## Why delivery has stretched

These are the primary's evidence-based observations. The independent reviewers must challenge them.

| Observation | Direct evidence | Improvement |
| --- | --- | --- |
| We combined two products under one word, "ready" | Ledger separates sprint/prod/store, but conversations often combine main, SAVIA, shop and deployment | Keep two acceptance results and one selected next business journey. A green shop demo cannot close SAVIA recovery; a green SQL suite cannot close card checkout. |
| Integration exposed preventable platform mismatches | 8523523 failed RAW snapshot identity; a77f705 passed integrity then failed an old CRLF layout expectation | Test committed-byte assumptions before freezing the candidate. Use the existing Linux path early. Fix the specific failure and keep its negative control. Primary owns these integration misses. |
| Environment failures consumed reviews without testing the candidate | The first supply critic could not read the worker overlay; the contained candidate review later succeeded. The reported missing SDK was later found as an existing portable installation | Put the frozen candidate and evidence in the reviewer's allowed worktree. Check installed prerequisites before delegating. Do not count an access rejection as a product defect. |
| We overproduced process relative to complete business journeys | Recent commits include audits, learning backlog, skills, evidence and test harnesses as well as actual features; receipt runtime and stock exception remain open | Freeze unrelated infrastructure. Measure completed business journeys and unresolved material findings, rather than agent count or document volume. Commit history alone cannot quantify exact wasted hours. |
| Review/CI boundaries created repeated handoffs | Worker returns, primary import, critic, corrections, judge and new publication each require source identity. Some changes affect tests/docs only | Integrate compatible work once. Give reviewers exact bytes in a contained packet. Reuse valid review of unchanged paths and adjudicate only meaningful deltas. Never remove adversarial checks for money/security/data. |
| Some "done" labels refer to preparation or classification | SUPPLY-UI is bounded mock/UI acceptance; real receipt journey is separately NOT RUN. P-LEGACY is classification only | Name the boundary in the acceptance result. Reconcile stale status without reopening valid work. A clean ledger is useful only if it agrees with direct evidence. |
| External facts and scoped runtime were not lined up with the execution window | C2 answers, C9 trust investigation, merchant eligibility and production host are open; earlier SQL authorization covered one consumed run | Prepare one concrete bounded campaign and its stop/cleanup rules, then ask for the necessary scope once. Continue independent product work while facts/authority are pending. Do not expand old permission by interpretation. |

**The primary is accountable for choosing the critical path, packaging reviewable candidates, checking prerequisites and preventing unnecessary rework.**
Provider failures and user decisions explain some waiting. They do not explain every delay or excuse avoidable orchestration overhead.
No defensible total delay/cost estimate is available from these records. Do not invent one.

## Decisions still open

The adopted decisions above are settled. These remaining decisions are different:

1. Production host, cost and accountable operator: P-HOST.
2. Eligible merchant provider and live-payment constraints: S-PAY.
3. Emergency Owner recovery policy: P-OWNER.
4. Same-user CSRF/session policy: SEC-CSRF.
5. One-branch provisioning method: API-BRANCH.
6. Supported equipment/network envelope, operational backup objectives and the business/fiscal facts not yet supplied through C2.

Recommendation: resolve them in dependency order, one concrete choice at a time. Do not ask Jason to choose implementation trivia.

## Plan from here

1. **Finish the existing candidate.** Primary publishes only owned paths to Tony, verifies remote SHA and reads applicable automatic Linux checks. Accept supply preparation with its exact limits. The storefront critic already has its own frozen candidate; do not duplicate that review.
2. **Run the independent process critique requested by Jason.** Gemini Argon/high reviews this assessment and its raw source/evidence in a separate managed worktree. It must identify unsupported claims, avoidable delays, missing work and a shorter critical path. Astra/high then judges its material objections. These are advisory results, not production acceptance.
3. **Complete one real business path.** Once the current candidate is fit and the exact scope is authorized, run the prepared receipt recovery journey against disposable SQL. Keep the runtime request concrete. Close it only after its persisted oracles and cleanup readbacks pass.
4. **Implement the already chosen stock exception.** One bounded Sol/high worker owns its feature paths. In parallel, the primary can prepare environment recovery or accept independent website verification. Never assign a second writer to the same app/backend paths.
5. **Demonstrate a synthetic business day.** Use agreed money/inventory equations and actual SAVIA persistence. Include receipt, multiarticle sale, reversal/return, retry, session change, exception review and close. A mock-only rehearsal cannot close this stage.
6. **Close target-specific operation.** In parallel with technical implementation, Jason obtains C2 facts and decides hosting/payments in dependency order. The named operator completes C9, P-SEC/P-OPS/P-OWNER and C10. The public shop separately completes authoritative orders and payments.
7. **Release a frozen candidate.** Required exact-SHA checks, reviewed migrations, recovery and rollback, operator acceptance and explicit release authority precede main/deployment. Verify what actually runs after release.

Work-in-progress limit: primary plus at most two active workers/reviewers, under the canonical lower capacity limit.
The same resource has one writer. Shared integration is serial. Critic and judge are used at meaningful acceptance boundaries, not for every sentence.

No honest three-hour production promise can be made while unknown business facts, hosting, payment eligibility and real recovery remain unresolved.
A bounded technical trial can advance substantially without pretending those production gates have passed.

## Independent audit acceptance checks

- Inspect direct sources and existing results; do not use this report or another agent's summary as proof.
- Reconcile every non-done ledger item; distinguish missing implementation, missing evidence, stale status, external fact and optional work.
- Identify the three highest-impact primary/agent process failures with specific examples and the shortest safe correction.
- Reject invented parity with SISFAIN, universal-device guarantees, simulated-payment success and claims that old CI covers new product bytes.
- Keep adopted decisions and permissions intact. Do not propose a broad refactor, another infrastructure project or endless simulation as the route to completion.
- Return a prioritized dependency-aware plan, exact owner/next action/completion evidence and any actual unavoidable Jason action.
- Do not quantify wasted time, cost or completion percentage without a measured basis.

Lesson: end a delivery window with an accepted business journey and named residual risks. More review documents do not compensate for an unexecuted critical path.

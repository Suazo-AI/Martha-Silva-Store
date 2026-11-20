---
name: technology-evaluation
version: 1.0.0
description: End-to-end, evidence-led evaluation and proof-of-concept workflow for introducing a technology into an existing application. Use when an agent must research a library, framework, service, SDK, API, or engineering technique; identify a high-value application problem; implement a bounded PoC in a reviewable draft PR; verify it; grade it; and recommend adopt, trial, defer, or reject.
---

# Technology Evaluation and PoC Delivery

## Purpose

Evaluate a technology against a real application problem, not against a demo in isolation. Produce a reproducible recommendation supported by source evidence, a bounded implementation, exact-commit test results, independent review, and an explicit deployment assessment.

This is one repeatable job and one canonical skill. Do not create a separate agent for every phase. Use the available Collector, Executor, Critic, and Judge roles under the orchestration contract below.

## Trigger

Use this skill when asked to assess whether a technology is useful in an existing codebase, try a new tool or library, compare implementation approaches, or prove a technology with a draft PR.

Do not use it for a standalone tutorial, toy project with no target application, or a production rollout request that lacks its own approval and release process.

## Non-negotiable operating rules

1. Read the repository's `AGENTS.md`, entry-point guidance, current project status, relevant decisions, security policy, and domain-specific instructions before changing anything. Repository instructions override this skill where they are stricter.
2. Inspect the current branch, full commit SHA, dirty state, relevant open PRs, owners, CI workflows, and deployment configuration. Never assume two branches or environments are equivalent.
3. Reuse existing code, libraries, tests, CI, templates, and skills before introducing new ones. Explain why an existing capability is insufficient.
4. Keep the experiment minimal and isolated. Prefer test-only dependencies and adapters. Do not add production dependencies unless the PoC specifically requires proving runtime integration.
5. Do not add secrets, credentials, real customer data, production database access, external accounts, paid API calls, or billable agent usage without explicit, scoped approval.
6. Do not merge, publish, change branch protection, alter permissions, run migrations, touch production data, or deploy without separate explicit approval.
7. The Executor cannot approve its own work. An independent Critic and, for material/high-risk choices, a separate Judge must assess the evidence. Never simulate delegation; when an independent role is unavailable, record `NOT RUN`.
8. A successful local test is not GitHub CI. A green PR is not a green integration branch. A build is not a deployment. A synthetic fixture is not real SQL, a real browser, a real payment, or production acceptance.
9. Never weaken a failing test, suppress a required check, or label an omitted test `PASS`. Report `PASS`, `FAIL`, `SKIPPED`, and `NOT RUN` separately.
10. If the repository requires a canonical checkout, hooks, progress receipts, or sync commands, use them. If the available environment cannot run them, stop before publishing a commit and deliver a bounded patch with the blocker. Do not bypass the rules with a direct API commit.

## Required inputs

Resolve as much as possible from the repository and request only what is essential:

- Candidate technology name, version, or problem domain.
- Target repository, branch, and exact base SHA.
- Application area and business workflow affected.
- Existing architecture, runtime, language, deployment model, and relevant constraints.
- Existing tests, CI jobs, incidents, known defects, or performance evidence.
- Permission boundary: what may be read, modified, tested, published, or spent.

If the technology is unspecified, select one that addresses a demonstrable high-value problem in the target application. State why it is a good test candidate and keep the initial scope small.

## Orchestration and role contracts

Use one primary Orchestrator/Executor and only the supporting roles that add independent value. A typical run uses one primary plus a Collector and Critic; add a Judge for high-risk decisions or when the recommendation materially affects architecture, money, security, or deployment.

| Role | Responsibility | Required output | Prohibited behavior |
|---|---|---|---|
| Orchestrator | Own scope, sequencing, state, permissions, and final handoff | Run manifest, phase status, unresolved decisions | Claiming evidence not produced by a tool or reviewer |
| Collector | Research official docs, releases, licenses, APIs, compatibility, maintenance, and application evidence | Source matrix with URL, date/version, claim, and confidence | Treating marketing claims or unverified posts as fact |
| Executor | Implement the smallest useful PoC, add tests, run checks, prepare a draft PR | Diff, commands, logs, exact SHA, known limits | Self-approving, expanding scope, weakening tests, merging or deploying |
| Critic | Independently try to falsify the fit, safety, API ergonomics, tests, complexity, and claimed results | Findings ranked by severity with reproduction evidence | Repeating the Executor's summary without inspecting source/diff |
| Judge | Independently decide GO / GO-WITH-FIXES / SPIKE-ONLY / NO-GO against criteria | Signed-off decision rationale and blocking conditions | Approving without seeing the exact candidate SHA and Critic findings |

If multiple agents are unavailable, the primary agent may perform the work but must mark independent review `NOT RUN`. It must not label its own second pass as an independent review.

## End-to-end sequence

### Phase 0 — Intake, authority, and repository snapshot

1. Read all applicable repository instructions and current status/decision documents.
2. Record repository, branch, base SHA, working-tree state, open PRs, owners, existing CI jobs, and deployment targets.
3. Identify protected or sensitive boundaries: payments, authentication, permissions, orders, inventory, accounting, migrations, personal data, secrets, and external services.
4. Record allowed actions and forbidden actions. Confirm whether a draft branch/PR is permitted and whether repository hooks must be run locally.
5. Create a run directory under the repository's approved evidence convention, for example `evidence/technology-evaluations/<slug>/<run-id>/`. Do not invent a new location if the repo already defines one.

**Gate 0 passes only when** the target, base SHA, instructions, scope, and permission boundary are known. Otherwise stop with a blocker.

### Phase 1 — Research what the technology does

Research in this order:

1. Official documentation for the exact major/minor version being evaluated.
2. Official API/reference documentation and minimal examples.
3. Release notes, compatibility matrix, support lifecycle, license, and migration/breaking-change policy.
4. Official security advisories and maintenance/security policy where relevant.
5. Independent technical sources only to test or challenge official claims; label their confidence and date.

Answer explicitly:

- What does it do, and what does it not do?
- What problem does it solve, and what underlying mechanism does it use?
- Which alternatives already exist in the application or toolchain?
- What constraints does it add: runtime, language version, package manager, operating system, hosting, network, data, account, license, or cost?
- What is the smallest API surface needed for this use case?
- What are the failure modes, security implications, and exit/removal costs?

Do not rely on a README alone when official API docs, version notes, or license details materially affect the decision. Record URLs and access dates in the source matrix. Do not copy large passages.

### Phase 2 — Find the highest-value application problem

Map the real application before selecting the PoC target:

1. Trace the relevant user/business workflow through UI, API, domain/service layer, persistence, tests, and deployment.
2. Inspect related code and tests, recent defects, TODOs, CI failures, performance evidence, and project blockers.
3. Distinguish the current production path, demo/simulator, fixtures, historical code, and disconnected backend. Never use a test double as proof of a production capability.
4. List candidate problems and rank them using: business/customer impact, severity and likelihood, current pain/evidence, fit to the technology, reversibility, and PoC cost.
5. Select one primary problem. Choose the gnarliness that creates the most value while remaining bounded and testable; do not choose complexity merely to make the PoC impressive.

The problem statement must name: affected user, workflow, failure/pain, current implementation, evidence, expected improvement, and non-goals.

**Gate 2 passes only when** the problem is located in the actual code path and the proposed technology has a plausible mechanism for improving it. If evidence is weak, run a read-only investigation or choose a better target.

### Phase 3 — Hypothesis, baseline, and acceptance contract

Before implementation, write a falsifiable hypothesis:

> For [specific workflow], technology [version] should improve [measurable property] compared with [current baseline], while preserving [business/security invariants], as demonstrated by [tests/evidence].

Record:

- Baseline behavior and current tests.
- Invariants that must never change.
- Positive, negative, boundary, failure, retry, concurrency, and recovery cases as appropriate.
- Performance/latency/memory/build-size budgets only where measurable and relevant.
- Compatibility targets and supported environments.
- Exit criteria, stop conditions, and rollback/removal plan.

Define what will count as a failed PoC. Do not write acceptance criteria after seeing the result.

### Phase 4 — Choose the smallest PoC design

Prepare a short design before coding:

- Proposed integration point and data/control flow.
- Minimum API surface used; avoid exposing unnecessary choices to agents or callers.
- Type and validation boundary.
- Test seam and deterministic fixture strategy.
- Production versus test-only dependency boundary.
- Configuration, secrets, network, deployment, observability, and rollback changes (or explicit `NONE`).
- Files expected to change and files that must not change.

Prefer an adapter or isolated module over a broad refactor. Add a feature flag only if the experiment genuinely exercises a runtime integration and the repo's feature-flag mechanism is approved. Do not introduce a flag as decoration.

### Phase 5 — Implement the PoC

1. Create an isolated branch/worktree from the recorded base SHA using the repository's required workflow.
2. Add the smallest failing regression/property/contract test first where possible. Run it red and preserve the output.
3. Implement the minimum integration. Avoid unrelated cleanup, formatting churn, product redesign, or speculative abstractions.
4. Keep production code untouched when the question can be answered by a test-only spike.
5. Pin dependency versions and lockfile integrity. Record license and transitive dependency impact.
6. Add comments only where they clarify non-obvious invariants or limitations.
7. Update the affected area documentation and dated correction notes as required by repository policy.

### Phase 6 — Build the reviewable draft PR

Open a draft PR only when repository hooks and write permissions allow it. The PR must contain:

1. Problem and baseline.
2. Technology, version, what it does, official sources, and why selected.
3. Hypothesis and acceptance criteria.
4. Scope: changed files and explicit non-changes.
5. Design and smallest API surface used.
6. Red/green evidence and exact test commands.
7. Exact base SHA and candidate head SHA.
8. CI run URLs and each result (`PASS`, `FAIL`, `SKIPPED`, `NOT RUN`).
9. Security, license, dependency, cost, and deployment effects.
10. Critic findings, responses, remaining risks, and requested review decisions.

Keep the PR draft while any required evidence is running, blocked, or unresolved. Do not merge it.

### Phase 7 — Full verification

Verify the exact candidate commit, not a nearby local commit or a synthetic tree incorrectly labelled as the PR head.

**Source and diff integrity**
- Confirm branch, base SHA, PR head SHA, and checked-out SHA.
- Inspect complete diff and changed-file list.
- Check rename/copy source and destination paths, generated files, lockfiles, secrets, licenses, permissions, and deployment configuration.
- Run whitespace/diff validation and repository policy tests.
- Run the clean code gate and record the before and after counts.

**Functional and adversarial testing**
- Re-run the red test and verify it is green for the intended reason.
- Run direct unit/contract/property tests.
- Test negative, invalid, boundary, timeout, retry, duplicate, concurrency, and recovery cases relevant to the target.
- Verify determinism and reproduction instructions (seed, fixture, command, environment).
- Run affected existing tests and the relevant full suites required by the repository or risk class.
- Test compatibility on the required OS/runtime matrix.
- Use a real browser, disposable database, or provider sandbox only when explicitly authorized and available; otherwise record `NOT RUN`.

**CI evidence**
- Inspect the actual workflow runs and job logs on the exact head SHA.
- A required job with `skipped`, `cancelled`, `timed_out`, missing, stale, or mismatched SHA is not a pass.
- A summary job is not proof that underlying suites ran. Confirm each selected suite individually.
- Re-run after each fix and record the final SHA. Never reuse old green results after code changes.

### Phase 8 — Independent Critic and Judge

The Critic independently examines:

- Does this actually solve the target problem?
- Is the test oracle independent of the implementation?
- Are there false positives, false negatives, vacuous tests, or untested branches?
- Can retries, concurrency, malformed input, partial failure, cancellation, or recovery break invariants?
- Did the PoC introduce hidden production dependencies or deployment assumptions?
- Are source claims supported by current official documentation?
- Can the change be removed cleanly?

The Critic must reproduce at least the highest-severity concern or explain why it cannot. The Executor addresses findings or records accepted residual risks.

The Judge then reviews the exact diff, evidence, scorecard, and unresolved Critic findings. The Judge is independent of implementation. For material changes, no Judge means recommendation remains provisional.

### Phase 9 — Score the technology

Score each criterion from 1 to 5. Use the same scale across candidates. Include evidence and a short rationale for every score. A numeric total must never override a critical blocker.

| Criterion | 1 | 3 | 5 |
|---|---|---|---|
| API nuance / agent ergonomics | Many choices, hidden modes, ambiguous behavior | Manageable but requires conventions | Small, explicit, predictable API with safe defaults |
| Type safety | Weak or mostly dynamic at boundaries | Partial static types/validation | Strong types end-to-end with validated external boundaries |
| Ease of testing | Requires network/services/stateful setup | Testable with adapters or fixtures | Deterministic, isolated, fast, easy to reproduce and shrink failures |
| Cyclomatic complexity | Large branching or callback/state complexity | Moderate increase | Clean code gate counts do not rise; no meaningful production increase; simple test/integration layer |
| Documentation quality | Missing, stale, or vague | Usable reference with gaps | Versioned official docs, examples, migration notes and clear failure behavior |
| Deployment impact | New service, migration, credentials, or fragile operations | Configuration/CI changes | No production deployment change; test-only or easily reversible |

Also record (not hidden inside the six scores):

- **Maintenance and ecosystem:** release activity, ownership, support policy, bus factor, license, transitive dependencies.
- **Security and privacy:** data flow, permissions, vulnerabilities, supply-chain controls, secrets, external calls.
- **Performance and resource cost:** measured only against a declared baseline.
- **Economic cost:** actual paid usage, infrastructure, and operational effort; use `UNKNOWN` when not verified.
- **Removal cost:** dependency, abstraction, schema, or data lock-in.

Report both the six individual scores and an unweighted mean if useful. Do not create precision from subjective inputs. A score is not evidence by itself.

### Phase 10 — Recommendation and adoption path

Choose exactly one:

- **ADOPT (bounded):** acceptance criteria passed, no critical blockers, independent review passed, operational/deployment path understood.
- **GO WITH FIXES:** strong fit, but named fixable blockers must be completed before merge/use.
- **SPIKE ONLY:** useful experiment, but evidence or production integration is incomplete. Keep isolated; do not ship.
- **DEFER:** may fit later, but timing, dependency, cost, or prerequisites are not ready.
- **NO-GO:** does not solve the real problem, fails acceptance, creates unacceptable risk/cost, or is inferior to reuse.

State the recommended next action, what evidence would change the decision, and the explicit non-authorization (no merge/deploy/spend unless separately approved).

### Phase 11 — Integration, monitoring, and closure

Only after explicit approval:

1. Rebase or recreate from the current approved target branch; do not force-push.
2. Re-run all required tests on the exact integrated SHA.
3. Verify branch protection/rules and required check names independently.
4. Deploy only through the authorized release path and immutable artifact. Verify smoke tests, health, logs, and rollback readiness.
5. Monitor the declared success/error metrics for the agreed observation window.
6. Roll back on invariant violations, payment/order/stock corruption, elevated errors, or failed health checks.
7. Close the experiment: retain useful tests, remove unused prototype code/dependencies, document the decision, and archive evidence.

If integration is not approved, preserve the draft PR or close it with an evidence-backed reason. Do not allow an experimental branch to become an undocumented dependency.

## Clean code gate

"Non-slop" code means code that a measurement can defend, not code that looks tidy.
Apply this gate to every PoC diff and to every refactor that this skill evaluates.

**Measured rules (existing tools, no new dependency)**

| Rule | Tool and limit | Pass condition |
|---|---|---|
| Cognitive complexity | biome `complexity/noExcessiveCognitiveComplexity`, max 15 | The diff adds no new finding and makes no existing finding worse. |
| Function length | biome `complexity/noExcessiveLinesPerFunction` | The diff adds no new finding. |
| Dead code | biome `recommended` preset (`noUnusedVariables`, `noUnusedImports`) and a search for unreferenced exports | The diff leaves no unused symbol, flag, or file. |
| Duplication | Manual check of the diff; no tool is installed | No copied block of 6 or more lines; reuse the existing helper instead. |
| Module boundaries | Manual check of imports | A screen module does not import another screen; shared logic lives in one named module. |

Measure from `savia/` with the repository's pinned biome:

```bash
node node_modules/@biomejs/biome/bin/biome lint web --only=complexity/noExcessiveCognitiveComplexity --max-diagnostics=none
node node_modules/@biomejs/biome/bin/biome lint web --only=complexity/noExcessiveLinesPerFunction --max-diagnostics=none
```

**Ratchet**

A ratchet is a check that fails when a quality count gets worse, so the count can only go down.
Record the counts before and after the change in `BASELINE.md` and `VERIFY.md`.
A count that rises is a blocker, unless the Judge accepts a named exception with a reason.
The baseline on 2026-11-20 (`Tony` at `0147124` plus the working tree) is 37 complexity findings and 50 function-length findings in `savia/web`.
Enforcing the ratchet in CI is a separate change that needs its own approval.

**Refactor rules**

- Refactor only behind existing tests that pass before the change; add a characterization test first if a branch has no test.
- Keep behavior identical: same outputs, errors, side effects, and persisted data.
- Split by responsibility (parse, validate, compute, render), not by line count.
- Do not add abstractions, options, or layers that have only one caller.
- Remove what the change makes unused in the same diff.

**Not measured yet**

The storefront (`src/app.js`), .NET, and T-SQL have no complexity measurement in this repository.
Report them as `NOT MEASURED`; do not claim the gate covers them.

## Required outputs

A completed run must leave these records (or their repository-approved equivalents):

1. `RUN-PACKET.md`: candidate, target problem, scope, hypothesis, acceptance tests, roles, score, decision, and handoff.
2. `SOURCES.md` or a source table in the packet: official references, versions, access dates, and supported claims.
3. `BASELINE.md`: existing path, current tests, known behavior, and baseline measurements.
4. `POC-PLAN.md`: minimal architecture, affected files, invariants, and deployment/rollback plan.
5. `VERIFICATION.md`: exact SHAs, commands, CI URLs, pass/fail/skip/not-run results, logs/artifacts, and limitations.
6. `CRITIC.md` and `JUDGE.md`: separate reviews, or explicit `NOT RUN` with reason.
7. `DECISION.md`: scorecard, recommendation, blockers, and next step.

Use one run folder such as `evidence/technology-evaluations/<slug>/<run-id>/`. Keep reusable policy in this skill, reusable blank templates under `files/`, approved examples under `examples/`, and dated corrections in `notes.md`. Never mix run evidence into the canonical skill.

## Definition of done

A run is complete only when:

- Repository rules and permissions were respected.
- The technology is described from current, cited sources.
- A real application problem is traced to code and tests.
- Hypothesis, baseline, and failure criteria were fixed before implementation.
- PoC is minimal, isolated, and reviewable.
- The exact candidate SHA has complete applicable test evidence.
- Selected checks are not silently skipped; skipped/not-run coverage is explicit.
- Critic and Judge are independent or marked `NOT RUN`.
- All six requested scores include evidence and rationale.
- Deployment, security, license, cost, maintenance, and removal impacts are explicit.
- Recommendation and approval boundary are unambiguous.
- Handoff includes actionable next step, blocker, and evidence links.

If any mandatory item is missing, status must be `PARTIAL`, not `DONE`.

## Handoff format

Every project handoff ends with:

- **STATUS** — DONE / PARTIAL / BLOCKED and risk class.
- **DONE** — artifacts and code actually completed.
- **NEXT** — one concrete next action.
- **BLOCKER** — missing approval, environment, evidence, or decision; use `NONE` only if none exists.
- **EVIDENCE** — exact repository/branch/PR/SHAs, test commands and results, CI URLs, artifact paths, and explicit `NOT RUN` items.

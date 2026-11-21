VERDICT: REVISE the runtime packet before PR creation. The product rollup is viable; merge readiness is not established.

Task `savia-merge-route-670d4a8-astra-20261116-01`, VALIDATE, 2026-11-16.
Source: `670d4a8e6fab650ef1ee2b0fba64d7e810b7dbe3`.
Requested: Codex / `gpt-6-astra` / `reasoningEffort=xhigh`.
Runtime-exposed: T3 Code / Codex / `gpt-6-astra` / xhigh, SUAZO-PC.
Independent provider telemetry/cost: unavailable; no additional provider execution requested.
Managed worktree: `C:/Users/Jason/.t3/worktrees/github/t3-ee501791-40773bf60626b84a`.
Branch: `t3/review-savia-merge-route`. Initial HEAD matched; initial tree clean.
Only this report is delivered. Primary owns integration and acceptance.

**Disposition and acceptance checks**

1. **Containment VERIFIED.** PR2 head `8744a9699812d62ea5ed31c63781748f833c3def` is an ancestor of the candidate. Main `3b0049163ece2d9431cee01f1bea624a66d9d8d4` is reachable through 244 raw first-parent commit objects. Ordinary merge-base returns a negative result under this checkout's shallow boundary. No fetch or history mutation was needed. One current Tony-to-main PR can supersede #2; merging #2 alone omits subsequent work. Close/supersede #2 only through primary's authorized external action. Its old green checks do not qualify this head.

2. **PR5: DEFER AS-IS, feature remains OPEN.** Exact main-to-PR5 diff: eight files, 318 additions, eight deletions. Seasonal rendering is absent from current app/home. This is an unported feature, not an indispensable repair to current behavior. The PR's own contract says no approved discount was activated. Absence of live campaign data does not cancel the feature commitment. Primary must explicitly record its deferral in the rollup and retain a follow-up; ?all PR increments delivered? would be false.

   Direct source at `cecdbeb05d03ccf01e8ccf74ad83eef4064c0846`, `src/app.js:35-66`, confirms strict approval/date/price gates but accepts coercible or fractional stock through `v.stock > 0`. Its checkout-named test at `tests/frontend-runtime.cjs:40-57` checks rendered text, not checkout. Current `src/app.js:279-283,346-350,667-680` has adapter isolation, newer media/cards and safer checkout mounting. Current `src/demo-api.js:128-129` derives cart totals from `price_minor`. Do not resolve integration by replacing these files. Historical exact-patch failure is not three-way merge proof.

   A later narrow port must preserve Jason's frontend, Denis images, approved data and both adapters. Require valid positive integer stock/nonempty sizes, Managua date boundaries, strict approved/active/USD metadata, and display/cart/quote equality using authoritative cents. Regenerate output from inputs; retain existing regressions. No immediate port is required for this product rollup.

3. **PR6: OPTIONAL POLICY CHANGE; keep draft open.** Tony's [NO-MISTAKES](../NO-MISTAKES.md):1-8,78-83 explicitly makes this gate optional/inactive. No root configuration exists. Current backend workflow equals PR2's backend bytes and has no dependency on this proposed job. Recorded protection requires seven product contexts, not no-mistakes. Therefore no PR6 port or shared CLI upgrade is required to merge the product increment.

   At `c62d8286e8c3a612d305484d918467c66effb6b4`, backend lines 20-45 introduce the dependency; it is not existing policy. Its root config disables repository commands and repair budgets, but does not prove execution. Recorded Windows v1.57.0 lacks the runbook targeting/privacy flags; authentic pipeline remains NOT RUN. The cached official verifier matches recorded Git blob `7379e69d406e60c0879d6ed93c23cbd5cf10fbf8`; its source checks declaration/head/phases and explicitly admits author-editability. Keep the draft failure visible. Never fabricate its declaration or weaken an adopted gate.

4. **Seven-context mapping VERIFIED against recorded protection and current source.** Live protection/check state was not refreshed.

| Required context | Workflow/job | Budget | Evidence layer |
| --- | --- | --- | --- |
| Complete backend suite on disposable SQL Server | savia.yml / backend-full-suite-sql | 25m | Legacy backend + SQL |
| Staff UI tests and real browser harness | savia.yml / staff-ui-and-browser | 15m | jsdom + Chrome, mocked HTTP |
| Real API + disposable SQL golden path | golden-path.yml / golden-path | 20m | Legacy real HTTPS/API/SQL + Chrome |
| build-and-guards | backend.yml / build-and-guards | 15m | Database-independent backend |
| Portable checks (windows-latest) | ci.yml / check[windows-latest] | 15m | Portable demo checks |
| Portable checks (ubuntu-latest) | ci.yml / check[ubuntu-latest] | 15m | Portable demo checks |
| Ledger check and deterministic digest | progress-digest.yml / digest | 5m | Ledger/PR-description consistency |

   These workflows target PRs to main; SQL jobs restrict fork execution. [Recorded protection](pr6/main-protection.json) has strict updates, enforced administrators and zero mandatory approvals. Preserve every context. Bind results to the final PR head, base and checked-out merge commit; record run attempts. If main advances, reconcile and revalidate the affected merge candidate. Old push/PR checks cannot satisfy new-head acceptance.

5. **Evidence reuse ACCEPTED WITH LIMITS.** The latest commit changes only assessments/receipts. Reuse source-bound worker evidence without rerunning unchanged suites: recorded PR5 DOM 29/29 and 16/16, predicates 27/27; PR6 11 rejection controls and 12 configuration checks. These counts come from [OUTCOMES](OUTCOMES.json), not my executions. Current-status v2 web 98/98 and .NET 145/145 remain historical evidence at their recorded SHA. None replaces final-head required CI or proves operational production.

6. **Runtime packet proposed; authorization readiness NOT VERIFIED until the preflight closures below.** Opening the PR itself starts runtime. Do not create it under an offline-only grant.

**Material findings, consequence and closure**

- **P1 ? omitted fourth SQL job.** [PLAN](PLAN.md):48 omits [savia-azure.yml](../../.github/workflows/savia-azure.yml):9-36. `build-and-prove` targets main/Tony PRs touching `savia/**`, runs for same-repository branches, and has a 30-minute timeout. The rollup contains that path. Consequence: the recorded authorization proposal understates execution. Primary must add this job and inspect its remaining commands, teardown and deployment predicate before approving runtime. Only its trigger/job header was fully retained within this review's six-invocation budget; comments are not deploy-exclusion proof.
- **P1 ? possible unbudgeted provider execution.** [progress-digest.yml](../../.github/workflows/progress-digest.yml):54-67,103-137 conditionally invokes Claude/Codex; `publish`:152-168 writes comments. Repository variables being empty does not establish secret absence. Primary must verify metadata-only narrator availability and billing authority. Require narrator inactivity or a separately approved capped provider grant before PR creation.
- **P2 ? cleanup cannot be inferred.** [savia-v2.yml](../../.github/workflows/savia-v2.yml):83-85 uses `down --volumes || true`, with no absence readback. Successful job status cannot prove removal. Primary must obtain fail-closed cleanup/readback through the smallest scoped correction, or explicitly document an accepted hosted-runner disposal boundary. Close only with fresh evidence; no correction/runtime was authorized here.
- **P2 ? misleading breadth.** `savia.yml:130-159` excludes the frozen restart test initially and may exit successfully without a release receipt. `golden-path.yml:42-43,125-130` automatically selects `--cash`; supply and stock-exception require manual opt-ins. Neither job establishes all recovery/supply paths or SAVIA v2 browser acceptance.

**Proposed one-attempt authorization packet**

Target: one same-repository Tony-to-main PR at primary's final frozen SHA; record exact base/head/merge SHA before accepting results. No local SQL, services, merge or deployment.

Authorize the seven table jobs plus `savia-v2.yml/check` (45m) and `savia-azure.yml/build-and-prove` (30m). PR path filters apply to the whole PR, not merely its last documentation commit; verify scheduling because the diff exceeds 5,000 files. Missing/skipped workflows are not execution proof.

Account also for `bug-proof.yml/proof` (20m), digest `narrate` (15m envelope, zero provider calls unless separately authorized), and `publish` (5m, existing PR-comment publication). The listed job envelopes total **225 job-minutes**; this is a proposed cap, not a dollar estimate or proof that all follow-ons are accounted for. Primary must verify Actions allowance and bug-proof's base-checkout script availability. Workflow-run follow-ons require default-branch applicability review; do not assume candidate workflows activate them.

SQL scope: GitHub-hosted disposable Ubuntu runners only; SQL Server 2022 Developer, nonproduction EULA acceptance, immutable image `mcr.microsoft.com/mssql/server@sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718`. Fictional customers, accounts, branches, stock and transactions only. Runner-generated masked credentials; never copy local secrets or .env files. Allow only job-owned migrations, fixtures, test databases, containers, networks and volumes.

Certificate scope: test-only SQL `Encrypt=true;TrustServerCertificate=true` / sqlcmd `-C` on disposable endpoints; ephemeral loopback HTTPS for the golden path. No host trust-store, production certificate or remote database changes. Verify Azure's exact equivalent policy during preflight.

Run automatic cash golden path once. Supply/stock-exception manual flags remain false; no manual dispatch. Existing bounded readiness polling and explicit test restart are within the attempt. No automatic test/workflow retries or fixes. Failure stops dependent work; retain sanitized outcomes and request a new bounded authorization after diagnosis.

Require per-step API/SQL oracles, zero unexpected skips, evidence hashes and teardown results. Verify owned API/Chrome/Node termination, disposable databases, containers/volumes/networks and temporary credentials/evidence removal. Preserve unrelated resources. Inspect v2's failure-log artifact policy before granting publication; do not substitute raw logs for reviewed outcomes.

Backend's separate SQL job is main-push/manual-only and excluded from this PR. Cloudflare artifact/deploy jobs exclude PR events. Azure deploy exclusion still needs predicate inspection. No Azure dispatch/OIDC deployment, merge, payment or production acceptance is included.

**Shortest sequence and review receipt**

Primary: record #2 supersession and #5/#6 deferrals; close the runtime preflight findings; publish the report through normal project controls; freeze the resulting SHA; obtain the exact one-attempt runtime grant; then create the current PR with `Por qu? / Alternativas / Evidencia / Qu? falta`. Inspect exact-head outcomes and cleanup. Request merge authority separately.

Six source-inspection invocations used. `git rev-parse HEAD`, source reads and eight-file PR5 diff exited 0. PR2 ancestry exited 0. Normal main ancestry/merge-base exited 1; `git rev-parse --is-shallow-repository` returned true. Raw-parent inspection resolved this without mutation. Verifier SHA256: `bacd65bc54c703a6ec5bdb96e1efaa6ab414b23e6bc96c5c5b93b5b56229129d`.

NOT RUN: tests/builds/browser, pipeline/init/install, SQL/Docker/services, GitHub reads/writes, dispatch, commit/push/merge/deploy. No private raw logs opened. Permitted stop: source-inspection limit; remaining runtime preflight belongs to primary. Lesson applied: enumerate every PR-triggered job before treating PR creation as an authorized runtime boundary.

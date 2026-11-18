# CI-strategy reusable index

| Artifact | Role | Authority / limit |
| --- | --- | --- |
| `tools/ci_strategy.py` | Deterministic impact classifier, syntax checks, fail-closed release receipt check | Read-only, no network calls or tokens; classification is advisory |
| `tests/test_ci_strategy.py` | Unit and negative contract tests for the selector and release receipt | Python stdlib; does not prove live GitHub configuration |
| `.github/workflows/ci-strategy-pilot.yml` | Read-only G1/G2 on spike branch or PR; risk summary | No merges, issues, secrets, agents, deploys or SQL |
| `.github/workflows/ci.yml` | Existing storefront QA on main | Already has full PR tests; no change in this pilot |
| `.github/workflows/backend.yml` | Existing .NET synthetic guard + SQL checks | SQL branch/trust policy remains in force |
| `.github/workflows/savia-v2.yml` | Existing SAVIA rules, web, SQL and .NET | `Tony` change gate; not replaced by fast pilot |
| `.github/workflows/savia.yml` | Existing SAVIA full judge and browser checks | Verify exact SHA and skipped status |
| `.github/workflows/golden-path.yml` | Existing real API + disposable SQL/browser golden path | Runtime authorization and source-bound proof required |
| `.github/workflows/bug-intake.yml` | Existing CI-failure deduplication | `workflow_run` requires the workflow on default branch to activate |
| `.github/workflows/bug-agent.yml` | Existing issue-labeled coding agent | Secret and approved spending required; not activated by this pilot |
| `.github/workflows/bug-proof.yml` | Existing red/green proof and PR comment | Do not bypass when fixing bugs |
| `docs/AUTO-SYNC.md` | Existing local checkout synchronization to Tony | Not installed or modified by this pilot |
| `docs/PROJECT-STATUS.md`, `savia/docs/PLAN.md` | Authoritative blockers and acceptance criteria | Read current source, don't infer readiness from backlog text |
| `docs/ci-strategy/PILOT.md` | Rollout and verification procedure | Pilot boundaries and required owner decisions |

`examples/` is intentionally absent. Add only user-approved examples. Avoid copying runner logs into policy files or creating another publisher.

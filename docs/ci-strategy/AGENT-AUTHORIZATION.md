# Paid coding-agent activation — explicit opt-in

Date: 2026-11-18. This is **configuration and code preparation only**, not an activation.

## Current boundary

The existing `.github/workflows/bug-intake.yml` creates/deduplicates issues from failed CI and labels them `bug`. Previously, `bug-agent.yml` would start an Opus coding agent simply when that `bug` label appeared, if `CLAUDE_CODE_OAUTH_TOKEN` existed. That is not sufficient user approval to spend money or grant write-capable code execution.

The new trigger requires **all**:
1. The repository owner manually sets `AI_BUG_AGENT_ENABLED=true` after explicitly authorizing provider cost, limit, and scope. This is not set by the PR.
2. `github.actor` equals `Suazo-AI` (an approved actor; bots do not qualify).
3. Exactly one opt-in path is satisfied:
   - For an issue: the owner adds label `agent-approved` to an issue **already carrying** label `bug`; or
   - For a manual workflow dispatch: the owner sets `authorize_paid_agent=true` and supplies an issue number.

An automatic CI failure or a newly labeled `bug` issue does **not** start a paid agent, even when the provider token exists.

The existing action remains scoped to a separate repair branch and PR targeting `Tony`. No automation can merge, deploy or edit production customer data from this workflow's prompt. The implementation still has write-capable GitHub permissions **if enabled**, so the owner must review the exact workflow revision and budget controls before enabling.

## Verifiable controls

- `tests/test_ci_strategy_agent_gate.py` extracts the actual workflow `if` expression and evaluates all 64 combinations of enable switch, actor, event, label, bug issue and manual authorization.
- The test asserts the action's `label_trigger` is `agent-approved`, not `bug`.
- The workflow remains on `Tony`; the issue/dispatch trigger will only operate from default `main` after separately approved integration, per GitHub Actions rules.
- No secret is added to this repo, and the agent action is never executed as part of PR checks. Runtime provider behavior and exact billing remain **NOT RUN**.

## Go/no-go checklist for the owner

Before activating the variable:
- Confirm provider account, token type, billing rates and real budget with an external spend limit.
- Inspect the action pin and the exact final workflow on default branch, including permissions and issue prompt-injection handling.
- Check authorization boundaries for external contributors and forks; do not grant broad write credentials to untrusted PR code.
- Ensure the agent's GitHub-created PR actually triggers independent CI; a PR created solely with `GITHUB_TOKEN` can have restricted workflow chaining. Adopt a reviewed GitHub App credential only when needed and approved.
- Test one disposable, non-production `bug` issue with no approval flag first: agent job must be skipped.
- Only then request a separate, explicitly cost-approved first live agent run and verify its PR/CI/usage.
- Set `AI_BUG_AGENT_ENABLED=false` to immediately disable future jobs. Existing jobs may need separate manual cancellation.

**No-go:** absence of spending approval, budget limit, default-branch integration, protected PR review or reproducible red/green proof. Do not interpret green offline predicate tests as real paid-agent execution.

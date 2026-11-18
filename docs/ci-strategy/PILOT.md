# Four-gate CI pilot — 2026-11-18

**Scope:** a deliberately read-only implementation of the CI architecture from the [shared discussion](https://chatgpt.com/share/6afd73b6-13d8-83e8-aef7-4a52bf4d52bf), based on `Tony`. This document is an experiment receipt, not a statement of production readiness.

## What exists and what remains inactive

| Stage | Proposed execution | Activation state |
| --- | --- | --- |
| G1 | Changed-path classifier, source syntax, diff whitespace, unit tests of gates | New `ci-strategy-pilot.yml`, active on its own `spike/ci-strategy-*` branch after workflow commit; other branches only after approved integration |
| G2 | Selected storefront or SAVIA architecture tests with 5-minute limits | New pilot, **advisory**; existing full PR workflows remain authoritative |
| G3 | Existing `ci.yml`, `backend.yml`, `savia-v2.yml`, `savia.yml`, `golden-path.yml` and any approved merge queue | Not changed; verify required outcomes on *exact* integration commit |
| G4 | Read-only `release-check` rejects stale SHA, missing evidence, skipped check and missing approval | No release, canary, deployment, or automatic artifact promotion |
| Failure loop | Existing bug-intake → issue dedup → bug-agent → bugproof → isolated draft PR | Depends on default-branch integration and explicit approved agent authentication; not activated by this PR |
| Ongoing prioritization | Existing six-hour ChatGPT development task | Reuse it; no new schedule |

## Commands

```bash
# Pure offline contract tests (no new packages)
python3 -m unittest discover -s tests -p 'test_ci_strategy.py' -v

# Compare two trusted full Git SHA values in a local checkout
python3 tools/ci_strategy.py plan --base <BASE_SHA> --head <HEAD_SHA>
python3 tools/ci_strategy.py static --base <BASE_SHA> --head <HEAD_SHA>

# Without a checkout, analyze a synthetic list of changed paths
printf '["src/demo-api.js","docs/CI-CD.md"]' > /tmp/changed-paths.json
python3 tools/ci_strategy.py plan --files-json /tmp/changed-paths.json

# Read-only release evaluation against a private receipt (does not deploy)
python3 tools/ci_strategy.py release-check --receipt /path/to/private-receipt.json
```

## Risk-aware selection contract

- G1 target ≤60 seconds; G2 job budget is 5 minutes, with failure on timeout instead of quietly declaring success.
- Syntax check handles changed Python, JavaScript and JSON files; TypeScript/C# type checks and YAML parsing are explicitly out of scope for this fast job and remain with established tools.
- Storefront changes: local adapter/catalog regression and portable runner contracts (not a browser).
- SAVIA changes: architecture and Python tool tests. The SQL engine, actual API, web UI, permissions, and refund flows are not exercised by these fast tests.
- Critical or unknown paths always mark `requires_full: true`. This metadata **does not prove** the full tests have run. No existing checks or branch policies are removed. A future mandatory ruleset must require these existing jobs as applicable.
- `GITHUB_TOKEN` is read-only here. Never run code from issue/PR descriptions, use `pull_request_target`, or grant write privileges to a test job.

## Release receipt (contract only)

The offline `release-check` expects a JSON object with a `main` branch, exact `commit_sha`/`artifact_sha`, completed successful check runs bound to that SHA, and booleans explicitly confirming: human approval, tested rollback, business acceptance, telemetry, SQL runtime, and payment sandbox verification. Its required check names are fixed in `tools/ci_strategy.py`.

**Warning:** A user-supplied receipt is not an authenticated source. Even a structurally passing receipt is only **eligible for manual review**. Real release acceptance also requires fetching check runs from trusted GitHub API, verifying artifact content/digest, owner sign-off and the production plan. This pilot does none of those external actions.

## Adopt in phases, never silently replace CI

1. Review this pilot's diff; verify the `spike/ci-strategy-*` workflow run on the exact SHA. No merging yet.
2. Compare selection with 20 recent PRs and record false negatives, classification distribution and p95 times; independently review risk rules.
3. With explicit owner approval, merge into `Tony` and test on ordinary PRs. Keep all existing full jobs running until evidence supports changes.
4. Approve separately any migration of full PR jobs to merge queue or post-merge. Only then update required check rulesets, after verifying that every critical class is still covered.
5. Integrate reviewed agent intake to default `main` with independent authorization of provider token, budget and scope. Use existing bug pipeline; no duplicate automatic publisher.
6. Enable G4 release controls only after business readiness, payment sandbox, SQL/browser proofs, incident response, immutable artifact storage and monitored rollback. No canary without deployment approval.

## Proof criteria that can fail

- Unsafe diff paths and unknown paths reject or require full inspection.
- A stale, skipped, duplicate or missing check produces nonzero release-check exit.
- Empty test selection fails rather than silently skipping every check.
- No production source files, SQL migrations, tokens or deployment workflow are modified.
- GitHub PR remains draft and both CI results and the SHA are independently inspected before handoff.

## Handoff

STATUS: Pilot only, production NO-GO.
DONE: Fixed-rule risk selector, syntax guard, sample impact tests, offline release guard, skill and workflow design.
NEXT: Validate the isolated workflow in GitHub; review false negatives; integrate only with approval.
BLOCKER: Main/Tony integration, branch policy, provider authorization, real SQL/browser/payment acceptance.
EVIDENCE: GitHub commit/CI links must be attached after an actual run; local commands are not remote evidence.

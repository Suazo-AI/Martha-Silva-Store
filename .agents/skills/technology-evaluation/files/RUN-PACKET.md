# Technology evaluation — run packet

> Copy this file to the repository-approved evidence folder for one evaluation. Replace every bracketed field. Use `UNKNOWN`, `NOT RUN`, or `NOT APPLICABLE`; do not leave ambiguous blanks.

## 0. Run identity and permissions

- Run ID: `[slug-YYYYMMDD]`
- Started / updated: `[ISO date/time + timezone]`
- Repository / application: `[name and URL]`
- Target branch / base SHA: `[branch]` / `[40-char SHA]`
- Candidate branch / head SHA: `[branch]` / `[40-char SHA or NOT CREATED]`
- Open PRs / overlap check: `[URLs and findings]`
- Repository instructions read: `[AGENTS, entry point, status, decisions, security, area guidance]`
- Allowed actions: `[read / edit / tests / branch / draft PR / other]`
- Forbidden without separate approval: `[merge / deploy / spend / secrets / live data / migrations / etc.]`

## 1. Candidate technology and research

- Name / version / category: `[name@version]`
- What it does: `[plain description]`
- Problem it solves: `[mechanism and intended outcome]`
- What it does not solve: `[boundaries]`
- Official docs: `[URLs + access dates]`
- API/reference docs: `[URLs + relevant APIs]`
- Release / compatibility / runtime evidence: `[URLs and details]`
- License / security / maintenance: `[evidence or UNKNOWN]`
- Dependencies / account / network / paid usage: `[evidence or UNKNOWN]`
- Existing application capability / alternatives: `[what was inspected and why insufficient]`

### Source matrix

| Claim | Source URL | Version/date | Evidence excerpt or section | Confidence / caveat |
|---|---|---|---|---|
| `[claim]` | `[URL]` | `[version/date]` | `[section]` | `[high/medium/low]` |

## 2. Target application problem

- User / actor: `[who]`
- Workflow: `[start → end]`
- Failure, cost, or pain: `[specific]`
- Current code path: `[UI → API → service → storage → tests]`
- Existing behavior / tests: `[paths and commands]`
- Evidence: `[bug, CI run, metric, incident, source finding]`
- Candidate problems considered: `[short list and ranking]`
- Selected highest-value bounded problem: `[one problem]`
- Why this technology is a fit: `[mechanism-to-problem reasoning]`
- Non-goals: `[explicit exclusions]`
- Demo/simulator vs production boundary: `[clear distinction]`

## 3. Hypothesis, baseline, and acceptance contract

**Hypothesis:** For `[workflow]`, `[technology/version]` will improve `[measurable property]` over `[baseline]` while preserving `[invariants]`, demonstrated by `[tests/evidence]`.

- Baseline command/results: `[commands, outputs, SHA]`
- Baseline measurement (when meaningful): `[value, method, environment]`
- Business/security invariants: `[list]`
- Positive cases: `[list]`
- Negative/boundary cases: `[list]`
- Retry/idempotency/concurrency/recovery cases: `[list or N/A with reason]`
- Compatibility targets: `[runtime/OS/language]`
- Performance/resource budget: `[target or N/A]`
- Stop/failure criteria: `[explicit]`
- Rollback/removal plan: `[explicit]`

## 4. Minimal PoC plan

- Integration point: `[path/module]`
- Design/data flow: `[short diagram or explanation]`
- Minimum API used: `[surface]`
- Types / validation boundary: `[how checked]`
- Dependencies added/changed: `[versions, lockfile, license]`
- Production runtime impact: `[NONE or exact details]`
- CI changes: `[NONE or exact details]`
- Deployment/config/secrets impact: `[NONE or exact details]`
- Files expected to change: `[paths]`
- Files forbidden to change: `[paths]`
- Test seam/fixtures: `[details]`
- Reviewer and approval boundary: `[details]`

## 5. Implementation record

- Branch created from: `[base SHA]`
- Red test command and result: `[command + evidence link]`
- Implementation summary: `[what changed]`
- Commits: `[SHA list]`
- Draft PR: `[URL or NOT CREATED]`
- Diff summary: `[files, additions/deletions, production vs test-only]`
- Unrelated files changed: `[NONE or explanation]`

## 6. Verification evidence

| Gate / test | Exact command or workflow/job | SHA | Environment | Result (PASS/FAIL/SKIPPED/NOT RUN) | Evidence URL/path | Limitation |
|---|---|---|---|---|---|---|
| Gate 1 / policies | `[command]` | `[SHA]` | `[OS/runtime]` | `[result]` | `[link]` | `[limit]` |
| Direct PoC tests | `[command]` | `[SHA]` | `[OS/runtime]` | `[result]` | `[link]` | `[limit]` |
| Existing domain tests | `[command]` | `[SHA]` | `[OS/runtime]` | `[result]` | `[link]` | `[limit]` |
| Negative/adversarial tests | `[command]` | `[SHA]` | `[OS/runtime]` | `[result]` | `[link]` | `[limit]` |
| CI matrix | `[workflow/job]` | `[SHA]` | `[runner]` | `[result]` | `[link]` | `[limit]` |
| SQL/browser/payment runtime | `[exact test]` | `[SHA]` | `[environment]` | `[result]` | `[link]` | `[limit]` |

- Checkout SHA equals declared tested SHA: `[YES/NO + evidence]`
- Required check names and statuses inspected individually: `[YES/NO + evidence]`
- Selected job skipped or stale: `[NONE or details]`
- Diff/secret/license/dependency review: `[result]`
- Red test reproduced before fix: `[YES/NO + evidence]`
- All final tests rerun after last code change: `[YES/NO + evidence]`

## 7. Independent review

### Critic

- Reviewer/agent: `[identity or NOT RUN]`
- Exact head SHA inspected: `[SHA]`
- Findings by severity: `[critical/high/medium/low]`
- Reproduced concern: `[command and evidence]`
- Fixes / accepted residual risks: `[details]`

### Judge

- Reviewer/agent: `[identity or NOT RUN]`
- Exact head SHA inspected: `[SHA]`
- Decision: `[GO / GO WITH FIXES / SPIKE ONLY / DEFER / NO-GO]`
- Rationale: `[evidence]`
- Blockers: `[list]`

## 8. Technology scorecard

Score 1–5; every score requires evidence. For API nuance, type safety, testing, complexity, docs, and deployment, 5 is best.

| Criterion | Score / 5 | Evidence and rationale | Remaining caveat |
|---|---:|---|---|
| API simplicity / agent ergonomics | `[ ]` | `[evidence]` | `[caveat]` |
| Type safety | `[ ]` | `[evidence]` | `[caveat]` |
| Ease of testing | `[ ]` | `[evidence]` | `[caveat]` |
| Cyclomatic complexity | `[ ]` | `[baseline → candidate, scope]` | `[caveat]` |
| Documentation quality | `[ ]` | `[official docs and practical completeness]` | `[caveat]` |
| Deployment impact | `[ ]` | `[exact required changes or NONE]` | `[caveat]` |

Additional evidence (do not fold into the six scores):
- Maintenance/license/ecosystem: `[evidence]`
- Security/privacy/supply chain: `[evidence]`
- Performance/resource cost: `[measured baseline and result or NOT MEASURED]`
- Economic cost: `[measured or UNKNOWN]`
- Lock-in/removal cost: `[assessment]`

## 9. Recommendation

- Decision: `[ADOPT (bounded) / GO WITH FIXES / SPIKE ONLY / DEFER / NO-GO]`
- Overall fit: `[summary; mean score optional, never decisive by itself]`
- Why: `[evidence-backed rationale]`
- Required fixes/prerequisites: `[list]`
- Evidence that would change the decision: `[list]`
- Authorized next action: `[one]`
- Explicitly not authorized: `[merge/deploy/spend/secrets/live data/etc.]`

## 10. Handoff

**STATUS:** `[DONE / PARTIAL / BLOCKED + risk class]`

**DONE:** `[actual completed work]`

**NEXT:** `[one concrete action]`

**BLOCKER:** `[exact missing approval/evidence/environment or NONE]`

**EVIDENCE:** `[repository, branch, PR, exact SHAs, test commands/results, CI URLs, artifacts, NOT RUN list]`

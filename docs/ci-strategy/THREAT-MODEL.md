# CI hardening threat model and proof boundaries

Date: 2026-11-18. Target: `spike/ci-strategy-20261118`, base `Tony`.

## Threats that the first green pilot missed

| Failure mode | What could go wrong | Defensive contract |
| --- | --- | --- |
| PR synthetic merge checked out but policy reports head SHA | Source/verification attribution is incorrect | All jobs checkout `pull_request.head.sha`; G1 asserts `git rev-parse HEAD == head` |
| Selected G2 job is skipped | Fast pipeline looks successful without executing a required suite | `gate2-check` fails unless selected jobs are `success` and non-selected jobs are `skipped` |
| Self-attested release receipt | Crafted JSON declares approvals, checks and money safe | `release-check` always returns nonzero; `audit-main` reads remote GitHub checks but still never certifies artifacts |
| Rename sensitive source into innocuous path | A change hides an original sensitive location | Git `--name-status -z --find-renames` includes both old/new paths |
| New source directory or case-aliased files | Unknown changes slip through selectors; Windows/Linux differ | Unknown is critical + both G2 suites; reject casefold collisions |
| Checkout file links outside repository | Symlink parent can bypass intended syntax source boundary | Reject direct and ancestor symlink paths; resolve under checkout |
| SAVIA golden path mapped to storefront | Wrong tests run while relevant browser/API/SQL tests are skipped | Explicit mapping of `tests/golden-path/` and `savia/deploy/`, `savia/demo/` |
| Runtime logic hidden behind generic JS name | Price, auth or order behavior changes in `src/app.js` or `savia/web/api.mjs` | Mark production JavaScript and HTML paths critical independent of filename |
| Missing GitHub branch rules | Workflow green cannot prevent manual merge | Never claim enforcement. Ruleset/protection changes require owner approval and follow-up verification |
| CI source itself modified in PR | A PR can edit its own policies and tests | Mark workflow/tools critical, require independent code review + trusted branch protection; self-tests alone are insufficient |
| Paid agent wakes from an issue label | Token usage or untrusted-code execution without owner approval | Existing bug agent remains unactivated on default branch; do not enable without approved scope, explicit opt-in and budget |
| Rollout errors on card charge or inventory | Silent loss/duplicate operation impacts money or customer data | Forbid canary and fix-forward without payment, SQL, rollback and business proofs |

| Paid agent starts when CI auto-labels `bug` | Unapproved Opus consumption and write-capable PR authoring | Explicit repo enable flag, owner actor and per-issue `agent-approved`/manual approval; 64 predicate combinations tested; still disabled on main |

## Proof classes

1. **Structural:** Changed-path classifier and fixed test selection. Does not prove correct domain behavior.
2. **Syntax:** Python AST, JSON and Node syntax for changed source in a fixed checkout. Not a security scanner or a TypeScript/C# compiler.
3. **Fast regression:** Selected local JavaScript/Python fixtures, no SQL or real browser.
4. **Integration:** Existing branch workflows use real disposable SQL, synthetic browser paths and/or actual API. Must check exact SHA, scope, skips and permitted runtime.
5. **Release:** Independently retrieved remote checks plus artifact digests, signed business approvals and real sandbox, observability and rollback. **Not implemented by this candidate.**

## Out of scope and limitations

- A valid `audit-main` result proves only public GitHub check-run metadata matched the current `main` ref at query time. Branch may advance immediately afterward. App slugs help disallow arbitrary status providers, but a compromised workflow or GitHub credential remains a trust risk.
- The tool never downloads or hashes a release artifact, verifies a bank reconciliation, validates a production database, or starts a deployment.
- No branch rulesets were present in the repository rulesets API during this review. Classic branch-protection settings were not independently verified; no settings were changed.
- Selection is conservative for all critical code and unknown areas, deliberately sacrificing fast CI for uncertain scopes. Risk-aware test selection can only replace full PR suites after historical impact recall, mutation or negative oracles, and an approved ruleset enforce G3.
- GitHub Actions jobs run the candidate's test scripts; this is not a substitute for a trusted base-branch policy validator. A dedicated protected ruleset/CODEOWNERS strategy is needed before declaring agent-safe merging.

## Release guarantee

`tools/ci_strategy.py release-check` is intentionally not able to return PASS from user-supplied JSON. It reports policy conditions and the permanent provenance blocker. `audit-main --sha SHA` is read-only, returns an external check-run assessment, and always prints `release_allowed: false`. The only actual release action remains separate and requires explicit approval.

# Technology evaluation skill — corrections

## 2026-11-19 — Initial release

- Created one canonical workflow to evaluate a technology against a real application's highest-value bounded problem.
- Separated research, application discovery, hypothesis/baseline, PoC design, implementation, draft PR, verification, independent critique, scoring, decision, and integration/release.
- Added explicit role contracts and a reusable run packet. No example is included because no user-approved example has been designated.
- Repository publication is intentionally pending: the repository requires the canonical local checkout and local progress/synchronization hooks. The available GitHub connector cannot execute those hooks; do not bypass that policy with a direct API commit.

## 2026-11-20 — Clean code gate and repository install

- Installed the skill at `.agents/skills/technology-evaluation/`, next to the other repository skills, on branch `Tony` with Jason's approval.
- Added the "Clean code gate": measured complexity and function-length rules with the pinned biome 2.6.4, dead-code, duplication and module-boundary checks, a ratchet, and refactor rules.
- Baseline measured from `savia/`: 37 `noExcessiveCognitiveComplexity` and 50 `noExcessiveLinesPerFunction` findings in 73 files of `savia/web`.
- Worst functions: `sale.mjs:657` (99), `payments.mjs:101` (47), `return.mjs:300` (40), `return.mjs:650` (34), `scanner.mjs:171` (32).
- Limits: CI does not enforce the ratchet yet. The storefront, .NET and T-SQL are not measured. Duplication and module boundaries are manual checks.
- Next: run the skill on `sale.mjs:657` as the first refactor, coordinated with PR7.

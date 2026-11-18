# CI-strategy corrections

## 2026-11-18 — Baseline inspection

- The shared architecture separates PR code rules, impact-selected PR tests, full integration tests and release/telemetry gates. Reusing existing SAVIA and storefront CI is safer than replacing them in one PR.
- The actual remote has active development under `Tony`, while default `main` does not yet contain the issue-driven bug workflows. `workflow_run` triggers require a default-branch workflow. Do not claim that a workflow committed only on a feature/Tony branch is an active default-branch agent hook.
- A fast-only PR selector must be advisory until critical-path exclusions, required check status and branch rules are explicitly configured. The conservative classifier treats unknown files as critical.
- Release receipts can be fabricated as JSON. The CLI checks structure and internal SHA consistency but cannot authenticate external check runs. A future source-bound evidence collector must fetch GitHub check-run evidence and independently verify artifact hashes before any release.
- No agent credential, paid usage, canary, deployment, live SQL or public release has been authorized by this pilot.

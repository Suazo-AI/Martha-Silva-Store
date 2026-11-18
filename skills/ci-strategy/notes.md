# CI-strategy corrections

## 2026-11-18 — Baseline inspection

- The shared architecture separates PR code rules, impact-selected PR tests, full integration tests and release/telemetry gates. Reusing existing SAVIA and storefront CI is safer than replacing them in one PR.
- The actual remote has active development under `Tony`, while default `main` does not yet contain the issue-driven bug workflows. `workflow_run` triggers require a default-branch workflow. Do not claim that a workflow committed only on a feature/Tony branch is an active default-branch agent hook.
- A fast-only PR selector must be advisory until critical-path exclusions, required check status and branch rules are explicitly configured. The conservative classifier treats unknown files as critical.
- Release receipts can be fabricated as JSON. The CLI checks structure and internal SHA consistency but cannot authenticate external check runs. A future source-bound evidence collector must fetch GitHub check-run evidence and independently verify artifact hashes before any release.
- No agent credential, paid usage, canary, deployment, live SQL or public release has been authorized by this pilot.

## 2026-11-18 — Adversarial second pass

- Initial green G1 could check a synthetic PR merge tree while reporting the PR head SHA; bind checkout and assert SHA.
- Initial G2 summary accepted skipped required tests; enforce selected=success and unselected=skipped.
- Initial G4 self-attested JSON could claim release readiness; fail-closed release-check now always denies it. New audit-main reads public GitHub metadata but never approves release.
- Initial selector misrouted `tests/golden-path/` and omitted SAVIA fast tests for `savia/demo/` and `savia/deploy/`; add explicit mappings and 20 representative historical samples.
- Initial rename and parent-symlink handling could hide sensitive old paths or leave checkout; include both rename paths, reject ancestor symlinks and casefold collisions.
- Existing full CI, rulesets, agent credentials and deployments remain untouched; independent branch rules still require owner approval.

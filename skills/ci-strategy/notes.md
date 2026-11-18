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

## 2026-11-18 — Red/green CI correction (route classification)

- Red proof: G1 on PR run `44392626090` / job `135114013758`, head `81dbdfc`, executed 32 tests; `test_workflow_and_unknown_changes_are_cross_cutting` failed because `unknown/entry.py` was critical but selected neither storefront nor SAVIA. The push job reproduced the same failure.
- Corrective change: unknown paths now select both fixed fast-test families. Keep the negative regression test unchanged and rerun GitHub Actions against a fresh exact SHA.
- Separate process issue: `Progress digest` run `44392626162` failed because the PR had moved out of draft and lacked mandatory headings (`Por qué`, `Alternativas`, `Evidencia`, `Qué falta`). Updated PR description; do not change the progress validator to pass.

## 2026-11-18 — Avoid duplicate fast CI

- Observed the same head SHA produced both a spike `push` and a PR run with identical G1/G2 test families. This doubles runner scheduling and log noise without increasing distinct coverage. Removed the spike push trigger. The PR `synchronize` event remains mandatory; existing full mainline push workflows are unchanged.

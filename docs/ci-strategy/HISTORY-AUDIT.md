# Historical change-path calibration — 20 Tony commits

Inspection date: 2026-11-18. Source: authenticated GitHub repository read of the newest 20 commits on `Tony`, their subjects, file lists and commit SHA values. This is a **one-path-per-commit regression sample** and a design review, not a complete historical test-selection recall experiment. The repository returned fewer than 20 historical PRs; commit sampling is explicitly not equivalent to PR sampling.

| # | Commit | Representative path under review | V2 risk | Fast test family |
| --- | --- | --- | --- | --- |
| 1 | `0147124` | `savia/db/migrations/V030__catalog_recounts_and_business_kpis.sql` | critical | SAVIA |
| 2 | `16ab6f2` | `tests/golden-path/golden_path.py` | critical | SAVIA |
| 3 | `ec11e64` | `savia/db/tests/sales/172_return_retry_safety.sql` | critical | SAVIA |
| 4 | `9879d5c` | `savia/deploy/migrator/MigrationExecution.cs` | critical | SAVIA |
| 5 | `ac0bb9f` | `.github/workflows/golden-path.yml` | critical | Both |
| 6 | `ba8ff2b` | `docs/merge-readiness-20261116/corrections/STATUS.md` | docs | None |
| 7 | `edd2e09` | `tools/bugproof/prove.py` | critical | Both |
| 8 | `670d4a8` | `docs/merge-readiness-20261116/pr5/probe.cjs` | normal (executable docs) | None |
| 9 | `51bbea4` | `docs/branch-choice-20261107/build.py` | normal (executable docs) | None |
| 10 | `2587712` | `savia/tools/verify.py` | critical | SAVIA |
| 11 | `63a8b1e` | `savia/web/screens/sale.mjs` | critical | SAVIA |
| 12 | `2c96904` | `savia/demo/api/index.mjs` | critical | SAVIA |
| 13 | `92d1f15` | `savia/docs/research/staff-metrics-20261114/charts/verify.py` | normal (executable docs) | None |
| 14 | `c360607` | `savia/docs/research/staff-metrics-20261114/decision.html` | docs | None |
| 15 | `4cc1de4` | `savia/docs/research/staff-metrics-20261114/decision.html` | docs | None |
| 16 | `7c3d19f` | `savia/docs/research/staff-metrics-20261114/mockup.html` | docs | None |
| 17 | `44fe307` | `savia/web/etiqueta/etiqueta.mjs` | critical | SAVIA |
| 18 | `5b70369` | `savia/db/migrations/V028__usd_change.sql` | critical | SAVIA |
| 19 | `1cb1a78` | `savia/docs/design/DOLARES.md` | docs | None |
| 20 | `6ef6591` | `savia/src/Savia.Application/ForeignCash.cs` | critical | SAVIA |

**Representative-path counts:** 12 critical, 3 normal/executable-doc, 5 docs-only. These are NOT complete-commit classifications because the commits often modify other areas at the same time (e.g. commit `ac0bb9f` changed 227 files). A full-commit analyzer should classify **all changed paths**, not these examples, before determining actual gate distributions.

## Concrete corrections informed by this sample

- Historical `tests/golden-path/` changes previously activated storefront checks, not the SAVIA family. They now select SAVIA and require deep validation.
- Historical `savia/deploy/` and `savia/demo/` were unknown; unknown paths were critical but lacked the matching domain's fast tests. Both have explicit SAVIA mappings now.
- Historical executable helper code inside `docs/` and `savia/docs/` previously appeared docs-only. It is now reported as executable documentation for human review. It is not automatically treated as product-critical without additional evidence.
- General `savia/web/` runtime changes and `src/` runtime changes are marked critical even when their filenames do not say `payment` or `auth`.

## Honest acceptance boundaries

This sample demonstrates **known path-mapping regressions** and prevents their recurrence through unit tests. It does not measure false-negative rate over 20 full PRs, since this repository does not have that many PRs and this review only selected representative paths per commit. No p95 CI feedback measurement or comparative cost result is claimed. Before enabling mandatory risk-based skipping, collect full path sets, expected affected tests, and actual missed failures for a representative PR dataset. Never use this file to justify disabling SQL/security/browser tests.

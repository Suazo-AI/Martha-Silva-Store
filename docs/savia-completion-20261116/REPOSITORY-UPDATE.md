# Repository update scope

2026-11-16. Request: bring completed project work up to date in the repository.
Base: `63a8b1e9bfe50e9426295cb22097514fc15155e7`, branch `Tony`.

## Included

- Four exact paths from the verification worker: two code/test files and its two public reports.
- Current routing and status in the root README, PROJECT-STATUS, AGENT-START, CODE-MAP, SAVIA README/PLAN and the UX report.
- This completion record and the existing AGENTS.md clarity guidance explicitly supplied by Jason.
- The Astra synchronization report and the primary's source-bound disposition. Only an extra EOF blank line is removed from the public report; original bytes are archived privately. Its implementation and runtime remain pending.

## Preserved exclusions

- The separate working change in `docs/DECISIONS.md`. It includes historical preview-target wording that this update does not accept or execute.
- Untracked raw logs, TRX, historical worker scratch files, videos, local HTML decision pages and incomplete simulation logs. Their presence alone does not establish acceptance or suitability for public publication.
- `.cloudflare/`, `.lavish/`, `skills-lock.json` and the untracked `.agents/skills/design-taste-frontend/` third-party bundle. They are not required to deliver this source correction.
- Ignored private exports and credentials. No blanket staging is used.

## Checks and publication boundary

Primary matched 7/7 correction bindings and 6/6 synchronization Git/LF bindings, inspected the original one-case Spec17 TRX and passed the integrated 4/4 regression suite.
`python tests/test_progress.py`: 23 tests PASS, exit 0. Its isolated fake sync receipts are not a publication of this repository.
`python tools/export_progress.py --verify`: PASS, 15 preserved evidence hashes, exit 0.
Final candidate checks: 15/15 public-content scans, 276 relative links and 12 historical local links passed; `git diff --check` exited 0.
The full local repository check exited 1 on three Windows symlink fixture errors (`WinError 1314`); it is not reported as green.
The completion record assigns the existing Linux snapshot workflow as the authorized verification route for those checks.
GitHub readback also records the three actual PR source/base pairs and their relationship to the published source.
The commit hook adds a generated progress receipt. Its post-commit hook publishes to Tony automatically.
Any commit touching `savia/**` starts the disposable-SQL workflow. Jason approved the new scope after reviewing this candidate:
"A. Publicar el candidato y ejecutar su CI (recomendado)".
Scope: one source publication to Tony and its automatic GitHub Actions CI, SQL Server 2022 Developer with fictional data,
the existing 45-minute job limit, test EULA/certificate trust and container/volume cleanup.
This grants no local SQL, synchronization simulator, customer data or additional runtime campaign.
No hook bypass, force push, merge, deployment or automatic retry is part of this update.

Remote completion requires `SYNCED`, a matching Tony SHA and readback of applicable checks.
A pending CI result is reported as pending. The previous failed CI remains part of the record.

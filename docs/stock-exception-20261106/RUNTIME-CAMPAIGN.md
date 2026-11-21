# Isolated persistence campaign: prepared, NOT AUTHORIZED

Owner: primary on SUAZO-PC. Runtime target: GitHub Actions `ubuntu-24.04`, not SUAZO-PC SQL.
Executable candidate: `139c3898d1e76e66a07b89f179e50508672df473`, 33 frozen LF bindings.
The next publication contains documentation only. Resolve its exact Tony HEAD before requesting approval.
Verify that both dispatches use that approved SHA and unchanged executable bindings. A different SHA requires a fresh check before runtime.

## Two runs, one bounded campaign

1. Dispatch `.github/workflows/savia.yml` once. Run every backend test, including the three stock-exception SQL cases, backup/restore and owned-container restart. Require zero failures/skips and successful cleanup.
2. After the first run succeeds and cleanup is verified, dispatch `.github/workflows/golden-path.yml` once with `supply_receipt=true` and `stock_exception=true`.
   Run the existing smoke path, then real Chrome -> HTTPS API -> SQL. Retain all17 supply/browser checkpoints and four SQL identity oracles; require the five stock checkpoints and stock identity oracle too.

Prepared commands; execute only after Jason authorizes this exact campaign:

```powershell
npx -y gh-axi workflow run savia.yml --ref Tony --repo Suazo-AI/Martha-Silva-Store
npx -y gh-axi workflow run golden-path.yml --ref Tony --field supply_receipt=true --field stock_exception=true --repo Suazo-AI/Martha-Silva-Store
```

Read back Tony immediately before each dispatch. Stop if it differs from the approved publication SHA.
Read back each run's `head_sha`, inputs, attempt and jobs. Do not rerun automatically.
If a check fails, stop dependent execution and report the failed assertion before another runtime request.

## Effects, limits and cleanup

The existing workflows create separate disposable SQL Server2022 Developer containers with synthetic accounts/data.
They use the pinned image `mcr.microsoft.com/mssql/server@sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718`.
The existing non-production EULA setting and test-only certificate acceptance remain explicit.
The harness creates temporary loopback HTTPS material; no SUAZO-PC certificate or trust-store changes.
Limits remain15/25 minutes for the two SAVIA jobs and20 minutes for the golden-path job. Actions minutes are consumed; actual billing is unknown.
No production credentials, real customers/payments, local SQL, deployment or merge.

Each workflow must remove only its owned container and verify its absence.
The golden harness must stop owned browser/API processes and drop only databases acknowledged as created.
Sanitize evidence before upload. Any uncertain cleanup or evidence-safety failure makes the run unacceptable.
For cancellation/failure, inspect the existing always-cleanup outcome; do not claim that container removal implies production rollback.

## Acceptance and remaining boundaries

Primary must inspect sanitized per-test outcomes, the three stock SQL case names, migration/backup/restore/restart proof, all22 browser checkpoints, five identity oracles and cleanup.
Compare recorded sale/review identities, exact retry key/body and stock/accounting invariants; a green workflow label is insufficient.
Source files and acceptance criteria must remain unchanged throughout the campaign.

This campaign proves only its Linux synthetic scope. It does not close the SUAZO-PC physical trial, C2/C9/C10, payment integration or production acceptance.
Source authority: `docs/DATABASE.md`, "Obtener alcance de runtime para esa ejecución. La aprobación del lote anterior está consumida."
No runtime is started by this document. Jason authorizes; primary executes and accepts evidence.

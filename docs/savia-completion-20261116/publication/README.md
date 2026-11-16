# Publication reconciliation - 2026-11-16

Jason requested publication of all project progress. This checkpoint publishes historical public documentation and closes the corrected-source CI readback.
Product source, generated output, dependencies and workflow definitions are unchanged.

## Verified product baseline

`Tony@2587712b8399eb1b4ac59fcf7dfd6de9852b1f79` was independently read back from GitHub.
All four applicable workflows completed successfully on that exact SHA, attempt 1:

- [SAVIA v2 check](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/43950552359): web 98/98 and .NET 145/145; zero failed or skipped tests.
- [Tony source snapshot](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/43950552396): integrity and Linux historical portable regression suite passed.
- [Progress documentation](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/43950552547): success.
- [Progress digest](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/43950552494): success.

The actual SQL job log records removal of its container, volume and network.
Linux passed the repository gate affected locally by Windows symlink privileges. No Windows security setting was changed.
[Sanitized source-bound readback](CI-2587712.json) preserves these results and limits.

## Imported public history

[Import and exclusion manifest](IMPORT.json) lists 49 formerly untracked public files, raw/LF hashes and local exclusions.
They contain the November 3 C3/PR review, the November 5 frontend decision and hardening reports,
the November 7 branch explanation and gallery evidence, and synthetic supply/stock browser outcomes.
Their old pending-review labels describe their original checkpoints. Current accepted gallery evidence remains in
[TECHNICAL-ACCEPTANCE](../../gallery-contracts-20261107/TECHNICAL-ACCEPTANCE.md) and the dated project status.
The old release draft explicitly remains superseded. No historical proposal becomes a current instruction through this import.
Only an extra blank EOF line in PREVIEW-COMPARISON.md is removed for publication; the manifest preserves its original hash and private archive reference.
D-030 is recorded as Jason's historical frontend/images decision; this push executes no deployment.

Two additional byte-exact evidence copies are archived here: the fictional pilot [refund screenshot](devolucion-transferencia.png)
and an [incomplete simulator log](cp4-incomplete-basic-run.txt). The latter contains no completed oracle and proves no synchronization result.
Their original files remain untouched. These documentation copies do not change the application or run SQL.

## Preserved boundaries

Raw logs, TRX, duplicate patches, unfinished/duplicate videos, service caches, local review boards and the installed third-party skill bundle remain local.
The manifest records each non-bundle exclusion and the aggregate skill count. No blanket staging or file deletion is used.
Credentials and private exports remain excluded. Existing execution evidence is reused only for unchanged source.
This documentation-only push can run snapshot/progress CI; it does not match the `savia/**` SQL workflow filter.
No merge, deployment, production acceptance, customer data or additional SQL runtime is included.

## Verification and next action

The primary reviews the exact staged source, applies the existing publication scanner and whitespace checks,
and runs the progress receipt/evidence-export checks before the normal commit hooks publish to Tony.
`python tools/export_progress.py --verify`: exit 0, 15 preserved evidence hashes.
`python tests/test_progress.py`: 23/23 PASS, exit 0. Its isolated fake sync receipts are not publication evidence.
The publication scanner accepts all 60 explicit paths. All 49 historical bindings and both byte-exact copies were checked.
All 159 relative links in the updated status pages resolve. `git diff --cached --check` passes.
Publication requires `SYNCED`, matching remote SHA and readback of the applicable documentation/snapshot CI.
The current application gaps remain three-branch synchronization, the current real browser-to-API-to-SQL journey and operational qualification.

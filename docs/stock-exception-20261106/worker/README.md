# Returned implementation candidate

Task `savia-stock-exception-9597f19-20261106-01`.
Base `9597f19d0e1621c2b3984f8bf8878a0f7d58d906`.
Assigned worktree `C:/Users/Jason/.t3/worktrees/github/t3-92a93a5c`.
Branch `t3/physical-stock-exception`.
This worker return is not acceptance or production evidence.

The cashier can explicitly record a physical garment delivered at recorded available stock 0.
Reason and physical size are mandatory.
The sale line stores the exceptional allocation; its sale supplies actor, time and location.
No stock, purchase receipt, cost or compensating movement is fabricated.
Ordinary lines keep their stock/reservation guards.
Returns/cancellations record quantity and original-price credit reversals without creating inventory.
A physical count and any evidence-based inventory correction remain separate.

A different Manager/Owner, including a substitute, reviews the sale at simulated day close.
The server rejects self-review even for an Owner.
The append-only review stores examined evidence, outcome, authorized responsible actor and next review date.
The cause stays open; the increment does not claim cause resolution or reconciliation.
The trial uses explicit sale/profile IDs; no real employees are assigned.

The UI persists pending intent before sending.
Lost responses preserve the original key/body across reload and retry.
Duplicate submits, changed session versions and late responses are guarded.
The existing serializable command runner and sorted stock-key lock order are retained.

## Verified locally

| Check | Result | Evidence |
| --- | --- | --- |
| SDK | 10.0.402 | [commands](commands.json) |
| Whole .NET suite, SQL disabled | 542 passed / 79 skipped / exit 0 | [log](backend-full-offline.log) |
| Focused commerce/release/exception suite | 75 passed / 6 skipped / exit 0 | [log](dotnet-tests.log) |
| Final staff DOM/mocked-transport suite | 133 passed / exit 0 | [log](staff-tests.log) |
| Golden harness guards | 44 passed / exit 0 | [log](harness-tests.log) |
| Final feature-specific actual Chrome | 1440x1000 and 390x844 passed | [results](browser-stock-results.json) |
| Earlier existing actual Chrome/mocked API regressions | 50 passed | [results](browser-mock/browser-results.json) |
| Earlier supply actual Chrome/mocked API regressions | 8 passed | [results](browser-supply/results.json) |
| SQL helper compilation | 0 warnings / 0 errors / exit 0 | [log](sql-helper-build.log) |
| Four negative controls | each exit 1; exact byte restoration | [hashes and commands](negative-controls.json) |
| Diff whitespace | exit 0 | line-ending warnings only |

Final feature-specific Chrome checks exercise blank-reason rejection, exceptional sale response loss,
reload recovery with one sale POST, different-person review response loss, exact key/body retry,
review readback and no horizontal overflow at both widths.
They report no page errors or external requests.
They use mocked HTTP and are not SQL persistence proof.
The earlier 50/8 browser checks bind earlier UI bytes; the final stock run binds final UI bytes.
Mobile screenshots were inspected, the cramped exception checkbox layout was corrected, and the flow reran.
See [mobile](stock-review-390.png) and [desktop](stock-review-1440.png).

The negative controls remove the cashier review guard, bypass exceptional receipt binding,
bypass late-response identity protection and permit cashier review in the server authorization switch.
Each focused check detects its mutation.
Each source file is restored with identical before/after SHA256.
The full backend suite was rebuilt and passed after restoring the server mutation.
Snapshot restoration before EF regeneration is separately recorded in [restoration.json](restoration.json).

## Reproduce the bounded offline checks

Use PowerShell in the assigned worktree:

```powershell
$stockSdk='C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe'
$env:SAVIA_PILOT_EVIDENCE="$PWD/docs/stock-exception-20261106/worker"
Remove-Item Env:MARTHA_INTERNAL_TEST_SQL_CONNECTION -ErrorAction SilentlyContinue
Remove-Item Env:MARTHA_TEST_SQL_CONNECTION -ErrorAction SilentlyContinue
& $stockSdk test backend/tests/Martha.Store.Api.Tests --no-restore --logger 'console;verbosity=minimal'
$env:NODE_PATH='C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules'
node --test dev/savia-staff-ui/*.test.mjs
python -m unittest discover -s tests -p 'test_golden_path*.py'
& $stockSdk build tests/golden-path/GoldenPath.Sql --no-restore
node docs/stock-exception-20261106/worker/browser-stock-check.mjs C:/Users/Jason/AppData/Roaming/npm/node_modules/@playwright/cli/node_modules/playwright
```

All executed commands/exits are indexed in [commands.json](commands.json).
The existing EF Design 10.0.13 package generated migration `20261106071201_PhysicalStockException`.
The retained [design-time driver](ef-scaffold/Program.cs) generated the migration and idempotent SQL without opening SQL.
Do not rerun its scaffold action against this already-generated candidate.
No SDK/global tool or new dependency version was installed.
The repository runner installed only its existing locked DOM packages with scripts disabled.

## Limits and blockers

`python tests/check.py --install` exited 1 at `tests/asset-audit.py`.
Three symlink fixtures failed with `OSError: [WinError 1314] A required privilege is not held by the client`.
Preceding stages passed; later repository-runner stages did not run.
No Windows privilege or security setting was changed.
Primary owns the next check in an existing authorized Linux environment; completion requires the whole runner exit 0.
See [repository log](repository-check.log).

Automatic approval review rejected recursive deletion of the worker's local EF build caches: `blocked by policy`.
No deletion ran and no bypass was attempted.
The cache remains local and ignored by [ef-scaffold/.gitignore](ef-scaffold/.gitignore).
`git check-ignore` confirmed exclusion; primary should omit these caches from integration.

SQL/API-backed runtime is outside this worker's authority.
No SQL connection, migration application, Docker, certificate/trust change, real data/payment,
Actions dispatch, deployment, stage, commit, push, PR, merge, ledger or status mutation occurred.
Three new real SQL tests are compiled but skipped.
Real locking, concurrency, rollback, reversal persistence and different-person review persistence remain NOT RUN.
Primary owns that separate authorization and execution.
The prepared journey defaults false, requires `--supply --stock-exception --mode browser`,
retains 17 existing checkpoints/four SQL identity oracles, and adds five stock checkpoints.
Expected rows, accounting and cleanup are in [oracles](../../../tests/golden-path/oracles.md).
No runtime was dispatched.

## Source binding and next action

[Source binding](source-binding.json) lists the 31 changed contracts and their exact raw SHA256.
[RESULT.json](RESULT.json) records identity, timing, commands, restoration, failures, owners and completion checks.
Host/model/settings were verified as SUAZO-PC, T3 Code/Codex, gpt-6.1-sol/high.
Exact elapsed/provider token/cost telemetry is unknown; elapsed is approximately 48 minutes against a 50-minute bound.
No children or extra checkout were created.

Primary should review this source-bound candidate, freeze it for the independent Gemini critic and Astra judge,
then run the separately authorized real journey with exact candidate bytes and verified cleanup.
The worker does not publish or accept its own candidate.

Lesson applied: compile shared .NET project references serially after a concurrent build file lock.
The serial SQL-helper build exited 0; its evidence is linked above.

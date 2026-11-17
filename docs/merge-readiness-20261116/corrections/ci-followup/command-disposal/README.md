# F1 correction: a failed migration keeps its original error

Astra/xhigh returned REVISE with one P2 finding on the frozen 12-source candidate. The finding is corrected. Astra/xhigh rechecked the correction: **ACCEPT WITH LIMITS, F1 closed, no new findings** ([recheck](astra-f1-recheck.md)). The primary accepts the 13-source candidate with the limits below.

Base: `ac0bb9f47f5a12ffc0626f7737a347dea9b37900`. Host: SUAZO-PC. Primary: T3 Code / Claude Code, `claude-fable-5-2`.
The previous primary (Codex `gpt-6.1-sol`) stopped on its usage limit after adding the failing tests. Jason then confirmed Astra had usage again.

## Finding and correction

[Astra's review](../review/astra-integrated-review.md) is imported byte for byte.
F1: when a migration command failed and disposing that command also failed, the disposal error replaced the original error.
Astra reproduced it on a fake for a batch, the ledger INSERT and the state SELECT. It did not show lost atomicity or data corruption.

Correction, in `savia/deploy/migrator/MigrationExecution.cs` only:
`Execute`, `Register` and `Scalar` now go through one `Run` wrapper.
After a failed operation, `Run` attempts disposal, ignores a disposal error and rethrows the original exception.
After a successful operation, a disposal error still propagates, so the transaction rolls back.
SQL text, timeouts, parameters, transaction ownership and the unmarked path are unchanged.

## Evidence

| Check | Result |
| --- | --- |
| Red, tests added before the helper changed | exit 1; 27 pass, 3 fail. The 3 failures are `Command_disposal_failure_preserves_original_operation_error` at batch1, ledger and validate. |
| Green, same command | exit 0; 30 pass, 0 fail, 0 skipped. |
| Migrator Release build | exit 0; 0 warnings, 0 errors. |
| Astra's own adversarial probe, byte-identical source, compiled against the corrected helper | 20 pass, 0 fail. It was 17 pass, 3 fail on the frozen helper. |
| Source bindings against the frozen packet | 10 of 12 unchanged; only the helper and its test file changed. |

Commands, exits, new RAW/LF hashes and private log hashes: [RESULT.json](RESULT.json).
Raw logs and TRX stay in ignored `private-exports/merge-readiness-20261116/corrections/ci-followup/command-disposal/`.
The frozen `review/PACKET.json` is unchanged; this record supersedes it for the two changed files.

## Second finding: C# format gate

The CI check script runs `dotnet format Savia.slnx --verify-no-changes --no-restore`. No earlier local check had run it.
On this candidate it exited 2. One error was real: `ReturnRetrySafetyTests.cs(58,59)`, already present in published `ac0bb9f`.
The v2 job on `ac0bb9f` failed earlier, at Biome, so CI never reached this gate. The next publication would have failed on it.
The other 452 reports were CRLF working copies of the two new C# files; Git stores them as LF.

Correction: `dotnet format` applied to that one file moved an object initializer to its own line. No token changed.
The two new C# files were converted to LF in the working copy.
After: format exit 0 with no output.

Final offline run on the exact files: focused tests 30/30; `Savia.slnx` Release build and migrator Release build 0 warnings, 0 errors;
Astra's probe 20/20; architecture rules 9 of 9; baseline check and no-physical-delete exit 0; `python -m unittest discover -s savia/tests` 41 tests OK.
The candidate is now 13 source files: the 12 in the frozen packet plus `ReturnRetrySafetyTests.cs`.

## Limits

- These tests use a fake ADO.NET connection. They do not prove SQL rollback.
- Real SQL, exact-candidate CI and the Linux aggregate `python tests/check.py` are NOT RUN.
- Astra reran the focused tests (30/30) and an extended probe (37/37). It read, and did not rerun, format, rules, builds and Python tests.
- Web, Biome, the V029 guard and the Windows aggregate were not rerun: nothing they cover changed.
- No commit, push, workflow, SQL, merge or deployment occurred. The Git index is empty.

## Next action

Jason authorized one Tony publication of this candidate with its automatic CI: maximum 330 cumulative job minutes, no retry, no paid AI, no merge, no deployment.
The primary publishes once from [the allowlist](../PUBLICATION.json), verifies `SYNCED` and the remote SHA, and reads every CI result.

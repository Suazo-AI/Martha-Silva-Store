# Migrator worker return

Offline candidate only. Primary acceptance and Astra review remain pending.
Source: `ac0bb9f47f5a12ffc0626f7737a347dea9b37900`.
Host: SUAZO-PC. Exposed Codex model/effort: `gpt-6.1-sol/high`, matching request.
Worktree: `C:/Users/Jason/.t3/worktrees/github/t3-d027758a-581f6d3ad87e6883`.

Marked migrations now use XACT_ABORT and one DbTransaction for every batch and the parameterized ledger insert.
The helper checks `@@TRANCOUNT = 1 AND XACT_STATE() = 1` before registration and commit.
Errors trigger explicit rollback. Cleanup errors preserve the original exception.
An uncertain commit outcome always fails the call.
The helper restores the prior XACT_ABORT setting.
Unmarked migrations retain separate execution without a transaction.
Leading marker matching follows Python, including BOM rejection and ordinal case sensitivity.

`Migration` moved into the single helper so tests execute the actual production orchestration.
The splitter and newline normalizer remain identical after LF normalization.
Program retains plan, checksum refusal, session applock, grants and final ledger verification.
No SQL, MANIFEST, workflow, lockfile or generated source was edited.

## Offline evidence

- Final: **24 passed, 0 failed, 0 skipped**, exit 0.
- Original-semantics control: **9 passed, 13 failed**, exit 1.
  This routes marked files through the former unprotected loop; it is not SQL207 reproduction.
- Missing rollback: **13 passed, 11 failed**, exit 1.
- Missing state validation: **17 passed, 7 failed**, exit 1.
- Ledger outside transaction: **20 passed, 4 failed**, exit 1.
- All mutations restored. Final helper hash is recorded.
- Initial compile stopped at CS0108/CS0162. Naming and mutation-condition corrections resolved them.
- A later 23/24 run exposed a CRLF expectation error in the test fixture. The corrected final run passed 24/24.
- Eight test/build invocations and one local-cache locked restore were used. No network installs or retries.

The fake DbConnection records real command transaction assignments and pending/committed effects.
Cases cover batch, ledger, commit and cleanup failures, invalid state before/after ledger, unmarked partial behavior, marker boundaries and prior session settings.
These tests do not prove SQL Server DDL behavior.

[Exact commands/exits and gaps](RESULT.json), [raw/LF and original Git hashes](source-hashes.json),
[patch](candidate.patch), [preservation checks](preservation.json), [final TRX](final.trx),
[control commands and restoration](controls.json), [reproduction script](run-controls.py).
The script deliberately stops at unexpected results; its historical final fixture failure is retained.

## Remaining gaps and handoff

SQL, containers, services, database connections, publication and GitHub refresh were NOT RUN because authority excludes them.
Primary/Jason owns fresh scoped SQL authority and the isolated fresh-install/rollback check.
The separate migrator executable was not built: the solution excludes it and its cached assets were absent.
Primary must restore/build that project after integration; the production helper itself compiled through the linked tests.
No staging, commit or canonical checkout mutation occurred.

Next: primary checks the patch and exact hashes, integrates serially, and requests Astra/xhigh review of the combined source.
Lesson applied: negative controls must execute production orchestration and retain failing evidence; a green mock cannot prove SQL atomicity.

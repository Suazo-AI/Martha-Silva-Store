# CI follow-up on ac0bb9f

The combined 12-source correction passes focused offline checks. The production migrator builds with zero warnings/errors. Its integrated tests pass 30/30. SQL proof remains pending.

Update 2026-11-17: Astra returned REVISE with one P2 finding (F1). It is corrected and verified offline: [F1 record](command-disposal/README.md). The 24/24 counts below are the pre-F1 candidate. A fresh recheck of F1 has not run.

Source: `ac0bb9f47f5a12ffc0626f7737a347dea9b37900`. Host: SUAZO-PC. Primary: T3 Code/Codex gpt-6.1-sol/xhigh.

## Actual CI and local evidence

All 25 check-runs completed on the published SHA. The seven required checks passed. Two additional workflow types failed, including both v2 push/PR executions.

| Item | Direct result | Limit |
| --- | --- | --- |
| v2 format | Original Biome failed. Corrected exact command: exit 0, 68 files. | Local cached Biome 2.6.4. |
| Web and scanner | 134/134, exit 0, zero skips. | Node tests; no new browser or persistence claim. |
| Product format equivalence | The three changed product modules equal Biome's safe rewrite of their HEAD versions. UUID test also matches. | Lifecycle test additionally replaces two string concatenations and removes one unused test variable. |
| Azure V029 | CI reports six SQL207 references. New source contract: 10 pass/1 fail before correction, 11/11 after. | Source contract only; corrected SQL not executed. |
| Migration preservation | One GO added after column ADD; both return procedure bodies and V001..V028 unchanged. Only V029 manifest digest replaced. | Explicit pre-release correction, not permission to rewrite an installed ledger. |
| Other guards | USD migration 1/1; rule tests 10/10; actual rules 9/9; diff check exit 0. | Offline. |

The [Azure failure](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/43996099832/job/133748432080) and [v2 PR failure](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/43996100000/job/133748431980) remain failures on the published SHA. Local fixes do not change those historical results.

[Astra preimplementation review](v029/astra-preimplementation.md) is imported byte for byte. Its transaction-envelope finding is adopted. The corrected production .NET runner now recognizes the marker and uses one transaction for all batches and the ledger insert. Python behavior is unchanged.

## Blockers and concrete continuation

| Blocker | Evidence / attempted resolution | Owner / completion check |
| --- | --- | --- |
| Production migrator atomicity | Four worker source files imported exactly. Standalone executable build exits 0 with zero warnings/errors; primary focused tests pass 24/24. Historical worker controls detect missing rollback, state validation and transaction-bound ledger. | Astra/xhigh reviews the frozen combined candidate. Actual SQL rollback remains unproved. |
| SQL behavior | Batch correction and source controls pass. Real migration rollback, cross-runner no-op, populated legacy rows and return contention remain untested. | Primary prepares bounded synthetic checks after source acceptance. Jason approves the concrete runtime packet. |
| Existing installed V029 | This fresh candidate failed before successful application. That does not establish every target's ledger state. | Deployment owner obtains authorized target ledger/schema evidence. Unknown or old-hash targets stop deployment; no ledger rewrite. |
| Aggregate Windows environment | One full check stopped at three unchanged symlink fixtures with WinError 1314; no source failure was shown by those exceptions. No repeat attempted. | Primary prepares the exact candidate for a separately authorized clean Linux aggregate, then verifies exit 0. |
| Publication / CI | Previous one-shot publication authority was consumed by ac0bb9f. No new push or workflow attempted. | Prepare exact candidate, review, allowlist and runtime effects before a new authorization. |
| Merge | Seven required checks are green, but extra failures expose real validation gaps. | Close the applicable gaps on the exact candidate, then make a separate merge decision. |

[RESULT.json](RESULT.json) binds exact sources, logs, exits and review import. Raw logs stay in ignored private-exports. Unrelated untracked files and the Git index are preserved.

The first web evidence wrapper failed on a Unicode marker after Biome finished. The replacement saves exits first and uses ASCII. Biome was repeated once for a retained exit; the final web suite ran once.

Lesson: green required checks do not cover every release path. Apply the same migration transaction contract in each supported runner, then test actual rollback before claiming atomicity.

## Integrated migrator evidence

The actual production helper now executes marked batches and the parameterized ledger INSERT on one `DbTransaction`. It checks transaction count/state, rolls back on failure and preserves the original exception. Unmarked migrations retain their historical path. The GO splitter, plan/hash checks, lock and grants remain unchanged.

Primary used the cached SDK 10.0.402. Locked local-cache restore, standalone Release build and the integrated `MigratorExecutionTests` invocation all exited 0. The retained TRX contains 24 executed/passed and zero failed/skipped tests. These tests use a fake ADO.NET connection; compilation and command ordering do not prove SQL rollback.

[Worker import receipt](migrator-worker/IMPORT.json) records four exact source copies, 14 public evidence files and eight private raw logs. Import initially stopped on the log-file allowlist after copying the sources. The corrected import archived logs privately and verified all copied bytes. The Git index remains unchanged.

The single integrated `python tests/check.py` attempt exited 1 after 146.781 seconds. Three unchanged asset-audit fixtures hit `WinError 1314` while creating symlinks. Staff 223/223 and all earlier groups passed. Later groups were not reached. No assertions or Windows privileges were changed. The exact log and exit are retained privately. A clean Linux aggregate on the accepted candidate is the completion check; a new CI authorization is required.

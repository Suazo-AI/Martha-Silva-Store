# Security SQL return

Task: `savia-local-sql-security-f9ffa45-20261107-01`. Mode VALIDATE. Status **partial**, NOT PASS.
Source: `f9ffa452bae7fc11a4a578ce24b57ecb72add139`. Host SUAZO-PC. T3/Codex `gpt-6.1-sol`, requested and exposed reasoning `high`.
Managed worktree: `C:\Users\Jason\.t3\worktrees\github\t3-4f8a34bb`. Primary and Astra/xhigh acceptance remain pending.

## Actual result

One exact OR-filter invocation executed all assigned initial 27 methods once: **23 Passed, 4 Failed, zero skips**.
Actual TRX definitions and UnitTestResult entries agree. GUID-normalized test/execution IDs are unique.
No initial methods missing, extra or duplicated. All six current HTTP acceptance methods, including N8, passed.
The remaining restart method is **NOT RUN**, because initial27 failed. Overall assigned scope is 23 passed, 4 failed, 1 not run.

Locked restore exit 0; Release build exit 0 (zero warnings/errors); initial27 test exit **1**.
Wrapper process exit 0 means the evidence/cleanup handler returned, not test success.
Native SDK 10.0.402 was used by absolute path with child-scoped DOTNET_ROOT/PATH.
Exact commands, stage durations, private artifact hashes and source bindings: [RESULT.json](RESULT.json).
Actual identities, outcomes, sanitized exact messages and stacks: [sanitized-outcomes.json](sanitized-outcomes.json).

## Failures and next owner

| Methods | Observed failure | Direct evidence and next action |
|---|---|---|
| BS21_25; BS28 | `Failure to infer one or more parameters`; `service` is `UNKNOWN` | OperationsHost maps Cash endpoints without registering Cash services. Primary reviews fixture dependency registration. |
| Release script; actual backup/restore | `Unsupported cash constraint token.` | Captured SQL contains `9000000000000.`; oracle tokenizer excludes decimal points. Primary reviews numeric grammar without weakening semantic checks. |

These are test-host and schema-oracle failures. This run does not establish a product security defect or schema equivalence.
No source correction or method retry was attempted because the worker scope prohibits both.
Closure requires a reviewed candidate and separately authorized fresh bounded execution.
Backup/restore test failed at its first schema assertion (line 117), before reapply, Down/Up or BACKUP/RESTORE.
No private release receipt exists. No controlled stop/start was attempted.
Exact raw TRX, logs, assertions and stacks were preserved privately before container cleanup.
Private archive: `C:\Users\Jason\.t3\worktrees\github\t3-4f8a34bb\private-exports\sql-security-20261107-01` (ignored; never publish raw contents).

## Isolation and cleanup

Owned container: `370a13d9754f83485b67f5d7e01e01068da3f5b9a207cfeb48d42d20b51bc417`.
Only loopback `127.0.0.1:14339`, 2 CPUs, 2 GiB; exact cached SQL image; no pull, volumes or host mounts.
SQL 2022 Developer readiness passed in 8 probes within 120 seconds.
Connection encryption and certificate trust were scoped to the disposable connection.
SQL targets/authorization existed only in child environments; no native SQL, business resources or port 14338 were used.
Ownership label and captured ID were read back before removal. `docker rm --force` exit 0.
Captured-ID inspect exit 1 and independent Docker inventory both confirm absence.
Elapsed execution: 251.015 seconds, within 25-minute container and 35-minute worker budgets.
HEAD and all eight normalized LF source bindings remain unchanged. No tracked source changes, staging, commit or push.

## Limits and lesson

One private preflight source read failed under the Windows default codec before any runtime attempt.
Explicit UTF-8 corrected that read; source-method preflight then passed. Use explicit UTF-8 for repository source reads.
No method retry occurred. No provider substitution or nested delegation occurred.
Tokens/cost telemetry: unknown. No production, browser-to-API-to-SQL, staff cash UI or historical-failure-cause claim.
Next action: primary inspects the four preserved failures and submits the return to the sole Astra/xhigh judge.

# Finish SAVIA: active execution

Target: a reproducible technical trial with real receipt, sale, stock exception, independent review, SQL persistence and recovery.
Production acceptance remains separate. The public storefront still needs authoritative ordering and card payments.
Source: [canonical ledger](../pipeline/ledger.json), [status](../PROJECT-STATUS.md), [database scope](../DATABASE.md).

| Work | Current evidence | Next action and completion check | Owner |
|---|---|---|---|
| Gallery verification | Primary and Astra/xhigh accept the bounded proof; exact-SHA CI green | Publish the prepared issue #4 update after authority; then close S-LEGACY | Primary |
| Backend offline partition A | Fresh 552/552, 195/195 methods; primary verified actual TRX, unique IDs and exact multiplicities | Accepted for offline A only; evidence linked below | Primary |
| Local SQL partition C77 | Corrected fingerprint proven offline; six historical SQL failures not confirmed at runtime | Prepare the existing scripts for a named disposable local runtime; obtain the required execution scope; run exact C77 | Primary + OpenCode |
| Combined journey D | Preparation incomplete, not run | Finish runnable commands; then scope and prerequisites: Chrome -> HTTPS API -> SQL, supply and stock-exception flags, persisted oracles and cleanup | Primary + OpenCode |
| Recovery E2 | Current candidate not run | Owned disposable backup/restore and restart; verify persistence and absence after cleanup | Primary + OpenCode |
| Integration | Technical proof at 69d3268 accepted; documentation at c07bd1b synchronized with three successful exact-SHA workflows | Serial integration of returned work; no merge or deployment implied | Primary |

Docker is ready: Linux engine 29.7.2. Required SQL Server and .NET SDK images are present locally.
Existing SAVIATEST certificate trust failed; it will not be bypassed or changed.
The disposable route needs no host certificate or service mutation.
`docs/DATABASE.md` requires scope for each new runtime execution; previous batch authority is consumed.
The local plan must specify image, resources, trust limits, budgets, stop conditions and cleanup before that request.

No agent summary closes an item. A green mock test does not prove persistence. A published commit does not prove production readiness.
Martha's operational data, real payments, host operation, recovery ownership and authorized release remain explicit release gates.

Fresh local site validation: `python tests/check.py`, exit 0. No product bytes changed.
A no-network SDK container preflight confirmed .NET 10.0.402 and OpenSSL/curl, but no Python, Node or Chrome.
That owned preflight container was removed and its absence verified. The real-journey runner still needs those prerequisites.

[Gallery acceptance and remaining issue handoff](../gallery-contracts-20261107/TECHNICAL-ACCEPTANCE.md).
[CI readback](CI-69d3268.json): six successful checks, one skipped optional narrator; no new dispatch or SQL runtime.

[Fresh A report](local-validation/A-sanitized-results.json) and [primary verification](local-validation/PRIMARY-VERIFICATION.json): one new run, 552/552; no SQL test executed.
The worker's [original return](local-validation/README.md) is preserved. Its runtime plan is not accepted as executable.
[Preparation findings and next action](local-validation/RUNTIME-PREPARATION-REVIEW.md) keep missing commands separate from runtime permission.

Documentation/ledger integration checks, 2026-11-07: `python tests/test_delivery_status.py` 24/24, exit 0;
`python tools/delivery_status.py --check` valid 39 items, exit 0; `python tests/test_progress.py` 23/23, exit 0;
`python tools/export_progress.py --verify` 15 preserved evidence hashes, exit 0; `git diff --check` exit 0.
Scoped JSON parses and local Markdown links were checked. These checks did not run SQL.

Current routing correction, 2026-11-07: TECH-TRIAL now names the local C77 -> D -> E2 route selected by Jason.
The earlier two-workflow campaign remains historical. It is not an instruction to dispatch GitHub Actions.
C10 now distinguishes implemented exception/review code from its still-unexecuted current SQL and combined-journey proof.
No status, completion criterion, dependency, operator acceptance or runtime authority changed.

Exact-SHA readback for documentation commit `c07bd1b0c579ead5b9bc39cd98d9c327f9f4ee41`:
[Progress documentation](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42374399090),
[Progress digest](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42374399147) and
[Tony source snapshot](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42374399098)
all completed successfully, attempt 1. Readback only; no dispatch or SQL runtime.
The active OpenCode task owns only the executable runtime entry and its bounded evidence in a separate managed worktree.
Next: integrate that returned artifact, resolve Astra/xhigh findings and obtain the concrete runtime scope before execution.

Routing-correction verification: `python tests/test_delivery_status.py` 24/24; `python tools/delivery_status.py --check`
valid 39 items; `python tests/test_progress.py` 23/23; `python tools/export_progress.py --verify` 15 preserved hashes;
`python tests/check.py` all recovered-demo checks passed, including staff 152/152, frontend 29/29 and localization 17/17.
All commands exited 0. Direct comparison with the parent ledger confirms all 39 statuses, dependencies and completion
criteria are unchanged; only TECH-TRIAL routing/preparation/report and C10 preparation changed. `git diff --check` passed.
These checks prove documentation consistency and existing offline regressions, not SQL execution or production readiness.

Read-only local prerequisite check, 2026-11-07: `wsl --list --quiet` lists only `docker-desktop`.
`docker image ls --digests` confirms the pinned SQL Server and SDK images remain cached.
`docker ps` confirms the engine responds; no container was started, stopped or changed.
C77 and E2 use C# fixtures without the Linux journey harness. Preparing Windows SDK invocations is an alternative,
not a verified runtime result. D still requires Linux: `golden_path.py` imports `fcntl`, `pty` and `termios`,
uses `/proc`, and the browser driver selects Chrome. A complete journey runner is still required.

Source correction sent to the existing OpenCode preparation task: the earlier database-name outline omitted fixtures.
`SqlDatabase.cs` generates `MarthaSynthetic_Test_<32hex>`; `InternalSecuritySqlTests.cs` generates
`MarthaInternal_Test_<32hex>`. Internal fixtures also generate `SaviaInternalTest_Commerce_<32hex>`,
`SaviaInternalTest_Supply_<32hex>`, `SaviaInternalTest_Release_<32hex>` and `SaviaInternalTest_Pilot_<32hex>`.
The real journey generates `SaviaInternalTest_Golden_<32hex>`. Here `<32hex>` means 32 lowercase hexadecimal digits.
The executable plan must account for these exact fixture names inside its nonce-owned disposable SQL container.
A name match alone never authorizes connecting to or deleting an existing host database.
Primary owns acceptance of this correction in the returned entry point; Astra/xhigh reviews the frozen result.
No runtime scope, existing acceptance criterion, test source or production status changed.

SEC-CSRF: Jason adopted session-bound protection on 2026-11-07; the decision is no longer pending.
Reject mutation tokens from an earlier session, including the same user's later login.
Implementation is pending under the [recorded decision and frozen checks](../session-csrf-20261107/README.md).
Retain the existing SQL red/green gate: an old token with a new valid session must reject without writes;
a fresh token must work. Preserve anonymous login, logout, cross-user rejection and pending-receipt recovery.
This is a separate production increment. It does not change the frozen local-trial source or authorize SQL execution.

C9 metadata narrowed, 2026-11-07: the read-only registry inspection now succeeds with the effective administrator token.
SAVIATEST has an empty configured certificate binding and `ForceEncryption=0`; its current startup log reports
`A self-generated certificate was successfully loaded for encryption.` Service/process timestamps were captured.
This is consistent with the earlier trust rejection; the presented fingerprint and chain remain unverified.
[Exact metadata and limits](local-validation/TLS-METADATA-20261107.json). Both metadata invocations exited 0.
No SQL connection, trust/certificate change or service action occurred. C9 remains blocked for its separate security/runtime scope.
The owned disposable local trial remains independent of that shared-instance correction.

Metadata integration checks: delivery-status 24/24; ledger valid 39; progress 23/23; export verification 15 preserved hashes.
All exited 0. Only C9's blocker/evidence changed; all statuses, completion criteria and dependencies remain identical.
Lesson: the administrator token resolved the registry-read failure. It does not establish certificate trust or pass a SQL test.

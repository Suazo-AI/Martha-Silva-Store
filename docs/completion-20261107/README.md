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

P-OWNER decision adopted, 2026-11-07: maintain two enabled Owner accounts and prepare a synthetic-tested emergency recovery procedure.
The [policy and review requirements](../owner-recovery-20261107/README.md) preserve the closed bootstrap and private maintenance boundary.
Current code prevents removal of the last Owner; it does not enforce the new operating minimum of two.
Fresh Astra/xhigh design review, implementation and a separately scoped recovery test remain pending.
Only P-OWNER's decision, owner and active preparation changed; its completion criterion and production gates remain intact.

Execution-limit readback, 2026-11-07, 15:27:42 UTC: the runtime-entry task was launched at 12:54:07 UTC
with a 25-minute budget. The session-CSRF task was launched at 14:22:49 UTC with a 45-minute budget.
The primary verified these launch times and limits from the original tool records, then requested cancellation
through `task_cancel`. Both requests returned `cancel_requested`; that response does not prove process termination.
No active worker checkout was inspected, no partial code was accepted and no replacement task was launched.
Next: receive the termination/completion event, recover the ended task's actual changed files and diagnostics,
then review useful output before selecting the smallest remaining execution scope. Primary owns this handoff.
SQL C77, combined journey D, recovery E2 and session-CSRF implementation verification remain NOT RUN.
Lesson: enforce the agreed execution limit; an elapsed limit is not a diagnosis of the underlying failure.

P-OWNER publication `ae8ad5d23ad07d7aeee619f93eb98192db9f2f29` has three completed successful workflows:
[Progress digest](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42386089235),
[Progress documentation](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42386089249), and
[Tony source snapshot](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42386089300).
These are exact-SHA documentation/publication checks; they do not execute Owner recovery or close P-OWNER.

Terminal-task recovery, 2026-11-07: both cancelled tasks now report `interrupted`, with no pending child runs or questions.
Only after that readback did the primary inspect their managed worktrees.
The ended session-CSRF task left a clean checkout and no implementation or test result.
The ended runtime-entry task left four untracked preparation files in `t3-ea4d8447`; no tracked changes or runtime proof.
Its final editing command failed with `SyntaxError: unterminated string literal (detected at line 1)`.
The cause of either task's inactivity remains unknown; these facts do not establish a provider or administrator-access failure.

The runtime candidate is not accepted or imported. Direct source review found these preparation issues:

- `run_local_validation.py:321` tests tar member permission bits as filesystem type bits; verify ordinary archive entries before correction.
- Lines 485-486 allocate 25 minutes to each C block, rather than one shared C25 deadline.
- Resource names derive from a deterministic scope; cleanup must verify unique run ownership before deleting resources.
- Execution exports frozen source while building its Docker context from the working tree; bind both to one reviewed candidate.
- Preparation files are absent from the pinned commit; the executable path must reject an incomplete frozen source.

These are source findings, not reproduced runtime failures. No candidate execution, container creation, SQL or cleanup was attempted.
Correction to the primary's earlier commentary: `run-stage.sh` already includes both `--supply` and `--stock-exception`.
Do not remove either flag or report the supply flag as missing.
Next: a bounded runner safety review and correction, then fresh focused checks before any runtime scope request.
In parallel, resume session-CSRF implementation from its already adjudicated design in a new isolated OpenCode worktree.
The Owner design review completed with conditions; primary accepted its bounded profile after direct source and hash verification.
Its [adjudication and frozen F1-F13](../owner-recovery-20261107/README.md#primary-adjudication-of-the-fresh-design)
separate an operational two-Owner gate from the existing server minimum, and reject disabled emergency targets.
No Owner implementation or recovery execution was accepted.
Primary owns integration and closure. C77, D, E2, Owner recovery and session-CSRF runtime acceptance remain open.

This recovery/adjudication documentation passed delivery-status 24/24, ledger validation 39 items,
progress 23/23, export verification 15 preserved hashes and `git diff --check`, all exit 0.
No product check, database runtime or readiness claim follows from these documentation checks.

Agent navigation correction, 2026-11-07: the primary replaced stale PR-head and N5 repair instructions in
`docs/AGENT-START.md`, and extended `docs/CODE-MAP.md` to the current supply, stock, fingerprint and local-validation sources.
The cause was directly visible: the November 4 entrypoint still selected an old PR and described a resolved defect as next work.
Historical evidence remains linked; runtime permissions and the current OpenCode/high executor plus Astra/xhigh judge selection remain explicit.
Read-only validation through `python -` checked both documents: 70 local links exist, obsolete instructions are absent,
permission boundaries remain, unrelated tracked changes are preserved and the index was empty; exit 0.
The first checker attempt failed because Windows stdin replaced an accented assertion literal with `?`.
Repeating the checker with ASCII/Unicode escapes passed; neither attempt ran product code.
Next: integrate the bounded executor returns after terminal events, then obtain independent review of their actual candidate bytes.
C77, D, E2, Owner recovery and session-CSRF runtime acceptance remain open.

Execution-budget enforcement, 2026-11-07, 16:31:12 UTC: the primary recovered the original delegate call
from this thread's activity, rather than polling the running child.
The CSRF offline assignment launched at 15:46:40 UTC with a 30-minute total budget; its deadline was 16:16:40 UTC.
`task_cancel` returned `cancel_requested`. This acknowledges the request, not process termination or a diagnosis.
Preserve any partial candidate; inspect it only after a terminal event. No replacement, retry or acceptance has occurred.
The runner correction launched at 16:04:54 UTC with a 35-minute budget; its separate deadline is 16:39:54 UTC.
It is not cancelled by the CSRF request. Owner implementation remains queued while these assigned slots are unsettled.
Primary owns recovery of terminal output, diagnosis and serial integration. Runtime permission boundaries remain unchanged.

Continuation boundary, 2026-11-07, 16:37 UTC: three consecutive goal turns produced no new implementation or terminal delegate result.
This is not a verified live wait: neither a prior launch nor `cancel_requested` proves that a process remains active or has stopped.
The supported T3 completion notification owns the next event; running-child polling and replacement before terminal confirmation remain excluded.
Owner implementation cannot take a third assigned worker slot under the three-agent limit, and the cash/credit product question remains unanswered.
Primary awaits those external events instead of repeating status-only turns or manufacturing another documentation/CI cycle.
After a terminal notification, read the actual return, verify the worktree and cleanup, then integrate or diagnose before the next bounded dispatch.
No task, SQL runtime, acceptance gate, provider selection or production status is changed by this boundary.

Cash-scope decision, 2026-11-07: Jason answered the pending question with "Contado primero; crédito después (recomendado)".
That product dependency is resolved. [D-031 and the proposed source-based checks](../cash-register-20261107/README.md)
separate the existing `not_processed` sale from a future cash collection, change and till close.
The document requires independent money reconciliation and real browser/API/SQL evidence before acceptance.
Cash implementation remains pending fresh Astra/xhigh preimplementation review and an available bounded worker slot.

Runner-budget enforcement, 2026-11-07, 17:48 UTC: its 35-minute limit from 16:04:54 UTC had expired.
The primary requested cancellation. The tool returned `cancel_requested`; no terminal result or cause is established.
This supersedes the earlier statement that only CSRF had a cancellation request. Both assignments remain unsettled.
Primary will inspect partial files only after terminal notification, verify owned-resource cleanup, and then integrate or diagnose.
No replacement, SQL execution, source acceptance or provider fallback was performed.

# P-OWNER: recovery policy

Status: decision adopted; design review accepted with conditions; implementation and runtime proof pending.
Decision date: 2026-11-07. Source inspected: `005fd9e0bbdfd978ed4c67ed5879844c98256826`.
Host: `SUAZO-PC`. Primary: T3 Code / Codex / `gpt-6.1-sol`, exposed reasoning `xhigh`.

## Adopted decision

Jason selected: "Dos Owner y recuperación de emergencia (recomendado)".
Maintain at least two enabled Owner accounts with separate credentials and accountable custodians.
Prepare an emergency recovery procedure and prove it using fictitious data before production acceptance.
This records the policy and permits reversible preparation. It does not execute account changes or SQL.
Database runtime, production identities, secrets, host security, merge and deployment retain their existing scope gates.

The decision lives here because `docs/DECISIONS.md` contains an unrelated uncommitted D-030.
Its existing content is preserved. The canonical ledger links this record.

## Current behavior verified from source

- `InternalSecurityService.ResetPassword` requires a currently authorized Owner inside a serializable transaction.
  It does not exclude resetting that Owner's own password. Recovery through a second Owner is the adopted operating policy.
  It uses the application password hasher, changes the security version, clears lockout and revokes existing sessions.
- `UpdateStaff` prevents disabling or demoting the last enabled Owner. Its existing threshold is one, not two.
  The adopted two-Owner operating rule is not yet an enforced server constraint.
- `InternalOwnerBootstrap.CreateInitialOwner` rejects every database containing any staff row.
  `InternalOwnerConsole` is initial setup only. It cannot recover an existing installation.

Sources: [service](../../backend/src/Martha.Store.Api/Internal/Security/InternalSecurityService.cs),
[console](../../backend/src/Martha.Store.Api/Internal/Security/InternalOwnerConsole.cs),
[existing recovery limits](../c9-recovery-20261103/PREPARATION.md#owner-reutilizar-el-borrador-ya-aceptado).
These are source findings, not a newly executed account recovery.

## Required safety and proof

1. Demonstrate two distinct enabled Owner identities and recovery through the second Owner using the existing authorized API.
   Keep separate custodians and credentials; do not create a shared default account or publish credentials.
2. Review a private, explicitly invoked emergency maintenance procedure before implementation.
   It must require privileged operator access, exact target confirmation and an existing identified Owner.
   It must not expose a public recovery endpoint, reopen bootstrap, delete staff or manufacture a new Owner.
3. Bind the operation to the target database, staff identity and current security version.
   Recheck those facts transactionally. Reject wrong targets, non-Owners, missing identities and stale versions without writes.
   Any change to an account's enabled state must be explicit in the reviewed procedure and execution scope.
4. Use the supported application password hasher and password rules. Rotate the security version, clear lockout and revoke sessions.
   Do not paste password hashes into SQL or carry secrets in arguments, reports, logs or versioned files.
5. Preserve business data and unrelated identities. Record a safe operator/target/result audit without credentials.
   Verify exactly the expected security changes and compare independent business-table fingerprints around the operation.
6. Prove old passwords and sessions fail, a fresh authorized login succeeds, and normal permission checks still apply.
   Exercise forgotten credentials, locked accounts, disabled-target handling, denied callers and concurrent changes.
7. Inject failure before commit and verify rollback. Classify an uncertain commit acknowledgement as UNKNOWN.
   Preserve private diagnostics and inspect state before any separately authorized retry; never retry automatically.
8. Keep the bootstrap-closed regression intact. A database with no recoverable existing Owner must stop for a different scope.
   Production backup/rollback ownership and the synthetic test cleanup must be explicit before runtime approval.

These are requirements for the design review, not a claim that a recovery mechanism already exists.
The review must resolve the exact maintenance mechanism and any two-Owner enforcement change before code is written.
No schema change, privileged SQL script or new account path is selected by this record.

## Next action and ownership

Primary owns this decision record, serial integration and final acceptance.
Use an OpenCode executor for the reviewed implementation below. Preserve other workers' separate paths and worktrees.
Then verify offline negative controls and request one concrete isolated SQL scope for the synthetic recovery proof.
`P-OWNER` stays open until its original reviewed-and-tested completion criterion is met.

The [execution contract](IMPLEMENTATION.md) fixes the next worker's seams, evidence order and remaining proof.
Primary verified its links and the accepted report's exact hash and thirteen F1-F13 identifiers.
This is local preparation, not an executed implementation, recovery or SQL run.

Verified now: Jason's decision, current source behavior and frozen review requirements.
Documentation checks: `python tests/test_delivery_status.py` 24/24; `python tools/delivery_status.py --check`
validates 39 items; `python tests/test_progress.py` 23/23; `python tools/export_progress.py --verify`
preserves 15 evidence hashes. Every command exited 0. The scoped ledger comparison confirms only P-OWNER changed;
its original completion criterion and dependencies are unchanged. `git diff --check` passed.
NOT RUN: implementation, account creation/reset, SQL, recovery runtime, browser, CI or production acceptance for this increment.
Lesson: a second administrator reduces lockout risk; it does not prove recovery after all access is lost.

## Primary adjudication of the fresh design

The [Astra/xhigh design review](astra-design-review.md) is accepted for bounded implementation preparation.
The imported report is byte-identical to the returned artifact: RAW/LF SHA256
`5beee5493a2e3bb900c1b9d62968ace5b665b64f729a943150ab04c20e1c47ff`.
Primary inspected the report and the service/console/early-dispatch seams; the ended reviewer changed only that report.
This is design acceptance. It is not evidence that recovery works.

- Minimum two enabled Owners is an operational readiness gate. Keep the existing last-Owner server invariant.
  A single-Owner installation fails readiness; concurrent demotions may retain one without satisfying readiness.
- Emergency maintenance can reset only an existing enabled Owner. Reject disabled, absent and non-Owner targets.
  Reactivation, account creation and a continuous server minimum of two require a separate choice and scope.
- Use the exact private console command before web-host construction. Keep bootstrap closed and expose no recovery endpoint.
- Preserve the report's controlled operator/SQL identity, fixed target manifest, TLS, transaction, version and lock checks.
  Implementation may prepare these controls; provisioning ACLs, SQL grants, certificates or identities is not authorized.
- Preserve the report's safe intent/completion journal. Uncertain commit or receipt is UNKNOWN; never retry automatically.
- Freeze F1-F13 from the report, including full-table no-write checks and preservation of BranchAssignmentAudit.
  Offline tests and source inspection cannot replace the separately authorized SQL, race, rollback and login evidence.

Next: implement the reviewed seams with free OpenCode, verify offline controls in a bounded sandbox, then obtain Astra/xhigh review.
Before any database recovery run, prepare its exact synthetic target, operator, backup/cleanup ownership and new runtime scope.
No account, database, service, host security, schema, server invariant or production status changed during this adjudication.

## Ledger correction after source readback

Primary rechecked `InternalSecurityService.ResetPassword` and its Owner-only endpoint.
The existing API permits self-reset with a valid Owner session; it does not cover loss of every Owner's login access.
Updated only P-OWNER's `why` and `prep`; its status, dependencies and completion criterion remain unchanged.
Verification: `python tests/test_progress.py` 23/23, `python tests/test_delivery_status.py` 24/24,
`python tools/delivery_status.py --check` 39 valid items, and `python tools/export_progress.py --verify` 15 preserved hashes.
All exited 0. The scoped comparison and `git diff --check` passed.
No implementation, account reset, SQL or recovery runtime was executed for this documentation correction.

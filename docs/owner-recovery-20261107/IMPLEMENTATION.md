# Owner recovery: execution contract

Status: prepared; no implementation or recovery proof.
Source: `cd955c05fe23f673643a0e399c6bb9b88f358b1b` on `Tony`, 2026-11-07.
Owner: primary orchestrator, SUAZO-PC, T3 Code / Codex / gpt-6.1-sol / xhigh.

The [accepted policy](README.md) and [Astra design](astra-design-review.md) govern this increment.
The design's RAW/LF SHA256 is
`5beee5493a2e3bb900c1b9d62968ace5b665b64f729a943150ab04c20e1c47ff`.
All F1-F13 remain required. This contract partitions their execution; it waives none of them.

## Outcome

An authorized private operator can reset one existing enabled Owner safely.
The operation revokes that Owner's sessions and preserves unrelated data.
Two distinct enabled Owners remain an operational readiness requirement.
The existing last-Owner server constraint remains unchanged.

Normal second-Owner recovery uses the existing HTTPS API and fresh CSRF.
Self-reset remains supported by that API.
Emergency recovery must never create an account, reactivate a disabled account, or reopen bootstrap.

## Ownership and dispatch

The next executor is `codex/gpt-6.1-sol`, `reasoningEffort=high`.
Jason approved this temporary route after OpenCode reported its free usage limit.
The independent judge is `codex/gpt-6-astra`, `reasoningEffort=xhigh`.
Use a T3-managed worktree and a self-contained PROTOCOL packet.
No nested delegation or model substitution.
Do not launch this executor while primary plus two assigned children consume the three-agent limit.
No executor has been launched by this document.

Allowed implementation seams:

- `backend/src/Martha.Store.Api/Program.cs`: exact recovery dispatch before normal host construction.
- `backend/src/Martha.Store.Api/Internal/Security/InternalOwnerRecoveryConsole.cs`: private terminal, controlled manifest, identity checks and journal orchestration.
- `backend/src/Martha.Store.Api/Internal/Security/InternalOwnerRecoveryService.cs`: transactional recovery and explicit outcome.
- `backend/src/Martha.Store.Api/Internal/Security/InternalOwnerConsole.cs`: only minimal reuse of its bounded reader and server validator; preserve bootstrap behavior.
- New directly necessary recovery-only helper files in that Security directory.
- New `InternalOwnerRecoveryConsoleTests.cs`, `InternalOwnerRecoverySqlTests.cs` and recovery-only test helpers in `backend/tests/Martha.Store.Api.Tests/`.
- `InternalSecuritySqlTests.cs` and `InternalAcceptanceHttpSqlTests.cs`: bounded ordinary Owner/self-reset and no-write regressions required by the accepted design.
- `docs/owner-recovery-20261107/worker/`: sanitized evidence and exact changed-path bindings.

Exclude schema, migrations, packages/locks, workflows, storefront, staff UI and global configuration.
Leave the CSRF worker's `InternalSecurity.cs`, new antiforgery provider and antiforgery tests untouched.
Do not edit the canonical checkout, ledger, AGENTS.md, DECISIONS.md or another worktree.
If another necessary seam appears, identify its exact purpose before expanding the assignment.

## Implementation and evidence order

1. Implement and test exact argument dispatch and the private console boundary before wiring the database operation.
   The only accepted trigger is `--internal-recover-owner` as the sole argument.
   Refusal must not fall through to normal startup, bootstrap, migration or a listener.
2. Implement identity, manifest, terminal and journal checks from F1-F3/F10.
   Keep Windows-only platform checks guarded; a simulated identity proves only the tested policy logic.
   Missing platform support or protected files must fail closed.
   Do not provision SIDs, ACLs, SQL grants, certificates or directories on the host.
3. Implement the real F4-F9 transaction using the existing SQL stack and password hasher.
   Pin target and SQL identity on one connection; use SERIALIZABLE and the reviewed target lock.
   Do not replace the transaction with an in-memory repository or a synthetic application Owner principal.
   Preserve rowversion and reject stale target identity/version without retry.
4. Wire the exact command only after the real service and its refusal paths compile.
   Flush intent before mutation; report success only after commit acknowledgement and completion receipt.
   An uncertain commit, rollback or receipt is UNKNOWN, exit 4; do not replay automatically.
5. Prepare the SQL/API tests and independent full-table oracle for F4-F13.
   Compare BranchAssignmentAudit, unrelated Staff/Sessions and target immutable fields separately.
   Capture immediate before/after state before login probes change counters or sessions.
   Declare SQL cases explicitly; never count a skipped or synthetic case as persistence proof.
6. Return the complete candidate and actual offline results for primary inspection and Astra/xhigh review.
   Preserve unexecuted SQL, Windows identity/ACL and operational checks as pending.

Use logical failing assertions before the feature and passing assertions after it where feasible.
A compilation error or an empty test selection is not a successful negative control.
Include a secret-marker check across output, exceptions and journal fixtures.
Reuse existing passing evidence only when its exact source and scope still match.

## Execution boundary

This contract prepares work. It does not start SQL, Docker, recovery or a workflow.
The eventual task packet must freeze a bounded offline sandbox before target code runs.
Use only cached tools and dependencies, locked restore, no external network, explicit minimal environment,
read-only source/toolchain inputs, private scratch, and CPU/memory/process/disk/time limits.
Do not expose the host home, credentials, Docker socket, other agent directories or shared services.
Do not run security-controlled project tests directly on the Windows host.

Prepare a concrete disposable SQL scope only after the candidate and offline checks are accepted.
That request must name the exact source, synthetic target, controlled test operator, budget,
failure diagnostics, backup/cleanup ownership and absence checks.
No account change, certificate bypass, service restart, merge or deployment is authorized here.

## Remaining proof and handoff

| Outcome | Current evidence | Next action / completion check | Owner |
| --- | --- | --- | --- |
| Policy and design | Adopted policy and accepted F1-F13 | Preserve exact controls through implementation and review | Primary |
| Private console and transaction | Not implemented | Approved Sol/high candidate; real service compiled; bounded offline assertions and negative controls | Next executor, then primary/Astra |
| Windows operator and protected manifest/journal | Design only | Prove actual supported Windows checks; identify provisioning needs without changing host security | Primary / Jason for provisioning |
| SQL persistence, races, rollback and UNKNOWN | NOT RUN | Separately authorized disposable SQL/API run satisfies F4-F13 and independent preservation oracles | Primary + assigned executor |
| Two enabled Owners | Operational policy only | Two distinct identities and successful logins; named separate custodians | Primary / Jason |
| Production acceptance | NO-GO | Original release gates plus accepted recovery evidence; no automatic deployment | Primary / Jason |

Current separation: the cash workflow has its own assigned worktree and files.
Recovery can use the remaining slot without touching that worktree or its cash/UI paths.
Do not duplicate the cash task or poll a running delegate.
The next executor owns the implementation. The primary owns integration and final acceptance.

## Dispatch preparation at 2160fd0

Primary compared the reviewed security service, bootstrap console and security model with design source
`1761a9a94f9da2573778552ec3595d49e6d899ff`: no source difference.
The accepted design hash above still matches. Reuse that design; retain F1-F13 without waiver.
This check is not implementation or recovery proof.

The bounded implementation packet may run cached SDK-only offline checks in an owned disposable sandbox.
Use SDK image `mcr.microsoft.com/dotnet/sdk@sha256:747cbade5bfd918a175ac32f8f1d931edec2c7d0d5397a3de72eaef1ac1f66d2`.
Primary verified that cached image and the local NuGet cache exist.
Use no network, ports, SQL image, host credentials, Docker socket, installations or downloads.
Keep source and package inputs read-only; use private bounded scratch, a non-root user, dropped capabilities,
and explicit limits: 2 CPUs, 4 GiB memory, 256 processes and 20 combined container minutes including cleanup.
Freeze exact mounts, scratch size, captured ownership ID and absence readback before starting that sandbox.
An unavailable cache or unmet sandbox control stops target execution; report the concrete missing prerequisite.

The worker has 80 minutes total and at most ten focused check invocations, with no automatic retries.
Use the current allowance only. Preserve a continuation checkpoint if a required step remains.
Jason chose D for the separate five-test SQL plan: review first, no execution.
This implementation packet does not dispatch that plan, SQL, account recovery or any account change.

Preparation verification: an inline Python check passed the design hash, thirteen control IDs,
document links, route and D boundaries, unchanged source comparison, two preserved unrelated files and empty index.
`git diff --check` exited 0. `git diff 1761a9a94f9da2573778552ec3595d49e6d899ff HEAD -- backend/src/Martha.Store.Api/Internal/Security/InternalSecurityService.cs backend/src/Martha.Store.Api/Internal/Security/InternalOwnerConsole.cs backend/src/Martha.Store.Api/Internal/Security/InternalSecurityModel.cs`
returned no changes. No product code, sandbox, recovery, SQL or tests of recovery ran during this preparation.
Next: dispatch the frozen implementation packet; primary inspects the returned candidate before independent Astra/xhigh review.

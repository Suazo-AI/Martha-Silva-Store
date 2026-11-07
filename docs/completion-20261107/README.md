# Finish SAVIA ? active execution

Target: a reproducible technical trial with real receipt, sale, stock exception, independent review, SQL persistence and recovery.
Production acceptance remains separate. The public storefront still needs authoritative ordering and card payments.
Source: [canonical ledger](../pipeline/ledger.json), [status](../PROJECT-STATUS.md), [database scope](../DATABASE.md).

| Work | Current evidence | Next action and completion check | Owner |
|---|---|---|---|
| Gallery verification | Two proof gaps reproduced and corrected; 4/4 origin controls, 2/2 real Chrome journeys | Astra/xhigh verifies the frozen candidate; then close S-LEGACY | Primary + Astra |
| Backend offline partition A | Historical 551 passes plus one targeted replacement | One fresh exact A552 run in a separate worktree; zero failures, skips or inventory mismatches | OpenCode executor |
| Local SQL partition C77 | Corrected fingerprint proven offline; six historical SQL failures not confirmed at runtime | Prepare the existing scripts for a named disposable local runtime; obtain the required execution scope; run exact C77 | Primary + OpenCode |
| Combined journey D | Prepared, not run | After prerequisites pass: Chrome ? HTTPS API ? SQL, supply and stock-exception flags, persisted oracles and cleanup | Primary + OpenCode |
| Recovery E2 | Current candidate not run | Owned disposable backup/restore and restart; verify persistence and absence after cleanup | Primary + OpenCode |
| Integration | Candidate progress may be published to Tony | Serial integration, exact remote SHA and required CI; no merge or deployment implied | Primary |

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

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
| Integration | Tony@69d3268 synchronized; four workflows successful | Serial integration of returned work; no merge or deployment implied | Primary |

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

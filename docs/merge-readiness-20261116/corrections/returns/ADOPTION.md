# Return correction contract adopted by primary

Base: `ba8ff2ba10935e99fc268ebbe5eae130f72c1cca`. SUAZO-PC, T3/Codex primary.
The independent [Astra preimplementation review](astra-preimplementation.md) is adopted for this correction batch.

## Compatibility decision

Legacy committed reversals without a complete original request digest are lookup-only.
Do not fabricate or backfill an identity from a retry or current policy.
Keep receipt lookup available. A legacy exact-body retry that cannot be proven equivalent must reject without writes.
This is a fail-closed technical correction; it does not permit deleting receipts or creating replacement financial operations.

## Frozen checks

1. New immutable V029 migration covers both return procedures. It records canonical, versioned complete financial request identity atomically. Historical migrations remain unchanged.
2. Current authorization precedes replay. Same-ID equivalent replay changes zero rows, even after till closure. Changed financial identity returns 51538 / sale.reversal_id_reused with rollback. Ordering and null/default normalization are explicit.
3. UI verifies durable reservation before POST, preserving exact endpoint/body/IDs and original owner scope. Storage failure blocks sending. Competing mounts/tabs cannot replace an uncertain intent.
4. Recovery mounts before till/policy/sale dependencies. GET absence, malformed response or later rejection never releases uncertainty. No automatic resend, fresh IDs, discard, or edit while unresolved.
5. Every asynchronous boundary fences mount/session ownership. Retired callbacks cannot submit, display, clear or leak a foreign attempt. Temporary supervisor credentials are never persisted and are revoked on all terminal/retirement paths.
6. UI adversarial checks cover response loss, 404-before-late-commit, edits, remount/reload, duplicate submits, storage failures/competition, invalid receipts and account/navigation changes during confirmation/approval/POST/lookup. Preserve ordinary returns and keyboard operation.
7. SQL fixtures cover each canonical financial field, same-request/reordered replay, closed till, current permission revocation and concurrent same-ID calls. Assert specific conflicts and exact unaffected rows. Preparing/compiling these fixtures is not SQL execution proof.

## Independent ownership

- UI worker: `savia/web/app.mjs`, `savia/web/screens/return.mjs`, return logic/durable helper and focused web tests; owned evidence under `returns/ui/`. No SQL or backend writes.
- SQL worker: only new `savia/db/migrations/V029__return_retry_safety.sql`, new return SQL/offline regression tests and owned evidence under `returns/sql/`. No historical migration, UI, workflow or runtime mutation.
- Primary owns this contract, serial import and integrated verification. Fresh Astra/xhigh owns advisory final review.

Local code/tests only. Existing no-SQL/no-Docker/no-push/no-workflow/no-merge/no-deploy gate remains.
The consumed PR runtime authority is not renewed by this document.

Lesson: an uncertain financial operation needs an immutable identity, durable ownership and an authoritative reconciliation path before another operation can replace it.

# Isolated branch authorization candidate — 2026-10-27

Status: source candidate only, NOT integrated, NOT compiled, NOT runtime-accepted. Original historical B1 snapshot remains untouched. No user records, PCs, credentials, runtime transfers or deployments were changed.

## Decisions and scope
- Explicit `InternalBranch` separates branch from stock location. `Staff.BranchId` and `Location.BranchId` are nullable for additive migration; null is **not global** for non-Owners. Owner remains globally authorized within existing capabilities.
- Future display names are exactly **Paseo Masaya**, **Natura Managua**, **Kilómetro 15**. No real branches or assignments are seeded. No branch creation API or user-data backfill is delivered; operational assignment awaits reviewed administrative workflow.
- Known non-Owner roles require an enabled persistent staff record and assigned active branch. Queries filter before totals/pagination and resource projection. Caller actor omission fails closed.
- Directory mutations and global Party reads are Owner-only. Cashier cannot read Supply cost DTOs (route capability plus persistent role filter); global Item catalog and scoped stock remain available under existing read capabilities.
- Staff branch updates run in existing serializable Owner workflow, append assignment audit and rotate security version/revoke sessions. Location branch remapping is rejected once stock/history/operation records exist, preventing historical cross-branch reassignment.
- Mutations pass persisted resource identity into the root serializable runner before action. Current session, capability, branch and location are checked in that transaction. Old non-resource runners fail closed for non-Owner; fake runners must opt into RunScoped.
- Three historical return paths are guarded: runner replay, GET operation and physical purchase-receipt dedup. Operation replay requires the same actor and current original branch scope; legacy null scope is Owner-only. Immutable original metadata is captured when recording operations.
- Historical inactive locations remain reversible when branch authorization is valid; activity rules for new transactions remain in existing services. Inactive branch is fail-closed for non-Owner.

## Migration and compatibility
`20261027224500_InternalBranchScope` is additive: Branches, nullable mapping columns, operation scope metadata, append-only assignment audit. No inferred assignment/backfill. Historical unassigned locations with stock/history cannot be assigned by SaveLocation either: this is an intentional conservative restriction, requiring a separate reviewed migration/backfill design before non-Owner use. Existing records remain Owner-visible; non-Owner historical replay without scope is denied. Migration, Designer and snapshot are hand-authored and require EF model-diff validation on the pinned SDK before integration. The old InitialInternalSavia.idempotent.sql remains historical and does NOT deploy this candidate migration.

Existing request DTOs accept optional BranchId; omitted branch in staff/location update resolves to null, deliberately removing access rather than guessing. Existing UI is unchanged and not certified compatible for branch administration. A later explicitly reviewed UI/API workflow is required before real rollout. No multisucursal access granted to Manager/Cashier.

## Evidence boundaries
- `git diff --check`: run locally; whitespace check only.
- dotnet SDK absent from PATH. No SDK installation attempted. Build, xUnit, SQL concurrency, EF migration application and EF model-diff checks: **NOT_RUN**.
- Added test source is not a passed test suite. Static review is not proof of SQL translation or serializable race behavior.
- No visual acceptance, publication, production acceptance or 100% completion claimed.

## Required integration gate (not executed here)
On an approved environment with existing pinned SDK 10.0.402 and disposable SQL test database: compile; run existing plus branch tests; validate migration/snapshot and Up/Down in disposable DB; exercise two-context branch reassignment/commit races and all three replay paths; check HTTP roles/sessions; review UI compatibility and operational branch workflow. Do not run against real data without a separately reviewed deployment plan.

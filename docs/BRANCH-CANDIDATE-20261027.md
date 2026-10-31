# Isolated branch authorization candidate — 2026-10-27

Status: source candidate only, NOT integrated, NOT compiled, NOT runtime-accepted. Original historical B1 snapshot remains untouched. No user records, PCs, credentials, runtime transfers or deployments were changed.

The status above describes the received cloud artifact. Local review on
2026-10-28 imported its sources into the isolated branch
`feat/savia-branch-integration-20261028`, on real parent `4a9c11e` through Owner/B1
`c927eed` and branch-source `744f245`. The 113-file historical source snapshot was
reconstructed and hash-verified; its declared `d77c64be` Git ancestry is unknown.
The subsequent local compatibility delta below is a new source revision, pending
cloud compilation and tests. Original checkouts and received artifacts are intact.

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

Update compatibility contract: an omitted `branchId` on staff/location PUT preserves the persisted assignment, resolved inside the existing authorized serializable transaction. Explicit JSON null requests unassignment; a nonempty GUID requests assignment. Existing Owner authorization, staff version/session rotation and location-history remap restrictions still apply. New locations without a branch remain unassigned, and null never grants global access to non-Owners. Request presence is represented by `InternalBranchIdUpdate`; location replay fingerprints include the presence/value intent, so omission is distinct from explicit null. DTO creation/response/entity schemas are unchanged. Existing general duplicate-property parsing policy is unchanged; the branch wrapper accepts only JSON null or a nonempty GUID, never a client-supplied presence object.

Owner-only Party reads require the companion UI compatibility gate: non-Owners start with the item catalog and never request customers/suppliers. This does not certify a branch administration UI or widen API permissions. A later explicitly reviewed UI/API workflow is required before real rollout. No multisucursal access is granted to Manager/Cashier. Compatibility tests are written source until the pinned SDK and cloud checks execute them.

## Evidence boundaries
- `git diff --check`: run locally; whitespace check only.
- dotnet SDK absent from PATH. No SDK installation attempted. Build, xUnit, SQL concurrency, EF migration application and EF model-diff checks: **NOT_RUN**.
- Added test source is not a passed test suite. Static review is not proof of SQL translation or serializable race behavior.
- No visual acceptance, publication, production acceptance or 100% completion claimed.

## Required integration gate (not executed here)
On an approved environment with existing pinned SDK 10.0.402 and disposable SQL test database: compile; run existing plus branch tests; validate migration/snapshot and Up/Down in disposable DB; exercise two-context branch reassignment/commit races and all three replay paths; check HTTP roles/sessions; review UI compatibility and operational branch workflow. Do not run against real data without a separately reviewed deployment plan.

The local [adoption and reversal plan](savia-internal/BRANCH-ADOPTION-PLAN.md)
keeps historical assignments closed pending explicit mapping and treats Down as
data-destructive. No mapping or migration was executed. Location requests that
omit branchId retain the pre-branch 4a9 fingerprint shape through DTO omission;
explicit null/GUID remain distinct. Unknown historical formats keep conflict and
the original operation identity; no receipt is rewritten to force replay.

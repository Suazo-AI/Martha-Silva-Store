# Private internal SAVIA implementation lot

Authorization: user said "entonces hazlo y terminame savia" after clarifying staff/owners internal administration, sales, inventory and procurement. No customer-public SAVIA app, deployment, spending, live SQL/EULA or account/bootstrap execution is authorized. Imported45files match packagea476e1f5064516c04e3cccad02befd8490d867b81cea71ef1d420ccc8f19c93b, reported upstreamf7e859bd0e6edf6bdef8b391b63589a212f0d088. Local import82b2e20 is NOT upstream history.

## Architecture and default closure
- Preserve synthetic V1/V2 and fixtures XXX unchanged. New namespace Martha.Store.Api.Internal and separate InternalDbContext/schema savia_internal. Single business per isolated instance; locations are inventory locations, NOT tenants. No claim of multi-tenant isolation.
- Internal feature off by default. Root integrator owns Program.cs, project/lockfiles, connection guards, migrations integration and UI host. No migrations/seed/bootstrap automatic; no public static deployment. SQL verification remains a separate unmet gate.
- Every internal business endpoint requires authenticated identity and server role policy. Owner/Manager/Cashier/Inventory are fixed server roles. No client-provided actor identity or login mock. No production accounts or credentials generated during implementation.
- No currency conversion or reuse of XXX fixture as commercial data. New domain accepts explicit 3-letter currency excluding XXX, integer minor units, server-authoritative stored item price. No taxes, bank payment settlement or fiscal invoice claims; recorded sale is NOT a card charge.
- Stateful mutations use server idempotency, serializable transaction and immutable operation replay; inventory updates conditional in SQL, movement audit with actor. Uncertain storage outcomes surface as unavailable/unknown; never switch authority/provider.

## Shared interfaces (freeze until coordinated)
- InternalDbContext partial; each module implements its named partial ConfigureX method and DbSets in its own folder. No editing root context/contracts by builders.
- InternalResult<T>(Value, Error), InternalActor.Id(ClaimsPrincipal), InternalRules in InternalContracts.cs.
- IInternalCommandRunner.Run<T>(actorId, scope, key, fingerprint, action, ct) provides transaction/replay. Root integrator implements runner, owns operation record/config. Module action must use same scoped context, may SaveChanges but never commit its own transaction.
- IInternalStockLedger.Change(itemId, locationId, onHandDelta, reservedDelta, actorId, operationId, kind, ct) implemented Commerce. Caller uses runner transaction. Negative available stock forbidden.
- Directory entities: InternalItem { Id:Guid, Sku:string, Name:string, UnitPriceMinor:long, Currency:string, Active:bool }; InternalLocation { Id:Guid, Name:string, Active:bool }; InternalParty { Id:Guid, Kind:string(customer|supplier), Name:string, Email:string?, Phone:string?, Active:bool }. Use db.Set<T>() to avoid coupling DbSet property names.
- Security: InternalStaff entity and InternalSecurity extension registration, policies named internal.owner (Owner), internal.manage (Owner/Manager), internal.sell (Owner/Manager/Cashier), internal.inventory (Owner/Manager/Inventory), internal.read (all four). Cookie scheme InternalSavia. Explicit CSRF on unsafe methods, server session validation and disabled-user/role-change revocation. Security builder supplies AddInternalSecurity(IServiceCollection), MapInternalSecurity(IEndpointRouteBuilder); root supplies middleware order/feature gate.
- Module mapping extensions: MapInternalDirectory, MapInternalCommerce, MapInternalSupply(IEndpointRouteBuilder). Paths /internal/api/{module}; protected policies, CSRF on mutations. UI must not be public wwwroot files.

## Exclusive ownership
1. Security builder: Internal/Security/**; tests/InternalSecurity*.cs. Auth/session/role tests and bootstrap CODE only, never run bootstrap.
2. Directory builder: Internal/Directory/**; tests/InternalDirectory*.cs. Real persisted entity operations and validation, no real PII.
3. Commerce builder: Internal/Commerce/**; tests/InternalCommerce*.cs. Inventory/ledger/sales; implement stock interface, server prices, cancel/return semantics explicit and auditable. No payments claim.
4. Supply builder: Internal/Supply/**; tests/InternalSupply*.cs. Purchase order/partial receipt/idempotent reception with supplier/items and shared stock ledger; no vendor payments.
5. Critic: read-only architecture/security critique, own evidence only.
6. Judge: independent verification/tests/evidence, no builder code writes unless coordinated.
Root: common runner/context/wiring, protected minimal internal UI, migration/source integration and merged testing. No builder edits Program.cs/csproj/locks/global.json or other modules.

## Verification
SDK10.0.402 and pinned packages unchanged unless separately coordinated. Unit/contract/security tests can run withoutSQL but never count asSQL proof. Use actual SQL tests with skip reason while no authorized SQL exists. tests/check.py absent from allowlist, report unavailable rather than fabricate aggregate. No web UI screenshots/latency claims from jsdom/unit tests. Deliver diffs, localSHA and exact limits. Auth, concurrency/persistence, deployment and business acceptance remain gates, not completed by this plan.

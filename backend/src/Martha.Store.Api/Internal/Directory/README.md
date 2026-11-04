# Private SAVIA directory

Server-owned SQL directory for one isolated business instance. It is not a public
customer portal. Register `MapInternalDirectory()` only behind the root internal
feature gate, server authentication/authorization and the separate scoped
`InternalDbContext` plus `IInternalCommandRunner`. An `IAntiforgery` service is
required. No extra service registration is needed for this module.

All entities are in `Martha.Store.Api.Internal`; the EF partial config uses schema
`savia_internal`. Nothing seeds data, opens accounts, applies migrations, creates
SQL servers or enables the feature on startup.

## HTTP contract

Base path: `/internal/api/directory`. Collections: `items`, `locations`, `parties`.

- `GET /{collection}`: `internal.read`; Party additionally requires `internal.owner`.
  Items are the global catalog; locations are filtered by the persisted branch
  for non-Owners. Response: `{items, total, skip, take}`.
  Optional query `q`, `includeInactive`, `skip` (default 0, max 100000), `take`
  (default 50, max 100); parties also accept `kind=customer|supplier`.
- `GET /{collection}/{id}`: same policy; includes an inactive record by stable ID
  so historic references remain readable.
- `POST /{collection}`: `internal.owner`, creates a server-generated ID, 201.
- `PUT /{collection}/{id}`: `internal.owner`, replacement of editable
  fields, 200; existing record required. Omitted location `branchId` preserves
  its persisted assignment; explicit null requests unassignment.
- `DELETE /{collection}/{id}`: `internal.owner`, **soft-deactivation only**, 200
  with retained ID and `active=false`. No hard-delete operation exists.

All directory endpoints reject plain HTTP before directory reads or command
execution (`https_required`, 400); reverse-proxy forwarding must be configured
only for trusted proxies by the host. Every mutation explicitly validates `IAntiforgery.ValidateRequestAsync`, requires
an authenticated GUID actor derived from the server principal and exactly one
`Idempotency-Key` header (16–128 ASCII letters/digits, `-`/`_`). The root security
module defines how clients acquire the cookie/token. JSON mutations do not rely
on form-only implicit CSRF behavior. Authorized directory responses are no-store.

Write bodies (unknown members, including actor/ID overrides, are rejected):

```text
items:     {sku, name, unitPriceMinor, currency, active?}
locations: {name, active?, branchId?}
parties:   {kind, name, email?, phone?, active?}
```

`active` defaults true. PUT can reactivate an existing entity. `kind` is immutable
after party creation: a second role needs a separate party ID. Responses contain
these fields plus `id`; optional contact fields are nullable.

New locations with no branch remain unassigned. A supplied branch must be active.
Changing a location assignment with stock/history/operations is rejected,
including assigning a historical unassigned location. No backfill is inferred.
Location replay fingerprints distinguish omitted branchId, explicit null and a
GUID; changing that intent with the same key does not replace an old receipt.

SKU is ASCII-only, trimmed and uppercased, with SQL uniqueness across active and
inactive items; deactivation never releases a historical SKU. Item prices are
required JSON integers in minor units, 0 through `InternalRules.MaxMinor`.
Currency must be explicitly supplied as three ASCII letters, normalized uppercase,
and cannot be `XXX`. No currency conversion, taxes or fiscal invoicing are implied.

Names preserve accents and internal spacing, use NFC, and reject control or bidi
spoofing characters. People/companies are identified by GUID, **not by name, phone
or email**. Names/shared contacts are not unique and no record is auto-merged.
Email domain case is folded, local-part case/plus tags/dots are retained; addresses
which the parser would silently rewrite are rejected. Phone formatting/country
prefix is preserved; the service does not infer country codes or verify ownership.

## Transaction and failure contract

Mutations invoke only the shared runner with actor, scope, key and normalized
payload fingerprint; updates/deactivation fingerprint the target ID too. Actions
use the same scoped SQL context and save inside the runner's transaction; they
never create/commit a separate transaction or fall back to memory. The root owns
serializable execution, rollback on domain failure, immutable replay, session
revalidation, database uncertainty and audit of the actor-bound operation.

Domain errors: `invalid_request` (400), `not_found` (404), `duplicate_sku` and
`party_kind_immutable` (409). Root `idempotency_conflict` is 409, `forbidden` 403,
`unauthenticated` 401; storage/unknown outcomes are 503. SQL uniqueness remains the
final barrier to concurrent duplicate SKU creation; storage exceptions are not
silently retried by the directory.

## Verification boundary

`InternalDirectory*Tests.cs` tests validation/JSON contracts, SQL model metadata,
route/filter wiring and runner parameters without connecting to SQL. Its
recording runner never executes an action or claims to persist; the test-only
authentication and CSRF doubles do not prove production cookie security.

Before business use, merged integration tests must prove real SQL CRUD/reload,
case-equivalent SKU conflicts (including inactive SKUs), repeated-key replay,
changed-payload rejection, concurrent creates/updates, rollback, immutable party
kind, and soft-deactivation with existing sales/stock/purchase references. Real
security-session and browser verification are separate gates. No SQL execution,
deployment, live accounts, payment processing or production data is authorized
or claimed by this module.

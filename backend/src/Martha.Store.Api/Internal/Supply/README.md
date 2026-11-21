# Private SAVIA procurement

Real SQL-backed internal purchase orders and receipts, not synthetic inventory or
vendor payments. Register `AddInternalSupply()` and `MapInternalSupply()` only
inside the root internal feature gate with Security, Directory, Commerce and the
same scoped `InternalDbContext`/`IInternalCommandRunner`/`IInternalStockLedger`.
No migration, seed, account, SQL instance or deployment runs from this module.

## Contract

Base `/internal/api/supply`; reads require `internal.read`:

- `GET /purchase-orders?skip=0&take=50`
- `GET /purchase-orders/{id}`
- `GET /purchase-orders/{id}/receipts?skip=0&take=50`

Lists return `{items,skip,take,hasMore}` with `take` from 1 to 100 and nonnegative
`skip`. Reads are no-store. The single-order view includes each stable line ID,
ordered/received/remaining-receivable/cancelled quantities and audit actors/times.

All writes require one valid `Idempotency-Key` header plus the real Security CSRF
cookie/header and authenticated staff identity; actor IDs cannot be submitted.
Unknown JSON members are rejected; required fields cannot silently default.

- `POST /purchase-orders`, `internal.manage`:
  `{supplierId,locationId,currency,reference?,lines:[{itemId,quantity,unitCostMinor}]}`.
  Supplier must be an active Directory party of kind `supplier`; location/items
  must be active. Currency is explicit uppercase ASCII, not `XXX`, and must match
  every item's currency. Up to 100 distinct items; quantities 1–1000000. Manager-
  entered purchasing cost is required, in integer minor units, and frozen on the
  order. It is not the Directory retail sale price. Server computes/bounds totals.
- `POST /purchase-orders/{id}/receipts`, `internal.inventory`:
  `{receiptId,lines:[{purchaseOrderLineId,quantity}]}`. **Persist/reuse receiptId for
  the same physical receipt.** The same receipt ID with the same actor, order and
  canonical lines replays its stored result even with a different command key;
  any conflicting reuse fails. New physical deliveries require new IDs/keys.
  Cost/currency/item/location come from stored order data, never this request.
- `POST /purchase-orders/{id}/cancel`, `internal.manage`: `{reason}`.
  Cancels only the unreceived remainder of an open/partially received order.
  Received stock and receipts stay intact. This is **not** a supplier return,
  refund, vendor payment, fiscal invoice or bank settlement. Fully received or
  already cancelled orders reject new cancellation/receipt commands; immutable
  replay of a previously successful command remains available.

Open orders transition `open` → `partially_received` → `received`, or from either
of the first two to `cancelled`. Receipt additionally requires active items and
location, and unchanged currency. An inactive supplier can still fulfill an
existing accepted order; creation of a new order requires active supplier status.

## Atomicity and audit

All writes use root scopes `supply.purchase.create`, `supply.receipt.create`,
`supply.purchase.cancel`. The service requires the root's serializable SQL
transaction and never starts or commits a nested transaction. It locks receipt
identity/order rows, validates every requested line, conditionally updates SQL
cumulative received counters, and changes stock through Commerce in stable item
order on that same context. A failure after any line requires root rollback of
**all** counters, balances, movements and receipts before recording the failure.

Database constraints bound totals/quantities and forbid duplicate order items or
receipt lines. Composite receipt foreign keys tie each item/line to the exact
purchase order. Stored receipts retain their completion-time status and actor;
root append-only audit protection must cover receipt and receipt-line entities.
Unknown storage outcomes return 503, not a fabricated success or provider fallback.

## Verification boundary

`InternalSupplyRulesTests` uses explicitly synthetic fixtures and no database
connection: validation, integer overflow, canonical fingerprints, cancellation
views, JSON ownership, SQL model/DDL generation, and rejection before a runner
call. These tests do not prove SQL concurrency, rollback, idempotency persistence,
authentication/session revocation, deployment or business acceptance. Actual SQL
integration remains a separately authorized gate; no SQL/EULA was executed.

`InternalSupplySqlServerTests` adds real provider cases for partial/multiline
receipt, command and physical-receipt replay, conflicting identity, overreceipt,
partial cancellation, second-line stock failure rollback, immutable failed-command
replay, duplicate/last-unit races, and revoked-session rejection before replay.
They use the actual root runner/security/stock ledger with explicitly synthetic
persisted identities. They remain **SKIPPED** unless both
`SAVIA_INTERNAL_SQL_TESTS_AUTHORIZED=1` and
`SAVIA_INTERNAL_TEST_SQL_CONNECTION` are explicitly provided after separate SQL
and license authorization. Each creates/drops only its own fresh
`SaviaInternalTest_Supply_*` database; `EnsureCreated` validates the model, not the
migration path. Never set these variables merely to make skips disappear.

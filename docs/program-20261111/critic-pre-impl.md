# Pre-implementation critique: WP-S / WP-B / WP-C / WP-D

Task: critic-pre-impl-wpsbcd-20261111. Mode: DISCOVER. Date: 2026-11-11.
Reviewer: T3 Code / Codex harness, gpt-6-astra, reasoning xhigh, SUAZO-PC.
Reviewed HEAD: 391041e471895d1d4862aa81feee0ae96dafcc65. Required SHA matched.
PLAN and architecture were read before implementation sources. Initial tracked worktree was clean.

**Recommendation: amend the frozen checks and shared contracts before implementing WP-S.**
There are 12 design findings: 10 P1 and 2 P2. No P0 is established by this source review.
These are evidenced design risks and counterexamples, not claims of reproduced runtime exploits.
No SQL, network, browser, build, test suite, commit, or deployment was run.
This report is the only intended new file. PLAN and implementation files remain unchanged.

## Numbered findings

### 1. P1 — Outbox must follow the actual paid-sale transaction, including savepoint rollback and semantic no-ops

**Evidence.** [backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs:67](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs:67) opens the Serializable transaction. Current session checks occur at line 75. Replay returns before the action at line 89. The savepoint is at line 119; failure rolls back and clears tracking at line 122. Operation persistence, final SaveChanges and commit are at lines 128, 134 and 135.
[backend/src/Martha.Store.Api/Internal/Cash/InternalCashService.cs:35](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Cash/InternalCashService.cs:35) runs cash.sale; line 42 calls RecordSaleLocal, and line 46 can reject insufficient tender after that local method saved sale/stock changes.
[backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceService.cs:32](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceService.cs:32) rejects new unpaid sales through the old RecordSale path. Local sale and return methods save but do not commit at lines 78 and 158.
[backend/src/Martha.Store.Api/Internal/Commerce/InternalStockLedger.cs:17](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Commerce/InternalStockLedger.cs:17) requires the caller's SQL transaction; its SaveChanges at line 49 is not an independent commit.
[backend/src/Martha.Store.Api/Internal/StockExceptions/InternalStockExceptions.cs:57](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/StockExceptions/InternalStockExceptions.cs:57) permits an exceptional sale allocation without a stock movement.
[backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceService.cs:92](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceService.cs:92) and [backend/src/Martha.Store.Api/Internal/Supply/InternalSupplyService.cs:98](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Supply/InternalSupplyService.cs:98) have successful existing-result/no-op paths.

**Failure.** Hooking the old sale endpoint misses paid sales. Hooking stock movements misses exceptional sales.
Writing before the savepoint leaves an event for a rejected payment. Writing after commit can lose the event during a crash.
Emitting for every successful runner result duplicates semantic events on replay or a no-op with a different key.

**Required design.** Add events to the same scoped InternalDbContext and transaction after the savepoint, within the action when a domain change occurs.
A typed pending-event collection may instead flush before the runner's final SaveChanges, but must be discarded on failure.
Use an event identity tied to the semantic change, not only a fresh HTTP attempt.
Publish only committed rows. Never await network delivery inside the financial transaction.
Cover sale/payment, refund/return, stock adjustment, receipt, and cash open/close according to a frozen topic matrix.

**Acceptance.** Fault injection after stock save, after payment save, before final save, and before commit leaves zero partial financial rows and zero events.
A committed command survives process death before delivery and produces the event after restart.
Same-key replay and successful domain no-op produce no additional semantic event.
A paid exceptional sale emits its sale event. Failed tender does not.
Run these against SQL Server; an in-memory EF model cannot prove this boundary.

**Q1: commits outside the runner.** No separate sale/cash/stock business commit was found in the inspected production Internal sources.
Security does commit outside it: login at [backend/src/Martha.Store.Api/Internal/Security/InternalSecurityService.cs:15](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Security/InternalSecurityService.cs:15), staff creation at line 75, staff update at line 93, password reset at line 124, bootstrap at line 189.
Logout performs a standalone revocation update at line 63. Owner recovery has its own transaction at [backend/src/Martha.Store.Api/Internal/Security/InternalOwnerRecoveryService.cs:94](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Security/InternalOwnerRecoveryService.cs:94) and commits at line 119.
Cash read transactions at [backend/src/Martha.Store.Api/Internal/Cash/InternalCashReadService.cs:22](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Cash/InternalCashReadService.cs:22) and line 51 are not business writers.
Separate StoreDbContext synthetic transactions exist at [backend/src/Martha.Store.Api/SyntheticOrders.cs:28](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/SyntheticOrders.cs:28), [backend/src/Martha.Store.Api/SaviaService.cs:33](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/SaviaService.cs:33), [backend/src/Martha.Store.Api/SyntheticSeed.cs:12](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/SyntheticSeed.cs:12), and [backend/src/Martha.Store.Api/SaviaSyntheticSeed.cs:17](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/SaviaSyntheticSeed.cs:17).
They are not the real private inventory authority. Revocation cannot rely only on a hook in InternalCommandRunner.

Owner: WP-B, with the primary owning the runner integration seam.

### 2. P1 — Authentication at SSE connection time does not revoke an already-open stream

**Evidence.** [backend/src/Martha.Store.Api/Internal/Security/InternalSecurity.cs:31](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Security/InternalSecurity.cs:31) sets the secure, HttpOnly, Strict cookie. Policies differ at line 41; internal.read includes Inventory as well as Cashier.
Cookie validation calls the persisted session validator per request at line 154.
[backend/src/Martha.Store.Api/Internal/Security/InternalSecurityService.cs:53](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Security/InternalSecurityService.cs:53) reloads staff/session. Logout revokes at line 63; staff changes rotate security and revoke sessions at lines 114 and 151.
[backend/src/Martha.Store.Api/Internal/Security/InternalSecurityRules.cs:34](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Security/InternalSecurityRules.cs:34) checks enabled status, expiry, revocation, version and identity claims.
[backend/src/Martha.Store.Api/Internal/InternalBranchAccess.cs:28](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/InternalBranchAccess.cs:28) reads current branch membership. Operation replay additionally preserves original branch at line 37.
Cash custody is narrower than branch membership at line 70.
[backend/src/Martha.Store.Api/Internal/Cash/InternalCashEndpoints.cs:23](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Cash/InternalCashEndpoints.cs:23) and line 39 reserve refunds/closing reports for internal.manage.

**Failure.** A Cashier opens SSE, logs out or is reassigned, then continues receiving events.
An Inventory user receives branch-wide cash totals because the stream only requires internal.read.
An old branch event becomes visible after location reassignment.
A late browser callback restores a private view after logout.

**Required design.** Use the same cookie/session authority, with no bearer secret in the URL.
Validate at connect and reconnect, before sending authorized batches, and on a bounded heartbeat while idle.
Use short-lived scopes/contexts; do not hold a Serializable transaction for the stream lifetime.
Check current role, active branch, resource membership, original event branch and topic entitlement.
Deny unknown/branchless topics except explicitly defined Owner global topics.
Prefer minimal invalidations followed by existing authorized reads. Do not broadcast raw receipts or customer records.
Close on revoked/expired session, failed validation, role/branch change and storage failure.
Use cancellation hints for speed, but persisted state must also catch logout and offline Owner recovery.
Close browser subscriptions on session epoch change and reject callbacks from an old epoch.

**Acceptance.** Establish real cookie streams for all roles, two Cashiers, two branches and an Owner.
While each stream is idle and busy, test logout, replacement login, expiry, disable, role change, branch reassignment, branch deactivation and Owner recovery.
Proposed bound: stop the stream within 1 second after persisted revocation becomes observable; emit nothing after failed revalidation.
Define the in-flight frame race explicitly; bytes already sent cannot be recalled.
Test cash custody and disallowed topics, historical branch events, forged branch filters, and reconnect with the revoked cookie.
Assert no PII or unauthorized financial fields in raw SSE bytes, including buffered frames.

Owner: WP-B. The primary must freeze topic permissions.

### 3. P1 — A unique GUID or ordinary SQL sequence does not establish a safe replay cursor

**Evidence.** [docs/program-20261111/PLAN.md:52](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/docs/program-20261111/PLAN.md:52) requires a unique event_id and delivery state, but specifies no cursor, retention or publication-order contract.
Line 58 promises no missed or repeated events.
[backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs:67](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs:67) and line 135 enclose independently concurrent transactions.

**Failure.** Transaction A allocates sequence 10 and stalls. B allocates 11 and commits.
A reader advances to 11. A commits later, and a query for sequence > 11 permanently misses 10.
GUID order and occurred_at timestamps also fail to define commit visibility.
A global delivered flag suppresses replay to the second screen.
A disconnect after receipt but before a client checkpoint causes legitimate redelivery.

**Required design.** Distinguish stable event identity from durable stream position.
Use a serialized publisher that assigns and persists delivery order after source transactions commit, while scanning unpublished rows without skipping delayed commits; or prove an equivalent ordering protocol.
Assign each event's published position once. Retries must preserve it.
A sequence column alone is insufficient proof.
Freeze per-resource ordering or use invalidation plus authoritative refresh instead of applying unordered financial deltas.
Promise at-least-once transport and idempotent UI effects, not unqualified exactly-once delivery.
Bound retention, replay pages, clients and buffers. Define reset/snapshot behavior for expired, malformed, unknown and future cursors.
Handle the snapshot/subscription boundary. Serialize bigint cursors as strings.

**Acceptance.** Force the 10/11 commit inversion and verify both events arrive.
Crash before and after publication checkpoint; reconnect two independent clients with different cursors.
Disconnect mid-frame and after receipt; assert each semantic UI effect occurs once despite possible wire duplicates.
Exercise replay/live handoff, slow consumers, buffer overflow, restart, purged cursors, two branches and sequence values above JavaScript's safe integer range.
Heartbeats must not advance the data cursor.
An overflow/reset must trigger a versioned authoritative refresh rather than silent loss.

Owner: WP-S freezes schema and cursor contract with WP-B before migration acceptance.

### 4. P1 — C4 contradicts the existing email identity rule and has no concurrency invariant

**Evidence.** [backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryModels.cs:113](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryModels.cs:113) explicitly permits shared contacts and prohibits silent merge or email/name uniqueness.
[backend/tests/Martha.Store.Api.Tests/InternalDirectoryModelTests.cs:31](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/tests/Martha.Store.Api.Tests/InternalDirectoryModelTests.cs:31) checks that Parties has no unique indexes.
[backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryValidation.cs:57](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryValidation.cs:57) permits absent email and lowercases only its domain; it preserves local-part case and does not deduplicate.
[backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryService.cs:95](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryService.cs:95) creates a fresh ID.
[backend/src/Martha.Store.Api/Internal/InternalDbContext.cs:19](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/InternalDbContext.cs:19) serializes idempotency by actor/scope/key, not customer email.
[docs/program-20261111/PLAN.md:65](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/docs/program-20261111/PLAN.md:65) now says duplicate email returns the existing customer.

**Failure.** Cashier and public signup concurrently pass a pre-insert lookup and create two customers.
An unconditional unique index fails on existing household/shared email records.
A case-insensitive or accent-insensitive database comparison merges distinct addresses accidentally.
A query returning the first legacy match attaches a sale to the wrong person.

**Required design.** Resolve the changed identity contract before WP-S.
Recommend a separate canonical customer-enrollment/email claim, preserving existing Party IDs and historical duplicates.
Define supported email syntax, trimming, Unicode NFC, IDNA domains and local-part case explicitly.
Preserve the display address. Reject unsupported forms consistently. Do not strip dots, plus tags or accents.
If whole-address case folding is selected, record it as a new business identity policy; the present validator does not implement it.
Enforce canonical uniqueness in SQL using an explicit comparison/collation and one shared admission primitive.
Scope identity to customers; suppliers and nullable legacy contacts must remain valid.
Use email-key serialization/unique-violation handling across C, D and relevant Owner updates.
An ambiguous legacy match requires a staff conflict outcome, not an arbitrary merge.

**Acceptance.** Seed null emails, shared household emails, suppliers, inactive customers and existing duplicates.
Race distinct actors, sessions, scopes and idempotency keys through both C and D.
Exactly one canonical enrollment is created; callers get the correct authorized outcome, never an unhandled unique/deadlock error.
Test domain/local-part case, composed/decomposed characters, IDN and invalid address forms against a frozen expected-results table.
Preserve existing Party/sale IDs and every old contact unless an explicit resolution was authorized.

Owner: primary decides identity semantics; WP-S owns schema; WP-C owns the shared customer admission primitive.

### 5. P1 — Relaxing the Owner directory policy would expose an enumerable customer/supplier directory

**Evidence.** [backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryEndpoints.cs:20](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryEndpoints.cs:20) and line 28 are Owner-only.
The list at line 84 accepts optional kind/query, searches name/email/phone, and returns total, pagination and full views.
[backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryValidation.cs:36](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryValidation.cs:36) permits empty searches and take up to 100.
[backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryModels.cs:25](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryModels.cs:25) has no Party branch field.
[backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs:28](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs:28) keeps directory writes Owner-only, and line 114 rejects unscoped commands from non-Owners.
[backend/src/Martha.Store.Api/Internal/InternalBranchAccess.cs:83](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/InternalBranchAccess.cs:83) has no Party resource resolver.

**Failure.** Adding Cashier to the existing endpoint allows bulk contact extraction and supplier discovery.
Changing only the endpoint policy leaves registration forbidden inside the runner.
Removing the runner's unscoped Owner restriction broadly opens unrelated operations.
Claiming branch isolation for customers is false because Party has no branch.

**Required design.** Add a dedicated customer search/register contract.
Server fixes kind=customer and active eligibility. Do not accept client-supplied role, actor, Kind or arbitrary Active changes.
Minimum search projection: customer ID, display name, masked email; reveal full email only where an exact supplied address and the approved workflow require it.
Exclude phone, supplier fields, transaction/history aggregates and global totals.
Recommend exact canonical-email search and a bounded name-prefix search: minimum 3 characters, cap 10, no bulk pagination.
Rate-limit by authenticated staff/session and globally. Masking and caps reduce enumeration; they cannot eliminate deliberate repeated searches.
State whether the approved customer directory is global or branch-scoped.
Introduce a narrowly authorized command scope/resource; preserve unrelated Owner-only rules and CSRF/idempotency protections.

**Acceptance.** Cashier can use only the new contract. Inventory, anonymous and revoked sessions fail.
Direct access to old lists, by-ID endpoints and mutations stays denied.
Reject empty/broad searches, supplier queries, unexpected fields and oversized pages.
Verify the chosen global/branch semantics, rate limits and minimal raw responses.
Reject missing/wrong-session CSRF and foreign idempotency replay.
A denied write creates no Party, consent, operation side effect or outbox event.

Owner: WP-C; primary freezes customer data scope with the appropriate business owner before production acceptance.

### 6. P1 — Public signup needs separate authority, abuse controls and non-enumerating duplicate behavior

**Evidence.** [backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs:56](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs:56) requires an authenticated staff actor.
[backend/src/Martha.Store.Api/Internal/InternalDbContext.cs:20](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/InternalDbContext.cs:20) requires operation actors to reference staff.
[backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryService.cs:98](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryService.cs:98) overwrites name/contact/active state in the Owner edit flow.
[backend/src/Martha.Store.Api/Internal/Security/InternalLoginLimiter.cs:16](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Security/InternalLoginLimiter.cs:16) is an in-process staff-login limiter.
[backend/src/Martha.Store.Api/Internal/Security/InternalSecurity.cs:99](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Security/InternalSecurity.cs:99) keys it using RemoteIpAddress.
[docs/program-20261111/PLAN.md:70](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/docs/program-20261111/PLAN.md:70) names validation and a limiter but no public duplicate or consent-replay contract.

**Failure.** Reusing a staff endpoint requires fake Owner authority or weakens private authentication.
Returning an existing customer discloses who shops here.
An attacker submits another person's email and changes that customer's name or consent.
Unlimited anonymous requests consume SQL connections or fill customer records.
A replay re-enables consent after withdrawal.

**Required design.** Public signup gets a narrow independent transaction/authority and reuses the shared identity primitive.
Do not fabricate a staff actor or expose Owner CRUD.
Use a generic accepted response for valid new/existing submissions, with no customer ID, existing name, active state or duplicate-specific body.
Do not overwrite existing identity or silently grant/regrant consent from an unverified duplicate submission.
Record consent purpose, policy/version, time and actor type/source. An anonymous claim is not proof of email ownership.
Set an explicit policy for repeat submission after withdrawal.
Enforce body/field limits and admission limits before costly database work: per client, global rate, concurrency, bounded limiter state and Retry-After.
Keep signup limits separate from staff login. Derive client identity only from a trusted proxy chain.
Cross-origin delivery needs an explicit origin/transport contract with no staff credentials; CORS is not an abuse limiter.

**Acceptance.** Race C/D enrollment; submit existing, inactive and anonymized identities.
Responses do not reveal existence and do not mutate another person's contact/consent.
Test duplicate/replayed requests after withdrawal, unsolicited opt-in fields, invalid/oversized bodies and bursts from one/many client addresses.
Verify bounded memory/SQL concurrency, 429 behavior and unaffected staff login.
Spoofing X-Forwarded-For must not evade limits. Raw logs/errors must not disclose addresses.
Test the actual intended storefront origin; no wildcard credentialed CORS.

Owner: WP-D, using WP-C's identity contract and WP-S's anonymous-consent representation.

### 7. P1 — Anonymizing Party alone leaves PII in immutable operation results

**Evidence.** [backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryService.cs:103](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryService.cs:103) returns the full Party view; line 131 includes name/email/phone.
[backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs:132](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs:132) serializes that result into Operations.ResultJson and line 110 replays it.
[backend/src/Martha.Store.Api/Internal/InternalDbContext.cs:32](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/InternalDbContext.cs:32) makes Operations and financial audit rows append-only.
Directory deactivation only clears Active at [backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryService.cs:111](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryService.cs:111).
Sales reference Party with Restrict at [backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceModel.cs:48](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceModel.cs:48).
Sale line snapshots are item/price data at [backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceService.cs:66](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceService.cs:66).
[backend/src/Martha.Store.Api/Internal/Cash/InternalCashService.cs:108](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Cash/InternalCashService.cs:108) computes closing from tills, entries and closes; lines 133-144 reconcile money without joining customer contact data.

**Failure.** Clearing Party name/email/phone appears successful, but replay exposes old contact data.
Deleting Party is blocked by sales references, or a workaround damages the audit trail.
Putting customer contact in the new outbox creates another durable copy.
Signup/replay restores erased contact or withdrawn consent.

**Required design.** Preserve an opaque Party tombstone and all sale/payment/refund/close IDs, amounts, currency and item snapshots.
Set the tombstone inactive with neutral name and cleared contacts; future customer assignment must reject it.
Keep refund/reconciliation working without an active customer contact.
Inventory all PII copies, especially existing operation JSON, future events, caches, exports, logs and retained backups.
Do not claim complete anonymization while accessible copies remain.
New operation/event contracts should minimize PII and resolve current projections where appropriate.
Existing immutable PII requires an explicit narrow erasure/retention design; do not disable GuardAudit globally.
Retaining linkage for accounting is pseudonymization unless the wider re-identification risk is addressed.
Consent history must record withdrawal without retaining unnecessary contact data.

**Acceptance.** Create a customer, paid sale, refund and closed till, then anonymize.
Compare financial rows and closing totals before/after; no financial or stock history changes.
Replay the old directory idempotency key and inspect SSE/caches/exports: no erased contact reappears within the declared erasure boundary.
Repeat signup and retries after withdrawal. They cannot silently restore the customer.
Document backup/retention limits separately; no unsupported legal-compliance claim.

Owner: WP-S and primary own the erasure contract; C/D/B must respect it.

### 8. P1 — The current storefront adapter points to a synthetic model, not InternalItem stock

**Evidence.** [backend/src/Martha.Store.Api/Program.cs:122](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Program.cs:122) serves a synthetic-only catalog from StoreDbContext and returns 503 when that mode is disabled.
[backend/src/Martha.Store.Api/StoreDbContext.cs:43](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/StoreDbContext.cs:43) has Product/Variant grouping, independent quantity and a currency=XXX constraint at line 54.
[backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryModels.cs:6](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryModels.cs:6) has a flat InternalItem with SKU/name/price/currency/active, without storefront product grouping, size or images.
[backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceService.cs:170](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceService.cs:170) calculates Available as OnHand minus Reserved.
[src/integration-adapters.js:116](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/src/integration-adapters.js:116) explicitly rejects guessed slug/image/size/currency mappings; line 125 validates the synthetic contract.
Line 187 maps synthetic IDs and line 30 blocks real orders.

**Failure.** Reusing /api/v1/catalog presents fixture stock as real.
Joining by display name or assuming matching IDs attaches the wrong item or size.
Summing every internal location exposes unpublished stock or double-counts a variant.
Using OnHand ignores reservations. Hardcoding USD or dividing all currencies by 100 gives false prices.
Offline failure resets freshness or silently falls back to demo stock.

**Required mapping.**
- Maintain an explicit publication map: storefront product slug and variant ID to a designated InternalItem ID/SKU.
- Define size/variant granularity. One aggregate SKU cannot truthfully provide independent size stock.
- Keep approved titles, images and size labels in curated storefront data; do not infer them from arbitrary internal names.
- Publish active, mapped items only; use an explicit allowlist of sellable locations and a frozen aggregation rule.
- Return public identifiers, approved catalog fields, actual currency/minor-unit interpretation, availability and data freshness/version.
- Use a separate live contract/adapter and fail closed on unmapped/mismatched items.
- Never serialize Internal entities wholesale. Exclude costs, supplier/customer/staff fields, movements, reasons, receipts, internal location topology and operational metadata.
- Last-known data must be from the same live contract/mapping/currency. Preserve last successful as-of time; display stale/unknown explicitly.
  Cold offline has no known stock. Cache contents are presentation data, never order authority.
- Reject out-of-order refresh responses. Define a maximum stale age and reconnect refresh. Keep real purchasing disabled unless separately authorized.

**Acceptance.** Seed different synthetic and internal stock; the public response must follow only the approved internal mapping.
Test reserved stock, inactive/unpublished items, multiple branches/locations, missing mappings, duplicate mappings, sizes and mixed currencies.
Assert a closed response-field allowlist.
Commit a cash sale and observe the actual storefront change within 5 seconds.
Simulate disconnect, cold start, old/corrupt cache, changed mapping and reordered responses; no synthetic fallback or falsely fresh data.

Owner: WP-D; mapping/schema ownership must be settled before WP-S closes.

### 9. P1 — A tunnel to the whole store PC origin is not qualified by the current HTTPS checks

**Evidence.** [backend/src/Martha.Store.Api/Program.cs:63](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Program.cs:63) applies HTTPS enforcement to /internal using Request.IsHttps at line 70.
Private authentication and UI share that application at lines 75-90.
[backend/src/Martha.Store.Api/Internal/Security/InternalSecurity.cs:73](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Security/InternalSecurity.cs:73) separately checks HTTPS for private mutations.
Anonymous synthetic write routes are mounted when enabled at [backend/src/Martha.Store.Api/Program.cs:135](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Program.cs:135).
The reviewed backend source contains no explicit UseForwardedHeaders/ForwardedHeaders configuration.
[backend/src/Martha.Store.Api/Internal/Security/InternalLoginLimiter.cs:3](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Security/InternalLoginLimiter.cs:3) warns against trusting arbitrary forwarded identity.
[backend/src/Martha.Store.Api/Internal/InternalHosting.cs:24](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/InternalHosting.cs:24) configures a private InternalDbContext; it does not qualify public ingress.

**Failure.** A TLS-terminating proxy forwards HTTP, so IsHttps rejects valid private requests.
A rushed fix trusts any X-Forwarded-Proto or X-Forwarded-For, enabling scheme spoofing or limiter bypass.
Publishing the whole origin exposes private login/UI and potentially synthetic write surfaces to the internet.
HTTPS alone does not isolate those routes.

**Required design.** Do not accept whole-PC-origin tunneling as safe from this evidence.
Use a public boundary that allowlists only catalog reads and signup, with private and synthetic routes denied externally.
Keep origin access restricted. Use HTTPS to the origin or narrowly trusted proxy forwarding with exact proxy/network and host configuration, processed before scheme checks.
Define which component terminates TLS and supplies client identity.
Keep staff cookies on the private origin and never forward staff credentials through the public adapter.
This is a design condition, not authorization to deploy or change certificates.

**Acceptance.** In an approved deployment test, verify legitimate ingress, direct HTTP/origin access, untrusted Host and forged forwarded headers.
Externally request /internal, staff SSE, private readiness, synthetic mutations and alternate path forms; deny them.
Confirm signup limits use trusted client identity and private endpoints retain HTTPS/cookie/CSRF protections.
The actual tunnel, TLS origin and proxy configuration remain UNKNOWN in this read-only task.

Owner: primary/hosting owner. WP-D can implement local contracts before deployment qualification.

### 10. P2 — Declared UI paths omit real integration seams and customer replay behavior

**Evidence.** [dev/savia-staff-ui/client.mjs:122](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/dev/savia-staff-ui/client.mjs:122) requires customerId===null in the current sale validator.
[dev/savia-staff-ui/cash.mjs:259](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/dev/savia-staff-ui/cash.mjs:259) constructs cash sales with customerId:null.
Pending-intent validation starts at [dev/savia-staff-ui/cash.mjs:56](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/dev/savia-staff-ui/cash.mjs:56).
[dev/savia-staff-ui/app.mjs:360](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/dev/savia-staff-ui/app.mjs:360) clears session state during logout; directory view permissions are at line 142.
[src/app.js:215](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/src/app.js:215) instantiates createDemoAdapter; line 673 mounts catalog data through that integration.
[backend/src/Martha.Store.Api/Internal/InternalUiHosting.cs:8](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/InternalUiHosting.cs:8) and [backend/src/Martha.Store.Api/Martha.Store.Api.csproj:16](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Martha.Store.Api.csproj:16) explicitly enumerate embedded staff files.

**Failure.** A backend customer endpoint passes tests but cash never submits customerId.
A retry changes its frozen body when the operator selects a different customer.
An SSE refresh retries a pending sale or replaces unsaved cash inputs.
A new browser module works in a development folder but is missing from the embedded API.
Editing only integration-adapters.js leaves the live storefront on the demo adapter.

**Acceptance/design.** Wire the actual cash form, validator, pending-operation contract and embedded resources.
Preserve legacy null-customer intents and guest sales.
For a pending sale, retry exactly the original key/body/customer ID; changing selection creates no mutation of that intent.
On logout, late search/SSE callbacks cannot restore customer data.
SSE may invalidate reads; it must not create/retry POSTs or discard an unsent cart.
Test cash sale with/without customer, unknown outcome/reload/retry, logout/login, two screens and an embedded Release build.
Test the storefront page's actual adapter selection, mapping and refresh rather than an isolated adapter unit test.

Owner: WP-C and WP-B staff integration; WP-D storefront integration.

### 11. P1 — Applying a migration twice to an empty database does not prove a safe current-data upgrade

**Evidence.** [docs/program-20261111/PLAN.md:51](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/docs/program-20261111/PLAN.md:51) freezes additive migration/idempotence only.
[backend/src/Martha.Store.Api/Internal/Migrations/InternalDbContextModelSnapshot.cs:360](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Migrations/InternalDbContextModelSnapshot.cs:360) contains the existing Party schema without an email identity constraint.
[backend/src/Martha.Store.Api/Internal/Migrations/20261107221938_FirstCashRegister.cs:12](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Migrations/20261107221938_FirstCashRegister.cs:12) is the current cash migration.
[backend/src/Martha.Store.Api/Internal/Migrations/InitialInternalSavia.idempotent.sql:11](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Internal/Migrations/InitialInternalSavia.idempotent.sql:11) uses transactions and migration-history guards.
[backend/tests/Martha.Store.Api.Tests/InternalReleaseScriptTests.cs:19](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/tests/Martha.Store.Api.Tests/InternalReleaseScriptTests.cs:19) records the exact EF script-generation command.
Line 40 checks checked-in script equivalence. Line 53 tests empty and first-migration upgrades; line 56 currently lists four migrations.
[backend/src/Martha.Store.Api/Program.cs:97](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/backend/src/Martha.Store.Api/Program.cs:97) shows --migrate operates on StoreDbContext, not InternalDbContext.

**Failure.** Empty-database tests pass, while a current populated database fails on legacy duplicate emails or non-null consent actors.
A migration silently backfills marketing consent.
An unmodified four-migration oracle misses the new schema.
Using the existing application --migrate command updates the wrong context.

**Acceptance/design.** Generate a new additive InternalDbContext migration, matching snapshot and idempotent script through EF; never hand-edit generated history.
Test empty, first-migration and populated current-cash-schema upgrades, then reapply the script.
Fixtures must include legacy duplicates/null contacts, suppliers, sales, exceptional stock, payments/refunds, open and closed tills, operation JSON and staff sessions.
Compare existing IDs/amounts/references/contacts before and after.
Assert default consent is unknown/not granted; require no fake anonymous staff FK.
Inspect constraints, indexes, cursor columns and migration history through a schema oracle.
Verify the StoreDbContext schema is untouched.
Include a failure/rollback or restore exercise on disposable data before operational use.
No SQL execution or migration safety acceptance occurred during this review.

Owner: WP-S, sole migration writer.

### 12. P2 — B/C/D are only partially parallelizable after S; the exclusive-path table is inaccurate

**Evidence.** [docs/program-20261111/PLAN.md:27](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/docs/program-20261111/PLAN.md:27) starts B/C/D after S.
Lines 33-35 call their paths exclusive, while line 81 permits at most two Codex tasks concurrently and requires serial integration.
Shared source seams are shown in findings 1, 4, 5, 8 and 10.

**Conflict map.**

| Shared contract/file | Participants | Required owner/order |
| --- | --- | --- |
| InternalDbContext, Directory models, Events schema, migrations/snapshot/script | S, then B/C/D consumers | S freezes all required columns/invariants before integration; one migration owner |
| InternalCommandRunner, InternalBranchAccess, InternalSecurity policies | B event flush and C customer command permissions | Primary integrates bounded changes; no broad policy relaxation |
| Program.cs and InternalHosting.cs | B event services/routes; C customer services; D public routes/limits | Primary owns composition, package modules expose explicit registration |
| dev/savia-staff-ui/app.mjs, client.mjs, login/session teardown, index.html | B subscription/lifecycle; C customer cash flow | Separate modules plus one integration writer |
| InternalUiHosting.cs and Martha.Store.Api.csproj | B/C new embedded modules | One resource-registration integration |
| Canonical email identity + customer admission + consent semantics | C staff registration, D public signup, S schema | Shared primitive before either divergent implementation; D signup depends on this |
| Public publication map and stock/currency DTO | D with S if persisted; B event invalidation consumers | Freeze source, mapping and version contract first |

**Failure.** Two workers pass isolated tests, then overwrite logout wiring or implement incompatible duplicate/consent rules.
D requires a new mapping migration after S was declared final.
Running B/C/D together violates the plan's maximum of two tasks; WP-A may already occupy a slot.

**Acceptance/design.** Parallel work is feasible on independent modules after interface/schema freeze, not merely after any S commit.
Freeze event positions/topics/payloads, identity/consent, public mapping and registration signatures first.
Allocate shared-file ownership and integrate in series. Run combined checks on the exact integrated SHA.
Allow D's catalog work alongside C; gate D signup on the shared admission primitive.
Respect the two-task cap and account for A.
Do not force separate persistent publication tables if existing curated configuration can meet the frozen mapping contract.

Owner: primary, before executor packets are issued.

## Proposed edits to the frozen checks in PLAN.md

These are proposed amendments only. The plan was not edited.

| Check | Replacement or addition |
| --- | --- |
| S1 | Generate the additive InternalDbContext migration/snapshot/script; compare script to EF output. Apply twice to empty, first-migration and populated current-cash databases. Prove existing row/reference preservation, schema oracle, context isolation and disposable failure recovery. |
| S2 | Keep unique event_id; add durable publication position, aggregate/resource identity, original branch, schema version and a frozen minimal payload. Prove commit inversion, atomic event creation, idempotent publication and retention/reset behavior. Delivery state is publisher state, not consumption by every screen. |
| S3 | Consent has purpose, policy/version, timestamp, actor type/source and withdrawal. No implicit legacy opt-in or fabricated staff actor. Anonymization preserves accounting and declares/removes accessible PII copies, including operation replay. Preserve tombstones and document retained-data limits. |
| S4 — new | Freeze canonical customer-email semantics and legacy duplicate handling. Enforce the shared invariant in SQL under C/D/Owner concurrency, preserving nullable/supplier/historical records. Update tests that intentionally assert non-unique contact fields only after the new identity contract is explicit. |
| S5 — new | Freeze B/C/D contracts and schema needs: cursor, authorization topics, customer admission/consent, publication map and currency. Assign shared-file owners. |
| B1 | Cover the actual paid cash.sale/refund path and every declared stock/cash event. Inject failures at intermediate SaveChanges and commit boundaries. Include exceptional sales, no-op successes, same-key replay and crash after commit. |
| B2 | Measure commit/ack-to-render on two real authenticated screens, with defined network/hardware/load and correlated event IDs. Require <=1 second in the agreed connected test profile. Also preserve the architecture's cash action p95 <=200 ms; slow SSE clients must not block sales. |
| B3 | Replace the unqualified “no repeated events” promise with at-least-once delivery and exactly-once semantic UI effects. Test ordering inversion, replay/live handoff, multi-client cursors, restart, duplicates, retention reset, bigint strings and backpressure. |
| B4 | Test the session/role/branch/topic/cash-custody matrix at connect, reconnect and while open. Add persisted revocation heartbeat, proposed <=1-second closure bound, current/original branch checks, fail-closed storage failure and logout epoch cleanup. Freeze the in-flight-frame limit explicitly. |
| C1 | Dedicated narrow customer endpoints and the actual cash UI submit the selected opaque customer ID. Existing Owner directory remains Owner-only. Require CSRF, scoped authorization and idempotency through the new command path. |
| C2 | Closed minimal DTO; no phone/history/supplier/global count; exact email or bounded name-prefix query, cap and rate limits. Explicitly approve global vs branch customer lookup. Test direct enumeration and forged requests. |
| C3 | Guest sale plus selected-customer sale, cash settlement/refund/close and immutable pending retry all work. Logout and SSE refresh neither leak customer data nor issue/rewrite a sale. Embedded Release resources must load. |
| C4 | Canonical duplicate returns the existing minimal customer only to authorized staff. Ambiguous legacy matches produce a defined conflict, with no automatic merge. Public responses remain generic. Race C/D and Owner edits across independent actors/keys. |
| D1 | Real InternalDbContext projection with explicit product/variant/size/item/location mapping; available=OnHand-Reserved under the chosen publication rule. Wire the actual storefront. Cash commit becomes visible <=5 seconds in the connected profile. No synthetic or guessed fallback. |
| D2 | Assert an exact public field allowlist and read-only catalog access. Exclude operational entities/fields and deny private/synthetic routes at public ingress. Keep live purchases disabled absent separate authority. |
| D3 | Narrow anonymous signup, shared atomic identity/consent primitive, generic duplicate behavior, no overwrites/regrant, body bounds, per-client/global/concurrency limits, bounded state and Retry-After. Test proxy spoofing and the intended origin without staff credentials. |
| D4 | Last successful live value carries source/version/as-of and explicit stale state. Cold offline is unknown. Define expiry and reconnect behavior. Test corrupt/old/wrong-mapping cache and reordered responses. Unavailable service must not reset freshness or invent zero stock. |
| D5 | Keep LCP <=2.5 s and INP <=200 ms; include architecture CLS <=0.1. Freeze device/CPU/network/load, sample protocol and tested interactions. Measure INP during interactions in a real browser; a passive load score alone is insufficient. Report exact SHA and observed timings. |
| D6 — new | Before exposure, qualify the exact TLS/proxy/origin boundary with trusted forwarded headers, restricted origin, public route allowlist and private-route denial. Source/config review alone is not deployment acceptance. |
| Integration gate — new | Primary integrates shared seams serially and reruns the affected combined checks at the resulting SHA. No more than two concurrent Codex tasks. Report unit, SQL, browser and deployed evidence separately. |

## Explicit answers and remaining unknowns

| Question | Answer |
| --- | --- |
| Q1 — Transaction seam/outside commits | Finding 1 gives the savepoint/action/final-save seam and the external security/synthetic commits. No inspected real sale/cash/stock path commits independently of InternalCommandRunner. |
| Q2 — SSE auth/revocation/order | Findings 2-3 give the persisted session/role/branch/custody contract and the commit-inversion counterexample. No SSE implementation was found in the reviewed source. |
| Q3 — Cashier fields/enumeration/email/race | Findings 4-5 give the minimal projection, narrow search surface, policy conflict and SQL concurrency invariant. The chosen business identity/global-vs-branch semantics are UNKNOWN. |
| Q4 — Public mapping/leaks/limiter/tunnel | Findings 6, 8 and 9 give the model split, mapping, closed DTO and ingress requirements. The actual publication map and deployed proxy/TLS state are UNKNOWN. |
| Q5 — Consent/anonymization/reconciliation | Finding 7 identifies opaque references and financial ledgers that preserve reconciliation, plus immutable operation JSON that defeats Party-only erasure. Actual data copies/retention outside the repo are UNKNOWN. |
| Q6 — Parallel B/C/D | Finding 12 gives specific overlaps, interface dependencies and the two-task cap. Module work can overlap after contracts freeze; whole packages are not independent solely because S lands. |

**Not verified, with reasons.**

- SQL constraints, locking, rollback, concurrency, script application and financial invariants: NOT RUN. The task prohibited SQL execution.
- Cookie/SSE behavior, actual browser UI, reverse-proxy buffering, performance and accessibility regressions: NOT RUN. This pass was repository review only; proposed systems are not implemented.
- Existing real customer duplicates, Unicode distribution, stock publication rules, business currency/exponent and sellable locations: UNKNOWN. No real data or credentials were accessed.
- Production host/process flags, certificates, proxy chains, firewall/origin access, tunnel route restrictions and runtime-injected forwarding configuration: UNKNOWN. No network or machine deployment inspection was authorized.
- Approved customer lookup scope, identity treatment for shared emails, consent purpose/retention and treatment of legacy PII: UNKNOWN. Architecture assigns customer-data/personnel permissions to Martha at [docs/architecture-20261111/README.md:13](C:/Users/Jason/.t3/worktrees/github/t3-686dc562-0bc3c3418045c126/docs/architecture-20261111/README.md:13) and lists that decision pending at line 53.
- Full erasure from backups, historical exports, logs or any prior deployment: UNKNOWN. Those artifacts were outside the repository review.
- CI results or operational/production acceptance at this SHA: UNKNOWN. No CI/network queries were made. Existing test source is not a passing test result.

**Blocker disposition and handoff.** No implementation correction was attempted because this assignment explicitly forbids tracked edits.
The permitted correction is this concrete acceptance/ownership amendment packet.
The primary owns adopting or resolving each contract above; package owners then implement and produce the named fresh evidence.
Open business/deployment decisions do not block independent local implementation whose contract is already fixed.
They do block claims that identity policy, complete erasure or public exposure are accepted.
Completion check for this review: all six questions have source evidence or an explicit UNKNOWN reason; only this report is created.

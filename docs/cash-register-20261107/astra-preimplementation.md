# SAVIA cash register: preimplementation review

VERIFIED: source review completed. Adopt the design below only after primary adjudication; implementation and operational acceptance remain pending.

Task: `savia-cash-design-astra-active-87ff799-20261107-01`.
Source HEAD: `87ff7991967b2f9f2bd98cf447be5d0e843337c8`.
Managed checkout: `C:/Users/Jason/.t3/worktrees/github/t3-836a58f0`; branch: `t3/cash-register-preimplementation-review`.
Host: SUAZO-PC; provider/harness: Codex through T3; model: gpt-6-astra.
Requested/effective effort: xhigh, exposed by runtime context and agent-awareness.
Token usage and cost: unknown/unreported. No delegates or fallback.

## Material findings

These are required design controls, not reproduced cash defects.

| Severity | Verified source and failure to prevent | Check |
|---|---|---|
| P1 | [Service:32–72,76–142,209–214](../../backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceService.cs#L32): sales record stock; receipts say `not_processed`; returns record credit. Relabeling history or allowing legacy reversals of paid sales would invent payment or bypass cash. | CASH-01/06 |
| P1 | [Runner:22–123](../../backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs#L22), [Access:27–49](../../backend/src/Martha.Store.Api/Internal/InternalBranchAccess.cs#L27): scopes are allowlisted; resources resolve only location/sale/purchase. Cash authorization, till custody and replay checks must be explicit. | CASH-03/04/07 |
| P1 | [Service:200–202](../../backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceService.cs#L200), [Ledger:17–49](../../backend/src/Martha.Store.Api/Internal/Commerce/InternalStockLedger.cs#L17): sale locks and stock writes exist; per-key serialization cannot protect different-key refunds or till closure. | CASH-02/04/06 |
| P1 | [DbContext:23–33](../../backend/src/Martha.Store.Api/Internal/InternalDbContext.cs#L23), [Fingerprint:8–27](../../backend/tests/Martha.Store.Api.Tests/InternalAcceptanceFingerprint.cs#L8): append-only types and exact 20-table inventory need cash additions. Excluding new cash tables would conceal corruption. | CASH-05/07 |
| P2 | [Client:86–94,127–150](../../dev/savia-staff-ui/client.mjs#L86) accepts only unpaid receipts; [UI:514–521](../../dev/savia-staff-ui/app.mjs#L514) divides by 100. Paid receipts and non-two-decimal currencies would fail or display incorrectly. | CASH-01/03/08 |

Scope authority: [D-031–034](../DECISIONS.md#L237), [CASH-01–08](README.md#L41), [ledger:529–556](../pipeline/ledger.json#L529).

## Minimal seams and contracts

Add three Internal tables, without a payment platform:

- `CashTills`: server TillId doubles as shift identity; immutable cashier, location, currency, minor-unit exponent, opening actor/time; nullable closed marker.
- `CashEntries`: append-only opening/sale/refund entries with EntryId/TillId; signed DeltaMinor, received/change, sale/reversal references, authorizer, paying cashier, currency and server time.
- `CashCloses`: one immutable row per till containing expected, counted, difference, counting actor and time.

Opening is an entry, not another amount added during summation.
Cash payment exists only through a sale entry; absence preserves historical `not_processed`.
Refund balance equals original paid amount minus persisted cash refunds, never recorded credits.
Reuse reversal lines for returned quantities and original-price valuation.
Never nest command runners: extract a transaction-local sale/reversal core.

Use bigint minor units bounded by existing `MaxMinor=9000000000000` ([Contracts:20–23](../../backend/src/Martha.Store.Api/Internal/InternalContracts.cs#L20)).
Check multiplication, sums, tender/change, accumulated till balance and difference.
Currency/exponent comes from explicit trusted configuration, with no business default.
Require item/sale/till currency agreement; no FX, mixed tender, tax or fiscal assumptions.

New idempotent contracts: open(location,currency,openingMinor); cash-sale(till,customer,lines,currency,receivedMinor); refund(sale,payingTill,currency,reason,returned-lines); close(till,countedMinor).
Server derives price, total, refund amount, actors and timestamps.
Recommend quantity-based refunds at original prices; no discretionary cash-credit amount.
Reject unknown fields and client-supplied totals/authorizers.
Responses include stable receipt, till/shift, sale, location, currency/exponent, received/change, paid/refunded/balance and provenance.
Cash status is paid/partially_refunded/refunded; bank-refund status remains separate.
Close returns expected/count/difference.
Historical operation responses remain unchanged.

Recommend one open till per cashier across locations/currencies; a client-created shift cannot evade it.
Opening/sale/close require Owner/Manager/Cashier and that actor's till.
Refund requires Owner/Manager; derive paying cashier from the selected till, not request claims.
For this increment require sale and paying till at the same location, current authorizer access, active responsible cashier and sufficient persisted cash.
Manager selection records authorization/custody; it does not prove physical handover.
No reopening, transfers or cross-location refund.

Under /internal/api/cash, map POST /tills, /sales, /sales/{saleId}/refunds and /tills/{tillId}/close.
Their explicit scopes are cash.till.open, cash.sale, cash.refund and cash.till.close; apply endpoint policies and CSRF filters.
Extend cash resource preflight to carry sale/till identities and check custody/location before action admission.
Replay checks current session, role and resource access, but not current openness.
A successful historical sale/refund/close may replay after closure without new writes.
Preserve [Hosting:59–75](../../backend/src/Martha.Store.Api/Internal/InternalHosting.cs#L59) operation recovery.

Keep legacy unpaid returns stock-only.
Reject legacy cancel/return for paid sales before mutation; direct callers must use controlled refund.
For cash rollout, retire fresh unpaid sale creation while retaining authorized old-key replay/recovery; test this compatibility boundary explicitly.

Generate an additive EF migration/snapshot after `PhysicalStockException`; never backfill payments.
Use restrictive foreign keys, kind/sign/bounds checks, received-change=delta for sales, unique filtered sale-payment and refund-reversal references, unique close(TillId), unique opening-entry(TillId), and filtered unique open-till(CashierId).
Reject inconsistent sale/till currency links; use wide SQL intermediates for aggregate sums.
Extend audit guards to entries/closes and freeze till provenance.
No API may edit/delete ledger entries or rewrite a close; test tracked updates and prohibit application bulk-write bypasses.

Lock order after runner session/idempotency locks: existing sale, paying till, sorted item/location balances.
Opening uses a cashier lock/range plus the unique index; close takes only its till domain lock.
Cash sale has no existing sale lock. Close marks the till and inserts its immutable close atomically.
Acquire update/range locks before shared resource reads can cause conversion deadlocks; adapt cash resolver preflight accordingly.
Use the same serializable context for entries, reversal, stock, close and Operations.
Deadlock/commit uncertainty requires original-key reconciliation, never an automatic new-key retry.

## Frozen acceptance design

All checks below are proposed, NOT RUN.
Use synthetic data and fresh migration-backed SQL.
Independent oracles use plain ADO.NET persisted rows, not write-handler helpers or response totals.
Each negative control is a deliberate disposable mutant/fixture that must fail its named oracle.

**CASH-01.** Independently multiply persisted line-price snapshots and quantities; compare sale entry, receipt, received-minus-total and currency.
Test exact/excess/underpayment, zero, negative, fractional/string/null inputs, duplicate lines, mixed/wrong currency, maximum and overflow, including aggregate balance overflow.
Preserve zero-price semantics without permitting a positive cash refund.
Negative: alter total/change by one; the oracle must fail.

**CASH-02.** Force failure after first saved stock movement, after sale/cash persistence, and before commit.
Compare every business table before/after.
A returned admitted rejection may add exactly one immutable Operations outcome; no other changes.
An aborted transaction retains no partial effects; uncertain commit must reconcile.
Negative: bypass rollback; persisted-stock or cash delta must fail.

**CASH-03.** Drop the response after confirmed commit; recover GET and resend identical actor/scope/key/body, including after close and price changes.
Assert identical original receipt, one payment and exactly intended stock movements.
Changed body conflicts; different actor/scope cannot recover another receipt.
Apply equally to open/refund/close.
Negative: regenerate retry key; duplicate-effect oracle must fail.

**CASH-04.** Two cashiers, two locations, sequential shifts and different-key simultaneous opens: at most one open till per cashier.
Reject foreign cashier/location/shift and closed till.
Barrier-test sale versus close: sale commits before the counted snapshot or has no business effect.
Same-key close replays; new-key repeat close cannot replace count or add entries.
Negative: remove ownership/open uniqueness/state checks; isolation or race oracle must fail.

**CASH-05.** Sum entry deltas independently; compare immutable close expected and counted-minus-expected.
Verify balanced and shortage fixtures; hash original entries/close before later activity.
Attempt application update/delete and closed-till append; reject.
Negative: add one to expected, suppress shortage or alter historical close; sum/hash oracle must fail.

**CASH-06.** Reject Cashier direct refund, historical unpaid sale, blank/missing reason, unauthorized-location/closed paying till, currency mismatch, insufficient funds, excessive quantities and amount.
An authorized manager may select another cashier's paying till at the same location.
Race two keys, including two managers/two paying tills, against the same remaining paid balance.
At most the permitted refund persists.
Race refund/close; outflow belongs before paying close or has no business effect.
Inject late stock failure; money and stock both roll back.
Refund exceptional lines without fabricated stock increments ([Exceptions:8–11,57–66](../../backend/src/Martha.Store.Api/Internal/StockExceptions/InternalStockExceptions.cs#L8)).
Preserve review evidence and original close.
Negative: bypass paid-balance lock/check, old-route guard or exception branch; independent cash/quantity/movement/history oracles must fail.

**CASH-07.** Compare receipt provenance with persisted actor/session, till, sale, currency, amounts and timestamps.
Exercise missing/wrong/stale CSRF, expired/revoked/replaced session, role/branch change and replay access after reassignment.
Security failures preserve the full-table fingerprint, including Operations.
Retain [Security:64–76](../../backend/src/Martha.Store.Api/Internal/Security/InternalSecurity.cs#L64), [Rules:34–45](../../backend/src/Martha.Store.Api/Internal/Security/InternalSecurityRules.cs#L34), [Session:53–60](../../backend/src/Martha.Store.Api/Internal/Security/InternalSecurityService.cs#L53).
Negative: bypass persisted-session or CSRF validation; rejection/no-write oracle must fail.

**CASH-08.** Real staff browser → HTTPS API → SQL: open, multiarticle sale, receive/change, post-commit response loss, recover, controlled refund, count/close.
Repeat later-shift refund; second cashier's till stays byte-for-byte unchanged.
Cashier direct refund must fail.
Retain pending key/body/till across reload; validate paid and legacy receipts separately.
Record actual UI before/after without redesign.
Negative: swap till identity or return an unpersisted success; SQL correlation must fail.
Mocks, SQL-only, combined journey, restart/restore and operational acceptance remain separate.

Independent arithmetic uses two sale articles: 1000×1 and 1500×1; refund the first article.
`10000+3000-500=12500; 12400-12500=-100`.
Separate refund fixture: `12500-1000=11500; 11500-11500=0; 2500-1000=1500`.
Later shift: original close `12500` unchanged; `20000-1000=19000`; balance `1500`.

## Ownership, inventory and stop

Increment 1 — backend worker owns new cash source, Commerce service/contracts/model/endpoints, InternalCommandRunner, InternalBranchAccess, InternalDbContext, InternalHosting, generated migrations and cash backend tests.
Security worker retains session-CSRF implementation; primary resolves shared-file integration before backend acceptance.
Increment 2 — UI worker owns `dev/savia-staff-ui/{client.mjs,app.mjs,index.html,*test.mjs}` only after contracts freeze.
Increment 3 — runtime/inventory worker owns cash journey extensions under `tests/golden-path/`, fingerprint acceptance fixtures and partition evidence after backend integration.
Primary serially integrates shared files and accepts exact-SHA results.

Three added tables mean 23 full/20 Business tables; retain Operations and StockExceptionReviews in Business.
Update explicit inventory and negative same-count substitution/hash tests, never derive expected names from EF.
Existing manifest records A552/C77/E2, 631 cases/274 methods; rediscover exact multiplicities/attributes for the candidate.
Extend migration/restart/restore evidence with paid/refund/close history; EnsureCreated is insufficient.

Essential product question: **NONE** for this proposed synthetic implementation.
Real currency/configuration and operational facts remain unverified; cards remain a separate production requirement.

Access gaps: none. Discovery misses were filesystem lookup errors, not denied access: ledger root path (os error 3), guessed rules path (os error 2), literal Windows globs (os error 123).
Exact reads resolved these at docs/pipeline/ledger.json, InternalStockLedger.cs and named source files.
Agent-awareness ran at start and before writing; initial tree was clean.
Only this report changes. Verification: git rev-parse HEAD; git status --porcelain=v1; source reads; independent integer arithmetic; report length/link/hash/scope checks.
NOT RUN: builds/tests, project scripts, SQL/Docker/browser/network, services/security changes, payments, installs, staging/commit/push/merge/deploy.
Lesson: preserve security's zero-write oracle while checking the runner's explicitly admitted Operations exception separately.

Next action: primary adjudicates these controls and freezes backend contracts before assigning the first implementation increment.

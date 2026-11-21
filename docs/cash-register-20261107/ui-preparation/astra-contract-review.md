# REVISE — cash UI contract

Source review only. D-031–D-034 (docs/DECISIONS.md:237–294) and CASH-01–08 remain unchanged. Proposed contracts below require primary adjudication.
HEAD: `0bda22a6cadd0deecc635c9a9649dd100bc1e96b`; branch: `t3/cash-ui-contract-review`; initial worktree clean.
Host: SUAZO-PC, Windows/PowerShell, T3/Codex.
Requested and exposed: `codex/gpt-6-astra`, `reasoningEffort=xhigh`, confirmed by `t3_thread_configure({})` and harness metadata.
Task: `savia-cash-ui-contract-review-0bda22a-20261107-01`; mode VALIDATE.
Current-session allowance only; token usage/cost unexposed.
No nested delegation.

Prefixes: B=`backend/src/Martha.Store.Api/Internal/`; U=`dev/savia-staff-ui/`; T=`backend/tests/Martha.Store.Api.Tests/`.

**1. Missing authoritative reads — P1.** B/Cash/InternalCashEndpoints.cs:14–23 exposes only POSTs.
B/InternalHosting.cs:60–76 recovers known operations, not unknown till IDs/configuration.
Local storage cannot supply balances or permissions.
Freeze these two additive GET contracts:

- `/internal/api/cash/context` → `{configuration:{currency,exponent}|null,ownTill:{till,balanceMinor}|null,lastClose:{till,close}|null}`.
  Return the actor's open till and latest accessible own immutable close.
  An inaccessible existing open till produces denial, never false “no till”.
- `/internal/api/cash/sales/{saleId}/refund-context?skip=0&take=50` → `{sale,payment,refundedMinor,refundableMinor,paymentStatus,payingTills:{items:[{till,balanceMinor}],skip,take,hasMore}}`.
  Existing commerce reads supply original line prices/returned quantities, but omit payment/exponent and current refund-money status (B/Commerce/InternalCommerceService.cs:203–218).
  Use stored payment/refund entries; never equate commerce's `paid` marker with remaining money.

Both require no-store responses, current persisted session validation and a consistent authorized database read.
Context requires `internal.sell`; refund context requires `internal.manage`.
Paying tills must be open, same sale location/currency/exponent, with eligible enabled custodians and current branch access.
Reuse B/InternalBranchAccess.cs:28–80; do not require the manager to own the paying till.
Page deterministically; reject invalid paging.
Missing configuration disables open/sale/refund, not historical reads or an otherwise authorized close.
Check: empty browser storage, second cashier, foreign location, disabled/reassigned custodian, configuration drift, >50 tills and later-shift refund.
Compare returned balances/closes with persisted rows.

**2. Exact writes and receipts — P1.** Base `/internal/api/cash`; one `Idempotency-Key` per logical operation, unchanged across retries:

| POST suffix | Scope | JSON body | Receipt |
| --- | --- | --- | --- |
| /tills | cash.till.open | {locationId,currency,openingMinor} | {till,opening} |
| /sales | cash.sale | {tillId,customerId:null,lines,currency,receivedMinor} | {sale,payment,locationId,exponent,changeMinor,paymentStatus} |
| /sales/{saleId}/refunds | cash.refund | {payingTillId,currency,reason,lines} | {reversal,refund,locationId,refundableMinor,paymentStatus} |
| /tills/{tillId}/close | cash.till.close | {countedMinor} | {till,close} |

Keys follow B/InternalContracts.cs:21 (16–128 ASCII alphanumeric, hyphen or underscore).
Sale lines retain `{itemId,quantity,exceptionReason?,size?}`; refund lines use `{saleLineId,quantity}`.
No browser prices, totals, actor or expected balance. Direct POST returns the receipt; recovery wraps `InternalResult`.
Source: Cash/InternalCashModels.cs:47–67; InternalCashService.cs:11–102.
Open/sale/close belong to the current cashier; refund authorizer is current Owner/Manager.
Sale and paying-till locations must match.

Validate every DTO field/type, recognized enums, nonzero UUIDs, valid dates, unique lines, bounded integers, actor/customer/location/till/custodian identity, currency/exponent and requested quantities.
Match reason/exception/size after server trimming, not raw whitespace (B/Commerce/InternalCommerceService.cs:69,227).
Bind validation to the saved request and server-origin till/sale context; current configuration cannot reinterpret historical receipts.
Opening delta equals openingMinor; its unrelated fields are zero/null.
Sale line sums equal total; payment.deltaMinor equals total; payment.receivedMinor equals the request; payment.changeMinor equals outer changeMinor; received−change equals total; both payment statuses are `paid`.
Refund delta equals negative reversal credit; validate original-price line credits, sale/reversal links, zero received/change, remaining bounds and status consistent with zero remaining.
Close counted equals request, difference=counted−expected, and closedAt=close.createdAt.
Require linked entry/sale/till/reversal IDs, entry kinds/nullability and signed bounds (Cash/InternalCashModel.cs:21–38).
Reversal.bankRefundStatus remains `not_processed`; it is not cash paymentStatus (B/Commerce/InternalCommerceService.cs:230–235).
Recovered receipts are immutable operation snapshots; refresh reads for current state.
Check: mutate each receipt identity, arithmetic, status and line field; reject without clearing pending.

**3. Rejection versus uncertainty — P1.** Service validation precedes the runner; such failures have no recovery row.
Runner: B/InternalCommandRunner.cs:106–143 persists action rejections, but returns `unknown_outcome` after interrupted writes.
U/login.mjs:63–71 currently discards server error codes.

Persist and read back `{schema,actorId,actorVersion,scope,key,path,body,rawBody,dispatchState}` before POST.
Validate before persistence; preserve exact references across reload.
Retain HTTP status, ProblemDetails.code and dispatch provenance (backend/src/Martha.Store.Api/Program.cs:211–214).
First-dispatch `400 invalid_request/csrf_invalid/https_required` or `403 forbidden` can release only with no earlier uncertainty.
`401` renews protection and retains identity; recognized business rejections resolve through recovery.
Otherwise require `GET /internal/api/operations/{scope}` with the original key:
`{status:"completed",result:{success:true,value:receipt,error:null}}`, or `{success:false,value:null,error:knownCode}`.
A validated durable rejection unlocks correction.
Timeout, malformed success, 5xx, `idempotency_conflict`, or `404 operation_unknown` never permits a fresh key.
Unknown recovery permits explicit same-key/same-body continuation when authorized; never automatic POST.
Storage failure prevents dispatch; cleanup failure retains the reference.
Unrecoverable scope/version changes require an explicit reconciliation handoff with actor/scope/key/body hash; retain the reference and isolate the affected workflow.
Check all four operations: invalid input, insufficient tender/cash, CSRF rejection, lost response, reload, malformed envelope and failed storage.
Prove editable definitive rejection and exactly one committed effect after uncertainty.

**4. Sessions, compatibility and precision — P1.** Extend U/login.mjs:123–143 with exact cash routes/scopes and fresh CSRF for each POST.
Keep transport and mounted-view generation checks before/after body reads, renewal, rendering and cleanup.
Same-account login renewal preserves operation bytes; never replace actorVersion.
Changed actor/authority cannot display, delete or resend another pending operation.
Controls: delayed headers/body/mount/CSRF across logout/relogin, revocation, Cashier refund denial and cross-till sale/close denial.
Reuse U/session-transition.test.mjs:99–141 and B/Security/InternalSessionAntiforgeryAdditionalDataProvider.cs:12–27.

U/client.mjs:128–152 accepts only `not_processed`; simply relaxing that check is insufficient.
Keep legacy `commerce.sale.record` recovery separate; never convert an old unpaid intent into cash.
Fresh legacy sales are rejected (B/Commerce/InternalCommerceService.cs:32–39).
Preserve supply and stock-exception flows, including reading paid sales for stock review.
Replace U/app.mjs:518's `/100`: parse decimal strings using BigInt arithmetic, exponent 0–6, money ≤9000000000000; convert to JSON numbers only after checking bounds.
Format exact recorded exponent; old unpaid receipts lacking exponent show minor units.
Check exponents 0/3/6, excess precision, overflow, changed catalogue prices and concurrent refunds.

**5. Bounded execution and proof.** Executor-owned product files: B/Cash/`InternalCash{Endpoints,Models,Service}.cs`; U/`{client,login,app}.mjs`, `index.html`.
Tests: new U/`cash.test.mjs`, T/`InternalCashReadTests.cs`, `tests/browser-cash-validation.mjs`; extend U/`{commerce,session-transition,failure-simulation,stock-exception}.test.mjs` and T/`InternalCashSqlTests.cs`; update only affected fixtures in `tests/browser-mock-validation.mjs`.
No migration, security-policy or supply-source change required.

Before UI edits, record actual baseline at 1440×1000 and 390×844.
Then run focused cash/read/session checks, existing staff regressions, and `python tests/check.py`.
Repeat recordings with identical viewports/actions; exercise keyboard focus/errors, double submit, reload and overflow.
Negative controls must fail when receipt validation, original-key retention or session generation guards are removed.
Later authorized browser→API→SQL proof must independently reconcile opening+sales−refunds, stock, actors, operation counts and immutable original close, including sale/close races.
T/InternalCashSqlTests.cs:19–133 supplies service-level oracles, not HTTP/UI proof.
Mocks prove only mocked behavior.

PLAN check→section: 1→1–2; 2→1,4; 3→1–2; 4–5→3; 6→4; 7→1–2; 8→1–2; 9→4; 10–11→5.
Runtime acceptance remains pending.
NOT RUN: builds/tests/browser/SQL/Docker/services/installations/accounts/Git mutations/publication/deployment.
No essential access blocker remains.
Next: primary adjudicates these contracts and freezes the bounded Sol/high packet.
Advisory review does not complete SAVIA; production remains NO-GO.

**Source bindings.** SHA256 of inspected bytes with CRLF normalized to LF.


| Inspected path | Lines | LF SHA256 |
| --- | ---: | --- |
| B/Cash/InternalCashEndpoints.cs | 1–31 | `d726f8e2817f302c99593b50f5c4a89eef9a47f89163531eb9416e584fb024b2` |
| B/Cash/InternalCashModels.cs | 1–85 | `0333a4f73104201182b58e9d48c03bc9b8f314a521c0c23280f5f1aedac75789` |
| B/Cash/InternalCashModel.cs | 1–42 | `9019756fb25b9497e69b98af8b2d8d29539ae5b6da9ce187ed0edf38f4e4ae35` |
| B/Cash/InternalCashService.cs | 1–116 | `5475c19c85591d47f990ed6402d4fbe4c8c7ea9c42d946cd6eefdd9c267146de` |
| U/client.mjs | 1–155 | `fa45879476a512d7fcaf9ecf375b412268869d45be31fec62f120fef1ef9e4da` |
| U/app.mjs | 1–679 | `c1c01336b60f9533c1aa92fd0a98fdef7a1a7745ac4df15ef2488fc162482264` |

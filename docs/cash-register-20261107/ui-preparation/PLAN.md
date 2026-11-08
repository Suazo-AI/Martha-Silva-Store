# Cash register UI: bounded preparation

Mode: VALIDATE. Owner: primary. Independent reviewer: Codex `gpt-6-astra/xhigh`.
Status: prepared for fresh source-only review. No UI implementation or runtime acceptance implied.

## Outcome

Freeze the smallest complete staff workflow for opening a shift, receiving full cash payment,
showing change, authorized quantity-based refunds and counted close.
Use the existing staff interface and its accessible patterns. No storefront redesign.
Credit, cards, mixed tender, real currency selection and operational acceptance stay separate.

## Direct evidence and remaining seam

The backend has four POST endpoints in `Internal/Cash/InternalCashEndpoints.cs`:
open till, cash sale, refund and close. Real local business SQL passed 39/39 on
`f9ffa452bae7fc11a4a578ce24b57ecb72add139`, including eight cash SQL cases.
This evidence does not exercise a staff cash interface.
The current staff client still calls the legacy commerce sale route.
That mismatch must be resolved before a usable cash trial can be claimed.

The reviewer must determine whether existing authorized read/recovery endpoints suffice
for active tills, balances, immutable closes and refunds after a new shift.
If a minimal server read contract is missing, specify it with server-side actor/location
authorization. Client storage must not become the authority for money or permissions.
Do not implement that contract during this review.

## Frozen acceptance checks

1. Preserve the approved D-031 through D-034 and CASH-01 through CASH-08 contracts.
2. Server supplies authoritative currency/exponent and monetary results. No guessed currency or two-decimal assumption.
3. One cashier/shift till; preserve isolation from another cashier and location.
4. Opening, sale, refund and close each retain their original operation key and body through uncertain responses and reload.
5. Distinguish a definitive rejection from an uncertain outcome. Invalid input and rejected requests must not wedge the form.
6. Renew session protection without deleting references to pending operations. Old replies must not reveal or change another session's state.
7. Refund requires current Owner/Manager permission, original sale, quantities, reason and open paying till. Preserve the prior shift's close.
8. Display server-confirmed total, received amount, change, expected cash, counted cash and difference. No simulated success labels.
9. Preserve stock-exception, supply and legacy pending-sale recovery flows. Do not silently reissue old unpaid sales as new cash sales.
10. Require focused contract tests, meaningful negative controls, desktop/mobile keyboard behavior and actual before/after recordings.
11. Mocked HTTP browser proof remains separate from the later authorized real browser/API/SQL journey and independent persisted-row reconciliation.

## Review scope and continuation

Read actual cash service/models/endpoints, generic operation recovery, relevant security and
staff UI sources on the frozen dispatch SHA. Use the prior cash preimplementation review as
an existing contract, not as proof of the current implementation.
Return concrete failure cases, minimum read/recovery seams, exact worker-owned files and
verification checks. Report missing access. Do not add new product policy.

One new review session, at most 20 minutes and 1,200 report words. No builds, tests, browser,
SQL, Docker, installations, accounts, Git mutations or publication. Write only the assigned report.
Primary adjudicates findings and serially freezes an implementation packet for the approved executor.
The security SQL worker keeps ownership of its existing isolated runtime. Do not poll or replace it.
Production remains **NO-GO**.

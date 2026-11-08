# Cash register UI: bounded preparation

Mode: VALIDATE. Owner: primary. Independent reviewer: Codex `gpt-6-astra/xhigh`.
Status: source-only review adjudicated; bounded implementation contract frozen. No UI implementation or runtime acceptance implied.

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

## Primary adjudication and implementation scope

Primary read [Astra's source-only report](astra-contract-review.md), verified its SHA256 and all six source bindings.
Its REVISE verdict correctly identifies missing implementation seams. It does not identify a new business decision.
Primary adopts sections 1–4 as the additive technical contract, subject to the eleven acceptance checks above.

Implement the two authoritative GETs, the four cash operations in the staff UI, strict receipt validation,
integer monetary parsing, and durable uncertainty/recovery handling. Follow the report's exact DTOs,
authorization, paging, current-session checks and legacy/supply/stock preservation requirements.
Preserve D-031–D-034 and existing write semantics. Do not infer currency, create accounts or apply migrations.

Executor: temporary approved Codex gpt-6.1-sol/high, in one managed worktree. Sole independent judge: Astra/xhigh.
Owned product paths: `backend/src/Martha.Store.Api/Internal/Cash/` service/read DTO/endpoints only;
`dev/savia-staff-ui/{client,login,app}.mjs`, `index.html`, and one dedicated `cash.mjs` module if useful.
No entity, migration, unrelated security-policy or supply-source changes.
Owned tests: new cash read/client/browser tests and the affected staff/browser fixtures listed in the report.
Changes to existing `InternalCashSqlTests.cs` may prepare tests, but must not execute SQL.

The SQL security correction owns `InternalBranchScopeSqlTests.cs`, `InternalCashSchemaOracle.cs`,
`InternalCashSchemaOracleTests.cs` and `backend/tests/fixtures/cash-checks.sqlserver2022.json`.
Do not edit them. Do not edit canonical ledger/status/decisions, workflow definitions or another agent's evidence.
Only the primary integrates and publishes.

Use the existing staff visual system. Record the genuine before state at 1440x1000 and 390x844 before UI edits.
Repeat the same focused sequence after implementation, including opening, cash/change, refund, close, keyboard errors and reload.
Use local recording with existing tooling; no generation credits or new product design.
Require source-bound offline/read/receipt/session checks, staff regressions and meaningful negative controls.
Mocked Chrome results cannot close the later real browser/API/SQL gate.

No SQL, Docker, services, accounts, certificate changes, push, merge or deployment in this implementation scope.
Return a candidate with precise remaining blockers; primary and a fresh Astra/xhigh review retain acceptance.

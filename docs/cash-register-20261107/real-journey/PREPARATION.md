# Real cash journey: preparation, not execution

State: **candidate integrated and qualified offline; Astra review pending; SQL runtime NOT authorized**.
The worker prepared the harness from accepted cash UI source `54e76663cef0a43029dc87b7ecc27dcf9e8ec180`.
Primary qualification is recorded in [PRIMARY-QUALIFICATION.json](PRIMARY-QUALIFICATION.json).
The final SQL helper compiles, all 81 harness checks pass, and the repository check exits 0.
These results do not prove a real cash transaction or change CASH-01–08.

## Historical gap at preparation start

At `39161ef8c5afcac1f7c9502cc5f38439608a8d70`, the browser driver posted to `/internal/api/commerce/sales`, validated
`paymentStatus === 'not_processed'`, and permits no `/internal/api/cash/*` requests.
Its served-resource map also omitted `cash.mjs`.
Source: `tests/golden-path/browser_path.mjs`, inspected at that revision.
The new candidate adds cash requests, resources, checkpoints and independent row checks.
The real journey remains NOT RUN. Running SQL5 alone would not close this gap.

## Required artifact

Adapt the existing golden-path harness. Do not create a second runner or modify product behavior.
Retain real Chrome -> real API -> disposable SQL, source-bound modules, restrictive network admission,
private credentials, owned-process cleanup, database ownership checks, and fail-closed evidence.
Keep historical evidence unchanged. Explicitly version the new cash checkpoints and oracles.

| Check | Required result | Independent evidence to prepare |
| --- | --- | --- |
| REAL-CASH-01 | Cashier opens one till, sells multiple articles, receives cash and sees change. | Persisted till, cashier, shift, sale lines, payment and stock effects; integer amounts and exact identities. |
| REAL-CASH-02 | A committed sale loses its response and recovers with the same key/body. | One sale, one payment effect and correct stock; original receipt recovered without another POST. |
| REAL-CASH-03 | Cashier cannot authorize a refund. Manager or Owner can refund original quantities. | Refusal has no business writes; successful refund records original sale, reason, authorizer and paying till. |
| REAL-CASH-04 | Close records counted cash, expected cash and the actual difference. | Independent sum of immutable cash entries; preserve a deliberate shortage rather than force zero. |
| REAL-CASH-05 | A later refund uses the currently open paying till. | Earlier close unchanged; refund affects only the paying shift. A second cashier's till remains unchanged. |
| REAL-CASH-06 | Existing supply and stock-exception journeys remain valid with cash-first sales. | Existing identity, stock, review and supply invariants remain checked. No fabricated inventory or silent reduction of coverage. |
| REAL-CASH-07 | The evidence verifier rejects incomplete or inconsistent cash proof. | Offline negative controls for missing checkpoints, mismatched identities, duplicate effects and arithmetic errors. |

The UI review accepts uncertain original-key recovery and discloses that an already confirmed cash
receipt does not automatically redisplay after another reload. Do not invent that requirement.
Preserve assertions for uncertain recovery, original identity, no replay and legacy restoration.

## Execution boundary

Only source edits, offline harness checks, syntax checks and a cached SDK build are in scope now.
No SQL connection, container, service, browser/API launch, account operation, certificate change,
install, workflow dispatch, merge or deploy is authorized by this preparation.
SQL5 remains **D: REVIEW FIRST, DO NOT EXECUTE**.
The real cash campaign needs its own reviewed source, runtime scope, limits and cleanup contract.

Owner: bounded Sol/high executor in a T3-managed worktree; primary owns serial integration.
Independent acceptance: Astra/xhigh after preparation, one judge at a time.
Completion of preparation requires source-bound offline evidence and an explicit NOT RUN runtime statement.
Production remains **NO-GO**.

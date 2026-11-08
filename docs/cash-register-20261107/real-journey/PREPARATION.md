# Real cash journey: preparation, not execution

State: **F1-F3 corrected; primary offline checks pass; fresh Astra review and corrected-SHA CI pending; SQL runtime NOT authorized**.
The worker prepared the harness from accepted cash UI source `54e76663cef0a43029dc87b7ecc27dcf9e8ec180`.
Primary qualification is recorded in [PRIMARY-QUALIFICATION.json](PRIMARY-QUALIFICATION.json).
The historical final SQL helper compiles. The corrected harness now passes 102 focused checks and the primary repository check, exit 0.
[Correction provenance, exact commands, hashes and CI wiring](corrections/PRIMARY.json).
These results do not prove a real cash transaction or change CASH-01–08.
Astra found F1/F2 evidence-publication bypasses and F3 insufficient returned-row preservation.
[Primary adjudication, correction owner and completion checks](REVIEW-STATUS.json).
[Verified CI on 990e23a](CI-VERIFICATION.json): backend 700 passed, 82 skipped; staff 223/223; mocked browser cash 2/2, existing 50/50, supply 8/8.
Preparation remains unaccepted until the listed counterexamples fail and corrected source passes independent re-review.

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


## Next local runtime proposal: held, not an execution instruction

Read-only preflight found Docker's Linux engine ready and the SQL Server and SDK images cached.
No container was started. No SQL or account was accessed.
The existing journey requires Linux PTY and /proc, Python, Node 24, Google Chrome,
Playwright 1.63.0, OpenSSL and SDK 10.0.402. Native Windows is not a supported host for this harness.
The cached SDK image does not establish those browser prerequisites.
Qualify one existing Linux environment or prepare an exact dependency/image proposal before requesting runtime authority.
No image build, pull, download, installation or host security change is covered by this preparation.

After F1–F3 acceptance, freeze the corrected Git SHA and source hashes.
The proposed existing harness uses browser mode with cash, supply and stock-exception flags.
It requires 31 ordered checkpoints, independent persisted-row checks, private credentials and captured-resource cleanup.
Its final evidence must pass the corrected publication verifier.
Before execution, specify total/container deadlines, ownership, loopback ports, allowed databases,
cleanup after failure and the terminal API/container absence checks in the runtime request.
The old SQL5 plan is frozen at 550b104; changed Owner and harness inputs require an explicit equivalence check or revised source-bound plan.
Do not treat its legacy recovery fixtures as populated Cash backup/restore proof.
Actual Owner recovery and Windows ACL/SID validation remain separate checks.
SQL5 is still **D: REVIEW FIRST, DO NOT EXECUTE**.

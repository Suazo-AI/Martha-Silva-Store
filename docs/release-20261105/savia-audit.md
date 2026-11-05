# SAVIA release audit ? RETURNED, NOT ACCEPTED

Verdict: the complete synthetic retail day is not demonstrated at this candidate.
The strongest working slice is multiarticle sale ? uncertain response ? original-operation recovery ? stock readback.
Reception exists in the backend. Payments, fiscal documents, exception review and business close remain separate gaps.
This audit changed no product code and ran no application, browser or SQL test.

## Identity and boundary

- Task: RELEASE-SAVIA-SOL-20261105. Mode: DISCOVER. Owner: Sol/high SAVIA audit worker.
- Host: SUAZO-PC. Harness: T3 Code / Codex. Runtime-reported model: gpt-6.1-sol; reasoning: high.
- Requested: Codex / gpt-6.1-sol / reasoningEffort high. Effective: runtime reports the same; independent provider telemetry is unavailable.
- Worktree: C:/Users/Jason/.t3/worktrees/github/t3-7dae3d3b. Branch: t3/7dae3d3b.
- HEAD/source: dfc7e65af477bdfc625f174d71bd2f23a99c400f. This is not C:/Users/Jason/MARTHA-SILVA/github.
- Initial Git status was clean. Only savia-audit.md and savia-baseline.json are owned writes.
- No nested agents, commits, stage, push, PR, ref mutation, installs, paid calls, account actions or external messages.
- No SQL, Docker, certificate/trust/service metadata inspection, runtime account access, bootstrap, deployment or customer data.
- Raw-input SHA256 manifest and commands are in savia-baseline.json. It hashes the actual worktree bytes against this source SHA.

## Evidence classification

Observed means source/assertions read in this audit. Inferred means a conclusion from that bounded source inspection.
Historical means an existing execution artifact, not a rerun or acceptance at this SHA.
NOT RUN means this audit did not execute that path. No new independent critic/judge review occurred here.
Opus5.5/high is quota-blocked per the assignment; Astra/high must review new scope independently later.

## One synthetic retail day

The following is a proposed acceptance script, not a claimed execution or Martha business policy.
Use the guided fictitious blusa/pantalon example, with independently identified item/location IDs and server prices.
Receive balances 5 and 2, then sell one of each: expected balances 4 and 1, one sale and two sale debits.
Keep the stock-zero branch separate from those normal balances. Never invent +1/-1 to pass that branch.

| Step | Implemented entry point and observed source | Evidence layer and acceptance gap |
| --- | --- | --- |
| Receive stock | POST /internal/api/supply/purchase-orders; POST /purchase-orders/{id}/receipts; InternalSupplyEndpoints.cs:27-32. Manager/Owner create; Inventory/Manager/Owner receive, with CSRF. InternalSupplyService.cs:86-163 checks remaining quantities, receipt identity, stock movement and order status. | API-only in staff product. browser-mock-validation.mjs:287 asserts purchasing remains unavailable. InternalSupplySqlServerTests.cs:17-46 asserts two-line partial reception, exact replay, one receipt, two movements and remainder completion. Test body observed; SQL execution NOT RUN. |
| Multiarticle sale | app.mjs:576-585 freezes lines/key/version; client.mjs:57 and 71-76 validate the body. InternalCommerceService.cs:32-69 prices from items, records lines and debits ledger. | UI+API implemented. InternalCommerceCommandSqlTests.cs:13-32 asserts server-priced total, immutable replay and one sale. Historical multiarticle README.md:20-22 reports 47/47 mocked Chrome, 601/601 backend and 21/21 browser?API?SQL at 922852cbf6c9af2eacb2e5c02a42d912c14f6893. Not this audit or new-scope acceptance. |
| Response loss/recovery | client.mjs:58-64 GET /internal/api/operations/commerce.sale.record with original key; app.mjs:521-542 preserves pending on uncertainty and clears it only for confirmed success/rejection. | Browser mock: browser-mock-validation.mjs:167-168 asserts one sale POST and matching recovery key; :276-279 protects pending sale. SQL durable evidence is historical. No fresh crash, persistence or SQL oracle here. |
| Record/verify payment and document | InternalCommerceService.cs:202-206 emits not_processed. client.mjs:81 rejects other payment statuses; app.mjs:495-501 shows an internal receipt and no bank charge. | Internal receipt exists. No payment-recording/verification or fiscal-document workflow was identified in the inspected internal endpoints/model configuration. This bounded inference is not a claim about public-store modules. A receipt is not settlement or fiscal acceptance. Martha/merchant/accountant rules remain missing. |
| Stock-zero exception/review | InternalStockLedger.cs:34-41 rejects negative/over-reserved stock. Existing adjustment endpoint is not an exception-review workflow. D-026/D-027 select cashier exception, another reviewer at close, substitute and open unsupported causes. | Selected policy, not implemented or exercised. Preserve current stock guard and cashier adjustment denial. Need durable linked exception, review actor/substitute, evidence, open cause and next review; no unapproved stock bypass. |
| Reconciliation/close | Commerce GET sales, movements and inventory: InternalCommerceEndpoints.cs:11-18. InternalDbContext.cs:10 configures Security/Directory/Commerce/Supply. | These reads can support stock audit; they are not a cash/transfer/card close. No dedicated close/payment reconciliation workflow identified in inspected internal source. GUION-RECONSTRUCCION-MARTHA.md:151-171 asks for opening float, withdrawals, tender balances and unresolved differences. Business facts missing; close NOT RUN. |
| Backup/restore | PrivatePilotReleaseTests.cs:107-142 contains migration and real backup/restore assertions; :134-142 compares four fixture facts and schema after restore. | Existing body is not a restored retail day with sale/operation/payment/exception oracles. C9 remains 0/5; no SUAZO-PC restore, timings or RPO measured here. Never run historical one-shot scripts from this audit. |
| Owner recovery | InternalSecurityService.cs:120-135 resets staff password only through a current Owner; :98-100 protects last enabled Owner. InternalOwnerConsole.cs:124 refuses bootstrap once staff exists. | Owner-authorized reset exists. InternalSecuritySqlTests.cs:115-127 and :167-177 assert last-Owner denial/reset/session effects. Those do not recover the lost last Owner. C9 last-Owner recovery procedure and runtime proof remain missing. |

Source abbreviations above resolve to the explicit paths in the JSON manifest.
The guided example is GUION-RECONSTRUCCION-MARTHA.md:45-55 and :128-149; it is not merchant data or a tax rule.

## N5-COV: actual assertions, not titles

| Extra | Browser harness at source SHA | Newer jsdom evidence | Precise remaining gap |
| --- | --- | --- | --- |
| Submit while recovery held | :167-168 checks submit disabled before clicking recovery; :276-279 waits for completed recovery and checks zero POSTs. Neither retains the operation GET while submitting. | failure-simulation.test.mjs:74-81 holds recovery, dispatches submit, clicks retry, asserts pending unchanged/zero POST, releases recovery and checks original key. | Covered by jsdom assertions; not by the required browser harness. Need held browser operation GET plus native disabled control and synthetic submit assertions before release. |
| Complete sale after stale discard | :257-262 observes enabled submit after 404. :266-269 clears receipt after 403 and asserts zero sales. Neither submits a complete fresh sale afterward. | :84-88 discards missing receipt, fills multiarticle body, posts once and confirms reference. | Need real-browser full cart, exactly one new key/body/POST, valid receipt, stale reference absent and refreshed stock. |
| Late404 race | :257-285 returns errors immediately. :221-255 delays CSRF/stock/logout, not receipt404. | :91-99 holds old receipt lookup; same-generation submit is blocked; clear/start plus explicit storage deletion permits new pending sale; old404 cannot erase it. | Constructed generation invariant is covered in jsdom. No held browser404 or user-reachable generation transition shown. Same-generation sale is prevented by busy in app.mjs:546-574; do not fabricate it. |

Historical PRIMARY-RESULT.json records focused 50/50 and staff 102/102, exit 0; no fresh tests ran here.
The 102 count includes nested tests/containers, not 102 distinct business-day scenarios.
Historical PRIMARY-RESULT hash comparison: dev/savia-staff-ui/failure-simulation.test.mjs differs from current raw bytes. Other compared inputs match. No historical result is attributed to this SHA.
N5-COV ledger.json:324-338 explicitly requires browser tests with red/green or a reasoned written dismissal for each gap.
Finding: no demonstrated product defect. Do not implement a product fix based solely on missing browser assertions.

Smallest follow-up: one bounded tests/browser-mock-validation.mjs task for these three cases, with no backend/security changes.
First execute added scenarios on unchanged product. If all pass, record explicit no-defect finding and exact assertions/hashes.
If a defect reproduces, capture red, make the smallest separately authorized fix, then green; never weaken expectations to obtain green.
For the late404 generation invariant, use a reachable logout/clear/re-auth transition, or document why browser automation cannot reach the constructed state.
Retain :276-285 pending-sale and 401 controls, :177-219 actor/scope controls, and :221-255 late-response invalidation.
Compare original pending bytes/key/body before release and after denial; no second POST or new success after invalidation.
Do not change SEC-CSRF binding while adding coverage; its decision is still open at ledger.json:341-353.

## Blockers and concrete handoff

| Blocker / evidence | Cause or hypothesis | Correction attempted / result | Next action / owner / completion check |
| --- | --- | --- | --- |
| C9 TLS; PREFLIGHT-RESULT.md:18-26,73-84 | Observed chain trust rejection; effective certificate/issuer/missing element unknown. | No runtime correction attempted because fresh scope is required. Historical 1 Open, 0 successful sessions, 0 statements, 0 mutations; closed/disposed, no retry. | Primary prepares bounded investigation; Jason/SQL admin authorizes it and any correction/new connection separately. Check validated certificate/target/session encryption and classified allowlisted metadata before designing restore. Keep Encrypt=True;TrustServerCertificate=False. |
| C9 recovery; ledger.json:249-262 | Missing Windows coordinator run, sales/operation restore oracles, RTO/RPO and last-Owner procedure. | None; SQL/restore/Owner actions prohibited in this audit. Existing fixture restore cannot close gap. | Primary/Denis designs separate synthetic G0-G9 run after TLS authority; Jason approves targets/actions. Check restored sales, lines, movements, operation replay, no duplicate debit, measured RTO/RPO and retained Owner access. |
| C2 business facts; GUION:198-209; D-029 | Guided walkthrough chosen, not performed. Payment/tax/document/discount/close details remain unconfirmed. | None; messaging and merchant data access not authorized. Script already prepared; no new interview required to be invented. | Jason schedules and conducts Martha walkthrough; accountant/merchant clarify their fields. Check sanitized declared vs observed facts, responsible roles and unresolved questions before freezing implementation criteria. |
| Payments/document and close; CommerceService.cs:202-206; GUION:118-123,151-171 | Internal receipt has no banking payment, fiscal issuance or tender close. Exact required behavior depends on C2. | No code change permitted. No provider or settlement test attempted. | Primary maps confirmed facts to minimal ledger/document/close tasks; Jason chooses provider, authority and hosting as needed. Check linked amounts, states, documents, balance differences, retry uniqueness; provider SUCCESS alone cannot prove cleared funds. |
| D-026/D-027 exception review; DECISIONS.md:136-180 | Policy selected but durable review flow absent; stock guard deliberately rejects shortage. | None; product modifications prohibited. No free cashier adjustment or guard relaxation. | Primary specifies atomic sale/exception design with scoped permissions; executor implements after approval of precise stock mechanism. Check recorded actor/location/line, distinct close reviewer/substitute, open cause, next review and zero untraceable balance changes. |
| N5-COV browser; browser harness:257-285 | Three jsdom cases do not satisfy browser-specific ledger contract. No reproduced defect. | Read assertions; no tests written/run in read-only audit. | Bounded executor adds/executes three browser cases as above; primary/Astra reviews new scope. Check exact claims and controls, red/green only for reproduced defect or explicit no-defect explanation. |
| C10/C12 and release host; ledger.json:267-320 | Selected acceptor/host do not equal an executed trial, production host or final release authority. | No runtime/hosting/merge/deploy attempted; prohibited. | SUAZO-PC coordinator accepts D-022/D-025 trial after dependencies; Jason owns hosting/integration/deploy decisions. Check five unaided tasks, 30 synthetic timings with p95 ?1s, physical count and per-flow verdict at exact candidate. |
| SEC-CSRF; ledger.json:341-353 | Same-user relogin token binding is an open decision; old-cookie rejection is separate. | No session-binding correction; no security authority in this task. | Jason decides user/session token semantics; primary scopes tests only afterward. Check recorded decision and, if changed, focused HTTP+SQL red/green with session revocation preserved. |

## Realistic three-hour cut

Under this worker's present scope, only this source map, hashes, bounded verification and executable handoff can be completed.
The following is a proposed next local batch; it requires explicit writer/test scope and must not silently inherit runtime permission.

| Budget | Small useful deliverable | Completion check / dependency |
| --- | --- | --- |
| 0-75 minutes | Add three N5 browser scenarios to existing harness; use existing installed dependencies only. | Unchanged-product no-defect or reproduced red/green; exact source hashes and request/storage assertions. Stop if dependency is missing; no install or new service authority implied. |
| 75-120 minutes | Specify stock exception acceptance against chosen D-026/D-027; map minimal receive UI to existing Supply API. | Explicit actor permissions, stock invariants, receipt identity and open-case states; no claim of implemented business day. |
| 120-150 minutes | Populate process?requirement?test gaps from sanitized Martha answers if Jason supplies them. | Without answers, keep tax/payment/close cells pending; do not guess or create a payment provider integration. |
| 150-180 minutes | Primary reads artifacts and exact hashes; independent Astra/high review of new scope when available/authorized. | Returned vs accepted decision and next executable packet. Do not claim quota-blocked Opus review occurred. |

Three hours cannot honestly promise C9, completed merchant onboarding, hosting, fiscal correctness, a production day or C10 acceptance.
People/permissions critical path: Jason/Martha/accountant facts ? approved exception/payment/close scope; Jason/SQL admin TLS scope ? restore evidence; coordinator trial ? Jason release commitment.
Recommend closing browser evidence and obtaining the existing guided walkthrough in parallel administratively; avoid new infrastructure.

## Verification and limits

Discovery used Git, rg, bounded source reads and agent-awareness only. All completed discovery calls exited 0 except one encoding failure.
A bounded source read hit UnicodeEncodeError under cp1252; the next read set PYTHONIOENCODING=utf-8 and exited 0. No product/runtime defect inferred.
Two bounded verification commands were used. First verified source/HEAD binding, then failed historical hash equality; second classified the mismatch and checked final ownership/limits. Receipts are in the JSON.
No package/test installs, broad check.py, browser, SQL, certificates, services, payment provider, runtime or CI checks were executed.
No new scope is accepted by this worker. Primary must integrate serially into Tony and verify its candidate independently.
Lesson: newer jsdom assertions can close a DOM hypothesis while leaving a browser-specific acceptance criterion open.

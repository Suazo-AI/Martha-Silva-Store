# SAVIA and website: evidence-led release plan

2026-11-05. SUAZO-PC. Mode: DISCOVER. **NO-GO for production; plan accepted for bounded use with limits.**
Primary accepted the source-audit/plan package after Astra's ACCEPT WITH LIMITS and the two corrections below. Opus critic remains pending.
Audited base: Tony `dfc7e65af477bdfc625f174d71bd2f23a99c400f`.
This plan grants no new runtime, security, integration or deployment permission.

## The shortest path

Demonstrate one complete business day with independent expected results for money, inventory and recovery.
Collect Martha's operational facts using the already selected D-029 walkthrough.
Close demonstrated gaps, exercise supported conditions, and make an evidence-based release decision.
Do not expand scope to every feature visible in the SISFAIN promotional video.

SAVIA and the public website have separate release gates, linked by approved business facts.
Neither currently meets its production gate. A catalog-only launch changes the existing card-payment requirement and needs Jason's decision.
Three hours can produce a smaller, reviewable candidate and precise go/no-go evidence.
Production within three hours cannot be promised while human, recovery, merchant and hosting prerequisites remain unresolved.

## Professional method and independent proof

| Question | Concrete answer |
| --- | --- |
| What a professional adds | Freeze scope, supported conditions, safe failure behavior, independent expected results, rollback and accepting owners before assigning fixes. |
| Raw material | Exact current source; actual HTTP/resource traces; representative-device observations; synthetic durable transactions; restore outputs; Martha's observed workflow and approved facts. |
| Methods/tools | Process walkthrough; requirement-to-test mapping; dependency/critical-path analysis; risk-ranked failure injection; race-condition checks; browser/network traces; Lighthouse lab measurements; accessibility tools plus manual checks; existing Node/backend suites; separately authorized restore drill. |
| Independent proof | Persisted results match stock/money equations; an unaided operator completes tasks; an isolated restore matches transaction oracles; exact-candidate CI passes; supported hardware completes flows; owners and qualified reviewers confirm business/legal/fiscal applicability. |

Critic/judge opinions challenge the evidence. They do not replace operational acceptance or legal/fiscal confirmation.
See [the rewritten prompt](PROMPT.md).

## Evidence available now

| Area | Direct evidence | Limit |
| --- | --- | --- |
| Website snapshot | 1,082 files, 472,334,693 bytes. Largest file: 2,694,766 bytes. Index/catalog/one product HTML gzip: 12,580 / 9,790 / 13,737 bytes. | Disk size and HTML compression are not actual transferred resources, speed or device memory measurements. |
| Indexing | Three sampled HTML sources contain noindex and no JSON-LD. No static robots.txt/sitemap.xml at checked paths. | Preview noindex is deliberate. Do not index sample prices/stock. Production metadata requires real domain and approved facts. |
| Commerce | `src/app.js` describes a browser-local demo and formats USD. Help describes simulated refunds and unconfirmed contact. | Browser-local orders, stock, refunds and newsletter behavior are not production commerce. |
| SAVIA | Historical multiarticle proof: backend 601/601, Chrome mocks 47/47, Chrome→API→SQL 21/21. Failure simulations: 50/50 focused, 102/102 staff. | Dated, bounded evidence. jsdom does not prove browser, durable storage or production behavior. |
| Receiving/payment | Purchase receipt endpoints exist in `InternalSupplyEndpoints.cs`; staff client requires `paymentStatus: 'not_processed'`. | API presence does not demonstrate staff receiving. Payment/document completeness remains unproven. |
| C9 | 0/5; consumed preflight: 1 Open, 0 sessions, 0 queries, 0 mutations; untrusted TLS chain. | Effective certificate/chain cause unknown. No new probe, certificate inspection or retry authorized. |
| Decisions | D-022 coordinator and D-025 synthetic SUAZO-PC trial selected. D-026/027 exception review policy and D-029 guided walkthrough selected. | Trial, exception mechanism and walkthrough evidence remain missing. Do not reopen these choices. |
| Git/CI | PR #2 historically passed seven required checks at `8744a9699812d62ea5ed31c63781748f833c3def`. Tony has later work. | Prior CI does not cover later Tony work. No merge or deployment is authorized. |

Raw input hashes and collection limits are recorded in [BASELINE.json](BASELINE.json), [website audit](website-audit.md) and [SAVIA audit](savia-audit.md).
Both workers completed in separate T3-managed worktrees at the audited base, with high reasoning reported by the runtime.
Primary verified all 13 website input hashes and all 31 SAVIA inputs against the base, accounting for CRLF/LF checkout differences.
The SAVIA worker's historical test-hash warning is resolved: canonical raw bytes match the historical hash; only worktree line endings differ.
This resolves source identity, not fresh execution. See [primary review](primary-review.md) for dispositions and remaining review gates.
The interrupted GATE is historical and superseded. Its proposed CSRF change, merge sequence and catalog launch are not authorization.

## Worker allocation

Maximum concurrent agents: primary plus two workers. Every assigned worker/reviewer uses high reasoning.
Each execution worker checks its T3-managed worktree, exact source SHA and effective settings.
Workers do not stage, commit, push, merge or deploy. Primary integrates reviewed explicit paths serially.

| Stage | Owner/model | Exclusive scope | Acceptance/dependency |
| --- | --- | --- | --- |
| A: website audit | Codex gpt-6.1-terra/high | `website-audit.md`, `website-baseline.json`, in its worktree's copy of this directory | Five prioritized findings, raw resource/asset evidence, source lines/hashes, proposed supported conditions and bounded follow-up task. |
| A: SAVIA audit | Codex gpt-6.1-sol/high | `savia-audit.md`, `savia-baseline.json`, in its worktree's copy of this directory | Full-day flow map; UI/API/mock/persistence distinctions; N5-COV assertions; blockers and smallest follow-ups. |
| A: integration/facts | Primary | PLAN, PROMPT, SOURCES, BASELINE, review/status evidence | Independently verify returned artifacts and preserve scope/decisions. |
| B: website measurement, conditional | Terra/high | Three actual routes; freeze traces/report paths before dispatch, with any correction paths separately bounded | Measure first. Correct only a demonstrated issue if time remains; otherwise return traces, no-defect or NOT RUN. Preserve originals and approved appearance. |
| B: recovery coverage, conditional | Sol/high | `tests/browser-mock-validation.mjs` plus bounded evidence folder | Three N5-COV cases exercise actual harness boundary or receive a precise disposition. Preserve duplicate-sale and session guards. |
| C: copy/search, conditional | One assigned writer | Exact shared HTML head/help/footer paths | Approved commercial facts first; preview noindex preserved; visible content matches structured data. Apply conversion-copy before shipping strings. |
| C: business flows, conditional | One worker per module | Receiving/exception/payment/document paths after C2 and frozen contract | Failing scenario first, minimal change, focused checks, real critical-flow proof. No invented fiscal rules. |
| Critic | Opus 5.5/high through Antigravity | Read-only new-scope review | Currently quota-blocked. Earlier verdicts do not cover this work. No silent provider/model substitution. |
| Judge | Codex gpt-6-astra/high | Independent candidate/evidence review | New task. Reject unsupported READY claims and unresolved material findings. |

Gemini 4 Argon/high research shares the failed Antigravity route and is not dispatched here.
GLM's approved name is GLM-5.3-Flash Free/high, not GLM3. GLM/DeepSeek execution qualification remains unproven.
Do not route private data there or add workers simply to fill provider slots.
Audit allowance: two tasks, 20 minutes each, one run each; no installs, paid fallback or recursive delegation.
Report token/currency cost only if exposed; otherwise mark unknown.

## Relative three-hour window

This is a work budget, not a guaranteed release deadline. T+0 begins when the selected scope and prerequisites are available.
Blocked tasks stop; they do not consume the window through repeated retries.

| Time | Primary/Jason/Martha | Worker lanes | Required result |
| --- | --- | --- | --- |
| 0–20 min | Freeze candidate/checks. Jason coordinates the existing Martha walkthrough as an asynchronous lane. | Independent Terra website and Sol SAVIA audits. | Actual gaps, supported conditions, facts and permissions explicit. |
| 20–70 min | Verify audits; select only demonstrated release blockers; freeze shared-path ownership. | Measure three routes; correct only a demonstrated issue if time remains. Three bounded recovery coverage cases. | Traces/no-defect or NOT RUN; minimal justified diffs and focused checks; no weakened guards. |
| 70–115 min | Serial integration into one candidate. | Actual page/critical-flow tests. SQL/restore only under separately approved exact scope. | Candidate-bound traces, durable oracles and before/after measurements. |
| 115–150 min | Review blockers, business facts and legal/fiscal gaps. | Critic when approved route works; Astra independent judgment. | Findings fixed/rechecked, or explicit NO-GO. |
| 150–180 min | Publish authorized Tony progress; verify remote SHA/applicable CI; prepare owner decision and rollback packet. | No late scope expansion. | Exact candidate, evidence matrix, accountable next actions. Deployment remains separately gated. |

Unresolved C2/C9/S-PAY/hosting means a prepared or partially verified candidate, not production acceptance.
The Martha walkthrough needs approximately 30 minutes plus her availability. It may extend past T+20; only dependent business-flow work waits for its facts.
No automatic fallback to catalog-only launch, relaxed TLS, simulated payments or a new acceptance owner.

## Proposed website acceptance envelope

These are proposed checks to freeze before implementation, not measured results or adopted business decisions.

| Condition | Check and evidence |
| --- | --- |
| Devices | Obtain actual equipment through C2. Test an available low-end Android phone, tablet and laptop; Chrome/Edge/Firefox and Safari/iOS where available. Record exact hardware, OS/browser versions and untested combinations. Label emulation. |
| Layout/input | 320/360/768/1366 CSS px, relevant orientations, keyboard and 200% zoom; critical controls remain usable. Relevant WCAG 2.2 AA criteria receive manual plus automated checks. |
| Mobile lab | Initial proposed profile: 1.6 Mbps down, 750 Kbps up, 150 ms latency, 4x CPU slowdown. Three cold/warm key-flow runs with traces/medians. Lab results are not field CWV. |
| Poor network | 400 Kbps down, 400 ms latency, 6x CPU; lost request/response, timeout and reconnect. Preserve honest state and safe recovery. Set timing budgets from measured baseline and business needs. Do not promise LCP 2.5 s in every condition. |
| Offline/storage failure | Never claim sale/payment success without authoritative confirmation. Preserve recovery identity where supported; show an explicit unavailable state. Check blocked storage, quota errors, expired/revoked sessions and reload. New service-worker caching needs cache/staleness/update/security design first. |
| No JavaScript | Inspect native catalog/product/contact access and define supported fallback. Do not assume full transaction operation without JS. |
| Performance | Separate HTML/CSS/JS/font/image bytes, requests and actual transfer per page. Proposed field objective: p75 LCP ≤2.5 s, INP ≤200 ms, CLS ≤0.1, mobile/desktop separately. Lighthouse TBT is not INP acceptance. |
| Payments | Eligible provider; sandbox approval/decline/timeout/duplicate-callback/signature tests; one durable order/payment outcome and reconciliation. Sandbox success is not production merchant activation. |
| Search/copy | Approved identity/contact/catalog/prices/availability/returns; production-only canonical/sitemap/indexability; truthful Product/Offer data. No fabricated reviews, facts, stock, ranking or AI-citation guarantee. |

## Business, legal and fiscal gate

Martha/Jason confirm business identity, image rights, products, prices/currency/tax treatment, contact, delivery, returns and operational rules.
Current MIFIC guidance describes national-currency displayed prices including tax and matching displayed/charged prices under Ley 842.
The USD sample display therefore needs production review. It is not a completed legal audit of the labeled demo.
Before real-data collection, document fields, purposes, processors/recipients, permissions, retention, rights requests and security controls.
Ley 787 was located through OAS, but its PDF body was unreadable in this retrieval; amendments and applicability remain unconfirmed.
Fiscal numbering, tax regime, authorization, cancellation and retention require current DGI/qualified local confirmation.
Do not label an internal receipt an authorized fiscal invoice or a `not_processed` record a completed payment.
No legal certification, regulator contact, merchant enrollment, real-data import or fiscal issuance occurred here.
Official sources and retrieval limits: [SOURCES](SOURCES.md).

## Blockers and shortest next actions

| Blocker/owner | Evidence/cause | Attempt/result | Next action/completion check |
| --- | --- | --- | --- |
| Worktrees/primary: RESOLVED | T3 root above Git; correction initially rejected because canonical path was already registered. | Jason authorized correction. Empty duplicate had zero threads/no custom configuration; its registration was removed. Root readback: `C:/Users/Jason/MARTHA-SILVA/github`. | Both workers completed in distinct managed worktrees at the exact base with high reasoning; imported artifacts and source bindings verified in BASELINE.json. |
| C2/Jason+Martha | D-029 chosen, walkthrough not performed; operational facts missing. | Existing script prepared; no messages sent or responses invented. | Jason coordinates and follows script. Close with owner-confirmed sanitized process→requirement→test→gap matrix. |
| Business flows/primary after C2 | Receiving API exists; staff payment `not_processed`; exception review policy lacks demonstrated workflow. | Audit only; no speculative changes. | Freeze one contract, reproduce missing path, delegate exact files. Close with operator result and durable money/stock/audit oracles. |
| C9/Jason+SQL administrator | Untrusted chain; consumed attempt; effective identity/chain unknown. | No runtime correction, retry, certificate inspection or trust relaxation. Existing bounded investigation scope prepared. | Approve that scope; use resulting facts to prepare correction/rollback and separately authorized connection/restore. Close with valid trust, restored oracles, measured RTO/RPO and Owner recovery. |
| C10/SUAZO-PC coordinator | Five unaided tasks, 30 synthetic sales, p95 submit→receipt ≤1 s and reconciled count unmeasured. | Owner/environment selected; no runtime started. | Execute after C1/C2/C9 prerequisites. Close with per-flow decision, exact mounting, timings, counts and limits. |
| S-PAY/Jason | Merchant eligibility/provider and sandbox integration open. | No enrollment/account change; card requirement preserved. | Supply merchant constraints and approve eligible route. Close with sandbox/reconciliation evidence; production activation needs separate authority. |
| P-HOST/Jason | Production host undecided; trial host is not production choice. | No cloud/security/account mutation. | Decide using C2/C10 needs, cost, owner and backups. Close with recorded decision and scoped setup/readback. |
| P-SEC/P-OPS/owner after hosting | TLS/accounts/secrets, scheduled backup, alert recipient and tested rollback unproven. | Existing controls retained; no production setup. | Prepare target-specific operations packet. Close with verified settings, restore/rollback drill, delivered alert and named owner. |
| SEC-CSRF/Jason | Same-user token survives re-login; session binding is an open decision. | No implementation or SQL regression. | Decide policy; if selected, authorize exact change. Close with recorded decision and adversarial checks. |
| Critic/primary+provider owner | Antigravity quota exhausted; Claude subscription route also rejected earlier. | No silent reroute or paid fallback; independent Codex work continues. | New-scope critic review when approved route is available; otherwise pending. Close with report and resolved material findings. |
| Release/primary+Jason | Tony differs from PR #2; old CI does not cover new candidate. | No merge, history rewrite or deployment. | Prepare integration diff/authority; exact-SHA required CI and operational acceptance. Close with remote readback, reviews and owner release approval. |

## Final decision

Each applicable check is PASS, FAIL, BLOCKED, NOT RUN or explicitly excluded with an approved reason.
Money, permissions, security and durable data need adversarial checks and recovery/rollback evidence.
Publish only reviewed public sources and sanitized evidence; exclude raw recordings, credentials, sessions, certificates, databases, private logs and authorizations.
Tony documentation publication is authorized. Merging PR #2 and deploying either unit are not.
The report names exact candidate/remote SHA, applicable CI, unresolved findings, human actions and untested conditions.

Lesson: correct and verify execution context before adding workers. Catalog availability and a dispatch request do not prove a child ran in the intended checkout.

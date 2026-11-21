# Update, secure, harden, optimize and deploy

2026-11-05. Host: SUAZO-PC. Base: `6d8d53c964ca07cf173e3683a7660624d955aa4c`, Tony.
Primary: T3 Code / Codex / gpt-6.1-sol, xhigh.

Jason requested update, deployment, security hardening and optimization in this turn.
This authorizes preparation and deployment of the reviewed candidate to the confirmed target.
It does not select a new production host, authorize charges, weaken TLS or replace the original Worker.
The storefront preview and internal SAVIA have separate runtime and acceptance boundaries.

## Frozen checks

1. Update the pinned deployment tool to a verified patched release, preserving an exact lockfile.
2. Audit all root dependencies and production dependencies separately. Record advisories, not an exploitation claim.
3. Exercise response hardening using the actual static-asset consumer. Preserve working storefront behavior and preview noindex.
4. Do not cache unversioned HTML or scripts as immutable. Preserve responsive images and fonts already accepted.
5. Run affected deployment, build and storefront checks. Record environmental failures separately from product defects.
6. Independently review the actual diff, publish explicit paths to Tony, and check CI for the exact commit.
7. Before deployment, identify the account, exact Worker, current deployment, candidate artifact and rollback.
8. After deployment, verify version, public bytes, headers, missing-path behavior and affected critical journeys.
9. Keep production NO-GO unless its existing business, recovery, hosting, payment and operational gates actually pass.

## Verified baseline and blockers

| Item | Evidence and cause | Correction / next action | Owner and completion check |
| --- | --- | --- | --- |
| Deployment tooling | Root npm audit: 3 affected dependency packages, including high-severity undici via miniflare / Wrangler 4.152.0. Production-only audit: 0. This is advisory matching, not a reproduced exploit. | Update exact Wrangler pin to 4.158.0, install without lifecycle scripts, audit and dry-run the packaging consumer. | Executor; patched installed dependency graph, audit exits and packaging result. |
| Preview access | The Denis Worker is outside the authenticated Jason account. cf deployment list returned API 10007 / 404. Browser inspection of the public Denis preview succeeded later. | Jason selected the current code and Denis imagery, with a single active preview in his account: new Worker martha-silva-preview, account 66ee81b7eafd0371097df646a80865bd. Both existing publications remain intact. | Primary verifies the account, target absence, reviewed artifact and rollback before deployment; exact version and public readback close this item. |
| Internal deployment | Existing ledger leaves P-HOST, C2, C9, C10, P-SEC, P-OPS and S-PAY unresolved. C9's consumed TLS preflight is not retried by this task. | Complete safe code hardening independently. Prepare exact host/recovery/business prerequisites; do not expose the staff API as a public demo. | Primary / Jason; existing ledger acceptance checks, not a green static build. |
| Session CSRF | SEC-CSRF records that a token may survive re-login by the same user. A stale session cookie already fails. | Evaluate session binding under the new hardening mandate; require a failing behavioral regression and current-session success. Do not silently mark the ledger item done. | Primary; regression evidence, independent review and integrated CI. |
| Windows full-suite check | Existing Windows symlink fixture fails with WinError 1314; prior exact-SHA Linux CI passed. | Preserve security controls and use existing Linux CI for the integrated SHA. No privilege change or repeated known-failing local full run. | Primary; exact-SHA CI readback. |

## Scope ownership

One bounded executor owns response hardening and deployment-tool updates in an isolated worktree.
A separate bounded executor will own Jason's frontend with Denis's images in another isolated worktree.
Primary owns this plan, integration, remote checks and eventual deployment.
No worker may stage, commit, push, deploy, mutate SQL, change credentials or create recursive workers.
Pre-existing untracked evidence, skills and unrelated files remain excluded.

## Current status

Both executors have returned. Hardening is a local candidate; the frontend return is partial.
The primary has not integrated or accepted either candidate. Publication and deployment remain pending.
Frontend completion requires the translation correction, fresh final-byte DOM/localization checks, and desktop/mobile demo-order acceptance.
The hardening return does not certify the combined frontend. Linux verification must cover the integrated candidate.

The live [preview comparison](PREVIEW-COMPARISON.md) replaces the earlier assumption about the two sites.
Selected after Jason's explicit correction: Jason's style, layout and frontend, with Denis's images only (D-030).
Implement that combination in the current project while preserving verified behavior and optimization.
Both current publications remain untouched. The new target has not been created or deployed.
The expected address is https://martha-silva-preview.jason-suazof.workers.dev; this remains a planned address until Cloudflare readback.

## SAVIA functional-trial review

Read-only review on SUAZO-PC, 2026-11-05. Local HEAD and GitHub Tony both resolve to
`6d8d53c964ca07cf173e3683a7660624d955aa4c`.
`python tools/delivery_status.py --check` returned exit 0: `Ledger: valid; 35 items.`
GitHub runs 42126015769, 42126015642 and 42126015686 completed successfully for that exact SHA.
The source-snapshot run covers publication integrity, reproducible build and historical portable regressions.
It is not a fresh execution of SAVIA's real Chrome/API/SQL acceptance suite.

The [existing real-browser/SQL evidence](../multiarticle-20261104/c6-oracles.md) already covers
login, inventory, multiarticle sale, receipt reload, lost-response recovery and logout.
Those are historical executions, not reruns in this review.
Since the [source audit](../release-20261105/savia-audit.md) at `dfc7e65af477bdfc625f174d71bd2f23a99c400f`,
the internal backend and staff UI product files are unchanged; only the staff README changed.
This supports reusing that source map while retaining the historical execution limits.

The highest-value next outcome is a complete synthetic store day in SAVIA, with every operation usable from its staff screens.
This can use declared fictional rules and data without waiting for Martha's interview.
It does not resolve C2 or establish production business/fiscal acceptance.

| Priority | Verified gap and cause | Next action and completion evidence | Owner / attempted correction |
| --- | --- | --- | --- |
| 1 | Directory writes, purchase receipts, stock adjustments, sale cancellation and returns have API entry points. The staff client does not expose their complete operator workflows; purchasing is explicitly unavailable. | Connect staff screens to existing APIs with existing roles, CSRF and replay protection. Prove each write and balance through real browser/API/SQL checks. | Primary scopes bounded executor work. Source inspection only; no product correction in this review. |
| 2 | Internal receipts emit `not_processed`. No operative staff workflow for tender recording, cash reconciliation, customer credit, proformas or business reports was verified. These go beyond adding a button. | Freeze synthetic money/document rules; implement authoritative records, linked reversals, closing and report totals. Keep provider settlement and fiscal validity separate. | Primary owns the trial specification. No payment/provider action or new business policy was attempted. |
| 3 | D-026/D-027 exception policy is selected, but durable exception/review behavior is absent. The stock guard still rejects shortage. | Design the linked sale/exception record and distinct reviewer flow. Test substitute review and unresolved causes without inventing stock or giving cashiers free adjustments. | Primary owns the mechanism and independent review. No guard was removed. |
| 4 | Standalone administrative simulations do not exercise SAVIA. A complete store-day trial has not been accepted. | Receive stock, sell, record tender, return/cancel, review an exception and close. Independently reconcile SQL balances, exercise restart/replay, then run the existing C10 five-task and 30-sale timing criteria. | Primary / SUAZO-PC coordinator. Existing sales evidence is reused; missing workflows prevent the complete trial. |
| 5 | C9 restore remains blocked by the consumed preflight's untrusted certificate chain. Owner recovery and operational restore evidence remain open. | Prepare a bounded trust investigation and a separately authorized synthetic restore. Verify restored records, replay uniqueness, measured recovery time/data loss and retained Owner access. | Primary prepares; Jason/SQL administrator authorizes the exact runtime scope. No SQL retry, certificate change or TLS weakening occurred. |
| 6 | Production hosting, secrets/accounts, backup alerts and go-live acceptance remain open. The public store also has separate authoritative-order and card-payment gaps. | Select the internal runtime, then verify access, alerts, backup and rollback. Exercise public order/payment sandbox flows separately where applicable. | Jason owns host/provider commitments; primary prepares exact technical actions. Preview publication cannot close these gates. |

The [SISFAIN reference](../sisfain-reference-20261105/README.md) is sampled promotional evidence.
It shows maintenance, receipts, POS, proforma controls, reports and customer balances; it does not prove their runtime behavior or Martha's installed version.
Proformas, customer credit and reports remain explicit comparison gaps, rather than silently claimed parity.
The independent offline administrative model remains model evidence only.
No suites, SQL, browser sessions, payments, merge or deployment were executed by this readiness review.

Lesson: a passing publication workflow and an accepted failure model do not complete missing operator workflows.
Prioritize a usable store day and independently reconciled records before adding general simulation coverage.

## Plain-English comparison

Private artifact: `C:/Users/Jason/MARTHA-SILVA/test-runs/hardening-20261105/comparison-plain-english.html`.
It uses the observed desktop screenshots to distinguish Jason's frontend from Denis's imagery.
It explains the selected images, account, current code and remaining release steps.
It does not certify production readiness or assert that the new preview is live.
HTML previews were inspected at 728px and 390px: both rendered, with no console messages or visible clipping.
The inline rendering adapts the same content to the host surface; the standalone file has its own white surface.
Lavish accepted the handback reply with exit 0. No feedback listener is claimed.
`git diff --check` passed for the current tracked documentation edits. These edits have not been published yet.

## Target and rollback preparation

Deploy only after the integrated candidate passes review and its exact-SHA CI.
Recheck account 66ee81b7eafd0371097df646a80865bd and Worker martha-silva-preview immediately before deployment.
Capture the first deployed version and public address. Preserve the existing Jason demo and Denis preview.
If first-deployment verification fails, stop promotion and disable only the newly created preview under the approved rollback scope.
Future updates must record a known-good version before deployment and verify rollback readback if used.

## Lesson applied

An authenticated Cloudflare account does not prove access to the project's configured Worker.
Verify the exact target and current version before using deploy, which can otherwise create a same-named Worker in the wrong account.
Selecting one site's images does not select that site's layout. Record frontend, imagery and hosting as separate choices.
Jason corrected the primary's mistaken visual interpretation before any frontend integration or deployment.

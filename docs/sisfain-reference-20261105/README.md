# SISFAIN reference and SAVIA readiness

2026-11-05 UTC. Host: SUAZO-PC. Source checkout: Tony at `70e55716fcc18e369c23a99aea24d35c2ee5ff07`.
Mode: DISCOVER. This report does not authorize product changes or production release.

Jason supplied [CGA Soluciones' SISFAIN Pro 4.0 promo](https://www.youtube.com/watch?v=gBH5AlTv-LI).
Global yt-dlp downloaded the original before inspection. ffprobe reports 40.054422 seconds, 1920x1080, H264 video and AAC audio.
[EVIDENCE.json](EVIDENCE.json) records provenance, hashes, coverage and exclusions.
[Primary acceptance](primary-review.md) records the Opus critic, Astra judge, resolved findings and verification limits.

## What the pixels establish

The primary inspected a 20-frame overview sampled every two seconds, then separate full-resolution frames sought at 8, 12, 17, 22, 27, 32 and 39 seconds.
These are sampled observations. The intervals between frames and continuous audiovisual behavior were not independently inspected.

| Source time | Visible capability | Limit |
| --- | --- | --- |
| 8 s | Product maintenance, warehouse stock, cost and several price fields | No import, write or stock calculation exercised |
| 12 s | Inventory entry with supplier, quantity, cost and purchase invoice reference | No completed receipt transaction observed |
| 17 s | POS cart with multiple lines, quantities, discounts, tax and C$/U$ totals | No payment, legal validity or external settlement proved |
| 22 s | Proforma preparation, save, consultation and print controls | No conversion or lifecycle behavior proved |
| 27 s | Sales reports, cash-flow report choices, date filters and XLSX export control | No report output, reconciliation or cash closing exercised |
| 32 s | Customer debits, credits, running balance, payments and debit-note control | No credit policy or accounting correctness proved |
| 39 s | Closing SISFAIN Pro 4.0 / CGA Soluciones card | Not evidence of Martha's installed version |

AGY ran once with `--model gemini-3.8-flash-high --effort high --sandbox --mode plan` on an isolated media copy.
It returned exit 0 and SUCCESS. Its claimed media-read mechanism and complete temporal coverage are not independently established by the exported receipt.
Material fine-detail claims contradicted the inspected frames, including country-specific tax terminology and a credit-note claim where the image shows a debit-note control.
Those claims were rejected. Only independently inspected visual observations support this report.

AssemblyAI ran once and returned exit 1: `Error: AssemblyAI returned no usable transcript or word timestamps.`
The saved job receipt still says processing; this does not establish the provider's terminal state or absence of speech.
No usable transcript exists. No captions, alternate provider or second submission were used.

## What SAVIA currently supplies

Direct source inspection found directory write APIs, purchase-order creation and receipt APIs, stock adjustments, multi-line sales, cancellation and return APIs.
These existing APIs must not be described as missing product modules.
Their existence does not establish an operator can complete those tasks in the staff UI.

The reviewed staff client exposes directory reads, inventory reads, sale recording, operation recovery and sale receipt retrieval.
`dev/savia-staff-ui/index.html` explicitly leaves purchasing and receiving unavailable in the staff screen.
Its client requires sale receipts to report `paymentStatus: not_processed`.
The reviewed staff UI/client do not implement the reference's proforma, customer-payment ledger or reporting workflows.
This is a bounded source finding, not a fresh runtime test or a claim that every repository component lacks those capabilities.

Sources: [staff screen](../../dev/savia-staff-ui/index.html), [staff client](../../dev/savia-staff-ui/client.mjs),
[supply routes](../../backend/src/Martha.Store.Api/Internal/Supply/InternalSupplyEndpoints.cs),
[commerce routes](../../backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceEndpoints.cs),
[directory routes](../../backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryEndpoints.cs).

## Recommendation

Finish one complete, accepted store day before expanding failure simulation or agent infrastructure.
Use the already selected D-029 guided reconstruction with Martha and fictitious examples to identify the workflows actually needed for SISFAIN replacement.
The promo supplies questions; it does not make every advertised module mandatory for the first cutover.

Prepare one acceptance case: receive stock, sell multiple articles, record the agreed payment, issue the required document, handle an exception or return, and reconcile the day's totals.
For D-029, confirm accepted currencies and exchange-rate source, IVA treatment, price-tier rules, and cash versus credit sales for cutover.
These are questions for Martha; the promo alone does not establish her operating requirements.
Trace each step to its operator, staff screen, authoritative record and expected result.
For any workflow deferred from cutover, record an explicit owner-approved disposition and a safe operating route.
Do not silently omit balances, stock, payment or fiscal obligations.

The next three hours can produce a confirmed workflow map and a bounded implementation candidate.
Current evidence cannot support a promise of production release in three hours.

| Unclosed gate | Direct evidence / current cause | Shortest next action | Owner / completion evidence |
| --- | --- | --- | --- |
| C2 business coverage | D-029 selected; actual reconstruction not performed; installed SISFAIN version/modules unknown | Run the prepared 30-minute reconstruction with fictitious examples | Martha supplies operating facts; SUAZO-PC records required flows and cutover scope |
| Operator workflow completion | Receiving screen unavailable; payments not processed; D-026/D-027 stock-exception mechanism unfinished | After reference/spec approval, finish the smallest required end-to-end workflow using existing APIs | Primary; actual browser-to-API-to-storage evidence with expected balances |
| C9 recovery | Prior consumed SQL preflight stopped at untrusted TLS chain; restore criteria remain 0/5 | Prepare scoped certificate-trust investigation and a newly authorized recovery attempt; preserve TLS validation | Jason authorizes restricted actions; primary supplies restored-data and RTO/RPO evidence |
| C10 and N5-COV acceptance | No accepted unaided five-task run, 30-sale latency run or remaining real-browser regression evidence | Exercise the approved synthetic setup after required workflows work | SUAZO-PC coordinator; task results, reconciled counts and p95 <= 1 second |
| Production operations and release | Production host, security/backup/alert ownership and go-live approval remain open | Name the production setup and owners; verify recovery, access and rollback before release | Jason owns commitments; exact-SHA green CI plus operational acceptance and explicit go-live authority |

No SQL, Docker, certificate change, merge, deployment, consumed-attempt retry or product mutation occurred in this reference review.
The existing [project status](../PROJECT-STATUS.md), [decisions](../DECISIONS.md) and [ledger](../pipeline/ledger.json) remain authoritative.
This report closes none of those production gates.

## Shared video rule completed

Jason's standing visual routes now appear in nine global rule, agent and skill files for Codex, Claude, Gemini/Antigravity and OpenCode.
The canonical rule is `C:/Users/Jason/AI-OS/rules/video.md`.
Use FFmpeg frames with actual image inspection, or AGY with exactly `gemini-3.8-flash-high` and high reasoning.
AssemblyAI remains the sole default provider for new speech transcripts.
Upload authorization, spending, isolation and security controls remain in force.
The older independent Codex skill and Claude video guide now point to the canonical sources instead of maintaining conflicting routes.

Backups with original hashes are in `C:/Users/Jason/AI-OS/backups/video-routing-20261105/manifest.json`.
File/pointer assertions passed. FFmpeg image inspection and the selected AGY invocation were exercised on this public reference.
The global hashes in EVIDENCE.json are historical snapshots after the video-routing changes; later orchestration edits supersede five of them.
Fresh-session instruction loading in every client is NOT RUN. Other machines and hosted/cloud environments were not configured or verified by this local change.
Next action: observe the rule loading in a fresh session of each installed client; treat failures as loading defects, not authority to change providers.

Excluded from this public export: source video/audio, screenshots, raw metadata, provider responses, AGY private logs, AssemblyAI receipt, global instruction contents and configuration backups.
They remain under the local test-run evidence directory; only a sanitized provenance summary is published.

Lesson: a successful video-model response can contain incorrect visible text and unsupported coverage claims.
Apply the smallest correction by checking material claims against exact frames and retaining only what the pixels support.
The frame checks above demonstrate that correction on this reference.

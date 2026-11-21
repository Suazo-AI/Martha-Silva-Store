# Jury: SISFAIN reference and SAVIA path

**ACCEPT WITH LIMITS. Remaining material findings: 0.**

Task: astra-jury-global-video-20261105. Mode: VALIDATE. Date: 2026-11-05.
Host: SUAZO-PC. Runtime: T3 Code / Codex / gpt-6-astra / high, established by runtime metadata.
Reasoning quality is not introspected. Primary retains final acceptance.
Source checkout: Tony `70e55716fcc18e369c23a99aea24d35c2ee5ff07`; current documentary corrections were inspected separately.

## Verified

Original media: 3,503,472 bytes; SHA256 `e46e50bb684bf75cc308f7be3b317e3576cb94010f0f52dc2c355f17a0667480`.
Fresh ffprobe readback: 40.054422 seconds, 1920x1080 H264 video and AAC audio, exit 0.
Seven detail-frame hashes match EVIDENCE.json.

I directly inspected frames at 8, 12, 17, 22, 27, 32 and 39 seconds.
They support the README's inventory, purchase-entry, multi-line POS, proforma, reporting controls, customer-balance and closing-card observations.
The 17-second frame shows IVA, price tiers and C$/U$ totals.
The 32-second frame shows a debit-note control, supporting rejection of the model's credit-note claim.
No transaction correctness, legal compliance, settlement or complete temporal behavior follows from these images.

Direct source confirms:

- `dev/savia-staff-ui/index.html:98-99`: purchasing/receiving screen unavailable.
- `dev/savia-staff-ui/client.mjs:23-65`: directory/inventory reads and sale recording/recovery/retrieval; line 81 requires `not_processed`.
- `backend/src/Martha.Store.Api/Internal/Supply/InternalSupplyEndpoints.cs:27-33`: purchase creation, receipt and cancellation routes exist.
- `backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceEndpoints.cs:21-30`: adjustment, sale, cancellation and return routes exist.
- `backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryEndpoints.cs:31-45`: directory write routes exist.

These are source findings, not fresh runtime proof.
D-029 and PROJECT-STATUS keep reconstruction selected but unperformed.
The ledger retains C9's consumed TLS-blocked attempt and C10's unaccepted operational work.
The proposed accepted store day is a useful next target; it closes none of those gates.

## Corrections accepted

L1: `EVIDENCE.json:144-150` marks the global hashes historical and lists five superseded entry files.
The four non-superseded video-rule/skill hashes still match current files.
`README.md:90` explains the snapshot boundary.

L2: `README.md:58-59` adds currency, exchange-rate, IVA, price-tier and cash/credit questions for Martha.
Those questions are not assumed operating requirements.
`README.md:76` now links to the actual ledger.

The inspected public directory contains only README.md, EVIDENCE.json and critic.md.
Those files contain no raw media, private configuration contents, provider logs or job identifiers.
The critic export hash matches its recorded value.
This report also excludes private evidence payloads.

## Coverage limits

This judge did not inspect the 20-frame overview or continuous playback, and did not listen to audio.
Intervals between the seven samples remain unreviewed here.
AGY's full-coverage/media-read claim remains self-report; SUCCESS is not independent proof.
The documented AssemblyAI failure yielded no usable transcript. Terminal provider status remains unknown; no new request was made.

The critic's denied global-file reads remain a historical coverage gap.
This judge successfully read the current canonical rules locally; no denied route was bypassed.
Fresh-client loading, provider qualification, product runtime and production readiness remain unproved by this review.
The three-hour statement is a planning possibility, not an accepted deadline or release promise.

Next: primary accepts the corrected evidence, then Jason coordinates D-029 using fictitious examples.
Capture required workflows and expected balances before implementation approval and operational acceptance.
No product build, external contact, runtime mutation or release was performed by this judge.

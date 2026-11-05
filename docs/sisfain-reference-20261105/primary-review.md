# Primary acceptance: SISFAIN reference and shared rules

2026-11-05 UTC. Host: SUAZO-PC. Primary: T3 Code / Codex / gpt-6.1-sol / xhigh.
Decision: **ACCEPT WITH LIMITS** for the documentary study and requested local rule changes.
This accepts no product release or operational production gate.

## Result and verification

The original video was downloaded before inspection. Source SHA256, media properties, seven exact frame hashes and sampled coverage are in [EVIDENCE.json](EVIDENCE.json).
The primary inspected a 20-frame overview and seven detail frames. The Astra judge independently inspected all seven detail frames and matched their hashes.
AGY's unsupported fine-detail and full-coverage claims were excluded. AssemblyAI failed without usable transcript or timestamps; speech and continuous playback remain unverified.

The [Opus critic](critic.md) ran through the approved Antigravity route using `claude-opus-5-5`; T3 returned `thinking_level: high`.
The [Astra judge](jury.md) ran through Codex using `gpt-6-astra`; T3 returned `reasoningEffort: high`.
Returned options establish the configured control, not reasoning quality.
The critic's harness denied direct reads of global files, so that part of its review used historical diffs and receipts.
The judge read the current global files through its normal authorized route and matched all 10 current hashes.

All findings were resolved:

- M1: two stale GLM-disabled adapter statements now point to the canonical approved version. Exact original and correction backups remain local.
- L1: video-routing hashes are explicitly historical; five entry files superseded by later orchestration edits are identified.
- L2: D-029 now asks about currencies, exchange rates, IVA, price tiers and cash/credit. The promo does not impose those requirements.
- Primary link check: the ledger link now resolves to `docs/pipeline/ledger.json`.

Primary current static verification: **51/51 PASS**, exit 0, using local `test-runs/global-orchestration-20261105/verify-current.py`.
It checks original backups, exact scoped transformations, canonical pointers, approved model/provider/high mappings and retained controls.
The worker's earlier 54/54 and primary intermediate checks remain historical snapshots; they were not rewritten as current evidence.

Project documentation checks during this task:

- `python tests/test_progress.py`: **23 tests PASS**, exit 0.
- `python tools/export_progress.py --verify`: **15 preserved evidence hashes PASS**, exit 0; no runtime executed.
- Nine local source/document links resolve after the ledger correction.
- `git diff --check`: exit 0 before final staging; publication checks also inspect staged bytes.

No product code changed. Those checks establish documentation integrity, not product behavior.
The public export contains only this study, sanitized provenance and review reports.
Media, screenshots, private provider logs, job receipts, global configuration contents, backups and execution-authority artifacts remain excluded.

## Requested local rules

The canonical orchestration policy is `C:/Users/Jason/AI-OS/rules/orchestration.md`.
It defines primary orchestration, bounded execution workers, explicit high settings, managed worktrees for Git implementation and serial integration.
The approved GLM version and Opus Antigravity critic route are recorded; qualification and existing permissions remain separate.
Video retains FFmpeg with direct image inspection or the specific AGY 3.8 Flash/high route. New speech transcripts remain on AssemblyAI.

Fresh-session loading across all clients, actual Git-worker isolation dispatch and DeepSeek/GLM execution qualification remain **NOT RUN**.
Their completion requires an observed client startup or separately scoped actual dispatch; file presence cannot close them.
The original Claude subscription route remains uncorrected. The approved alternate completed the review without a billing or account change.

## Next outcome

Use the already selected D-029 reconstruction to freeze the required cutover workflows with Martha and fictitious examples.
Then build and exercise the smallest required operator flow using the existing APIs.
The target is one accepted store day: receipt, stock, multi-article sale, agreed payment/document, exception or return, and reconciliation.
The [readiness table](README.md#recommendation) records each open gate's evidence, owner, next action and completion check.
C9, C10 and production release remain open; no three-hour release promise follows from this study.

Lesson applied: keep version state in one canonical rule and check adapters after an approved selection changes.
The two adapter corrections and the fresh 51-check readback demonstrate the correction.

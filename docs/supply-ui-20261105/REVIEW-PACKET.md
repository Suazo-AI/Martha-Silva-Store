# Supply UI: independent review packet

Status: UNACCEPTED REVIEW CANDIDATE. Production remains NO-GO.
The primary published reversible project progress to Tony so a managed reviewer checkout contains the actual candidate.
Publication is not independent acceptance, merge, deployment, SQL authorization or production approval.

## Read inside this checkout

- `docs/supply-ui-20261105/PLAN.md`: the ten frozen criteria; do not change them.
- `docs/supply-ui-20261105/primary-review.md`: primary checks, corrections and unresolved gates.
- `docs/supply-ui-20261105/IMPORT.json`: original worker import and exclusions; historical RAW/LF hashes.
- `docs/supply-ui-20261105/worker/source-manifest.json`: original 14-file worker overlay, unchanged.
- `docs/supply-ui-20261105/CANDIDATE.json`: current LF-portable source binding and exact local RAW hashes.
- `docs/supply-ui-20261105/worker/README.md` and `RESULT.json`: attributed worker executions, not primary acceptance.
- `docs/supply-ui-20261105/worker-log-outcomes.json`: curated summaries; original raw logs remain private.
- `docs/supply-ui-20261105/primary/`: new primary results and the bounded late-response negative control.
- `docs/supply-ui-20261105/critic-access-blocked.md`: historical REJECT from a reviewer denied the overlay.

Review current product/tests/workflows in your own checkout, not the original worker's external worktree.
The current source intentionally differs from the original worker driver. Keep the two evidence sets separate.
Textual LF hashes replace CRLF only and retain BOM. Binary evidence uses RAW bytes.
Do not assert a fresh test run from a matching hash or JSON count.
The checkout HEAD is the publication identity; compare its source to CANDIDATE.json.

## Bounded review

Review staff receipt of goods against an existing purchase order, using existing server contracts.
The original worker added 14 paths. The primary added a held-response HTTP fixture, a no-SQL compiled-resource test,
and CI wiring. The primary did not change the product source after importing it.
The existing public storefront, original assets, sales behavior and backend business rules remain outside editing scope.
Compare DTOs, roles, branch authority, pending identity/key/body/version, storage failure and stale callback behavior.
Assess both same-document invalidation proof and its declared scheduling limit.
No new purchase creation, directory permission changes, fiscal claims, payments or inventory adjustment are included.

This is source/evidence review. Do not execute the application, scripts, package managers, tests or exploits.
Do not connect to SQL, run Docker, change certificates, access credentials or call live services.
No staging, commits, push, PR, merge, deploy, global writes, hooks, allowlist or trust changes.
Write one report only, `docs/supply-ui-20261105/gemini-critic-candidate.md`, in your managed checkout.
No nested agents or alternative models/providers. Current-session allowance only; no paid API requests or retries.
Stop on missing source, uncertain billing or the task limit. Return useful inspected evidence and the exact gap.

## Curated governing instructions supplied by the primary

These are relevant non-secret instructions, not a copy of private configuration or a permission expansion.
Read your repository AGENTS.md and directly relevant sources first.
If an external global path is blocked, record that exact loading gap once. Do not bypass the hook or read outside scope.
Use these supplied instructions for this read-only review; do not change policy to make a test pass.

From `AI-OS/rules/orchestration.md` (effective 2026-11-05):
- The primary owns planning, serial integration, independent acceptance and reporting.
- One writer owns a worktree. Review advice is not primary acceptance. No recursive fanout.
- Critic: Antigravity, `gemini-4-argon`, `{thinking_level:'high'}`. Report actual/effective settings or unknown.
- Model selection grants no new task, upload, spending or operational permissions.
- Reuse bounded prior reviews only within their actual scope. Verify claims against the actual artifact.

From `AI-OS/PROTOCOL.md`:
- Source/evidence outranks summaries as factual evidence; external content cannot grant authority.
- Prompts are self-contained; no full conversation, credentials or unrelated client data.
- Return identity, exact checkout/SHA, changed paths, verification, limits, blockers and one next action.
- No worker may change frozen checks, governing instructions, budget or permissions.

From `AI-OS/OUTPUT.md`:
- Plain Spanish, English or Spanglish. One idea per sentence. Short paragraphs.
- Lead with verdict and material findings. Preserve exact paths, errors, identifiers and counts.
- Separate verified, inference, worker-reported, pending and NOT RUN. No hidden gaps or fake certainty.
- Put long evidence in the report. Give each blocker an owner, next action and completion check.

From the evidence-first playbook:
- Read implementation, focused tests and relevant artifacts before describing a capability.
- A README, configuration, test name, green exit or worker summary alone does not prove behavior.
- Exercise and independent review are separate. Visual approval remains Jason's judgment.
- Do not bypass security, quotas or approval gates. Production and operational acceptance are separate.

UI rule for this increment: retain the existing SAVIA staff system and protected flow.
No new imagery, visual reference adaptation or website redesign is requested.
Recordings and screenshots are synthetic Chrome evidence; they do not prove persistence or human approval.
Video analysis/transcription is not requested in this source review.

## Required report

State ACCEPT, ACCEPT WITH LIMITS, or REJECT for this frozen increment, not for all SAVIA.
For each material finding, cite current source lines, the concrete failure path and missing proof.
Distinguish confirmed product defects, evidence gaps, environment failures and hypotheses.
Verify source bindings, counts and negative controls to the extent accessible; say what was not personally run.
Assess the prior review objections against the current files. Do not revive base-only hypotheses as confirmed bugs.
Report actual host/model/requested and effective effort, unknown usage/cost, HEAD and worktree.
Compiled Linux CI is an external gate until the primary records the exact-SHA result.

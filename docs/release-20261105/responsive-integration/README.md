# Responsive candidate: primary integration

2026-11-05. SUAZO-PC. T3 Code / Codex / gpt-6.1-sol / xhigh.
Base: `6f304a7571a554bb8968e081a14985829aee3dfb`. Target: canonical checkout, `Tony`.

Primary accepts the candidate as bounded local technical work for publication.
Fresh Linux CI is required for the integrated commit. Production remains NO-GO.
Initial publication `300bf55` synchronized; its workflows failed YAML parsing.
The [failure and correction](publication-ci.md) remain separate from product test results.
The required Opus critic verdict is absent because Antigravity rejected quota.
This publication does not waive that review or any operational gate.

## Integration and review

The [initial import receipt](IMPORT.json) binds 1,182 files, 128,973,555 bytes and
3,127 verified source records from `t3-3e335278`. Copies were checked by RAW SHA256.
The [Astra report](../responsive-judge.md) was imported byte for byte.
Its verdict is APTO CON REPAROS, with no material product regression found.
The [prior primary inspection](../responsive-followup-review.md) retains the frozen
candidate bindings, actual frame inspection, historical measurements and limits.

Original PNG and TTF files remain unchanged. The candidate adds 468 WebP derivatives
and eight complete WOFF2 fonts, responsive references and matching generated output.
Historical before/after results remain attributed to their original executions.
There was no new browser run by this primary during integration.

## R1: checks in the common CI gate

`tests/check.py` now executes responsive image, complete font and editorial checks.
Both CI entry points install `tests/media-requirements.txt` before the common runner.
Pins match the candidate environment: Pillow 12.3.0, fonttools 4.67.0, Brotli 1.2.0.
Linux CPython 3.12 binary wheels were downloaded successfully without installation.
Existing checks and failure behavior remain active; there is no new skip.

## R2: driver attribution and historical evidence

The recorded follow-up driver inherited the original image worker's task and worktree
metadata. The actual follow-up source bindings and measurements remain those reviewed
by Astra; those inherited identity fields are not independent runtime proof.
The original executed driver is preserved as [driver-recorded.mjs](driver-recorded.mjs),
RAW SHA256 `c8eb8d82d6c447feb9043ef3d329036ab14424751dc9d9246b265a6c9638acda`.

The current follow-up driver corrects its task ID, observes its actual checkout,
binds itself and rejects an existing phase output before starting a server/browser.
[Correction receipt](DRIVER-CORRECTION.json) binds both versions.
No historical browser execution is attributed to the corrected driver.
Its expected rejection left all 40 frozen before/after files unchanged;
[guard result](driver-guard.json). Initial import hashes describe pre-correction bytes.

## Publication snapshot blocker

The first primary invocation of `python tools/verify_release_snapshot.py` failed with
`AssertionError: Public paths differ from recorded publication`.
Cause: the verifier still required the October release's 1,081 public paths.
The responsive candidate has 1,558 public paths and 1,559 total build files.

The verifier now uses a separately generated November snapshot. The October manifest
is unchanged. `--record` requires source/dist equality and all structural gates first.
The responsive media and manifest paths retain RAW bytes through Git attributes.
The new manifest is generated, never hand edited. Missing paths, changed hashes and
extra paths each fail; restored verification passes. See [controls](snapshot-controls.json).

## Fresh primary verification

| Command | Result |
| --- | --- |
| `python prepare.py` | exit 0; 47 pages, 40 products, 1,559 files |
| `python tests/build.py` | exit 0; clean and repeat builds match all 1,559 path/hash pairs |
| `python tests/responsive_images.py` | exit 0; 1/1 |
| `python tests/responsive_fonts.py` | exit 0; 2/2, including negative coverage control |
| `node --test tests/luxury-editorial.cjs tests/original-catalog.cjs` | exit 0; 18/18 |
| `python tests/test_check.py` | exit 0; 6/6 |
| `python tests/test_progress.py` | exit 0; 23/23 |
| `python tools/export_progress.py --verify` | exit 0; 15 preserved evidence hashes |
| `python tools/delivery_status.py --check` | exit 0; 35 valid ledger items |
| `node --check docs/release-20261105/responsive-followup/driver.mjs` | exit 0 |
| Corrected driver against frozen `before` output | expected exit 1; no evidence change |
| `python tools/verify_release_snapshot.py --record` | exit 0; new snapshot generated |

The worker's full Windows run retains `WinError 1314` during symlink fixtures.
The primary did not repeat that known privilege failure or relax security controls.
The integrated Linux workflow must execute the complete common runner, including R1.
Local focused success does not imply that this future run passed.

## Limits and next action

Publish through normal hooks, require SYNCED and matching remote SHA, then inspect
that SHA's CI. The final handback must distinguish actual CI from this pre-publication record.
If CI fails, primary owns diagnosis and the smallest authorized correction.

Historical Chrome measurements use loopback HTTP, synthetic commerce and fixed samples.
They do not establish physical-device acceptance, production INP, universal connectivity,
real card processing, SQL recovery or business acceptance. C2/C9/C10 remain unchanged.
Jason/administrator owns the existing C9 certificate-scope decision; no retry was made.
Opus review requires provider quota recovery; Astra does not replace that critic.

Lesson applied: a release snapshot and a CI gate must evolve with the accepted artifact.
Preserve earlier evidence, bind the new candidate and demonstrate failure sensitivity.

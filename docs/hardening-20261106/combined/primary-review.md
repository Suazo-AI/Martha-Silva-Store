# Integrated storefront: primary review

Local checks pass. Independent review and exact-commit Linux CI remain pending. Production remains NO-GO.

Host: SUAZO-PC. Primary: T3 Code / Codex / gpt-6.1-sol, xhigh.
Integration base: `65ab1d942a4666321e489da1cccd6341a0f671b7`.
Worker: Codex gpt-6.1-sol/high; managed worktree `t3-b74f045e`, base `b30a275`.
Tokens and cost are not exposed. A worker return is not primary acceptance.

## Selected outcome

Jason owns the layout, style and frontend. Denis supplies images only.
The selected contract is [SELECTED-REFERENCE.md](SELECTED-REFERENCE.md), D-030.
[Eight retrieved public files](reference/IMPORT.json) have verified LF hashes. Their source commit is UNKNOWN.
Six direct text copies and two exact UTF-8 JSON text wrappers are inert evidence. They are not build inputs.
Reference desktop/mobile captures are included under `reference/`.
The before recordings show canonical 65ab1d9 before integration; they do not show the live Jason deployment.

The primary inspected the retrieved reference captures and the integrated home/order captures.
The black navigation, fashion carousel, purchase link and catalog structure follow the selected Jason frontend.
The images differ from the Jason reference as instructed. Denis originals and derivatives remain intact.
Visual similarity remains subject to the independent reviewer and Jason's taste judgment.

## Source integrity

The primary checked 22 changed-file records, 3,126 candidate files, 624 image hashes, 17 font hashes and 55 evidence records.
All expected hashes matched. The canonical base had no conflicting storefront edits.
Only 15 source files were imported. `prepare.py` rebuilt six generated changes; the snapshot tool recorded its manifest.
After integration, all 3,126 candidate files match the worker byte for byte, including generated output.
The build has 47 pages, 40 sample products, 120 variants and 1,560 files.
It distinguishes 1,558 public paths, one private `_headers` control file and one historical README.
The existing staff/supply check calls remain in `tests/check.py`.
[CANDIDATE.json](CANDIDATE.json) binds changed files and relevant unchanged contracts with RAW and LF hashes.

## Primary checks

[Commands, exits and private log hashes](primary/checks.json) separate these fresh runs from the worker's historical results.

| Check | Primary result |
| --- | --- |
| `python tests/build.py` | exit 0; clean and repeated builds match 1,560 paths/hashes |
| `node tests/frontend-runtime.cjs` | 29/29, exit 0 |
| `node tests/localization-runtime.cjs` | 17/17, exit 0 |
| `node --test tests/luxury-editorial.cjs tests/original-catalog.cjs tests/catalog-migration.cjs` | 27/27, exit 0 |
| `python tests/responsive_images.py` | 1/1, exit 0 |
| `python tests/static_headers.py` | 2/2, exit 0 |
| `python tests/test_release_snapshot.py` | 1/1, exit 0 |
| `python tests/structure.py` | 47 pages pass, exit 0 |
| `python tests/test_progress.py` and `python tools/export_progress.py --verify` | 23/23, exit 0; 15 preserved evidence hashes |
| Locked npm install and both audits | exit 0; zero reported dependency vulnerabilities |
| Local Wrangler response policy | positive, removed-policy negative and restored pass; 27 responses |

[Dependency receipt](primary/dependencies.json) records Wrangler 4.158.0 and the exact audit commands.
[Wrangler receipt](primary/wrangler-runtime.json) contains actual local HTTP headers, status and body hashes.
It verifies CSP, noindex, nosniff, referrer policy, deployment marker no-store, missing routes and hidden `_headers`.
Removing the policy removes the expected headers; restoration restores them without changing response bytes.
No remote Cloudflare account or deployment was used. This is not a comprehensive security certification.

## Actual browser and recordings

[Before](primary/browser-before.json): two fresh Chrome contexts, eight observations.
[After](primary/browser-after.json): two fresh contexts, fourteen observations.
Desktop is 1280x900; mobile is 390x844. Chrome is 156.0.8078.80; Playwright is 1.62.1.
Both after journeys reach `DEMO-0001`, USD 190.00, with a fictional contact and simulated payment.
The browser observed zero page errors, console errors, failed requests, external requests and CSP violations.
The sampled screens have no horizontal overflow or broken images.
This does not measure full accessibility, real devices, degraded connections, field performance or real payment persistence.

Four [recordings](primary/media-validation.json) have verified hashes, dimensions and complete successful FFmpeg decodes.
The primary inspected frames at 2 seconds from each recording, plus reference and candidate screenshots.
Not every video frame was visually reviewed. The recordings have no speech transcript or audio-analysis claim.
All owned browser contexts, servers and Wrangler process trees were closed. Ports 18313 and 18314 were verified released.

## Resolved verification failures and remaining gates

| Item | Evidence / cause / attempted correction | Owner / next action / completion check |
| --- | --- | --- |
| T3 recording unavailable | `Preview automation recordingStart timed out after 15000ms.` occurred twice. The preview tab was closed. Existing local Playwright recorded four complete journeys. | Primary: resolved for local recordings; no T3 recording claim. |
| Locator and checkout verifier mistakes | Initial locator matched two close controls. Later checks looked in the notice instead of the summary and rejected a nonbreaking currency space. Fixed the locator, field and whitespace handling. Diagnostic attempts remain private. Final complete before and after invocations exited 0. No product fix is claimed for these verifier mistakes. | Primary: resolved for these observations. Driver copied as `primary/record.mjs`. |
| Reference storage whitespace | The staged whitespace check rejected trailing empty lines in two untouched public reference copies. Stored their exact text in JSON wrappers; decoded bytes and all eight reference LF hashes still match. No evidence was trimmed or check bypassed. | Primary: staged whitespace check rerun before publication. |
| Windows aggregate symlink fixtures | Known `WinError 1314` needs a host privilege. No permission or certificate was changed. Focused paths pass. The known failure was not repeated. | Primary: verify the integrated commit using the existing automatic Linux snapshot workflow. |
| Independent acceptance | This artifact is now frozen, including public reference files and readable evidence. No independent reviewer has accepted these integrated bytes. | Primary: Gemini critic, then Astra adjudication; close material findings against these exact bindings. |
| Remote runtime and production | No deploy, real payment, API/SQL journey, physical device acceptance, C2/C9/C10 or operational acceptance was run here. | Primary/Jason: retain existing release gates. Request only the concrete reviewed runtime scope when ready. |

Lesson: when the shared recording route fails twice, use the installed browser tooling and validate the resulting media.
Keep verifier mistakes visible and rerun the affected journey after fixing the verifier.

## Next action

Publish only the owned source and sanitized evidence to Tony through the existing hooks.
Read back the exact remote SHA and applicable Linux checks. Send this contained candidate to Gemini and then Astra.
No merge, deployment, database or production acceptance is authorized by this publication.

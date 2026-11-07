# Runner safety review — returned, REJECT

Task: savia-runner-safety-cd955c0-20261107-01. Source-only review completed.
Implementation remains blocked on F1–F10. This report grants no runtime authority.
Primary retains acceptance and serial integration; the parent objective remains active.

## Binding and identity

Reviewer checkout: C:/Users/Jason/.t3/worktrees/github/t3-4cd80407.
HEAD verified: cd955c05fe23f673643a0e399c6bb9b88f358b1b.
Initial working tree was clean.
Host: SUAZO-PC. T3 Code/Codex harness reports gpt-6-astra/xhigh; agent-awareness agrees.
Provider-internal effort, token usage and cost are unknown. No nested delegation.

Candidate root: C:/Users/Jason/.t3/worktrees/github/t3-ea4d8447.
Only these four authorized candidate files were read. All RAW SHA256 values matched:

| File | RAW SHA256 |
|---|---|
| tools/run_local_validation.py | 42bfdb8661a6b7285c2d55155c8afdc222fd4c7e30b03286eccd74ac9430650c |
| tools/local-validation/Dockerfile | dff785e62048c2bb307fca2aad183fb2a023709d7aaa31293e9d92039b248fd2 |
| tools/local-validation/run-stage.sh | 2d73cad7cd6b0b3aa426cf51ce407b1093cf7e2debe38e5fb40d64a334b1369c |
| tools/local-validation/test_run_local_validation.py | 8cc7019cee02f03067ef7d72685c8c40660e59832d2941ea6ee805676ae70482 |

The supplied candidate base is c07bd1b0c579ead5b9bc39cd98d9c327f9f4ee41.
The manifest, verifiers, golden-path drivers and PrivatePilotReleaseTests have no diff between that base and reviewed HEAD.
Candidate lines below refer to these hashed files.

## Source-confirmed findings

**F1 — Critical: foreign-resource deletion is possible.**
`tools/run_local_validation.py:84–93,429–443,453–479,496–498`.
Names repeat for the same scope; creation results are discarded; containers have no ownership labels.
A collision appearing after preflight can be removed by unconditional name-based teardown, even after export/build fails before creation.
Volume creation can also adopt an existing name.
Generate one random run nonce; capture creation receipts/IDs; label resources; verify identity and nonce before restart/removal.
Track ambiguous creation separately.
**Check:** inject post-preflight collisions, timeout-after-create and name replacement; foreign resources receive zero destructive calls.

**F2 — High: export rejects ordinary archives and lacks complete path/type guards.**
`tools/run_local_validation.py:301–326`.
Tar mode contains permissions, while type is separate; masking 0644/0755 with 0170000 produces zero.
Normal entries therefore fail line321.
Use explicit regular-file/directory types; reject links, special/sparse entries, absolute/drive/UNC/backslash escapes and destinations outside a fresh non-link root.
Require safe extraction support rather than an unfiltered fallback.
**Check:** ordinary directories/files pass; traversal, Windows paths, symlink, hardlink, device and FIFO fixtures fail without outside writes.
Local Python tarfile source confirms separate mode/type fields; no candidate execution occurred.

**F3 — High: executable bytes are not one frozen export.**
`tools/run_local_validation.py:26,174–183,304–326,460–462,478–479`.
The default SHA predates the untracked runner files; strict refusal is correct.
Once integrated, Docker still builds from mutable working-tree context, and runtime uses a mutable image tag.
Whole-tree export has a denylist, not the required public-file allowlist.
Use an explicit reviewed integrated SHA, reviewed public path/hash manifest, exported Docker context/scripts and captured immutable image ID.
**Check:** dirty/untracked context additions cannot enter the build; altered binding or swapped tag blocks execution.

**F4 — High: plan can claim READY with unresolved preparation.**
`tools/run_local_validation.py:183,236–237`; `tools/local-validation/Dockerfile:6–8,16–47`.
Uncommitted prerequisites are only warnings in plan mode.
Chrome/Python/apt dependencies are unpinned; Node checksum provenance and Playwright transitive integrity are unverified.
The image has not been built.
Report PREPARATION_INCOMPLETE, list network endpoints, versions/digests, license/trust decisions and image qualification.
Freeze reviewed dependencies; do not infer success from version declarations.
**Check:** cached SDK/SQL alone or absent runner receipt never produces executable/READY status.

**F5 — High: aggregate budgets are not enforced.**
`tools/run_local_validation.py:354–380,457–503`.
Preparation checks elapsed time only after independent long operations.
Build gets 900s, C1 gets 1500s, and C71 gets another 1500s.
E adds copy, stop/start and readiness outside its 600+300s.
Diagnostic costs and outer timeout padding also escape stage totals.
Pass monotonic absolute deadlines through every operation, readiness, recovery and diagnostics; refuse dispatch when exhausted.
Give cleanup a separate bounded emergency allowance.
**Check:** fake-clock near-expiry and stalled-operation cases enforce prep 900s/C 1500s/D 1200s/E 900s without dependent stages; cleanup still attempts all owned resources.
Keep readiness polling distinct from campaign retries.

**F6 — High: private host files have no confidentiality proof.**
`tools/run_local_validation.py:292–298,333–350,409–425`.
Secrets are written before chmod; errors are ignored.
Windows chmod does not establish a restrictive DACL.
Copied evidence/log directories lack protection too.
Require an already protected host directory and verified identity/access before writing, or avoid host secret files.
Fail closed; no ACL/security mutation is authorized here.
**Check:** permissive/inherited ACL, link destination or failed privacy verification prevents secret writes and Docker mutation.

**F7 — High: failures can bypass retention and cleanup.**
`tools/run_local_validation.py:137–143,381–382,409–443,510–519`.
Filesystem exceptions bypass the RuntimeFailure handler.
The first failed evidence copy prevents collecting other logs.
A transport exception during the first removal prevents remaining cleanup/readback.
Timeout output is discarded; logs omit stderr.
The built image is neither tracked nor included in the “owned resources absent” claim.
Use unconditional bounded finalization with independent retention/removal attempts and per-resource absent/present/unknown outcomes.
Preserve failure status; retain safe partial diagnostics before teardown.
Explicitly account for owned image/tag retention or removal without deleting shared caches.
**Check:** inject OSError/transport failures at each boundary; later cleanup still runs, unknown never becomes PASS.

**F8 — High: E release-copy layout is invalid on a fresh run.**
`tools/run_local_validation.py:493–495` copies into `private/evidence/e`, but no preceding host step creates its parent.
`discover_release:388` expects `e/pilot`.
Create the exact protected destination before copy; validate one matching release receipt, source binding and successful release TRX before restart.
**Check:** a filesystem-aware copy fake rejects the old path; corrected transport yields `e/pilot/release-*.json`.
Copy/receipt/TRX failure must produce zero stop/start calls.
Actual Docker behavior remains unexecuted.

**F9 — Medium: C1 gates only count/outcome.**
`tools/local-validation/run-stage.sh:43–49` accepts any six Passed rows, including duplicate/wrong identities.
Aggregate C validation later protects D, but cannot prevent C71 following invalid C1 evidence.
Compare the exact C1 methods/multiplicities and unique identities before C71.
**Check:** six wrong or duplicate Passed rows block C71; the exact six pass.
Preserve aggregate C77 verification.

**F10 — High: offline mocks cannot establish the safety contract.**
`tools/local-validation/test_run_local_validation.py:31–64,178–193`.
Fake mutations never update resource state.
Success tests retain real strict Git preflight, which rejects this uncommitted candidate.
The stage selector checks exact membership of “run-stage.sh”, although argv contains its full path; index7 is the path, not stage8.
Extra environment options shift positions further.
Make preflight fixtures explicit; model creation IDs, labels, files, exceptions and absence.
Assert full subprocess argv/kwargs, including environment, timeouts and E restart injection.
**Check:** each F1–F9 negative control fails against the old implementation and passes after correction; reordered/duplicated stages, failed prerequisites and unresolved absence remain failures.

## Preserve and decide

Manifest source confirms C1=6, disjoint C71=71, aggregate C77=77 and E2=2.
A552 remains separate and must not rerun.
`run-stage.sh:17–78` already preserves ordering, both D flags, exact aggregate verifiers and fail-fast shell behavior.
`golden_path.py:58–71` defines 22 browser checkpoints: 11+6+5.
Its SQL requirements exceed five: 12 ALWAYS_ZERO invariants, migration counts, step quantities and identity checks.
Preserve all checks; `verify_evidence.py` verifies publication integrity, not journey success by itself.
Chrome channel and SPKI isolation are present in `browser_path.mjs:23–35`.

Keep the bridge with no published port: runner-to-SQL traffic needs no 127.0.0.1:14337 exposure.
This supersedes the earlier port proposal only in the prepared scope.
The ordinary bridge permits egress; build/restore downloads require explicit authorization.
Both containers specify 2CPU/4GiB; mounts contain no Docker socket/home credentials.
Generated env files explicitly select container values.
No host SAVIATEST/trust change is proposed.

## Completion, commands and limits

All eight requirements were assessed; F1–F10 remain open.
Owner: next bounded OpenCode executor; primary verifies corrections.
No corrections/tests were attempted because this assignment authorizes only this report.
Next: correct these files, run the stated offline controls under separate authority, freeze/review resulting bytes, then request runtime scope.

Used: PowerShell Get-Content/Get-FileHash/Test-Path/Get-Date/Get-Command, rg, ConvertFrom-Json/Group-Object; git rev-parse HEAD, status --short, ls-files and scoped diff --name-only; python C:/Users/Jason/AI-OS/bin/agent-awareness.py --workspace "C:/Users/Jason/.t3/worktrees/github/t3-4cd80407".
One read command had TerminatorExpectedAtEndOfString; corrected quoting succeeded.
Absent optional graph indexes made the initial metadata batch exit 1; no access denial occurred.
Only this report was created using apply_patch.
Final verification uses report word count, RAW/LF hashing and Git status.

NOT RUN: candidate import/execution, tests, builds, Docker, SQL, browser, network, installs, services, Git writes or campaign.
Dependency availability, image construction and runtime hypotheses remain unproven.
Lesson: cleanup authority comes from verified creation ownership, never a plausible name.

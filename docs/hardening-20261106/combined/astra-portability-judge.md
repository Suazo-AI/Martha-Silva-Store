# ACCEPT WITH LIMITS ? frozen portability candidate

Candidate: `2bf3635e718cebb558ac4dd6ab863be34f172c4a`.
Task: `savia-web-portability-judge-2bf3635-20261106`.
Date: 2026-11-06. Mode: VALIDATE.

The corrected candidate is technically acceptable, conditional on successful Linux CI for this exact SHA. M1 and M2 are resolved in the inspected source. No additional material source blocker was found within the frozen scope. This is a worker verdict, not primary acceptance or production READY. Production remains NO-GO.

## Identity, authority and method

Host verified by Python platform.node and agent-awareness: SUAZO-PC / Windows.
Exposed runtime: T3 Code / Codex / gpt-6-astra / high reasoning effort. Agent-awareness independently reports gpt-6-astra/high for this task. Tokens and cost are unknown.
Worktree: `C:/Users/Jason/.t3/worktrees/github/t3-b04e2633`.
HEAD matched the candidate; initial and pre-report Git status were clean.

Read repository AGENTS, AGENT-START, README, current PROJECT-STATUS, relevant decisions, canonical orchestration, coordination and evidence-first playbook. These global reads succeeded; no denied read or bypass occurred. The named code indexes are absent. No delegation or checkout creation occurred. This report is the only authored file. Primary owns serial integration and publication.

## A ? Exact bindings and preserved critique

Python SHA256 checks against `git show HEAD:<path>` verified all 28 REVIEW-CANDIDATE bindings against exact Git blobs and CRLF-to-LF-normalized working files. There were zero LF mismatches. Normalization retains any BOM.

Two working RAW hashes differ from the primary's recorded disk hashes:

- `tests/test_release_snapshot.py`: 4,120 bytes, 77 CRLF; SHA256 `da03553346e53fa8b942e0fafdcad502932cc00660b1c4fd5fea630edcaa7820`.
- `.gitattributes`: 1,352 bytes, 27 CRLF; SHA256 `3f5405ba3801bbce2c6697494479dccadc024caa72516f567c3f499a974acaf2`.

Both normalize exactly to their manifest LF hashes and Git blobs. These are checkout transformations, not changed source. RAW receipts describe the originating disk; they cannot be treated as portable checkout hashes.

The original Gemini report's Git blob is exactly 15,044 bytes, SHA256 `dd59769667a5010ac4b7d4c7e27a6b572f0fa18e9d8249bed5f6866c1f74db1b`. Its current normalized disk hash also matches. Its REJECT remains attributed to a77f705. This adjudication and the primary's disposition do not rewrite that critique.

## B ? M1 adjudication

`git diff a77f705 8e38d98 -- tests/responsive_images.py` changes only the index hash constant and its explanatory comment. The actual stripped Git index hashes to `35a8495127d2da4ce6061e77092fb46682e5a7c5d34ec5c88f2646985f3db1f5`. Catalog remains `672886e25c2de0535b5265f9e105d63f1acbb50eeefceb6f8cebc79328268c92`.

The exact-byte assertion, original and derivative image hashes, dimensions and source/dist parity checks remain. This corrects the expected representation without relaxing layout integrity.

Git product diff a77f705..8e38d98 is empty. The app, index and locale Git blobs also remain identical from 8523523 to HEAD. The earlier snapshot correction changed exactly app.js, index.html and locale-en.js manifest entries.

CI-IMAGE-LF-FIX records baseline exit 1, corrected exit 0, substituted-index negative exit 1 and restored exit 0. I inspected the substitution script and receipt; I did not rerun that mutation or access private logs.

CI-HEADERS-LF-FIX records Linux run 42173233401 at exact `8e38d98dca394d0730ddd830ecd55bc834dbf366`, with jobs 127745691382 and 127745813085 successful. This is historical receipt evidence, not a fresh GitHub read. It predates M2 and cannot establish CI success for 2bf3635.

## C ? M2 adjudication

The two added `.gitattributes` rules explicitly enforce LF for canonical and dist `_headers`.
For each path I ran:

`git -c core.autocrlf=true cat-file --filters --path=<path> HEAD:<path>`

Both outputs are 486 bytes, zero CRLF, SHA256 `503d49f3f495ee3001ae78d8db6ca666bbe424cfa962ba4244348000943e907f`. This independently verifies Windows checkout-filter behavior without modifying the checkout.

The verifier now guards `rel in controls` as well as top-level HTML/JS/CSS. The CRLF assertion runs before the sole manifest write. Source/dist RAW equality still runs first. `_headers` remains required and included in the recorded set and exact-byte comparison.

The existing regression now includes `_headers`. It supplies matching CRLF canonical/dist bytes, requires the CRLF assertion, and compares the manifest to frozen bytes after refusal. Existing one-sided header tamper, matching two-sided tamper, extra-path and missing-control assertions remain. The correction weakens no integrity assertion.

The primary receipt records original Windows snapshot exit 1, expanded regression exit 1 before correction, then regression exit 0 and static headers exit 0. Before-filter evidence records 495 bytes / 9 CRLF / hash `7585293acbbcf9e7ed8a35b80bbaa9b92af00ecf90127afb69b2830d7384590f`. These historical observations were not re-executed by this judge.

Fresh judge execution:

- `python tools/verify_release_snapshot.py`: exit 0. All 1,559 recorded entries match RAW bytes; all 1,560 dist files match canonical inputs; 47 pages / 40 products / 120 variants.
- `python tests/static_headers.py`: exit 0, 2/2 tests.

No fixture suite, recorder invocation or mutation run was needed to duplicate primary evidence.

## D?F ? Scope and evidence limits

`git diff --name-status 8e38d98 HEAD` shows only checkout policy, verifier, its regression, current status/review documentation, the preserved critic and a progress receipt. An explicit protected-path diff is empty for src, build-inputs, dist, evidence, historical CANDIDATE.json and primary/ARTIFACTS.json. Thus app/header/media/recorded-snapshot Git bytes and those historical manifests are unchanged.

The 28-binding check, checkout-filter checks and Git equality scripts all exited 0. They used Python hashlib, pathlib, JSON and subprocess with checked Git exits. No source normalization or file rewrite was performed.

The selected Jason frontend / Denis images contract is explicit in SELECTED-REFERENCE.md. The supplied pointer to D-030 in docs/DECISIONS.md is absent at this SHA; the selected-reference document and task supply the decision. This indexing discrepancy does not reopen visual selection or block portability adjudication. D-008/D-009 still require real card capability and provider selection for production.

Historical browser recordings and Gemini pixel review remain historical local/synthetic evidence. I ran no browser, API, SQL, Docker, certificate, live-provider or production checks. No new browser run is required for these unchanged app bytes. No install, full suite, staging, commit, push, PR, merge or deploy occurred.

## G ? Primary acceptance gate and next action

Primary must read run [42175006747](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42175006747), verify headSha equals the candidate, and require both publication integrity/build and historical portable regressions to finish successfully. An earlier green job or in-progress run is insufficient. I used zero GitHub reads; current completion is unknown here.

The task packet reports SYNCED, remote Tony at this SHA, and progress documentation/digest runs 42175006706/42175006693 successful. Those publication claims were not independently read back by this judge and do not substitute for the snapshot workflow.

Remaining gate owner: primary. Shortest correction: obtain exact-SHA completed CI readback; if failed, inspect its failed step and correct only the evidenced defect. Completion check: both required jobs successful for 2bf3635, exact report bytes verified during serial import, and primary records its own acceptance. No source correction is presently requested.

Lesson applied: compare committed blobs, transformed checkout bytes and RAW release bytes separately. The independent filter and snapshot checks close the local portability claim without inflating historical CI into current acceptance.

# REVISE — corrected runner source review

Task: `savia-runner-corrected-review-754b67e-20261107`.
Advisory verdict only. F2, F5, F7 and their F10 regression coverage need revision.
The deliberate image stop is correct and remains required.
This review grants no runtime permission or production acceptance.

## Identity and exact source

Host: `SUAZO-PC`. Harness: T3 Code / Codex.
Requested model/effort: `gpt-6-astra/xhigh`.
Runtime context and fresh agent-awareness expose the same model/effort.
Provider-internal effort, token usage and USD cost are unknown.
No delegation, provider substitution or additional paid service was used.

Managed checkout: `C:/Users/Jason/.t3/worktrees/github/t3-392ab4d9`.
Branch: `t3/review-corrected-runner-safety`.
HEAD: `754b67eedd70d4234db950f53262d652b83d616c`.
Initial Git status was clean. No other checkout or private log was read.
Applicable project instructions, orchestration, task-completion, evidence-first and coordination rules were read.
Agent-awareness identified this assigned task in this checkout; other harness processes do not establish overlapping ownership.

Personally verified **6/6 bindings** against `RESULT.json`, supplied frozen hashes and `git show HEAD:<path>`.
Only CRLF was normalized to LF; no BOM was stripped. All six files had no UTF-8 BOM.
Working-tree RAW hashes differ because of CRLF; every LF hash equals its Git blob hash.

| File | LF/Git SHA256 |
| --- | --- |
| tools/run_local_validation.py | 659a78a24b2000cf067a465a16b4f1b1b25d68671cda013538f367f368926f2f |
| tools/local-validation/Dockerfile | 86c65a020b06cf3706debff26b181fc8af3e3aacab43c682c399ae1a8225a0e4 |
| tools/local-validation/run-stage.sh | a68e165dcf7f613ae718ef67294a20d45d74327e74d2945416e9d1090d2fed3c |
| tools/local-validation/safety.py | 97eaaba1c8a343af18c44f16334042813110b0bc1cbcc7d52aec924c63cd1069 |
| tools/local-validation/evidence_gate.py | a6f366d76e07578793ed0f2bdb8293a65f8b7aa689e081de92b57df5822f4eb0 |
| tools/local-validation/test_run_local_validation.py | 17cd1bcacb72176309b6d2d83e606df3daa127ec49aab3f1e1780e7e896330c7 |

## Material findings

These are source/control-flow findings. The proposed additional counterexample probes did not execute; they are not reported as reproduced runtime failures.

**R1 — High, F5: a completed log write can bypass an exhausted stage budget.**
`tools/run_local_validation.py:291-297,228-234`; `tools/run_local_validation.py:166-171`.
`run_stage` checks the deadline before transport and before writing, but never after the log write.
If the final C71 write crosses C's deadline, execution returns normally and creates a fresh D deadline.
The same boundary exists between build and C, and D and E.
This exceeds the acknowledged inability to interrupt filesystem calls: the missing post-write check permits dependent dispatch after exhaustion.
Minimal correction: check the shared deadline after persistence and before each stage-budget transition.
Closure check: advance a fake clock past the budget inside the final stage-log write; the next stage must receive zero calls.

**R2 — High, F7: cleanup can classify unproved absence as absent.**
`tools/local-validation/safety.py:167-174`; `tools/local-validation/test_run_local_validation.py:118-120`.
Removal's nonzero exit is ignored. Successful listing output has no required-field validation.
A row `{}` therefore counts as no match and yields `absent`.
An abbreviated ID also fails equality with the captured full ID; a surviving resource renamed after verification evades the fallback name comparison.
The listing command omits `--no-trunc`; the fake always emits complete IDs.
This is a source-derived failure scenario, not an observed Docker failure.
Minimal correction: require valid authoritative full-ID listing/readback; malformed or inconclusive evidence must remain `unknown`.
Closure checks: failed removal with a renamed surviving ID, abbreviated IDs and malformed rows must never produce an absence/PASS claim.

**R3 — High, F7: interruption can leave a false PASS receipt.**
`tools/run_local_validation.py:248-279`; `tools/local-validation/safety.py:160-176`.
`KeyboardInterrupt` and `SystemExit` bypass `except Exception`, but still enter `finally` with `failure=None`.
If retention and cleanup succeed after an interrupted C1, the saved `result.json` can say `PASS` despite unfinished stages.
Python still propagates the interruption; this does not imply a successful CLI exit.
An interruption during cleanup also escapes its per-resource handler and skips remaining attempts.
Minimal correction: record interruption as non-PASS before finalization; preserve/re-raise it after bounded independent cleanup.
Closure checks: interrupt C1 and the first cleanup operation; retain the original failure and attempt remaining owned cleanup without any PASS receipt.

**R4 — Medium, F2: duplicate detection compares spelling instead of extraction destination.**
`tools/local-validation/safety.py:64-72,87-105`.
With corresponding allowlist entries, `backend/x` and `backend/./x` pass raw-name uniqueness and hash checks but address the same file.
`safe_name` constructs a normalized `PurePosixPath`, yet `seen` and membership comparisons use `m.name`.
The local Python tar implementation checks containment, not uniqueness (`tarfile.py:754-769,2387-2400`).
Ordinary Git export does not introduce the dot alias; this is an incomplete adversarial archive contract, not demonstrated outside writing.
Minimal correction: require canonical allowlist/member names and reject duplicate destination identities, including Windows case aliases.
Closure check: equivalent file paths must fail before extraction; ordinary 0644/0755 archives must still pass.

## F1–F10 disposition

Abbreviations: R=`tools/run_local_validation.py`; S=`tools/local-validation/safety.py`; G=`tools/local-validation/evidence_gate.py`; H=`tools/local-validation/run-stage.sh`; T=`tools/local-validation/test_run_local_validation.py`.

| Check | Disposition and direct evidence |
| --- | --- |
| F1 | Source correction accepted with limits. S:109-158 requires creation receipt, nonce/scope labels and ID/name verification. R:242-245 guards restart. Ambiguous creates remain unknown. R:276 explicitly retains the shared image; no owned image/cache deletion. Cleanup evidence defect is R2. |
| F2 | REVISE R4. S:75-105 otherwise uses regular/directory types, mandatory data filter, allowlist hashes, sparse/special rejection and fresh non-link ancestors. T:209-218 exercises ordinary/hostile archives. |
| F3 | Source correction accepted subject to R4. R:75-123 binds explicit SHA, clean source, reviewed blobs, runner/helper and qualification evidence; R:188-198,224-227 exports Git bytes and uses an immutable image ID. No mutable tag/build context dispatch. Actual dependency closure remains pending. |
| F4 | Retained gate accepted. Dockerfile:6-9 deliberately aborts. R:100-121 requires receipt/dependency evidence; R:310-315 never reports READY or successful execution. No image readiness accepted. |
| F5 | REVISE R1. S:17-32 and R:182-247 share prep900/C1500/D1200/E900 deadlines, including C1+C71 and E transport/restart/readiness. R:252-273 and S:160-179 provide separate finalization allowances. Filesystem post-check gap remains. |
| F6 | Source correction accepted; real Windows qualification pending. S:40-61 rejects links, insecure ownership/DACL/inheritance; R:125-171 checks private identity before writes. R:187,203-218 puts privacy before secrets/Docker mutation. No ACL mutation. T:172-174,246-253 is simulated evidence only. |
| F7 | REVISE R2/R3. Ordinary Exception paths, independent retention and ownership cleanup improve substantially (R:248-279; S:160-179). Unknown/interrupt handling is not complete. |
| F8 | Source/offline accepted. R:238-245 creates exact destination, copies contents and validates before restart. G:55-90 requires one release JSON, successful exact TRX and source/nonce/hash receipt. T:191-196 verifies zero restart on invalid evidence. |
| F9 | Source/offline accepted. H:40-53 gates C71 through G:34-48 and the frozen verifier's exact multiplicities/unique identities. H:53,76 retains C77/E2; H:57 retains both D flags. Manifest confirms C1 six methods/cases, E two; no A552 dispatch. |
| F10 | PARTIAL. T:76-158 models state/argv/environment; T:160-263 tests ordering, timeouts and failures; T:266-323 retains nine old-defect controls. Full listing IDs, transport-only clock advancement and Exception-only controls miss R1-R4. Extend those controls before acceptance. |

## Executed evidence and limits

Personally executed once: `python tools/local-validation/test_run_local_validation.py`, exit **0**, **39/39**, **1.736s**.
`PYTHONDONTWRITEBYTECODE=1` avoided import-cache writes.
Adapter inspection preceded execution: both test classes deny `subprocess.run`; fixtures replace Git, Docker and privacy adapters. The real-adapter denial test passed.
These are nine old-defect controls plus thirty corrected fake-process tests, not SQL proof.

Second and final check invocation: `python -` with an in-memory probe harness.
Exit **1** before any probe: `ImportError: cannot import name 'ExitStack' from 'unittest.mock'`.
Cause: reviewer imported `ExitStack` from the wrong module; it belongs to `contextlib`.
No retry: the two-invocation limit was reached. All five planned additional probes are **NOT RUN**.
Primary owns any newly authorized corrected probe execution and regression confirmation.

Recorded history only: worker39/39 in 2.338s (`RESULT.json`); primary39/39 in 44.309s (`PRIMARY.md`). Private logs were not accessed.

NOT RUN: actual runner/plan CLI, shell campaign, Docker/SQL/browser, build/restore, installs/network, real Windows DACL qualification, CI, A552 or production.
No source correction was attempted: this assignment permits only this report.
Dependency closure/trust/licenses, qualified image, private destination and explicit runtime authorization remain prerequisites owned by primary/Jason.
Their closure requires reviewed dependency/image evidence, actual protected-destination proof and separately authorized C77/D/E2 outcomes.

Next action: primary independently verifies R1-R4, assigns minimal corrections and missing regression controls, freezes new bytes and requests bounded re-review.
Lesson: successful simulated stages do not cover persistence, cancellation or resource-listing boundaries.
Only this assigned report is delivered; final changed-path readback and RAW/LF hash accompany the return.
The primary retains serial integration and overall project closure.

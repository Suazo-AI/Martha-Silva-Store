# ACCEPT WITH LIMITS

Advisory review: `savia-partition-recheck-5f671dd-20261106`, 2026-11-06.
F1/F2/F3 are corrected on the reviewed source.
No remaining material finding was reproduced within the frozen scope.
Primary owns integration and final acceptance.
Production readiness is not established.

## Identity and scope

Host: `SUAZO-PC`, Windows; Python `3.11.9`.
Harness/provider: T3 Code / Codex.
Model and effective effort: `gpt-6-astra/xhigh`, exposed by the session runtime and corroborated by agent-awareness.
No nested agents, alternate models or new dispatch were used.

Reviewed HEAD: `5f671dddf1ce25d5bef6669bb44e073f8c28f0ca`.
Its direct parent is `460c7720da51fa4689b7898c5f779a6555c60d7b`.
Branch: `t3/review-partition-corrections`.
The checkout was initially clean.

Compared only `backend/tests/verify_full_suite.py` and `backend/tests/test_verify_full_suite.py` against that parent.
Read the specified public sources and evidence, including AGENTS, AGENT-START, PARTITIONS, both prior review/correction documents and PRIMARY-ACCEPTANCE.
Applied the readable canonical evidence-first playbook and OUTPUT.md.
The accepted C# correction and other product files were excluded.

## Source bindings

All three `CORRECTIONS.json.sourceBindings` match both exact committed blobs and LF-normalized checkout bytes.
The recorded sourceBase matches the verified parent.
The historical judge-report digest also matches its recorded source.

| Path | Verified LF SHA256 |
| --- | --- |
| `backend/tests/verify_full_suite.py` | `196a69c742b0cf9aa5619278626a8874877a196043b8bcacbebca1ce79088ead` |
| `backend/tests/test_verify_full_suite.py` | `94257dfacd0c3ffd57b77e19496045de7ecce291e70abbd5d61afe234383c144` |
| `docs/local-validation-20261106/PARTITIONS.json` | `d2feccd4c8af3b8358865b1bc23e15e287a28f852e4e70b3357a7d4f39caaad8` |

Checkout CRLF explains the different RAW source hashes.
No historical evidence or source was rewritten.

## Findings adjudicated

**F1, previous P1 — CLOSED.**
Location: `backend/tests/verify_full_suite.py:27`, `:103`, `:111`.
The UUID parser plus canonical-string comparison requires standard GUID shape.
Both modes canonicalize test IDs before deduplication.
Partition mode also canonicalizes each nonempty execution ID.

Reproduction: synthesize all frozen A methods and 552 occurrences.
Select two occurrences of one repeated method.
Assign equivalent lowercase/uppercase GUIDs to their test IDs while keeping execution IDs distinct.
The real CLI exits 1 with `duplicate test case`.
Repeat with distinct test IDs and equivalent execution IDs.
It exits 1 with `duplicate execution identity`.
Standalone legacy rejects equivalent test IDs too.

Hyphen-only, unhyphenated, braced and URN GUIDs are rejected in both test-ID modes and partition execution IDs.
Mixed uppercase/lowercase valid identities pass.
Missing execution IDs remain permitted.
These observations close acceptance checks 1–2.

**F2, previous P2 — CLOSED.**
Location: `backend/tests/verify_full_suite.py:159`.
Five invalid CLI combinations exit 2 and create no report:
manifest alone, manifest plus minimum, partition alone, partition plus minimum, and complete partition mode plus minimum.
Standalone `--min-tests 2` passes a valid two-row fixture.
Complete partition commands remain accepted.
Acceptance check 3 passes.

**F3, previous P2 — CLOSED.**
Location: `backend/tests/verify_full_suite.py:173` and `:182`.
Both legacy and partition entry points were exercised with captured JSON, stdout and stderr.

For input errors, a child-process `Path.glob` wrapper enumerates and then deletes only fresh synthetic TRX files.
The actual parser encounters FileNotFoundError.
Both modes exit 1 with constant reason `unreadable TRX evidence`.
A nonexistent synthetic manifest produces constant `malformed partition manifest`.

Separate child-process hooks raise marked OSError from mkdir and report write.
Both modes exit 1 with exactly `Evidence output unavailable.\n` on stdout and empty stderr.
A native regular-file/directory collision independently confirms the output-directory handler.

Six fault-injected children execute the actual script through `runpy.run_path(..., run_name="__main__")`.
The remaining 33 subprocess probes invoke the script directly.
Every probe checks captured outputs and any JSON for the marker, fixture path, traceback and raw OS diagnostics.
None leaked.
Acceptance check 4 passes.

## Independently observed evidence

Two focused top-level stdlib Python invocations were used.
Administrative agent-awareness checks are separate.

1. `python -m unittest discover -s backend/tests -p test_verify_full_suite.py`
   — exit 0; 21/21 tests, zero failures/errors/skips; 0.267 seconds.
2. `python -B -`, supplied one bounded combined probe through a PowerShell here-string
   — exit 0; 39 subprocess assertions passed; 5.656 seconds.
   Five children correctly exited 0, 29 exited 1, and five exited 2.

The combined probe independently generated fixtures from the frozen manifest without importing verifier fixture helpers.
Accepted exact dictionaries: A 195 methods/552 cases; C 77/77; E 2/2.
Missing occurrence, extra occurrence, wrong method at unchanged count, Failed and NotExecuted controls all exit 1.
Thus checks 5–6 pass within the reviewed paths.

The seven primary CLI claims were independently repeated among these 39 probes.
Primary's 21-test claim was independently repeated.
Historical private logs and their RAW digests were not inspected.
The old red log's secondary artifact assertion was not treated as another defect.

`git diff 460c7720da51fa4689b7898c5f779a6555c60d7b 5f671dddf1ce25d5bef6669bb44e073f8c28f0ca -- backend/tests/verify_full_suite.py backend/tests/test_verify_full_suite.py` exited 0.
A final scoped checkout diff against HEAD exited 0.

## Limits and next primary action

All fresh fixtures were synthetic and temporary.
These checks are not backend, SQL, browser or recovery executions.
Real C77/D/E2 and the six historical SQL failures remain NOT RUN.
The prior A runtime acceptance was read as primary evidence, not re-executed here.

No full repository checks, installation, .NET, Docker, services, credentials, certificates, security changes or remote queries occurred.
CI remains the supplied snapshot: Progress documentation/digest success; Staff UI and Tony snapshot in progress.
Current completion is unknown.
Acceptance check 7 is preserved.

No review blocker remains.
Existing runtime blockers were not investigated or corrected because this task excludes that authority.
Their concrete owner/action remains PRIMARY-ACCEPTANCE: Jason opens Docker Desktop; primary verifies readiness before authorized runtime work.
That handoff does not establish readiness or resolve historical SQL failures.

Primary should inspect and integrate this report serially, bind acceptance to the reviewed SHA, and assess applicable CI independently.
No staging, commit, push, PR, merge or deploy was performed.
Only this report is the lasting review artifact.

Lesson confirmed: identity-equivalence, invalid-mode and OS-error controls catch failures that exact green counts alone cannot exclude.

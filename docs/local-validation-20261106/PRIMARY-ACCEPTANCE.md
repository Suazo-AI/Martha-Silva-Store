# Primary acceptance: offline partition A

Host: SUAZO-PC. Primary: T3 Code / Codex, gpt-6.1-sol, xhigh.
Base: `0f786c3f2a747115b5cae90957b17a959f357298`, plus the three-file fingerprint overlay in `source-bindings.json`.

Accepted: backend partition preparation, the focused nine-case result, and offline A coverage with one targeted environment retest.
This does not accept the six historical SQL failures as fixed, the complete backend runtime, or production.

## Independently verified

- Five artifact hashes match the worker's frozen manifest.
- Eleven LF source bindings match both worker and canonical checkout.
- The private TRX hash matches RESULT.json; all nine result rows are Passed.
- The inventory has 274 unique method names and 631 case occurrences.
- The disjoint backend groups sum to A552 + C77 + E2 = 631.
- Twenty-two frontend/browser bindings match the unchanged canonical sources.
- Six public files were copied byte for byte into this directory.
- Unrelated AGENTS.md and docs/DECISIONS.md were preserved.

Private readback: `C:/Users/Jason/MARTHA-SILVA/test-runs/local-validation-20261106/primary/import-verification.json`.
Runtime discovery and theory multiplicities are accepted as preparation. Exact executed case coverage still requires final TRX comparison.
The original worker files remain frozen. This note is the current primary interpretation.

## Offline A acceptance

The worker executed all 552 occurrences: 551 Passed, one Failed, zero skips; exit 1.
Primary independently parsed the private TRX and verified its recorded SHA256.
All 195 method multiplicities matched partition A. All 552 test IDs and execution IDs were unique.
No C/E methods ran. Truncated theory labels retain the argument-identity limitation in the worker report.

The failed method was `PrivatePilotReleaseTests.Offline_current_release_scripts_are_context_isolated_without_model_drift`.
Its `DirectoryNotFoundException` identified a missing `SAVIA_PILOT_EVIDENCE` directory.
The direct source generates SQL scripts offline and writes them into that directory.
This was worker environment preparation, not a reproduced product defect.

Primary precreated a new private directory and repeated only that method using the existing Release assembly.
The command used `dotnet test --no-build --no-restore -c Release --filter FullyQualifiedName=...`.
Result: one Passed, zero failures/skips, exit 0, 6.231 seconds; three nonempty SQL scripts generated.
The assembly hash and eleven source bindings remained unchanged. All 105 backend input files matched canonical LF bytes.
The six SQL variables were removed only from the child environment. No SQL, Docker or service command ran.

Accepted coverage is 551 original passes plus one targeted replacement pass, matching all 552 expected occurrences.
There is no new single all-green 552-result TRX. The original failure and all private diagnostics remain preserved.
The original worker's request for another whole A attempt is superseded by this bounded primary acceptance.
No product or test source changed to resolve this environment failure.

Exact command, hashes and counts: [PRIMARY-A-RESULT.json](PRIMARY-A-RESULT.json).
Frozen worker evidence: [offline-A/RESULT.json](offline-A/RESULT.json).
Private verification: `C:/Users/Jason/MARTHA-SILVA/test-runs/local-validation-20261106/primary/offline-A-import-verification.json`.

Measured worker build: 212.155 seconds. Original A execution: 38.220 seconds. Targeted retest: 6.231 seconds.
Reusing that build avoided another compilation. No general parallel speedup is claimed.
Lesson: precreate evidence directories before execution; retry the failed test when source and compiled bytes are unchanged.

## Authorization clarification

Jason requested local testing and independent chunks. That mandate remains active.
The one-preflight limit was the worker's execution budget; it is not a new project-wide permission expiry.
No repeat connection is useful until its cause changes. Certificate, trust, account, transport and shared-service changes still require their existing authorization.

## Open blockers

### Existing SQL instance

Evidence: the worker's one strict ODBC18 connection to shared-memory SAVIATEST failed before executing its query.
Error: `The certificate chain was issued by an authority that is not trusted.`
The six real SQL regressions remain NOT RUN. No database inventory was obtained.

Primary attempted a read-only registry inspection. SuperSocketNetLib reported an empty Certificate setting and ForceEncryption=0.
Reading MSSQLServer/Parameters failed with `Requested registry access is not allowed.`
An empty setting does not identify the certificate actually served. No log or certificate-chain conclusion is inferred.
No elevation, alternative access to the denied parameters, trust change or service restart was attempted.

Owner: primary/Jason for an authorized certificate investigation or an isolated local test runtime.
Completion: a verified connection under the chosen approved trust policy, followed by six executed/passed cases, zero skips and database preservation/cleanup proof.

### Local Linux runtime

Evidence: Docker info exited 1 because `dockerDesktopLinuxEngine` was absent. Docker Desktop is installed.
The attempt to launch Docker Desktop with Start-Process was rejected by automatic approval review: `blocked by policy`.
The rejected composite command did not run. Its independent artifact verification was then performed separately without launching Docker.
No alternative launch route was attempted.

Owner: Jason opens Docker Desktop. Primary checks prerequisites after it is ready.
Manual action: open Docker Desktop from the Start menu and wait until its engine is running.
Completion check: `docker info --format '{{.ServerVersion}}'` returns a nonempty version with exit 0.
This check alone does not prove image availability, Linux runner readiness, SQL, or the full journey.
Only owned disposable test resources may be restarted; SAVIATEST must remain untouched.

### Remaining independent execution

A552 coverage is accepted through the original run and targeted environment retest described above.
B retains historical source-bound evidence; it is not a fresh browser run.
C77, the combined journey D, and recovery E2 remain NOT RUN for this candidate.
The 42.962-second measurement includes compilation and the focused nine cases; no speedup is claimed.

Next action: Jason opens Docker Desktop; primary verifies engine readiness and the local Linux runner prerequisites for C/D/E.
Preserve raw diagnostics privately before any task-owned cleanup. Keep review and integration acceptance separate from runtime success.

## Publication verification

`python tests/test_progress.py`: 23 tests, exit 0.
`python tools/export_progress.py --verify`: 15 preserved evidence hashes, exit 0.
Full Windows repository verification is not claimed. Its known symlink-fixture blocker is `WinError 1314`.
No host privilege change was attempted. Primary owns its Linux verification after the local runtime becomes available.
Only owned test/evidence paths enter this publication; unrelated AGENTS.md and docs/DECISIONS.md remain excluded.

## Independent review and exact chunk verifier

Primary accepts Astra's `ACCEPT WITH LIMITS` for the three-file fingerprint correction at `857bea1`.
The imported report matches RAW SHA256 `c106f7901755c799e7505111e7be5fe2cb6682f6d37a7aa8fb8f29a5d95ecda4`.
The judge independently checked source, historical TRX evidence and A's targeted replacement.
No SQL runtime conclusion follows from this acceptance.

OpenCode/DeepSeek returned an optional exact-partition mode in the existing TRX verifier.
Primary inspected both changed Python files and verified all three recorded LF bindings, including the unchanged manifest.
Four executor artifacts and the judge report were imported byte for byte; see [IMPORT.json](partition-verifier/IMPORT.json).
On the integrated bytes, `python -m unittest discover -s backend/tests -p test_verify_full_suite.py` passed 16 tests, exit 0.
Publication checks: `python tests/test_progress.py` passed 23 tests, exit 0; `python tools/export_progress.py --verify` checked 15 preserved hashes, exit 0.
The scoped `git diff --check` passed. No full Windows repository gate or SQL runtime is claimed.
Those tests include an intact synthetic 552-case inventory and rejection after one missing occurrence.
They also exercise the existing full-suite behavior, missing/extra methods, failed/skipped rows, duplicate test IDs and malformed manifests.
These are verifier tests, not 552 newly executed backend cases.

The Python change is published as a review candidate. Independent Astra/xhigh adjudication is still pending.
The earlier Astra fingerprint verdict does not review this newly imported Python change.
No acceptance criterion, frozen partition, product source or workflow was changed.

Fresh runtime check: `docker info --format '{{.ServerVersion}}'` still exits 1 because `dockerDesktopLinuxEngine` is missing.
No Docker launch or alternative launch route was attempted. Jason owns opening Docker Desktop; primary owns readiness verification afterwards.
C77, D and E2 remain NOT RUN. The six historical SQL failures remain unexplained by runtime evidence.
[Current routing, prerequisite evidence and manual alternatives](LOCAL-CONTINUATION.md).

## Partition review correction, 2026-11-06 local

Astra returned REVISE on `460c772`: equivalent GUIDs can bypass duplicate checks; incomplete CLI mode ignores the manifest; filesystem diagnostics can enter public output.
Primary reproduced and accepts those findings. The previous partition candidate is rejected; its 16 green tests were insufficient.
Small serial review corrections now pass 21 focused tests and seven synthetic CLI probes. A new independent Astra/xhigh review is pending.
The accepted C# fingerprint correction remains separate and unchanged.
[Corrections, evidence, limits and Docker handoff](partition-verifier/CORRECTIONS.md).
All four CI workflows on the earlier `460c772` succeeded. Corrected bytes need their own CI.
C77/D/E2 and the six historical SQL failures remain untested. Production remains NO-GO.

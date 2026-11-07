# REVISE — optional partition verifier

Advisory verdict for `savia-partition-judge-460c772-20261106`, 2026-11-06.
Two false-success paths and one inherited diagnostic leak violate the frozen checks.
Primary owns final acceptance. Production remains NO-GO.

## Identity and source

Host: SUAZO-PC / Windows. Harness: T3 Code / Codex. Model: `gpt-6-astra`.
Requested effort: `xhigh`. Effective effort: `xhigh`, reported by the session runtime and agent-awareness metadata.
Usage and cost: unknown.

Reviewed HEAD: `460c7720da51fa4689b7898c5f779a6555c60d7b`.
Verified parent: `857bea105fe1dfa045114a5569ba5cb4c31b3391`.
Compared only `backend/tests/verify_full_suite.py` and `backend/tests/test_verify_full_suite.py` against that parent.
Read the specified instructions, manifest and evidence directly. No C# re-audit.
Local Git objects establish the reviewed version; remote publication was not independently queried.

## Material findings

### F1 — P1: equivalent GUIDs bypass duplicate rejection

Path: `backend/tests/verify_full_suite.py:93-102`.
The sets compare identity strings without canonicalizing GUIDs.
The test-ID comparison is inherited; the new execution-ID comparison repeats the weakness.

Concrete reproduction: generate the frozen A inventory as 552 Passed TRX rows with unique GUIDs.
Choose two rows of `Martha.Store.Api.Tests.GuardTests.Database_guard_rejects_before_any_connection_is_opened`.
Give the first row these identities:

```text
testId=abcdef00-0000-0000-0000-000000000001
executionId=fedcba00-0000-0000-0000-000000000001
```

Replace the second row with a copy of the first, uppercasing both identity strings.
Keep its method and outcome unchanged. Invoke:

```powershell
python backend/tests/verify_full_suite.py --manifest docs/local-validation-20261106/PARTITIONS.json --partition A <fixture-dir>
```

Observed through `main(argv)`: exit 0, `status=passed`, `cases=552`.
Independent `uuid.UUID` canonicalization finds only 551 unique test IDs and 551 unique execution IDs.
The control with byte-identical duplicate IDs exits 1, `duplicate test case`.

Impact: a repeated execution replaces a missing theory occurrence while the exact partition gate succeeds.
Fix: validate and canonicalize GUIDs before deduplicating test IDs and nonempty execution IDs.
Add a regression that rejects this fixture while retaining valid 552-case acceptance.

### F2 — P2: an incomplete CLI combination silently ignores the manifest

Path: `backend/tests/verify_full_suite.py:147-159`.
Use one Passed row for the first frozen A method and invoke:

```powershell
python backend/tests/verify_full_suite.py --manifest docs/local-validation-20261106/PARTITIONS.json --min-tests 1 <fixture-dir>
```

Observed: exit 0, `status=passed`, `cases=1`; no `partition` or `expectedCases` fields.
The manifest is never loaded. This is legacy-mode success, not an explicit partition success, but the invalid mixed invocation exits successfully.
Impact: omitting `--partition` silently removes the requested manifest coverage constraint.
Fix: require `--manifest` and `--partition` together; reject either with `--min-tests`.
Add this negative CLI regression. Preserve the standalone `--min-tests N` invocation.

### F3 — P2: filesystem exceptions enter public evidence

Path: `backend/tests/verify_full_suite.py:161-178`.
This behavior already exists in the parent; the new partition path retains it.

Concrete reproduction: create a valid E TRX named `SYNTHETIC_ONLY_SECRET_MARKER.trx`.
Using a stdlib `Path.glob` wrapper, collect the real file list, delete that disposable file, and return the collected list.
This deterministically models disappearance between enumeration and parsing; no denied access was induced.
Invoke `main` with the frozen manifest and `--partition E`.

Observed: exit 1, but both `sanitized-results.json` and stdout contain the marker and raw `[Errno 2]` exception text.
Impact: an ordinary filesystem race exports its diagnostic message and input path, violating frozen check 5.
Fix: publish a constant sanitized reason for `OSError`; keep diagnostic details outside public artifacts.
Add an exception-path sanitization regression. Existing argument/output sanitization is insufficient for this path.

## Verified evidence and acceptance checks

- Check 1: the legacy path remains usable. Its existing failure, skip, duplicate-string, minimum-count and normal sanitization tests pass. F3 is an inherited limitation.
- Check 2: independently matched exact dictionaries: A 195 methods/552 cases; C 77/77, including C1 and C.*; E 2/2. B/D remain excluded. Synthetic C77 and E2 fixtures exit 0; these are not runtime tests.
- Check 3: missing/extra methods, wrong multiplicity, failed/skipped rows and identical duplicate IDs are rejected. Equivalent GUID identities still bypass rejection: F1.
- Check 4: malformed manifests in the existing tests are rejected. Missing manifest, manifest without either mode, mixed partition/minimum, and partition D each exit 2. F2 is the reproduced exception.
- Check 5: ordinary argument, StdOut, message and trace markers are absent from JSON/stdout. The exception path fails: F3.
- Check 6: all three worker LF bindings match exact committed blobs and LF-normalized checkout bytes. All five IMPORT entries match recorded LF hashes. Three imported document blobs match recorded RAW hashes; the two Python RAW hashes match CRLF checkout bytes and are reproducible from their LF blobs. Git newline conversion explains the differences.
- Check 7: reviewed documentation separates synthetic verification from runtime. This verifier does not fix the six historical SQL failures or establish C77/D/E2 runtime.

One independent unittest discovery run passed 16/16, zero errors/failures/skips, in 0.216 seconds.
Invocation: `python -B -`, using `unittest.defaultTestLoader.discover('backend/tests', pattern='test_verify_full_suite.py')` and `TextTestRunner`.
The same final stdlib invocation exercised the probes above; exit 0 means the probe assertions held, including the reproduced defects.

Two focused invocations total. The first stopped before tests because my hash reader treated the `algorithm` metadata key as a path: `fatal: path 'algorithm' does not exist`.
The second skipped that metadata key and completed binding checks, the sole unittest run and focused probes.

Primary's recorded integrated 16/16, progress 23/23 and 15 preserved hashes remain separate evidence.
Progress/export checks were NOT rerun. Synthetic A552 acceptance is not 552 newly executed backend cases.
NOT RUN: full suites, .NET, SQL, Docker, services, browser, CI, security changes or publication.

## Handoff

No source correction was attempted because this task permits only this report to be created.
Primary/executor owns F1–F3. Fix these three paths, add focused regressions, and verify a new exact SHA before accepting partition mode.
No branch/index mutation, commit, push, dispatch, merge or deployment occurred.
Lesson: include semantic identity and error-output controls alongside happy-path counts.
The report's SHA256 is returned separately to avoid a self-referential digest.

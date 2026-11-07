# Corrected partition verifier candidate

Primary accepted the three reproduced findings in [Astra's original REVISE](astra-judge.md).
Source base: `460c7720da51fa4689b7898c5f779a6555c60d7b`.
The original verifier candidate is not accepted. The corrected candidate awaits a new Astra/xhigh review.

- F1: parse standard GUIDs and canonicalize test IDs and nonempty execution IDs before duplicate checks. Reject malformed GUIDs.
- F2: require `--manifest` and `--partition` together, excluding `--min-tests`. Standalone legacy mode remains usable.
- F3: report constant reasons for input filesystem errors. Output filesystem errors return exit 1 with a constant message and no raw traceback.

`python -m unittest discover -s backend/tests -p test_verify_full_suite.py`: red exit 1 before the source fix; final 21/21, zero skips, exit 0.
The final tests isolate each invalid CLI invocation in its own directory. The original red log predates that refinement and includes a secondary artifact assertion.

Seven real CLI subprocess probes used synthetic TRX data: exact A552, C77 and E2 accepted; duplicate equivalent test GUIDs rejected; duplicate equivalent execution GUIDs rejected; incomplete manifest mode rejected; legacy mode accepted.
Those are verifier checks. They are not new backend, SQL, browser or recovery runs.
Input-error tests inject FileNotFoundError; output-error tests inject OSError. Neither public JSON nor captured output contains the synthetic diagnostic marker.

The previous SHA has four successful CI workflows. That is historical evidence, not CI for this corrected source.
The unchanged progress implementation retains its previous 23-test pass. Fresh export verification checked 15 preserved hashes.
The full Windows gate remains blocked by the known symlink fixture prerequisite, WinError 1314; it was not repeated.

Docker still reports `daemon-stopped`. Jason must open Docker Desktop normally. Primary must verify engine readiness before preparing local runtime.
No SQL, container, privilege, certificate or service mutation occurred. C77/D/E2 and reproduction of the six historical SQL failures remain NOT RUN.
No merge or deployment is authorized here. Production remains NO-GO.

Lesson: exact counts are insufficient. Test semantic identity equivalence, incomplete mode selection and diagnostic failure paths.

Bindings, process exits and private log hashes: [CORRECTIONS.json](CORRECTIONS.json).
Historical worker/import receipts remain unchanged and refer to their original source bytes.

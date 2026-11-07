# Final receipt correction: independent acceptance pending

Mode: BUILD. Host: SUAZO-PC. Primary: T3 Code / Codex, gpt-6.1-sol/xhigh.
Base: `457a1576cd782874d1b3159c08e958bac96482eb`.

## Reproduced and corrected

Primary accepts Astra's [R3.1 finding](../revision-2/astra-recheck.md) as a demonstrated evidence-persistence defect.
Three fresh controls against the base runner fail: KeyboardInterrupt, SystemExit and deadline exhaustion during final close leave a saved PASS.
Red: 3 failed / 0 passed, exit 1. The original interruption objects are preserved and simulated resources are absent.

The corrected writer closes `result.pending.json` before publishing `result.json`.
Only `result.json` is authoritative. A pending file, even when complete, is not an accepted result.
Publication uses an exclusive hard link; it cannot overwrite an existing destination.
A post-publication interruption or exhausted deadline removes only the matching owned inode after checking the private destination.
Final receipt work has a separate 20-second budget; invalidation has a bounded five-second privacy check.
Unsupported hard links fail closed. No image, container, SQL, privilege or certificate change is implied.

Fresh full offline suite: **55/55 PASS**, exit 0, 3.843 seconds process wall time.
It includes all prior 46 controls and nine new receipt tests.
Checks cover the three red cases, visibility before close, normal persisted/returned equality, commit interruption/deadline, unsupported commit, foreign-file preservation and original-interrupt precedence.
The full suite globally forbids real subprocess calls; Docker transport is stateful simulation.

Exact commands, raw/LF source bindings and private log hashes: [RESULT.json](RESULT.json).
Raw logs remain in ignored `private-exports/runner-receipt-20261107/`.

## Limits and next action

This is offline receipt behavior, not runner/image qualification, SQL persistence, cash acceptance or production readiness.
The tests do not simulate power loss, storage corruption or concurrent privileged tampering with the protected directory.
No durability guarantee across those events is claimed. No fsync/power-loss qualification was performed.
The original directory confidentiality and ownership checks remain required; the synthetic suite does not qualify a real destination.

Owner: primary. Next: freeze these sources, publish normally and obtain fresh Astra/xhigh review of R3.1.
Completion check: the judge verifies no authoritative PASS survives the bounded finalization faults and unchanged safety checks still pass.
Image/dependency qualification and a separately authorized real runtime remain open afterward.

Lesson: changing an in-memory result is insufficient once success bytes are public. Test the final filesystem boundary itself.

## Additional primary checks

`python tests/check.py`: exit `0`, 267.562 seconds. `python tests/test_progress.py`: 23/23, exit `0`. `python tools/export_progress.py --verify`: exit `0`, 15 preserved hashes. `python tests/test_delivery_status.py`: 24/24, exit `0`. `python tools/delivery_status.py --check`: exit `0`, 40 ledger items. Python compilation, the branch example JavaScript syntax check and `git diff --check`: exit `0`. Commands and log hashes are recorded in `RESULT.json`; raw logs remain ignored under `private-exports/runner-receipt-20261107/`.

The protected dirty files `AGENTS.md` and `docs/DECISIONS.md` remain unchanged by this task. These checks do not qualify Docker, SQL, cash operations, the runtime image, or production. Fresh Astra/xhigh acceptance remains pending.

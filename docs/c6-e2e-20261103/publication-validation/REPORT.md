# C6 publication validation — 2026-11-04

Verified on SUAZO-PC in `C:/Users/Jason/MARTHA-SILVA/github`. Canonical source and index were read only by this worker.

| Check | Result | Exact evidence |
|---|---|---|
| `python -B tests/test_progress.py -v` | PASS, exit 0 | 23/23; `Ran 23 tests in 228.214s`; process 229.679 s |
| `python -B tools/export_progress.py --verify` | PASS, exit 0 | `PASS: 15 preserved evidence hashes; no runtime executed.` |
| `python -B tools/delivery_status.py --check` | PASS, exit 0 | `Ledger: valid; 34 items.` |
| `git diff --cached --check` | PASS, exit 0 | Empty output; initial staged set |
| JSON old 17 vs new first 17 | PASS, exit 0 | Identical records; total 18; final record only b6bc0396 |
| `verify_import(b6, manifest_ref=c00)` | PASS, exit 0 | Frozen import/publication scan against real Git blobs |

The suite ran once after a launcher-only correction. Python inherited its environment; `PYTHONUNBUFFERED=1` was set only in the child before `os.execv(sys.executable, ...)`. Timeout was 600 s. The last case was `test_wrong_branch_or_remote_blocked ... ok`.

The manifest reference was `c00ae5e766f71defbaf2894bac20b2ea7e93a1de`. The existing 17 records were compared with `2ddf83de7a89da608e8267a21313d64b373bf5e2`. Only `b6bc0396bb7d53359d23b806a3177edc194c8e62` received a fresh `p.verify_import` scan, as root explicitly directed. Exact scripts, commands, timings, exit codes and sanitized case logs are in [checks.json](checks.json).

The first nonverbose suite and full 18-import scan reached the 90 s collector limit. Both are NOT PASS. Eight completed test dots did not identify a failure or a hang cause. The later PowerShell launcher could not resolve `python`; no test started. Its exit 0 is NOT RUN, not PASS. The corrected direct Python child completed all 23 tests. No passed gate was repeated.

Before the revised route, no owned Python/Git process was pending. Final readback found both owned launcher PIDs absent, zero direct Python/Git children, and zero Git processes. No process was signaled. No API, SQL, Docker or browser runtime was executed.

Root added authorized files while validation ran: first the C9 Trello receipt, then three sanitized historical CI files. The initial 23-path and intermediate 24-path states were observed; root reported 27 final paths. Index hashes are retained only to account for that activity. This worker did not write the index. Root owns the final whitespace check and publication tree.

Pending: root publishes the combined candidate and verifies real C6+C8 CI. These checks do not prove combined browser/API/SQL runtime success. No commit or push was performed here.

Lesson: distinguish collector limits and launcher failures from product results; preserve progress output and use a resolved interpreter with child-only environment.

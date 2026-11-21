# Cash journey preparation: candidate with limits

Task `savia-real-cash-preparation-20261108-01`. Status `PREPARED_WITH_LIMITS`, not acceptance.
Host SUAZO-PC; T3 Code through Codex; requested and runtime-exposed `gpt-6.1-sol/high`.
Usage/token telemetry is unknown. No delegates were started.
Worktree `C:/Users/Jason/.t3/worktrees/github/t3-784e36ee`, branch `t3/real-cash-harness`.
Actual base `54e76663cef0a43029dc87b7ecc27dcf9e8ec180`; no commits or remote mutations.

## Acceptance matrix

All seven source preparations are implemented. Runtime remains NOT RUN for every row.

| Check | Prepared control | Offline evidence |
|---|---|---|
| REAL-CASH-01 | UI opens till; two-article paid sale; tender/change DOM; authenticated `cash.mjs`; exact four migrations/23 tables; SQL request/result/row identity | Positive persisted-row fixtures and identity/amount mutations |
| REAL-CASH-02 | CDP drops only a real HTTP 200 response after headers/body; original pending key/body hash; exact original receipt/payment recovered through UI GET; no second POST | Lost-response/key/body/POST negative controls |
| REAL-CASH-03 | Real cashier request returns 403; Manager UI refunds original line/quantity/reason; persisted authorizer and paying cashier/till | Reversal/original-line/actor/till mutations; full checkpoint fixture |
| REAL-CASH-04 | Sum immutable SQL cash entries; expected 20550; counted 20450; shortage -100 | Ledger, tender, close, integer and zero-shortage negative controls |
| REAL-CASH-05 | Later refund pays from newly open same-location shift; previous close and Cashier2's 20000 till remain unchanged | Earlier close/till mutations rejected |
| REAL-CASH-06 | Existing six supply/five physical checkpoints and SQL identity helpers retained; no physical stock fabrication; explicit `real-cash-v1`; API-only unpaid-v2 refusal/replay/conflict/recovery retained | Existing 17 safety + 24 browser + 5 stock tests; new supply/stock controls |
| REAL-CASH-07 | Exactly 31 checkpoints, eight mandatory row-oracle results plus independent money projection; SQL invariants/counts; verified cleanup; exact-byte publication | 35 cash tests; 81 total final tests; exit 0 |

`tests/golden-path/README.md` documents the single current browser command.
Historical evidence is untouched. Earlier unpaid browser commands/counts are explicitly labeled historical.
The old successful unpaid smoke method remains historical code; current fresh unpaid sales are rejected by the backend.
Already confirmed cash receipts remain hidden after reload. Uncertain-result recovery must redisplay the exact original receipt.

## Changed paths

- `tests/golden-path/browser_path.mjs`
- `tests/golden-path/golden_path.py`
- `tests/golden-path/verify_evidence.py`
- `tests/golden-path/README.md`
- `tests/golden-path/oracles.md`
- `tests/golden-path/GoldenPath.Sql/Program.cs`
- `tests/test_golden_path_cash.py`
- This README and `RESULT.json`.

Existing safety/browser/stock test files, product code, migrations, package files, workflows and project ledgers are unchanged.
`RESULT.json` binds source and README bytes. The ignored private `tests/golden-path/out/final-bindings.json`
also binds RESULT itself and reports RAW/LF equality for every changed owned path.

## Observed checks

Eight focused Python invocations were used. No failed test group or corrected failing rerun occurred.
Each command below returned exit 0. Repeated groups followed added controls or source corrections.

| Invocation | Exact command | Tests | Private log under `tests/golden-path/out/` |
|---|---|---:|---|
| 1 | `python -m unittest discover -s tests -p test_golden_path_safety.py` | 17 | `safety.log` |
| 2 | `python -m unittest discover -s tests -p test_golden_path_browser_safety.py` | 24 | `browser-safety.log` |
| 3 | `python -m unittest discover -s tests -p test_golden_path_stock_exception.py` | 5 | `stock-safety.log` |
| 4 | `python -m unittest discover -s tests -p test_golden_path_cash.py` | 20 | `cash.log` |
| 5 | `python -m unittest discover -s tests -p test_golden_path_cash.py` | 24 | `cash-final.log` |
| 6 | `python -m unittest discover -s tests -p 'test_golden_path_*.py'` | 79 | `all-offline.log` |
| 7 | `python -m unittest discover -s tests -p 'test_golden_path_*.py'` | 80 | `final-offline.log` |
| 8 | `python -m unittest discover -s tests -p 'test_golden_path_*.py'` | 81 | `delivered-offline.log` |

`node --check tests/golden-path/browser_path.mjs`: exit 0 on the delivered browser source.
Python AST parsed the three new/changed Python files: 3/3, exit 0; final unit tests imported subsequent Python edits.
`git diff --check`: exit 0; Git's configured future CRLF conversion warning is not a whitespace failure.
The final binding audit verifies actual delivered bytes are UTF-8 LF.
Its first attempt exited 1 on `tests/golden-path/README.md`: retained documentation had CRLF bytes.
The correction normalized README.md (267 CRLF), oracles.md (88), and this README (109) to LF without changing text.
The corrected audit must pass for all nine changed paths before handoff.
PowerShell renders unittest stderr as `NativeCommandError`; native Python exit codes were captured as 0.

One cached SDK helper build was used:

```powershell
$cashEmptySource = Join-Path $env:TEMP 'savia-cash-empty-package-source'
& C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe build tests/golden-path/GoldenPath.Sql/GoldenPath.Sql.csproj -c Release -p:RestoreSources=$cashEmptySource -p:RestoreLockedMode=true --nologo
```

The existing package cache and an empty local package source supplied dependencies.
Private `helper-build.log` reports `Build succeeded`, 0 warnings, 0 errors, 21.12 seconds.
The tool yielded while that command ran; its terminal process exit was not captured.
The final result-ID SQL projection, explicit database guard and broader private row hashing were added afterward.
The final helper source was not rebuilt because the packet permits only one helper build.
Do not execute the intermediate compiled helper as final evidence.

## Remaining boundaries and blockers

1. Final helper compilation is unverified.
   Cause: final source hardening followed the single permitted build.
   Attempt/result: cached earlier revision built successfully; no second build attempted under the one-build cap.
   Owner: primary. Next action: compile the exact delivered source offline, then obtain the independent Astra/xhigh verdict.
   Completion check: captured build exit 0, zero compile errors, exact final source binding.
2. Real SQL/API/browser/cash persistence and operational behavior remain unverified.
   Cause: packet explicitly authorizes preparation only; SQL5 D remains REVIEW FIRST, DO NOT EXECUTE.
   Attempt/result: no runtime, connection, account change, container, recovery, backup/restore or deployment was attempted.
   Owner: Jason/primary. Next action: review the candidate, prerequisites, scope and cleanup before any separate runtime authority.
   Completion check: one separately authorized exact-source campaign passes all 31 checkpoints, independent SQL oracles and owned cleanup.
3. Parent CI runs `42439915787` and `42439915859` were reported in progress at delegation.
   Cause: this worker has no authorized remote verification action.
   Attempt/result: no CI polling or dispatch; no pass claim.
   Owner: primary. Completion check: direct exact-SHA CI readback during integration.

Future runtime command, NOT RUN:

```sh
python3 tests/golden-path/golden_path.py --mode browser --cash --supply --stock-exception --no-build \
  --playwright-directory /absolute/existing/node_modules/playwright \
  --sql-env-file /private/approved-disposable-sql.env --out /private/real-cash-v1
python3 tests/golden-path/verify_evidence.py --source /private/real-cash-v1 --destination /private/real-cash-v1-approved
```

Prerequisites: reviewed final Release binaries, Linux `/proc`/pty, existing Node24/Chrome/Playwright1.63.0/OpenSSL/.NET10.0.402,
and separately authorized disposable SQL/TLS configuration. No install or runtime permission is implied by this command.

Lesson applied: a historical successful-unpaid oracle cannot validate a backend that now refuses fresh unpaid sales.
The current API-only smoke validates that refusal, while the cash browser protocol independently proves its own prepared identities and arithmetic.

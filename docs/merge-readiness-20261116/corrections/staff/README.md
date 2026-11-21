# PR7 staff timing correction

Status: returned for primary integration and Astra/xhigh review. This worker result is not acceptance.

Base: `ba8ff2ba10935e99fc268ebbe5eae130f72c1cca`.
Task: `savia-pr7-staff-correction-ba8ff2b-20261116-01`.
Host: SUAZO-PC. T3 Code / Codex, gpt-6.1-sol, high reasoning exposed by runtime and awareness metadata.
Worktree: `C:/Users/Jason/.t3/worktrees/github/t3-84a947fe-3e4a084275ffd036`.
Branch: `t3/fix-pr7-staff-verification`. Token, cache, cost and internal reasoning telemetry are unknown.

## Result and cause

The original test assumes a 10 ms sleep means `send` has started.
`CashIntentStore.prepare` awaits SHA-256 before `send` installs the response resolver.
The offline red control holds that actual digest seam indefinitely.
The original test then fails at its original `release` call with `TypeError: release is not a function`.
This deterministically reproduces the reported CI failure at test line 67, column 314.
It demonstrates a test timing defect. No product defect was demonstrated.
The private CI log was read locally for the named failure and summary only; it was not copied.

Only `dev/savia-staff-ui/cash.test.mjs` changes outside this evidence folder.
The mounted helper now accepts an optional test-local digest implementation.
The corrected case holds preparation, delegates actual hashing to Node WebCrypto, and waits for an explicit send-start signal.
It asserts the lock immediately after the first call, before any await or second call.
It awaits the second call and checks one digest, no early send, one eventual dispatch, receipt change, refreshed reads and unlock.
The 5-second test deadline bounds missing signals. It never signals readiness.
The old `tick` remains for unrelated cases; this case contains no sleep.

## Evidence

Node `v24.18.0`; existing jsdom `26.1.0`.
All Node commands used this process-local, read-only dependency path:

```powershell
$env:NODE_PATH='C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules'
```

Focused verification budget: 8/8 invocations, including source binding and final scope verification.
Reads and evidence serialization are not test invocations.

| # | Invocation | Actual result |
| --- | --- | --- |
| 1 | `python docs/merge-readiness-20261116/corrections/staff/control.py red` | Node exit 1, 1 FAIL, 0 skips; expected TypeError reproduced. Wrapper exit 1 from subsequent console encoding error. |
| 2 | `node --test --test-name-pattern 'mounted cash sale double submit locks synchronously and refreshes current reads' dev/savia-staff-ui/cash.test.mjs` | Exit 0, 1 PASS, 0 skips under held preparation. |
| 3 | `python docs/merge-readiness-20261116/corrections/staff/control.py negative` | Wrapper exit 0; disposable mutant Node exit 1, 1 FAIL, 0 skips at synchronous lock assertion. |
| 4 | `node --test dev/savia-staff-ui/cash.test.mjs` | Exit 0, 58 PASS, 0 FAIL, 0 skips. |
| 5 | Explicit expansion below, equivalent to `node --test dev/savia-staff-ui/*.test.mjs` | Exit 0, 223 PASS, 0 FAIL, 0 skips across 11 files. |
| 6 | `git diff --check` plus scope readback | Exit 0; only owned test and evidence folder changed. |
| 7 | Python source binding and product byte assertions | Exit 0; 18 source bindings saved. |
| 8 | Final `git diff --check` plus byte/scope/evidence assertions | See RESULT.json. |

Exact PowerShell expansion for invocation 5:

```powershell
$staffTests=@(Get-ChildItem -LiteralPath dev/savia-staff-ui -Filter '*.test.mjs' | Sort-Object Name | ForEach-Object { $_.FullName })
node --test @staffTests
```

`staff-files.json` records the expanded files. Logs retain actual counts and diagnostics.
`RESULT.json` binds base Git blob SHA-256, working RAW SHA-256 and LF-normalized SHA-256 for all staff MJS and HTML sources.
The RAW hash preserves on-disk line endings. LF hashes replace CRLF with LF.

`control.py` creates disposable mirrors inside this owned folder and removes them on exit.
The red control reads the exact base test using `git show` and replaces only the mounted digest seam.
The negative control removes `busy=true;lock();` from `begin` in a disposable product mirror.
It imports real unmodified dependencies and the corrected test.
It fails with `sale locks before awaiting preparation`, detecting removal of the duplicate-submit lock contract.
The actual product file is never mutated. Before/after RAW hashes match.

## Limits, correction and next action

The first control saved its successful red detection, then its console printer failed with Windows `UnicodeEncodeError` on a test reporter symbol.
The printer now explicitly uses UTF-8. The negative control exercised that corrected printer successfully.
No red rerun was needed; `red.log` and `red.json` already contained the actual Node result.
PowerShell-created logs were normalized from UTF-16 to UTF-8 for portability without changing their text.

NOT RUN: browser, API, SQL, Docker, services, repository-wide static-site checker, network installation, workflow execution, GitHub mutations, staging, commit, push, merge or deploy.
No cached dependencies, other checkout, shared ledger, generated source, credentials or product cash code were changed.
This offline jsdom result does not establish current CI or production behavior.

Owner of next action: primary. Inspect and integrate this exact test diff serially, obtain Astra/xhigh review, then verify required checks on the resulting PR head.

Lesson: observe the asynchronous boundary that establishes readiness. A synchronous lock claim must be asserted before the first await.

## Primary import

Primary verified all 18 source bindings and unchanged canonical base before importing.
The five historical logs are archived privately under `private-exports/merge-readiness-20261116/corrections/staff-logs/`; `IMPORT.json` records their exact hashes.
The worker results remain attributed to the worker. No new full staff execution is claimed by this import.
Independent review and remote CI are pending.

# CI result on 9879d5c

Local record, not yet published. Head: `9879d5c63de30a75b69a2fcf5cda745f13de895c` (Tony, PR 7). Primary: Claude Code `claude-fable-5-2`.
The one-shot publication authority is consumed. No rerun, second publication, merge or deployment occurred.

## Result

Three check runs failed: `SAVIA v2 check` twice (push and pull_request, same failures) and the golden path once. That is two distinct jobs and three failure modes. Of 24 check runs: 15 pass, 3 fail, 6 skipped by their own conditions. Check list with links: [checks.tsv](checks.tsv).

| Job | Result | What it shows |
| --- | --- | --- |
| SAVIA Azure hub: build, images, migration, container smoke | PASS | Corrected V029 installs on SQL Server 2022. The six SQL207 errors on `ac0bb9f` are gone. |
| savia.yml: complete backend suite on disposable SQL | PASS | |
| savia.yml: staff UI tests and real browser harness | PASS | |
| Recovered demo CI: portable checks, Linux and Windows | PASS | The Linux aggregate `python tests/check.py --install` passes. |
| Backend build and guards, bug proof, progress, Tony snapshot | PASS | |
| SAVIA v2 check (push and pull_request) | **FAIL** | Rules 9/9, baseline, no-delete, .NET build and C# format pass. T-SQL: 134 pass, 1 fail. .NET on real SQL: 175 pass, 6 fail. |
| SAVIA golden path: real API + disposable SQL | **FAIL** | 29 browser steps pass. The run stops in the last step, the second till close. |

## Failure 1: T-SQL `sales/172_return_retry_safety.sql`

`Msg 59002, Line 104: ASSERT FAIL: mutation did not throw 51538`, printed label `branch`.
The mutations `sale`, `node`, `location` and `till` were refused with 51538 as expected.
A replay of the same reversal with a different `branchId` did not raise 51538.
The assertion does not print the caught number, so the number is not observed.

Source reading (inference, not a run):
- Both procedures check current authorization against the request's `@BranchId` before the identity check (`V029__return_retry_safety.sql:53-58` and `188-193`) and raise 51529. The identity check that raises 51538 comes after (`:63-67`, `:198-202`). `branchId` is part of the identity hash (`:39`, `:178`).
- The log shows three conservation result sets before the failure, so scenarios 0 and 1 passed their whole mutation loop, including `branch`, and scenario 2 failed.
- Scenario 2 is the credit return. Its actor is `cashierA` (`172_return_retry_safety.sql:80`). `cashierA` has access to `branchA` only (`_fixture.sql:71`). The manager has access to all three branches.
- So in scenario 2 a replay with `branchB` most likely raises 51529 "Actor sin acceso vigente a la sucursal", which is the designed order: authorization first.
- Most likely a wrong expectation in the fixture for that one row, not a product defect. It stays unconfirmed until the fixture prints the caught number on real SQL.

First run of this fixture on real SQL.

## Failure 2: `ReturnRetrySafetyTests`, 6 of 6 cases

`Same_reversal_serializes_exact_and_different_financial_requests` fails for all six parameter sets, about 5 seconds apart.
The quiet log prints no assertion text. The cause is undetermined.
The spacing between failures does not tell apart three candidates: the winner's call throwing, the contender returning before a lock wait is observed, or the 6-second observation deadline.
First run of these tests on real SQL.

## Failure 3: golden path, last cash step

The script printed `c6_logout_me`. That is only the last phase marker the script had set; it hides the real error text by design.
The last passing checkpoint is `browser.cash_later_refund`. The failing statement is the cashier login, count `87.50`, till close, `browser.cash_later_close`.
`tests/golden-path`, `dev/savia-staff-ui`, `backend` and `.github` are byte-identical between `ac0bb9f` and `9879d5c`. The same job passed on `ac0bb9f` in 83 seconds.
Likely a timing failure in the browser step. Not confirmed.

## Codex review on the PR (three P2 comments, none in files changed by 9879d5c)

1. `savia/web/screens/sale-logic.mjs:20`: ticket total excludes per-line tax, but `sales.usp_PostSale` requires tax-inclusive tenders. A taxed item cannot be checked out.
2. `savia/db/migrations/V027__usd_cash.sql:1057`: the business report subtracts tax-inclusive returns from tax-exclusive revenue.
3. `savia/web/screens/import.mjs:93`: an older catalog preview response can be confirmed with a newer request.

None is verified by the primary yet.

## Limits and next action

No SQL has run locally. Failures 1 and 2 need a real SQL Server to reproduce and to verify a correction.
The golden-path artifact holds only the passing smoke evidence; it does not name the failing browser step.
Local route, pending Jason's authorization: the existing dev container `savia-sqlserver-dev` (`savia/infra/docker-compose.dev.yml`, SQL Server 2022 Developer, bound to 127.0.0.1:14340, volume `savia_sql_data`), driven by `python savia/tools/db/saviadb.py`. Each test clones a template database and drops it. It is separate from the native instance `MSSQL$SAVIATEST`. Docker Desktop is installed but its engine is not running.
If a correction touches a V029 procedure body, the pre-implementation critic gate applies and Astra's "bodies unchanged" acceptance no longer holds. A fixture-only correction needs neither.
PR 7 is not ready to merge.

## Authorization (2026-11-17T04:09:27.445960+00:00)

Jason answered "Sí, SQL local (Recommended)": the dev container `savia-sqlserver-dev` on this PC, fictional data, to reproduce and correct failures 1 and 2. It is stopped afterwards. Nothing is published without a new question.
Jason answered "Repetir una vez (Recommended)": one rerun of the failed golden-path job only, maximum 20 minutes, no code change.

## Diagnosis on local SQL (2026-11-17T04:15:30.670187+00:00)

Container `savia-sqlserver-dev`, SQL Server 16.0.4305.5 Developer, same build as CI. Fictional data only.

**Failure 1 reproduced and corrected: fixture defect, not a product defect.**
The unchanged fixture failed locally with the same message.
With the assertion printing its values: `branch scenario=2 expected=51538 caught=51529`.
The product refuses the replay, with the authorization error, before the identity check. No row changes.
Correction in `savia/db/tests/sales/172_return_retry_safety.sql`: scenario 2 expects 51529 for the `branch` row, and the assertion now prints label, scenario, expected and caught.
After: `python tools/db/saviadb.py test sales/172` reports PASS.

**Failure 2 reproduced and corrected: test helper defect, not a product defect.**
Local red: 6 of 6 fail with `InvalidCastException: Unable to cast object of type 'System.DBNull' to type 'System.String'` at `ReturnRetrySafetyTests.Snapshot`.
Cause: the helper concatenates each table's JSON. An empty table yields NULL JSON, and NULL blanks the whole image.
Correction in `savia/tests/Savia.Tests/ReturnRetrySafetyTests.cs`: `COALESCE` on the row JSON and its length, and `@rows` reset per table.
After: 6 of 6 pass on real SQL. These tests observe the real application-lock wait, the 51538 refusal on mismatched and mixed-endpoint requests, unchanged snapshots and conservation.

No V029 procedure body changed. The pre-implementation critic gate does not apply.

**Failure 3, golden path: rerun once as authorized. It failed again at the same statement.**
Attempt 2 of run 44011518265: last passing checkpoint `browser.cash_later_refund`, then `c6_logout_me`.
The listed source hashes are identical to the passing `ac0bb9f` run, except the compiled API DLL, which is rebuilt each run. Chrome, Node and Playwright versions are identical.
So it is not a one-off flake, and it is not explained by a source difference. The error text is hidden by the harness. Cause unknown.
The passing run started 2026-11-17T01:30Z. The failing runs started 03:37Z and later. A time dependence is possible; no time-of-day rule was found in the cash code by search.

**Full v2 check on local SQL with both test corrections: RESULT PASS.**
Command, from `savia/`: `python tools/check.py`. Exit 0.
Rules 9 of 9, baseline, no-delete, T-SQL `SUMMARY PASS=135`, .NET build, C# format, .NET tests on real SQL `Passed: 181, Failed: 0, Skipped: 0`.
This is the same gate list as the failed CI job "Rules, web, T-SQL and .NET on real SQL". Local Windows run, not CI.

**Golden path: the reported label is stale.**
`browser_path.mjs` sets `failurePhase = 'c6_logout_me'` at line 348 and never updates it in the later stock and cash blocks.
So the failure is in the step after `browser.cash_later_refund`: cashier login, count `87.50`, then `POST /internal/api/cash/tills/{later}/close` (line 521).
The checks there are `c6_cash_action` (HTTP 200) and the confirmation text. The harness does not record which one failed, or the API error.
Not yet reproduced. A local run of the golden harness would show the close response.

The local SQL container was stopped after these checks.

**Golden path local run: blocked, not attempted.**
Jason chose a local run on 2026-11-17. Two blockers stop it:
- `golden_path.py` needs Linux `pty`, `fcntl`, `termios` and `/proc`. Native Windows cannot run it (`docs/completion-20261107/local-validation/README.md`).
- The Linux runner recipe `tools/local-validation/Dockerfile` stops on purpose: `PREPARATION_INCOMPLETE: reviewed dependency lock required`. No runner image exists locally. That stop was not bypassed.

Source reading after the block, without a reproduction:
- `usp_CloseTill` and `InternalCashService.Close` have no time-of-day rule.
- The oracle in `golden_path.py:327-333` expects the later till to sum 8750 and close with counted 8750. No time-dependent check was found.
- Golden history weakens the time hypothesis: runs on 2026-11-04 passed between 02:05Z and 05:27Z, on other commits.
- Open hypothesis: a UI timing race in the cashier re-login before close. Pass, fail, fail on identical sources fits a race. Not proven.

Smallest next step: make the C6 cash block set `failurePhase` per step and record the close HTTP status and error code in sanitized evidence. That is a harness change and needs a CI run, so it needs a publication.

**Golden path diagnostic correction: prepared locally, not published.**
Finding from `browser_path.mjs:528`: a failing `check()` reports its own `c6_*` code. The run reported `c6_logout_me`, so the failure was not `c6_cash_action` (HTTP status). It was a Playwright wait or assertion timeout before the `browser.cash_later_close` checkpoint.
Change: the C6 cash helpers set a fixed phase before each wait: `c6_cash_login`, `c6_cash_count`, `c6_cash_open_form`, `c6_cash_refund_form`, `c6_cash_click`, `c6_cash_response`, `c6_cash_confirmation`, `c6_cash_refresh`, `c6_cash_logout_wait`. `golden_path.py` allows those codes. No product file changed.
New test `test_cash_child_phases_are_reported_not_replaced` in `tests/test_golden_path_browser_safety.py`.
Red, against the unchanged allowlist: `FAILED (failures=9)`. Green: the six stdlib golden suites print `OK`. `node --check` passes.
It does not fix the failure. It makes the next CI run name the exact failing wait.

## CI on ec11e64 (2026-11-17)

Published once as authorized: Tony = `ec11e6447e30a4a88e6cc71cf3b4a4ca0f13985a`, hook `SYNCED`, remote SHA read back.
The golden path failed again, now with the exact phase: `c6_cash_login`, after `browser.cash_later_refund` (run 44018689092).

**Probable cause: the login rate limit, not cash logic.**
- `InternalLoginLimiter.cs:13,27`: at most 10 login attempts per remote address in a fixed 1-minute window. The 11th gets `429 login_rate_limited`, `Retry-After: 60`.
- Every login in the run comes from 127.0.0.1. The browser journey makes 10 logins; the failing one is the 10th. The harness also logs in the Owner through the API during setup (`golden_path.py:1011`). So the failing login is at least the 11th attempt.
- The window starts at the first attempt. Whether the 11th attempt falls inside it depends on run speed. That explains pass, fail, fail on identical sources.
- `login.mjs:190-198`: on 429 the screen enters a 60-second cooldown, locks the form and clears the password. The harness then times out waiting for `#staff-shell`.
Limit: not reproduced here (no Linux runner). The CI run did not record the HTTP status of that login.

**Harness correction, local only.** The C6 cash login helper waits for the login response. On 429 it waits for the screen's own unlock (up to 75 s), submits once more and requires HTTP 200 (`c6_cash_login_http`). New phase `c6_cash_login_cooldown`. No product file changed; the limiter stays as is.
`node --check` passes; the six stdlib golden suites print `OK`. Proof needs one CI run.

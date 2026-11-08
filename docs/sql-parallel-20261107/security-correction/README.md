# Security SQL fixture correction

Status: **CANDIDATE; independent review pending. Production NO-GO.**
Host SUAZO-PC. Primary: T3 Code / Codex / gpt-6.1-sol, xhigh.
Base: `0bda22a6cadd0deecc635c9a9649dd100bc1e96b`.
Original SQL source: `f9ffa452bae7fc11a4a578ce24b57ecb72add139`.

## Direct diagnosis and changes

- BS21_25 and BS28 failed while ASP.NET materialized endpoints: Cash services were not registered in OperationsHost.
  The test host now mirrors production Cash registration. A fresh HTTP admission regression uses the same host and forbids SQL context creation.
- Two release/backup tests failed in the schema oracle before backup. Captured SQL Server 2022 metadata contains `9000000000000.` and prefix `NOT ... LIKE`.
  The limited expression parser now accepts integral trailing-dot constants and the reviewed prefix-negated LIKE expression.
  It preserves literal strings, operator precedence, grouping, numeric bounds and collation.
- The five captured cash constraints are an allowlisted fixture at `backend/tests/fixtures/cash-checks.sqlserver2022.json`.
  No database rows, credentials or full schema export are included.
  Source schema RAW SHA256: `f0c726bc6c84710c690e56d9a395eeb98ab74b9ac2304b430df05c8026aa124f`.
- Negative checks reject changed bounds, missing NOT, changed collation and changed quoted strings.
  Fractional, exponent and malformed numeric forms still fail closed.

No product code or migration changed. These are verification defects, with original runtime failures and fresh offline regressions.

## Fresh evidence

SDK `10.0.402` by absolute path. SQL connection/authorization variables were absent in each child.
The private pilot evidence directory was precreated.

| Invocation | Result | Exit |
|---|---|---|
| Focused before correction | 28 passed, six failed | 1 |
| Focused after correction | 34 passed, zero skipped | 0 |
| Wider offline backend | 641 passed, 67 NotExecuted, zero failed | 0 |

Focused command:
`dotnet test backend/tests/Martha.Store.Api.Tests/Martha.Store.Api.Tests.csproj -c Release --no-restore --filter "FullyQualifiedName~InternalCashSchemaOracleTests|FullyQualifiedName~Operations_host_materializes_all_private_routes_without_sql"`

Wider command uses `--filter "Category!=SqlServer"`.
The complete commands, durations, RAW log/TRX hashes and candidate RAW/LF source bindings are in [RESULT.json](RESULT.json).
Raw logs and TRX remain ignored under `private-exports/sql-security-primary-20261107/`.

Repository check: `python tests/check.py`, exit 0, 264.094 seconds.
Registration check: `python tests/test_progress.py`, exit 0, 84.265 seconds.
`python tools/export_progress.py --verify`: 15 preserved hashes.
`python tools/delivery_status.py --check`: valid, 40 items.
`git diff --check`: exit 0. Product paths have no tracked diff.
Published correction: `550b10456c10a2857da930913b397bd1a96949d2`, Tony, synchronized with the remote.
Exact-SHA CI readback: all four workflows completed successfully, attempt 1:
[progress digest](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42429493338),
[progress documentation](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42429493346),
[Tony snapshot](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42429493327), and
[staff/resource candidate](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42429493236).
Both snapshot jobs and the staff/resource job succeeded. Read commands exited 0; no workflow was dispatched for this readback.
These workflows do not execute the corrected SQL cases.

## Blockers and next actions

| Blocker | Evidence / attempted correction | Owner and completion check |
|---|---|---|
| Four original SQL failures | Fixture/oracle failures reproduced offline; focused red-to-green completed | Astra/xhigh reviews frozen 550b104 and adversarial coverage; primary retains acceptance |
| Corrected SQL behavior | No SQL retry was executed under the exhausted one-shot scope | Astra adjudicates four corrected methods plus restart versus a wider affected set; primary prepares the exact runtime request after review |
| Backup, restore and restart | Original run stopped before BACKUP; dependent restart prohibited | Authorized worker proves backup/restore first, then the owned-container restart and exact cleanup |
| Cash release | Business SQL39 passed; staff cash UI and combined real journey remain pending | Primary completes source-reviewed UI and browser/API/SQL cash proof separately |

Lesson: build synthetic parser fixtures from actual SQL metadata, then prove that semantic mutations still fail.
Offline acceptance cannot replace a fresh SQL execution of the corrected fixtures.

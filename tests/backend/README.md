# SQL Server backend tests — synthetic first slice

These tests are separate from `tests/backend.cjs`, which checks the browser demo.
No real customer, payment-card, production-inventory or historical database data is used.

## Commands

From the repository root, with .NET SDK **10.0.402**:

```sh
dotnet restore backend/tests/Martha.Store.Api.Tests --locked-mode
dotnet test backend/tests/Martha.Store.Api.Tests --no-restore --configuration Release --filter 'Category!=SqlServer'
```

SQL tests require an **already authorized, disposable SQL Server**. Do not use a
production/shared server. Pass its connection string in `MARTHA_TEST_SQL_CONNECTION`
through the process environment (never a tracked file or terminal transcript). The
login needs create/drop database permission. The fixture assigns a unique database
name beginning `MarthaSynthetic_Test_`, runs the application's actual migrations,
and drops only that database on disposal. The supplied database is never cleared.

```sh
# Provision/authorize the disposable SQL server separately before this command.
# Inject MARTHA_TEST_SQL_CONNECTION without printing credentials.
test -n "$MARTHA_TEST_SQL_CONNECTION"
dotnet test backend/tests/Martha.Store.Api.Tests --no-restore --configuration Release --filter 'Category=SqlServer'
```

Without the variable, SQL tests are visibly **skipped**, not passed. A build or
unit-test pass is not evidence of transaction correctness on SQL Server.

## Approved disposable SQL CI

The user explicitly accepted **SQL Server 2022 Developer** licensing on
2026-10-24 for non-production, synthetic CI only. This does not authorize
production use, other licenses, paid resources or deployment.

`.github/workflows/backend.yml` runs build/guards on pushes and PRs to `main`.
The SQL job runs only after guards succeed, on this repository's trusted `main`
push or manual dispatch; PR and fork events cannot start it. It uses a disposable
GitHub-hosted Ubuntu runner and the immutable official image:

`mcr.microsoft.com/mssql/server@sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718`

Registry manifest/config reviewed 2026-10-24: `2022-latest` at resolution time,
Linux amd64, Microsoft SQL Server **16.0.4305.5**, Ubuntu 22.04, image created
2026-10-03. Runtime checks additionally enforce engine major 16 and Developer
edition. Source: [Microsoft container instructions](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-docker-container-deployment?view=sql-server-ver17).

The job generates a cryptographically random strong SA password, masks it before
use, and publishes only a dynamic loopback port. No credentials are committed.
Each SQL test creates its own unique `MarthaSynthetic_Test_<guid>` database,
applies actual migrations and drops that database on disposal. An `always()` cleanup step removes the container and its anonymous volumes,
including databases left by an interrupted test; if the runner itself is terminated,
GitHub-hosted runner destruction is the final isolation boundary. No external or production database is accessed.

Readiness is bounded. Missing connection configuration, missing TRX, any skipped
SQL test, any failure, an unexpected/duplicate test, or anything other than all
six expected passing SQL tests fails the job. Only allowlisted test names,
outcomes and counters are retained as a seven-day artifact; raw stdout/TRX,
environment and container logs are not published. The sanitizer has independent
unit tests and strips all arbitrary diagnostic text. No API deployment occurs.

## Dependencies

Pinned official NuGet packages: `Microsoft.AspNetCore.Mvc.Testing` 10.0.13,
`Microsoft.NET.Test.Sdk` 18.11.0, `xunit` 2.9.3, and
`xunit.runner.visualstudio` 4.0.1. Restore only from the official NuGet feed;
commit generated lockfiles and use locked restore in CI.

## Coverage and deliberately deferred scope

Database-independent guards verify that Production, Staging and Test deny writes
regardless of the flag, Development needs the explicit flag, and invalid database
catalogs fail the guard without opening connections. Liveness is not readiness.

Real SQL tests apply migrations to a fresh database and verify synthetic catalog,
non-replenishing seed, invalid quantities, rejected client price/total/customer
fields, 20 distinct last-unit contenders (one winner), 20 same-key concurrent
replays (one exact response/order/decrement), changed-payload conflict, and forced
insert failure rolling back stock with successful same-key retry afterward. The
fault is a test-only CHECK constraint, not a production bypass/hook.

Reservation expiry/cancellation/release, payment adapters, production auth, HTTP
frontend wiring, and real inventory are explicitly outside this first slice.

## Verification — 2026-10-24

Temporary integration checkout combining the current backend source/migrations
with this test branch, SDK 10.0.402 / runtime 10.0.13:

- Locked NuGet restore: passed.
- Release compilation: passed, zero warnings after analyzer correction.
- Database-independent tests: **16 passed, 0 failed, 0 skipped**.
- Full discovery/run without SQL configuration: **16 passed, 6 explicitly skipped**.
- Existing demo `python3 tests/check.py --install`: passed (writable npm cache
  override required in the restricted executor).
- Actual SQL Server integration at the first foundation verification: **not run**.
  Licensing was subsequently approved; the new CI job awaits remote execution. No concurrency/rollback runtime claim
  is made from the successful compilation or guard tests.

### SQL CI implementation checks — 2026-10-24

- Official MCR manifest and image configuration inspected; immutable digest pinned.
- YAML parsing, bash syntax and five sanitizer unit tests passed.
- Verifier checked against real VSTest TRX with six skipped SQL tests: correctly
  failed (exit 1), retained only expected names/outcomes/counters.
- No local Docker executable; genuine SQL behavior still awaits the first remote
  run. Static review or a skipped-test verifier check is not a SQL test pass.

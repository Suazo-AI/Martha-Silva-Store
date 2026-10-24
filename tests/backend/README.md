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

## CI approval boundary

`.github/workflows/backend.yml` runs on push and pull requests to main, with manual
dispatch also available. It builds and runs database-independent guards. Its SQL job is hard-disabled and does not accept a license or start SQL.
After explicit SQL Server EULA authorization, the next implementation must:

1. Pin an official Microsoft SQL Server Linux image to a reviewed tag/digest; use
   a disposable GitHub-hosted Ubuntu runner, loopback-only port, Developer edition.
2. Generate a strong random administrator password **at runtime**; mask it before
   use, store only in job environment, never commit or print it.
3. Start the approved container and perform bounded readiness checks. Do not copy
   databases from users, shared environments or historical backups.
4. Set `MARTHA_TEST_SQL_CONNECTION`, fail if it is absent, run the SQL category and
   verify zero failed and zero skipped tests. Preserve sanitized test results.
5. Always remove the disposable container. Do not deploy or publish API services.

Approval to execute tests is not approval to deploy, merge, accept other licenses,
or connect to a production database. The current workflow deliberately cannot
claim a SQL Server integration pass.

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
- Actual SQL Server integration: **not run**, pending explicit EULA authorization
  and disposable SQL Server provisioning. No concurrency/rollback runtime claim
  is made from the successful compilation or guard tests.

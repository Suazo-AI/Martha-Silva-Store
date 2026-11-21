# Private SAVIA: offline SQL migration plan

## Scope and separation

This lot prepares **source and reviewable SQL only** for `InternalDbContext`.
It does not connect to SQL Server, accept a server licence, create a database,
apply DDL, seed business data, bootstrap staff, change accounts or deploy.

- Internal migrations and their snapshot live in
  `backend/src/Martha.Store.Api/Internal/Migrations/` under
  `Martha.Store.Api.Internal.Migrations`.
- Existing `StoreDbContext` migrations/snapshot under `Migrations/` are unchanged.
  EF's context attributes select the correct migration set; always pass the full
  internal context name to the CLI.
- Business tables belong only to `savia_internal`. EF's unchanged default
  `__EFMigrationsHistory` table is not a business table. The current runtime and
  factory do not configure a custom history-table schema.
- The internal database is separate from the synthetic Store database and must
  pass the existing `SaviaInternalTest_[A-Za-z0-9_]{1,64}` guard. That name is an
  accidental-target check, **not authorization** or a production-readiness claim.
- No real staff, credentials, stock, party data or synthetic fixtures are seeded.
  Generated `Down` operations are destructive and are not a data-recovery plan.

## Offline design-time factory

`InternalDbContextFactory` supplies SQL Server provider options with the fixed
dummy database `SaviaInternalTest_DesignTime` at `design-time.invalid`, a reserved
non-target hostname. It ignores application arguments, connection environment
variables and configuration files; it neither loads secrets nor starts the web
host, opens a connection, migrates or seeds.

This factory is **not an execution guard**. EF CLI options such as `--connection`
can override provider options. Direct `database update`, `database drop`,
`Migrate`, `EnsureCreated` and migration bundles are outside this offline plan.
Do not use them as a substitute for a separately reviewed apply procedure.

## Reproduce source and offline verification

Use the repository's unchanged `global.json` SDK **10.0.402** and locked EF Core
**10.0.13** packages. Install the official EF tool at the same version into an
isolated tooling directory outside the checkout; no global tool or source-version
changes are required. For example, from the repository root:

```sh
dotnet tool install dotnet-ef --version 10.0.13 \
  --tool-path ../tooling/ef-10.0.13 \
  --add-source https://api.nuget.org/v3/index.json --disable-parallel
EF=../tooling/ef-10.0.13/dotnet-ef
PROJECT=backend/src/Martha.Store.Api/Martha.Store.Api.csproj
CONTEXT=Martha.Store.Api.Internal.InternalDbContext

dotnet restore backend/Martha.Store.slnx --locked-mode --disable-parallel -m:1
dotnet build backend/Martha.Store.slnx --no-restore -c Release \
  -m:1 -p:UseSharedCompilation=false
dotnet test backend/tests/Martha.Store.Api.Tests --no-build --no-restore \
  -c Release --filter FullyQualifiedName~InternalMigration

"$EF" migrations has-pending-model-changes --context "$CONTEXT" \
  --project "$PROJECT" --startup-project "$PROJECT" \
  --configuration Release --no-build
"$EF" migrations script 0 --idempotent --context "$CONTEXT" \
  --project "$PROJECT" --startup-project "$PROJECT" \
  --configuration Release --no-build \
  --output backend/src/Martha.Store.Api/Internal/Migrations/InitialInternalSavia.idempotent.sql
# Normalize only trailing blank lines in the generated review artifact.
python3 - <<'PYSQL'
from pathlib import Path
path = Path("backend/src/Martha.Store.Api/Internal/Migrations/InitialInternalSavia.idempotent.sql")
path.write_bytes(path.read_bytes().rstrip(b"\r\n") + b"\n")
PYSQL
```

The initial C# source was scaffolded with `migrations add InitialInternalSavia`,
the same context/project/build flags, `--output-dir Internal/Migrations` and
`--namespace Martha.Store.Api.Internal.Migrations`. Do not add the initial
migration a second time. Future approved model changes require a new migration,
review of both directions and regeneration of the script.

EF 10.0.13 initially placed the new snapshot under a namespace-derived directory
(`Martha/Store/Api/Internal/Migrations/`) despite the output-directory flag. The
generated snapshot was moved unchanged beside the migration, retaining its
context attribute and namespace; the temporary empty directories were removed.

Microsoft documents [design-time factories](https://learn.microsoft.com/en-us/ef/core/cli/dbcontext-creation),
[pending-model verification](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/managing)
and [reviewable SQL scripts](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying).
Generation does not establish that a script is safe for a particular database.

## Already-provisioned / shared-host database path (not executed)

No `CREATE DATABASE` capability is required by this script. A host administrator
must supply an **already provisioned, isolated, expressly authorized test database**
and a narrowly scoped way to apply its approved schema. This is not permission to
use another database or to bypass a host restriction.

Before any future apply, the responsible operator must separately establish:

1. Exact server, database, owner authorization, SQL Server edition/licence and
   permission boundary. Do not request server-admin roles or database-creation
   permission merely to use this script.
2. Backup/restore responsibility, an appropriate maintenance window and the
   starting schema/history state. Existing tables without matching migration
   history are not a safe initial target; do not fabricate history rows.
3. DBA approval for `savia_internal`, its tables/indexes/constraints and the EF
   history table in the database's resolved default schema. If the host cannot
   grant schema creation, its administrator can provision the approved schema
   beforehand. If no authorized DDL path exists, stop with that exact blocker.
4. Review of the generated SQL and its hash. It must contain no `CREATE/ALTER/DROP
   DATABASE`, database switching, login creation, secrets or synthetic tables.
   Idempotence checks migration history; it does not validate pre-existing
   objects, permissions, isolation or authorization.
5. A separately authorized apply through the host's supported mechanism, against
   the selected existing database. Keep the ordinary application identity free
   of schema-management privileges. No apply command is supplied or run here.
6. After an approved apply, independently verify history, constraints and schema;
   run actual SQL auth/session, rollback, idempotency and concurrent stock/receipt
   tests. Offline tests cannot close these gates. Account bootstrap is a separate
   explicit action, not part of migration application.

## Evidence and limits

Verified offline on 2026-10-25 against the unchanged model at base `b1eb4be`:

- Official `dotnet-ef` 10.0.13 installed in the isolated workspace tool directory;
  SDK reported 10.0.402. Locked restore and Release solution build passed with
  zero warnings/errors; no project/lock/global version files changed.
- Initial migration `20261025085402_InitialInternalSavia`: 17 internal tables,
  32 check constraints, 22 restrictive foreign keys and 30 indexes.
- CLI `migrations has-pending-model-changes`: **no pending model changes**.
- Focused `InternalMigration` suite: **6 passed, 0 failed, 0 skipped**. Checks
  cover dummy connection, context/snapshot isolation, snapshot/model parity,
  migration operation scope and both normal/idempotent offline SQL generation.
- After moving the unchanged snapshot into its final directory, the complete
  solution rebuilt with zero warnings/errors. Full backend suite:
  **324 passed, 0 failed, 48 SQL tests skipped (372 total)**, using
  `dotnet test backend/tests/Martha.Store.Api.Tests --no-build --no-restore -c Release`.
  `MARTHA_TEST_SQL_CONNECTION`, `MARTHA_INTERNAL_TEST_SQL_CONNECTION`,
  `SAVIA_INTERNAL_TEST_SQL_CONNECTION` and `SAVIA_INTERNAL_SQL_TESTS_AUTHORIZED`
  were unset for this verification. Skipped tests prove no SQL behavior.
- The committed idempotent SQL was generated without a connection or execution;
  only the generated extra blank line at EOF was normalized for diff hygiene.
  SHA-256: `18a0d76c793b9d43a4a75008d39fe8ac92f791deaf1e4e63e487e5655f065fe0`.
  It creates schema objects in the selected existing database, never a database.
- Static inspection of the committed SQL confirmed only the 17 internal tables
  plus EF history and no database-switching, database-management or account DDL.

The frontend aggregate `python3 tests/check.py` is absent from this
restricted backend checkout and is not represented as run. No SQL server test,
live authentication, visual browser check, remote push, CI or deployment is
proved by this lot.

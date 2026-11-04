# Real SQL validation with synthetic data

Status: EXECUTED. Date: 2026-11-03, America/Managua. Result: 67 passed, zero failed, zero skipped. This records technical scope, not a reusable authorization for future runs.

This layer exercised the actual SQL Server engine with disposable synthetic data. Existing databases were excluded.

## Concrete target and effects

- Host: SUAZO-PC. Existing running Windows service: MSSQL$SAVIATEST.
- Connection: local shared memory, Windows integrated identity, existing SQL Server Developer instance. No passwords, remote endpoints, installation, service restart, Docker or certificate-store changes.
- Candidate: isolated snapshot of Tony 9befe15 plus existing working-source overlays, recorded by the test worker's SHA-256 manifest.
- Run only the existing SQL-dependent automated tests that create uniquely named disposable fixture databases. Exercise real SQL transactions and in-process HTTP TestServer endpoints with synthetic records.
- Allowed new names: MarthaSynthetic_Test_<32 hex>, MarthaInternal_Test_<32 hex>, SaviaInternalTest_Commerce_<32 hex>, SaviaInternalTest_Supply_<32 hex>.
- The fixtures create, migrate or EnsureCreated, seed, mutate, and drop only their own newly generated databases. The distinction between migrations and EnsureCreated remains in the results.
- Do not address or modify SaviaInternalTest_20261031, restored pilot databases, existing identities, sessions, stock or historical evidence.
- Exclude PrivatePilotReleaseTests from this SQL batch: that suite has Linux-specific backup paths and separate persistence prerequisites. Its offline script checks may run separately.

## Execution and recovery

1. Verify host and SQL edition/version with a read-only query. Record database names before the run in private evidence.
2. Derive the exact SQL test selection from skipped results and source attributes. Exclude the release/persistence suite above.
3. Set MARTHA_TEST_SQL_CONNECTION, MARTHA_INTERNAL_TEST_SQL_CONNECTION, SAVIA_INTERNAL_TEST_SQL_CONNECTION and the two internal SQL authorization flags only in the child test process.
4. Use the already installed .NET SDK 10.0.402 and compiled isolated candidate. No changes to application code or test expectations.
5. Stop after one bounded run or 15 minutes. A failure is evidence, not permission to reset a pre-existing database.
6. Re-read database names. Confirm every pre-existing database remains and normal fixture cleanup removed this run's databases. Report leftovers; any cleanup must match the exact recorded newly created names.

The worker must preserve raw results privately and export only sanitized outcomes. A successful SQL test does not establish browser-to-live-API acceptance, production connectivity, restore readiness or deployment acceptance.

## Observed outcome

SQL Server Standard Developer Edition (64-bit), version 17.0.1000.7. SDK 10.0.402. One selected run completed in 29.484 seconds wall time. Before and after inventories each contained 52 databases. Every pre-existing database name remained; no new databases remained. No manual cleanup was needed. Inventory names and connection details remain private. See [results](evidence/results.json) and [case outcomes](evidence/dotnet-cases.json).

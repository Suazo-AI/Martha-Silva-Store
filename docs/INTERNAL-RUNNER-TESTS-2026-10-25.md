# Independent internal runner checks — 2026-10-25

## Scope and evidence

Base reviewed: `b1eb4bec119e8ee8985d59291146b52c41579566`.
This change owns only `InternalRunner*.cs` and this report. It changes no production
code, package dependency, migration, environment gate, SQL endpoint or deployment.

Coordinated verification used the exact repository SDK, `10.0.402`, with the
existing official package cache and no new package dependencies. Locked restore
passed. Final Release build: **0 warnings, 0 errors**. Final focused runner
suite: **80 passed, 6 explicitly skipped, 0 failed (86 total)**. `git diff --check`
passed. This is a focused runner verification, not a new full-suite result.

| Check / target | State | Evidence or exact limitation |
| --- | --- | --- |
| Pinned build and 80 non-SQL runner cases | Completed / PASS | SDK 10.0.402, final build log and TRX |
| Six runner SQL cases / disposable SQL Server | Pending / SKIPPED | `MARTHA_INTERNAL_TEST_SQL_CONNECTION` absent; no SQL action attempted |
| SQL apply, transaction and commit uncertainty | Unverified | Source review and compiled skipped tests are not live SQL proof |
| Production code changes, server start, EULA, deployment | Not attempted | Outside this test-only change |

Commands (from this backend repository):

```sh
source /workspace/scratch/14cff504045e/martha-cli-qa/tooling/env.sh
unset MARTHA_INTERNAL_TEST_SQL_CONNECTION
dotnet restore backend/Martha.Store.slnx --locked-mode -m:1
dotnet build backend/Martha.Store.slnx --no-restore -c Release -m:1 -p:UseSharedCompilation=false
dotnet test backend/tests/Martha.Store.Api.Tests --no-build --no-restore -c Release \
  --filter 'FullyQualifiedName~InternalRunner' \
  --logger 'trx;LogFileName=internal-runner-tests.trx' \
  --results-directory /workspace/scratch/14cff504045e/savia-internal/evidence-runner-tests
```

Logs/TRX are retained in the task workspace at
`savia-internal/evidence-runner-tests/`; initial failed-assumption evidence was
preserved separately rather than represented as a pass. Only final corrected
source and this report are committed; build outputs and logs are not source.

## Added checks

- Real runner admission rejects invalid key/fingerprint/actor/scope, mismatched
  authenticated actor, missing/unauthenticated identity and disallowed scope
  before callback or connection. A connection interceptor fails the test before
  any network open if admission regresses.
- All 16 known mutation scopes have explicit role allowlists. Unknown scopes,
  role case changes and unauthenticated role claims do not gain permission.
- A providerless context is refused by EF during the `IsSqlServer` check before
  the callback runs; the test verifies the actual configuration exception, not
  a `storage_unavailable` result. It is neither an InMemory/SQLite stand-in nor
  evidence for transaction behavior.
- A deliberately injected availability exception before connection open verifies
  the actual runner `storage_unavailable` result, zero callback calls and no
  retry. No network open, session query or transaction is simulated by this test.
- The SQL model has actor/scope/key unique replay identity, BIN2 collation on
  scope/key/fingerprint, required stored result, restricted actor FK and no seed.
- Tracked operation update/deletion is rejected by both save overloads. This is
  an EF guard assertion, **not** direct-SQL immutability or trigger verification.
- Hosting/database guards reject absent or noncanonical catalogs and MARS; valid
  registration is the real scoped runner with SQL Server and timeout 30 seconds.
  Accepting a catalog name does not establish authority to access any server.
- Six SQL facts reuse the existing `InternalCommerceSqlFact` opt-in and disposable
  fixture. They cover actor/scope/case-sensitive-key separation, persisted session
  revocation, changed-role replay denial, nested typed-result replay, concurrent
  same-key serialization and a post-action storage exception's unknown outcome.
  They do not duplicate the eight commerce-command tests already in the base.

## Source review

`InternalCommandRunner` revalidates persisted session/current scope permission
inside its serializable transaction and before replay. Its application-lock
identity and unique model index agree on actor, exact scope and exact key.
Failed actions roll back to the savepoint and clear tracked effects before the
failure itself is recorded. Caught storage/serialization failures after entering
the action return `unknown_outcome`, without automatic retry. Stored result JSON
uses web serializer defaults. Operation lookup is scoped to the current actor and
requires the same command-scope authorization.

No P1/P2 defect identified in this focused source review. The initial test run
corrected two test assumptions: EF throws for a missing provider (rather than
returning false from `IsSqlServer`), and catalog whitespace must be explicitly
quoted to prevent `SqlConnectionStringBuilder` from normalizing the fixture.
Neither adjustment changes production behavior or weakens the asserted admission
barrier. A malformed authenticated NameIdentifier throws at the runner's internal actor accessor rather than returning
an `unauthenticated` result; the actual cookie/session validator rejects malformed
or duplicate identity claims before business entry. This is not a demonstrated
external authorization bypass. Runtime SQL claims below remain separate from this
source observation.

## Limits and blockers

- Real SQL transaction, application lock, replay persistence, current-session
  revocation, commit ambiguity and direct-SQL audit immutability require the
  separately authorized disposable SQL gate; unit/model tests cannot prove them.
- The reused SQL fixture uses `EnsureCreated`, not release migrations, cookie
  issuance or a successful password login. Its staff/session data is synthetic;
  no bootstrap, SQL server/container start or license acceptance is performed.
- No Windows, deployment, remote push/CI, browser, payment or production acceptance
  claim is made. The backend-only base contains no `tests/check.py`, so that root
  frontend aggregate is not available in this repository.

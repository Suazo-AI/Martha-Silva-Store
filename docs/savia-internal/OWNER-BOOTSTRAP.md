# Explicit offline initial-owner command — implementation only

`--internal-bootstrap-owner` is the sole manual invocation for
`InternalOwnerBootstrap.CreateInitialOwner`. It is **not** an HTTP endpoint,
startup hook, migration, seed, recovery route or default account. Normal startup
and migration/seed commands do not invoke it. The command exits without building
or starting the web host. “Offline” means a separate maintenance process, not
that a database write can happen without SQL connectivity.

**No owner has been created by this implementation or its tests.** Actual
execution requires separate authorization for the operator, server and isolated
database. The repository authorization to complete internal SAVIA code does not
authorize account creation, SQL/EULA acceptance, production or deployment.

## Prerequisites and target

1. Obtain explicit authorization for this specific maintenance action and target.
   Stop the application/other maintenance writers using the separately approved
   operating procedure. Do not bootstrap while serving application requests.
2. Use the pinned SDK/runtime and reviewed release artifact. Configure the existing
   `Development` environment and `InternalSavia:Enabled=true`. Neither is changed
   by this command, and command-line configuration overrides are rejected.
3. Supply the existing `ConnectionStrings:InternalSavia` through the approved
   private configuration mechanism. The command reads no owner credential from
   configuration or environment variables. Do not put connection credentials or
   owner passwords in shell commands, history, source files or logs.
4. Independently verify the configured server is the authorized isolated instance.
   The actual shared `InternalDatabaseGuard` requires the database name
   `SaviaInternalTest_[A-Za-z0-9_]{1,64}` and rejects MARS. That name does **not**
   prove server ownership, environment safety or permission. The console also
   rejects a missing/unsafe server identifier, `AttachDBFilename`,
   `User Instance=true` and any `Failover Partner`. It snapshots the validated connection so configuration
   reload cannot change targets midway. It does not fall back to the synthetic
   Store connection or any other provider/database.
5. The database and reviewed schema must already exist. This command never calls
   `Migrate`, `EnsureCreated`, seed, database creation or schema repair. Preparing
   SQL/schema is a separate authorized procedure, not a workaround to refusal.
6. Use an interactive, private, **unrecorded** local console. Standard input,
   output and error must all be unredirected. Do not use CI, a pipe, transcript,
   terminal recorder, screen sharing or a remote automation runner. A TTY check
   cannot detect recording, local administrators or hostile terminal software;
   the operator must establish that boundary.

## Manual invocation (not executed here)

From the API project directory, with the authorized existing configuration and
reviewed Release build already prepared:

```sh
dotnet ./bin/Release/net10.0/Martha.Store.Api.dll --internal-bootstrap-owner
```

No additional arguments are permitted, including `--migrate`, seed flags,
configuration overrides, usernames or passwords. Nothing is run if the gates or
console checks fail. Target server and database are displayed; the connection
string, database credentials and exception details are not.

The operator must type `PRIVATE`, supply a new login and display name, type the
new password twice, and finally type the exact displayed
`CREATE OWNER IN <server>/<database>` phrase. This is an explicit authorization
checkpoint, not a substitute for the separate operational approval. Escape
cancels before the database attempt. All input uses intercepted console keys
without echo, including the identity fields; Backspace edits silently. Overlong,
control-character, invalid or mismatched inputs stop the invocation without
calling the service. There are no default identities or generated credentials.
Rejected overlong/control-character lines are consumed without echo through
Enter, rather than returning a queued password suffix to the shell. Enter or
paste only one prompted line at a time. Escape or process interruption can still leave queued terminal
input outside this process; terminal privacy and safe cancellation remain the
operator's responsibility.

The password is passed only in process memory to the existing service/hasher.
Temporary character buffers are cleared; .NET immutable strings cannot be
reliably zeroized and may persist until garbage collection. There is no claim
of protection from memory dumps or a compromised host. Bootstrap DI uses no log
providers; input, request, exception and result data are never logged or printed.
The service uses the existing configured password hasher and serializable
transaction. **Any existing staff row**, including disabled/non-owner rows,
closes bootstrap permanently for that database. Never remove staff to reopen it.

## Exit status and uncertain outcomes

| Exit | Meaning | Action |
| --- | --- | --- |
| `0` | Existing service returned a committed creation and nonempty identity ID. | Stop; do not bootstrap again. No credentials or identity ID are printed. |
| `2` | Refused/cancelled before the attempt, or the service explicitly rejected invalid input before writing. | Review the stated gate; do not bypass it. Correct only under existing authorization. |
| `3` | Service returned `bootstrap_closed`. Staff exists; this attempt created no account. | Stop. Use a separately approved account-management/recovery process. |
| `4` | Outcome **UNKNOWN** after service invocation: storage/commit/cancellation error, or unrecognized response. | Do not retry. Reconcile the same target first. |

A connection timeout does not establish that a write failed. Process loss,
Ctrl+C, power loss, absent exit status or a lost commit acknowledgement after the
final confirmation must also be treated as **unknown**, even without exit `4`.
There is no automatic retry or provider fallback. An authorized operator must
inspect safe staff state (IDs, normalized login, role, enabled status; never
password/hash export) on the same confirmed database using separately authorized
read access. If a staff row exists, bootstrap is closed; do not rerun or reset
credentials speculatively. If state remains uncertain or cannot be inspected,
leave the action pending and escalate. A permitted retry requires new material
evidence that the original action did not execute and renewed confirmation;
absence of a response alone is not evidence. This command does not implement a
credential recovery or reconciliation endpoint.

## Verification scope

`InternalOwnerConsoleTests` exercise fake console keys and a fake service
callback only: argument dispatch/refusal, gates, target parsing, input limits,
confirmations, no-echo behavior, sanitized output, existing-staff closure mapping,
and unknown outcomes without retries. These tests never invoke the real
bootstrap callback, create an account or open SQL. They do not prove SQL
transactions/concurrency, database migrations, actual console behavior on Windows,
real login, production security or operational approval. Those remain separate
gates. The older security README's requirement for a reviewed private invocation
is implemented here; its prohibition on executing it without authorization is
unchanged.

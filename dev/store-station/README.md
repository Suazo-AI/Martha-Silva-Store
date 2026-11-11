# Station kit: running the cash register on a store computer

The kit turns this computer into a station for the SAVIA cash register. It creates a disposable
rehearsal database, starts the API over HTTPS with a certificate the machine already trusts, and
opens the register in its own window.

Nothing here stores a credential: the database connection uses Windows Integrated Security, the
certificate password lives in a protected folder on the machine, and the register keeps its own
session cookie.

## One time, on the store computer

1. Build the two binaries with the pinned runtime (10.0.402):

   ```
   dotnet build backend\src\Martha.Store.Api\Martha.Store.Api.csproj -c Debug
   dotnet build tests\golden-path\GoldenPath.Sql\GoldenPath.Sql.csproj -c Release
   ```

2. Prepare the station (creates the disposable database and writes the configuration):

   ```
   powershell -ExecutionPolicy Bypass -File dev\store-station\prepare-station.ps1
   ```

   It prints the database name it created. Use `-Currency HNL -Exponent 2` for lempira, or
   `-Currency USD -Exponent 2` for a dollar till.

3. The station certificate: the API needs an HTTPS certificate the browser accepts, because the
   session cookie is a secure cookie. On this computer the certificate already exists for the local
   SQL instance; export it with

   ```
   powershell -ExecutionPolicy Bypass -File private-exports\owner-recovery-20261110\prepare-station-tls.ps1
   ```

   It writes `C:\ProgramData\Savia\station-tls\station.pfx` plus its password, readable only by
   this account, the administrators and SYSTEM.

## Every day of the rehearsal

1. Create the first Owner once, in a private console (the console refuses redirected input):

   ```
   dev\store-station\bootstrap-owner.cmd
   ```

2. Start the API:

   ```
   dev\store-station\start-api.cmd
   ```

3. Open the register in its own window:

   ```
   dev\store-station\open-register.cmd
   ```

## What the station uses

| Piece | Where |
| --- | --- |
| Configuration | `C:\ProgramData\Savia\station` (database name, currency, no credential) |
| Certificate and its password | `C:\ProgramData\Savia\station-tls` (readable only by the operator, administrators and SYSTEM) |
| Database | a disposable `SaviaInternalTest_Golden_...` database with the four real migrations |
| Register window | Microsoft Edge in application mode over `https://localhost:5001/internal/` |

## Limits

- The rehearsal database is disposable and holds fictitious data only. Deleting it removes every
  trace of the rehearsal.
- The API runs in Development with the internal module enabled. That is a rehearsal posture, not a
  production one.
- The kit does not deploy anything, does not publish anything, and does not touch the production
  database.

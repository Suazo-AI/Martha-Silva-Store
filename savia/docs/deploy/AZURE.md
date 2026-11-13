# SAVIA hub in Azure

Status: prepared and validated locally on 2026-11-12. Nothing is deployed. No Azure resource exists yet.
Checklist and exact commands: [CHECKLIST.md](CHECKLIST.md).

## Result first

The repository now holds everything needed to deploy the SAVIA cloud hub with one approved command sequence.
The container images build, migrate a database and serve the API locally: see [evidence](evidence/local-proof-20261112.json).
The infrastructure template builds and lints without warnings.
The deploy workflow passes actionlint.
Deploying needs Jason's Azure sign-in, a subscription choice, and the GitHub "production" environment.

## What the hub is, and what it is not yet

ADR-001 keeps every store offline-first: each branch runs its own host and its own SQL Server.
The cloud hub is the central node (`Savia:Node:Kind=Cloud`): it owns the catalog and receives branch data through sync.
The sync endpoints are not built yet, and finding F14 (Change Tracking on Azure SQL) is still open.
So a deployed hub today is a hosted API with its own empty database, not a connected multi-store system.
Do not point a branch till at the hub until sync is built and tested.
Deploying early still has value: it proves the hosting, identity, backup, monitoring and rollback path before data depends on it.

## Resources

All resources live in one resource group, created by `savia/deploy/azure/main.bicep`.

| Resource | SKU | Purpose |
| --- | --- | --- |
| Container Apps environment | Consumption | Runs the API and the migration job; sends console logs to Log Analytics. |
| Container App `ca-savia-api` | 0.25 vCPU, 0.5 GiB, 0-2 replicas | Hub API and static web, HTTPS only, multiple revisions for rollback. |
| Container Apps job `caj-savia-migrate` | 0.5 vCPU, 1 GiB, manual trigger | One-off production migration before each new revision. |
| Azure SQL server + database `savia` | Basic (5 DTU, 2 GB) | Hub database; Entra ID authentication only; 7-day point-in-time restore. |
| Container Registry | Basic | Holds the `savia-api` and `savia-migrator` images; no admin user. |
| Key Vault | Standard, RBAC | Holds future secrets (branch node credentials, payment keys). SAVIA needs none today. |
| Log Analytics workspace | Pay-as-you-go, 30-day retention, 1 GB/day cap | Logs, SQL diagnostics, alert data. |
| Application Insights | Workspace-based, local auth off | Request and dependency telemetry after code patch P2. |
| Three user-assigned managed identities | - | `api`, `migrate` and `deploy`, each with only the rights it needs. |
| Action group + 4 metric alerts | - | Email the owner on API errors, restarts, database space and database load. |

## Region

Recommended region: Mexico Central (`mexicocentral`), the Azure region closest to Nicaragua.
The price list has Container Apps, Azure SQL and Key Vault meters for it.
Fallback region: South Central US (`southcentralus`), which is slightly cheaper for compute and has every service.
The branch tills do not depend on latency to the hub, because they work offline and sync in the background.

## Monthly cost

Source: Azure Retail Prices API (`https://prices.azure.com/api/retail/prices`), queried 2026-11-12, USD retail, before taxes.
The Container Apps free grant and the Log Analytics free allowance are from Microsoft's pricing pages, not from the API.

| Item | Unit price (Mexico Central) | Expected month |
| --- | --- | --- |
| Azure SQL Basic | $0.1771/day | $5.39 |
| Pre-migration database copy (one kept) | same as Basic | $5.39 while a copy exists |
| Container Registry Basic | $0.1666/day | $5.07 |
| Container Apps, scale to zero | active vCPU $0.000026/s, idle $0.000003/s, memory $0.000003/GiB-s | $0 within the monthly free grant (180,000 vCPU-s, 360,000 GiB-s, 2 million requests) |
| Container Apps, one replica always warm | same | about $4-8 |
| Key Vault | $0.033 per 10,000 operations | under $0.10 |
| Log Analytics | $2.76/GB after 5 GB free each month (South Central US price; the Mexico Central query was rate-limited) | $0 at pilot volume |

Cheapest viable start: about $16 per month, with scale to zero and one kept pre-migration copy.
Always-warm start: about $20-24 per month.
To save $5.39 per month, run deploys with `-KeepCopies 0` after the first month; the newest copy is still kept until the next deploy.
Main cost risks: a larger SQL tier (S0 is about $15 per month), many kept copies, and log volume above 5 GB.

## Identity and secrets

No connection string, password or key is stored in configuration, in GitHub or in the repository.
The API and the migration job reach Azure SQL with their managed identities (`Authentication=Active Directory Managed Identity`).
Microsoft.Data.SqlClient 6.1.7, already used by SAVIA, supports this, so no application code changes for it.
The SQL server accepts Entra ID logins only; SQL logins are switched off.
The `migrate` identity is the SQL Entra administrator: it runs schema changes and creates the API database user.
The `api` identity gets only the `savia_api_host` database role: read, execute procedures, write `security.Sessions`, update `security.Staff`.
These grants match what `savia/src` does today; the API never runs schema changes.
The `deploy` identity is used by GitHub Actions through OIDC federation, only from the `production` environment of `Suazo-AI/Martha-Silva-Store`.
It can push images, update the app and the job, and copy the database; it cannot read secrets or change role assignments.
Key Vault uses Azure RBAC, soft delete and purge protection; in this template only the API identity can read its secrets.

Break-glass access to SQL: a person cannot sign in to SQL by default, because the administrator is the migrate identity.
If a person must inspect the database, Jason sets an Entra group as administrator for the session and switches it back afterwards (commands in CHECKLIST.md).

## Network and HTTPS

The app accepts HTTPS only (`allowInsecure: false`); Container Apps redirects HTTP and holds the TLS certificate.
SQL accepts connections from Azure services only, and only with an Entra token; branches talk to the API, never to SQL.
A private endpoint for SQL is a later upgrade; it needs a virtual network and costs more.
Code patch P1 adds forwarded headers, HSTS and security headers, because the app sees plain HTTP behind the Container Apps proxy.

## Sessions and cookies

SAVIA does not use cookies today: the sign-in token is a Bearer token kept in the browser's `sessionStorage`.
That token is readable by any script on the page, so the Content-Security-Policy in patch P1 matters.
If cookies are ever added, they must be `Secure`, `HttpOnly` and `SameSite=Strict`.

## Database backups and restore

Azure SQL takes automatic backups; the template keeps 7 days of point-in-time restore (PITR), the Basic maximum.
Backup storage is geo-redundant by default, so a restore is possible after a regional outage.
Before every migration, `savia/deploy/migrate.ps1` records the PITR timestamp and makes a full database copy named `savia-premig-<run>`.
To undo a bad migration, restore that copy or restore to the recorded timestamp into a new database, then point the app at it.
Branch backups stay local in each store, as described in OPERACION.md.

## Migrations

The production runner is `savia/deploy/migrator`, built into the `savia-migrator` image.
It applies `savia/db/migrations/V*.sql` with the same ledger, checksums and batch splitting as `savia/tools/db/saviadb.py`.
The local proof showed that a database migrated by the runner has the same schema fingerprint as one migrated by `saviadb.py`.
It is idempotent: a second run applies nothing; a changed applied file stops the run.
Only one run at a time can migrate, because the runner holds a SQL application lock.
The deploy runs the migration before the new revision gets traffic, while the previous revision still serves.
So every migration must stay compatible with the previous release: add columns and procedures first, remove them one release later.

## Monitoring and alerts

Container console logs and SQL diagnostics (errors, timeouts, blocks, deadlocks) go to Log Analytics.
Application Insights receives request and dependency telemetry after patch P2.
Alerts email the owner when:

1. the API returns more than 5 server errors in 5 minutes;
2. the API container restarts more than 3 times in 15 minutes;
3. the database is more than 80% full (Basic stops writes at 2 GB);
4. the database is above 80% DTU for 15 minutes.

## Deploy and rollback

The deploy runs only from a manual workflow run, after a reviewer approves the `production` environment.
Order: build and push both images, pin traffic to the live revision, back up, migrate, start the new revision with 0% traffic.
The workflow smoke-tests the new revision on its own URL: health, access page, and a refused sign-in that proves the SQL path.
If it passes, the workflow moves 100% of traffic to it and smoke-tests the public URL again.
If any step fails, the workflow moves traffic back to the previous revision and deactivates the new one.
The database is not rolled back automatically; the compatibility rule above keeps the previous revision working.
A manual rollback is one command: `az containerapp ingress traffic set --revision-weight <previous-revision>=100`.

## Data that must never leave a store

- `security.Sessions`: sign-in sessions are local to each node (ADR-001) and are never synced.
- Local `.bak` backup files and the backup folder.
- The local SQL Server SA password and the repository `.env`.
- Branch node credentials, once sync exists; they belong in each store and in Key Vault, never in Git.
- Device, scanner and printer state of the till.
- Staff passwords set through `SAVIA_PILOT_PASSWORD*` variables.
- Card data: SAVIA collects none, and the hub must not start collecting it without a payment provider decision.

## Code patches needed in existing files

These files belong to the area another agent is editing, so this change does not touch them.

| ID | File | Change | Reason |
| --- | --- | --- | --- |
| P1 | `savia/src/Savia.Api/Program.cs` | Add `UseForwardedHeaders` (X-Forwarded-For, X-Forwarded-Proto), `UseHsts` in Production, and headers: `Content-Security-Policy: default-src 'self'; frame-ancestors 'none'`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`. | TLS ends at the Container Apps proxy; the app must know the request was HTTPS, and the Bearer token in `sessionStorage` needs XSS protection. |
| P2 | `savia/src/Savia.Api/Savia.Api.csproj`, `Program.cs` | Add `Azure.Monitor.OpenTelemetry.AspNetCore`; call `UseAzureMonitor` only when `APPLICATIONINSIGHTS_CONNECTION_STRING` is set, with `ManagedIdentityCredential(AZURE_CLIENT_ID)`. | Application Insights telemetry; local auth is off, so ingestion needs the identity. Without it, only console logs reach Azure. |
| P3 | `savia/src/Savia.Api/Program.cs` | Add a fixed-window rate limiter on `POST /api/v1/auth/login` per client IP. | The hub login faces the internet; the existing lockout is per account, not per address. |
| P4 | `savia/src/Savia.Api/Program.cs` | Add `GET /health/ready` that runs `SELECT 1`; point the readiness probe at it. | `/health` does not touch SQL, so probes cannot see a broken database connection. |
| P5 | `savia/db/migrations/V0NN__api_host_role.sql` (new number chosen by the schema owner) | Create role `savia_api_host` with the grants now in `savia/deploy/migrator/Program.cs`. | One source for the API's least-privilege grants, used locally and in Azure. |
| P6 | `savia/Savia.slnx` | Add `deploy/migrator/Savia.Migrator.csproj`. | So the normal solution build and `tests/check.py` compile the migrator. |
| P7 | `tests/check.py` | Add an optional step that runs `python savia/deploy/local_proof.py` when Docker and the dev SQL container are available. | Keeps the container proof in the regular check. |
| P8 | `docs/PROJECT-STATUS.md`, `docs/CODE-MAP.md` | Add the Azure hub status and the `savia/deploy` paths. | Repository rule: record each advance in the area document. |
| P9 | Sync endpoints (ADR-001, F14) | Build hub sync and verify Change Tracking on Azure SQL. | Required before any branch connects to the hub. |

## Files

- `savia/Dockerfile`, `savia/.dockerignore`: API image (default target `api`) and migration image (target `migrator`), pinned base images, non-root user.
- `savia/deploy/migrator/`: production migration runner.
- `savia/deploy/azure/main.bicep`, `main.parameters.example.json`: infrastructure.
- `savia/deploy/migrate.ps1`: backup plus migration job run.
- `savia/deploy/smoke.ps1`: smoke test used by the workflow.
- `savia/deploy/local_proof.py`: local proof against the dev SQL container.
- `.github/workflows/savia-azure.yml`: pull request checks and the approved deploy.

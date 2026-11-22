# SAVIA operations runbook

Written 2026-11-22 from the six Azure runs recorded in [AZURE.md](AZURE.md).
Every command here ran at least once on the live resources, unless the step says "not run".
Resource group: `rg-savia-prod`. App: `ca-savia-api`. Job: `caj-savia-migrate`. SQL server: `sql-savia-bukmlt`, database `savia`. Registry: `acrsaviabukmlt`.

## 1. Deploy a new version of the hub

Requirement: the commit is on `Tony`, and the workflow `SAVIA v2 check` is green for the last commit that changed `savia/`.
Build from a clean worktree, never from a checkout with uncommitted files.

```powershell
git worktree add --detach C:/Users/Jason/wtd <sha>
cd C:/Users/Jason/wtd
$sha = git rev-parse HEAD; $acr = "acrsaviabukmlt"
az acr login --name $acr
docker build --target migrator --tag "$acr.azurecr.io/savia-migrator:$sha" savia
docker build --target api --tag "$acr.azurecr.io/savia-api:$sha" savia
docker push "$acr.azurecr.io/savia-migrator:$sha"
docker push "$acr.azurecr.io/savia-api:$sha"
```

### 1.1 Dry-run the migrations on the newest copy

Rule since 2026-11-22: run the migrator against the newest `savia-premig-*` copy before production.
Reason: local tests run on SQL Server, and Azure SQL Database lacks some system views (V036 failed there with SQL error 208).

```powershell
az sql db list -s sql-savia-bukmlt -g rg-savia-prod --query "[].name" -o tsv   # pick the savia-premig-* copy
az containerapp job start -n caj-savia-migrate -g rg-savia-prod --image "$acr.azurecr.io/savia-migrator:$sha" `
  --container-name migrate --cpu 0.5 --memory 1Gi --env-vars `
  "Savia__Sql__ConnectionString=<the job's connection string with Database=<copy name>>" "AZURE_CLIENT_ID=<migrate identity client id>"
az containerapp job execution show -n caj-savia-migrate -g rg-savia-prod --job-execution-name <name> --query properties.status -o tsv
```

Read the job's connection string and client id with `az containerapp job show -n caj-savia-migrate -g rg-savia-prod`.
Continue only when the status is `Succeeded`.
The copy is older than production, so the dry run applies more migrations than production will; that is expected.

### 1.2 Migrate production and switch traffic

```powershell
az containerapp revision list -n ca-savia-api -g rg-savia-prod --query "[?properties.trafficWeight>``0``].name" -o tsv   # the live revision
az containerapp ingress traffic set -n ca-savia-api -g rg-savia-prod --revision-weight "<live revision>=100"
pwsh savia/deploy/migrate.ps1 -ResourceGroup rg-savia-prod -JobName caj-savia-migrate -SqlServer sql-savia-bukmlt `
  -Database savia -MigratorImage "$acr.azurecr.io/savia-migrator:$sha" -RunId "<short sha>-1"
az containerapp update -n ca-savia-api -g rg-savia-prod --image "$acr.azurecr.io/savia-api:$sha" --revision-suffix "g<7 chars of sha>-1"
pwsh savia/deploy/smoke.ps1 -BaseUrl "https://<fqdn of the new revision>" -RetrySeconds 180
az containerapp ingress traffic set -n ca-savia-api -g rg-savia-prod --revision-weight "ca-savia-api--g<7 chars>-1=100"
pwsh savia/deploy/smoke.ps1 -BaseUrl "https://<app fqdn>"
```

`migrate.ps1` records the point-in-time restore target and copies the database to `savia-premig-<RunId>` before it migrates.
It keeps one copy, so the previous copy is removed.
The new revision gets traffic only after `smoke.ps1` passes on its own address.
Write the revision, job execution, copy name and rollback revision into AZURE.md and the checklist.

## 2. Roll back

Code: one command, to the previous revision.

```powershell
az containerapp ingress traffic set -n ca-savia-api -g rg-savia-prod --revision-weight "<previous revision>=100"
```

Migrations add objects and replace procedures; they do not remove columns or tables.
A rollback to the previous revision has not been exercised on a newer schema: V060 replaced the sync procedures, so smoke-test the old revision after a rollback and treat sync as unproven there.
Data: restore the `savia-premig-*` copy or restore to the recorded point in time into a new database, then point the app at it.
The data restore has not been run. Do the drill in section 5 before real stores connect.

## 3. Add, rotate or revoke a store

Guide with exact arguments: [PROVISIONING.md](../sync/PROVISIONING.md).
The command is a migrator mode: `--provision-node register | create | rotate | revoke`.
It prints the secret once and stores only the hash.
Keep a recovery copy with `az keyvault secret set --vault-name kv-savia-bukmlt ...` (operator step; the tool does not write to Key Vault).
On Azure this needs the stores to exist in the hub database first. Not run on Azure yet.

## 4. Open public web orders

All four are needed; until then the public order route refuses every order.

1. Web stock: a store consigns units to its web location (`POST /api/v1/stock/web-consignments` on the store).
2. CORS: `az containerapp ingress cors enable -n ca-savia-api -g rg-savia-prod --allowed-origins <storefront origin>`, then read it back.
3. Bot check: the Turnstile secret in the API configuration (from Key Vault), and the site key in `site.config.json`.
4. Storefront: `storefront.apiBase` and the SKU map in `site.config.json`, then the steps in [STOREFRONT-DEPLOY.md](../../../docs/production-20261122/STOREFRONT-DEPLOY.md).

Configuration keys and local run: [ORDER-PATH.md](../webstore/ORDER-PATH.md).

## 5. Restore drill (not run)

1. Restore `savia` to a point in time into a new database on the same server.
2. Run the migrator in `--plan` mode against it; expect 0 pending.
3. Confirm that `sync.CurrentFork` differs from production's value; this is the hub's restore signal and is only inferred today.
4. Delete the restored database.

A restored database costs about the same as the pre-migration copy while it exists.

## 6. When something is wrong

| Signal | Where to look | First action |
| --- | --- | --- |
| Alert email: API 5xx or restarts | Application Insights `AppRequests`, `AppExceptions`; Log Analytics `ContainerAppConsoleLogs_CL` | Roll back the revision (section 2) if it started after a deploy. |
| Alert email: database over 80% full or busy | Azure SQL metrics | Basic stops writes at 2 GB; raise the tier (cost) or find the growing table. |
| A store shows "esperando reconstrucción" | The till message shows tables done of total | Wait; the lock lifts when the rebuild ends. Do not edit the database. |
| A store is refused with `sync.schema_mismatch` | The store is on another migration | Update the store to the hub's version. Order: hub first, then stores. |
| A store is refused with 401 on sync | Its credential was revoked or is wrong | Rotate the credential (section 3). |
| A web order is in `payment_review` | Hub screen "Pedidos web" | Mark refunded, or accept and re-reserve. Never cancel a charged order by hand. |
| Migration job failed | Log Analytics, `ContainerJobName_s == 'caj-savia-migrate'` | The live revision did not change. Fix forward; do not edit an applied migration. |

## 7. Limits of this runbook

- Sections 3, 4 and 5 have not run on Azure.
- Store hosts (install, local backup, restore of a store) are in [OPERACION.md](../pilot/OPERACION.md), not here.
- The Azure subscription is a trial; it must be upgraded before about 2026-12-12 or every resource stops.

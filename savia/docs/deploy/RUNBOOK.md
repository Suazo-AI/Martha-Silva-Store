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
A point-in-time restore into a new database ran once (section 6); pointing the app at a restored database has not been run.

## 3. First owner, add a store, rotate or revoke

Full first-day sequence, as it ran locally from empty databases: [DAY-ZERO.md](../../../docs/production-20261122/DAY-ZERO.md).
All of these are migrator modes; none applies migrations, and each retry with the same ids is a no-op.

| Task | Command | Database |
| --- | --- | --- |
| First hub owner | `--provision-staff --role OWNER --set-password` (prints `staff-password:` once) | hub |
| Hub's own node, once | `--provision-node register --node-kind azure` | hub |
| A store's branch, location and register | `--provision-branch` | hub and that store, same ids |
| A store's staff | `--provision-staff --branch-id ... [--approver] --set-password` | hub and that store, same ids |
| The owner's row on a store | `--provision-staff --role OWNER` (no password) | that store |
| A store's node and credential | `--provision-node register` (store), then `create` (hub; prints `node-secret:` once) | both |
| Rotate or revoke | `--provision-node rotate` or `revoke` | hub |

Arguments: [PROVISIONING.md](../sync/PROVISIONING.md).
`--set-password` takes the password from `SAVIA_STAFF_PASSWORD` when set, or prints a new one once; there is no default password.
Keep a recovery copy of a node secret with `az keyvault secret set --vault-name kv-savia-bukmlt ...` (operator step; the tool does not write to Key Vault).
On Azure, run the hub's commands as the `caj-savia-migrate` job with the command's arguments. Not run on Azure yet.

## 4. Open public web orders

All five are needed; until then the public order route refuses every order.
The whole path ran locally from empty databases in a real browser (DAY-ZERO.md steps 10 to 13).

1. Catalog and stock: the hub imports the items, a store receives them and consigns units to the web (`POST /api/v1/stock/web-consignments` on the store).
2. CORS: `az containerapp ingress cors enable -n ca-savia-api -g rg-savia-prod --allowed-origins <storefront origin>`, then read it back. The API also checks `Savia__Public__AllowedOrigins`.
3. Bot check: the Turnstile secret in the API configuration (from Key Vault), and the site key in `site.config.json`.
4. Storefront: `storefront.apiBase` and the SKU map in `site.config.json` (storefront slug to hub SKU, one per size), then the steps in [STOREFRONT-DEPLOY.md](../../../docs/production-20261122/STOREFRONT-DEPLOY.md).
5. `Savia__Public__OrderPageUrl`: the storefront's order page, where a payment return sends the buyer.

Staff work the orders on the hub: "Administración → Pedidos web" (`#/pedidos-web`): "Registrar pago" with the bank reference, then "Marcar enviado".
The store is not told about a web order (DAY-ZERO.md, open gap 1).

Configuration keys and local run: [ORDER-PATH.md](../webstore/ORDER-PATH.md).

## 5. Upgrade a store

A store on another schema version is refused with `sync.schema_mismatch`, so every hub migration stops each store's sync until that store is upgraded.
Order: hub first (section 1), then each store, the same day.

1. Stop the store host (the Windows service or process). The store cannot sell while it is stopped; plan it outside opening hours.
2. Back up the store database ([OPERACION.md](../pilot/OPERACION.md)).
3. Run the migrator of the hub's release against the store database:

   ```powershell
   $env:Savia__Sql__ConnectionString = '<store database, as an admin>'
   dotnet Savia.Migrator.dll --migrations db/migrations
   ```

   Expect `migrate: ledger complete (<n> versions)` with the same count as the hub.
4. Start the store host with the new API build. Its log shows `Sync round: pulled ...` within one interval.

Sales the store made before the upgrade stay in its database and travel on the next round.
Ran locally: hub on V999 (an empty test migration), store refused with `sync.schema_mismatch`, store upgraded with these steps, sync resumed ([run 2](../../../docs/production-20261122/day-zero-evidence/run2.md), step 14).
Not run on a real store host.

## 6. Restore drill

Ran once on 2026-11-22: steps 1, 2 and 4 ([AZURE.md](AZURE.md), checklist O1). Step 3 was not done: the operator account is not a SQL admin.

1. Restore `savia` to a point in time into a new database on the same server.
2. Run the migrator in `--plan` mode against it, as the `caj-savia-migrate` job with `args:` in a `--yaml` template; expect the pending count of the restore time (0 unless a migration ran after it).
3. Confirm that `sync.CurrentFork` differs from production's value; this is the hub's restore signal and is only inferred today.
4. Delete the restored database.

A restored database costs about the same as the pre-migration copy while it exists.

## 7. When something is wrong

| Signal | Where to look | First action |
| --- | --- | --- |
| Alert email: API 5xx or restarts | Application Insights `AppRequests`, `AppExceptions`; Log Analytics `ContainerAppConsoleLogs_CL` | Roll back the revision (section 2) if it started after a deploy. |
| Alert email: database over 80% full or busy | Azure SQL metrics | Basic stops writes at 2 GB; raise the tier (cost) or find the growing table. |
| A store shows "esperando reconstrucción" | The till message shows tables done of total | Wait; the lock lifts when the rebuild ends. Do not edit the database. |
| A store is refused with `sync.schema_mismatch` | The store is on another migration | Upgrade the store (section 5). Order: hub first, then stores. |
| A store is refused with 401 on sync | Its credential was revoked or is wrong | Rotate the credential (section 3). |
| A web order is in `payment_review` | Hub screen "Pedidos web" | Mark refunded, or accept and re-reserve. Never cancel a charged order by hand. |
| Migration job failed | Log Analytics, `ContainerJobName_s == 'caj-savia-migrate'` | The live revision did not change. Fix forward; do not edit an applied migration. |

## 8. Limits of this runbook

- Sections 3 to 5 have not run on Azure or on a real store host; they ran locally from empty databases (DAY-ZERO.md). Section 3's `--provision-branch` ran once on an Azure copy. Section 6 ran on Azure without step 3.
- Store hosts (install, local backup, restore of a store) are in [OPERACION.md](../pilot/OPERACION.md), not here.
- The Azure subscription is a trial; it must be upgraded before about 2026-12-12 or every resource stops.

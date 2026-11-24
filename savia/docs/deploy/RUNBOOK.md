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
| First hub owner | `--provision-staff --role OWNER --set-password` (on Azure with `SAVIA_STAFF_PASSWORD`, section 3.1) | hub |
| Hub's own node, once | `--provision-node register --node-kind azure` | hub |
| A store's branch, location and register | `--provision-branch` | hub and that store, same ids |
| A store's staff | `--provision-staff --branch-id ... [--approver] --set-password` | hub and that store, same ids |
| The owner's row on a store | `--provision-staff --role OWNER` (no password) | that store |
| A store's node and credential | `--provision-node register` (store), then `create` (hub; on Azure with `SAVIA_NODE_SECRET`, section 3.1) | both |
| Rotate or revoke | `--provision-node rotate` or `revoke` | hub |

Arguments: [PROVISIONING.md](../sync/PROVISIONING.md).
`--set-password` takes the password from `SAVIA_STAFF_PASSWORD` when set and prints none.
Without it, it prints a new one-time password once; the staff member must change it at the first sign-in (V064).
`--provision-node create|rotate` takes the secret from `SAVIA_NODE_SECRET` when set and prints none; without it, it prints a new one once.
There is no default password or secret.
On Azure, run the hub's commands as the `caj-savia-migrate` job, always with the variables of section 3.1. Node registration, branch and store credential ran on Azure on 2026-11-24 ([STORE-PC-20261124](../../../docs/production-20261122/STORE-PC-20261124.md)).

### 3.1 Create accounts and store credentials on Azure

Status: steps 3 to 6 ran on Azure on 2026-11-24 for a node secret, with a job secret holding the value instead of a Key Vault reference, because the operator account has no Key Vault data role; 0 secret lines in the workspace ([STORE-PC-20261124](../../../docs/production-20261122/STORE-PC-20261124.md)). The Key Vault reference and the staff-password path have not run on Azure.
Reason: the job's console output goes to Log Analytics (`ContainerAppConsoleLogs_CL`, 30-day retention).
A printed `node-secret:` or `staff-password:` line would stay readable there, so on Azure the value always comes from Key Vault.

Prerequisite: the migrate identity `id-savia-migrate-bukmlt` has no Key Vault role in `main.bicep`; only the API identity has `Key Vault Secrets User`.
Give it that role on each secret it must read, not on the whole vault, and remove the role after the run:

```powershell
$migrateId = az identity show -n id-savia-migrate-bukmlt -g rg-savia-prod --query principalId -o tsv
$vaultId = az keyvault show -n kv-savia-bukmlt --query id -o tsv
az role assignment create --assignee-object-id $migrateId --assignee-principal-type ServicePrincipal `
  --role "Key Vault Secrets User" --scope "$vaultId/secrets/<secret name>"
```

1. Generate the value on the operator's PC. Never print it.
   The result is 43 base64url characters: a valid node secret, and a valid staff password (10 to 200 characters).

```powershell
$value = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
```

2. Store it in Key Vault, one secret per value (for example `node-secret-<node code>` or `staff-password-<login>`).
   `--output none` matters: without it, the CLI prints the secret value.

```powershell
az keyvault secret set --vault-name kv-savia-bukmlt --name <secret name> --value $value --output none
Remove-Variable value
```

3. Give the job a reference to that secret, never the value:

```powershell
az containerapp job secret set -n caj-savia-migrate -g rg-savia-prod --secrets `
  "<job secret name>=keyvaultref:https://kv-savia-bukmlt.vault.azure.net/secrets/<secret name>,identityref:<migrate identity resource id>"
```

4. Start the job with the variable as a secret reference (`secretRef`), never as a literal.
   An override replaces the container's variables, so pass the connection string and the client id too (section 1.1 shows where to read them).
   For a staff password, name the variable `SAVIA_STAFF_PASSWORD` and use the `--provision-staff ... --set-password` arguments.

`az containerapp job start --args` refuses values that start with `--` (seen 2026-11-22), so the arguments go in a template file passed with `--yaml`.
The same form ran `--provision-branch` and `--plan` on Azure; the `secretRef` line has not run.

```yaml
containers:
- name: migrate
  image: acrsaviabukmlt.azurecr.io/savia-migrator:<sha>
  resources: {cpu: 0.5, memory: 1Gi}
  env:
  - name: Savia__Sql__ConnectionString
    value: "<the job's connection string>"
  - name: AZURE_CLIENT_ID
    value: <migrate identity client id>
  - name: SAVIA_NODE_SECRET
    secretRef: <job secret name>
  args: ["--provision-node", "create", "--node-id", "<guid>", "--branch-id", "<guid>", "--node-code", "<code>"]
```

```powershell
az containerapp job start -n caj-savia-migrate -g rg-savia-prod --yaml <template file>
```

5. Confirm that the job log holds no secret.
   The first query must count 0. The second must show the `(not printed)` or `password set` line of this run.

```powershell
$workspace = az monitor log-analytics workspace show -n log-savia-bukmlt -g rg-savia-prod --query customerId -o tsv
az monitor log-analytics query -w $workspace --analytics-query `
  "ContainerAppConsoleLogs_CL | where ContainerJobName_s == 'caj-savia-migrate' | where Log_s has 'node-secret:' or Log_s has 'staff-password:' | count"
az monitor log-analytics query -w $workspace --analytics-query `
  "ContainerAppConsoleLogs_CL | where ContainerJobName_s == 'caj-savia-migrate' | where Log_s has 'provision:' | project TimeGenerated, Log_s | take 20"
```

6. Remove the job's secret reference: `az containerapp job secret remove -n caj-savia-migrate -g rg-savia-prod --secret-names <job secret name>`.
   Then remove the role with `az role assignment delete` and the same scope.

7. Hand the value to its user from Key Vault, not from the log.
   The store operator puts the node secret in the store's configuration ([PROVISIONING.md](../sync/PROVISIONING.md)).
   A staff member receives the password in person.

Limit: a password given with `SAVIA_STAFF_PASSWORD` does not force a change at the first sign-in, because the operator chose it.
Ask the staff member to change it after the first sign-in.

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
- Section 3.1 (Key Vault references for the migrate job) has not run on Azure; the migrate identity's Key Vault role is a manual step, not in `main.bicep`.
- Store hosts (install, local backup, restore of a store) are in [OPERACION.md](../pilot/OPERACION.md), not here.
- The Azure subscription is a trial; it must be upgraded before about 2026-12-12 or every resource stops.

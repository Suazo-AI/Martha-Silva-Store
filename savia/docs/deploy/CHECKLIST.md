# SAVIA Azure deploy checklist

Design and reasons: [AZURE.md](AZURE.md).
Status values: **done in repo**, **patch listed**, **needs owner decision**, **needs Azure access**.

## Items

| # | Item | Status | Evidence or next action |
| --- | --- | --- | --- |
| 1 | API and migration images (`savia/Dockerfile`, `savia/.dockerignore`) | done in repo | `local_proof.py --build`: build exit 0, health and access page OK, non-root, against `SAVIA_DEV_deploytest`. |
| 2 | Production migration runner, idempotent, one run at a time | done in repo | Local proof: apply, re-run applies nothing, changed file refused, schema fingerprint equals `saviadb.py`. |
| 3 | Least-privilege API database user | done in repo | Local proof: API signs in to SQL as `savia_api_host` member, login path returns 401 as expected. |
| 4 | Pre-migration backup and migration job run (`savia/deploy/migrate.ps1`) | done in repo | Parses; not run, because it needs Azure. |
| 5 | Infrastructure (`savia/deploy/azure/main.bicep`) | done in repo | `bicep build` and `bicep lint` exit 0 with no warnings (Bicep 0.49.2). |
| 6 | Workflow: PR checks, approved OIDC deploy, smoke, automatic rollback | done in repo | `actionlint` 1.7.12 exit 0; YAML parses. Not yet run on GitHub. |
| 7 | HTTPS only, managed identity, no secrets in config, Key Vault, PITR, logs, alerts | done in repo | In `main.bicep`; see AZURE.md. |
| 8 | Forwarded headers, HSTS, security headers | patch listed | P1 in AZURE.md. |
| 9 | Application Insights telemetry from the API | patch listed | P2. |
| 10 | Login rate limit, SQL-aware readiness probe | patch listed | P3, P4. |
| 11 | API role as a migration, migrator in the solution, check.py step, status docs | patch listed | P5-P8. |
| 12 | Hub sync endpoints and Change Tracking on Azure SQL (F14) | patch listed | P9; required before a branch connects. |
| 13 | Azure subscription and who pays | needs owner decision | Jason chooses the subscription and billing account. |
| 14 | Region | needs owner decision | Recommended `mexicocentral`; fallback `southcentralus`. |
| 15 | Scale to zero or always warm | needs owner decision | `apiMinReplicas` 0 (about $16/month total) or 1 (about $20-24/month). |
| 16 | Alert email and hub node id | needs owner decision | `alertEmail`, `hubNodeId` parameters. |
| 17 | Who approves production deploys | needs owner decision | Required reviewers on the GitHub `production` environment. |
| 18 | Sign-in, provisioning, GitHub environment and first deploy | needs Azure access | Steps below. Nothing here has been run. |

## First-month cost

About $16 with scale to zero, or about $20-24 with one replica always warm, in USD before taxes.
Breakdown: SQL Basic $5.39, one kept pre-migration copy $5.39, Container Registry $5.07, Container Apps $0-8, logs and Key Vault under $0.10.
Prices: Azure Retail Prices API, Mexico Central, queried 2026-11-12. Details in AZURE.md.

## What Jason must do (each step is a separate approval)

Steps 1-4 create paid resources; run them only after approving the spend above.

### 1. Sign in and choose the subscription

```powershell
az login
az account set --subscription "<subscription-id>"
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
```

### 2. Provision the base (no app yet)

```powershell
az group create --name rg-savia-prod --location mexicocentral
Copy-Item savia/deploy/azure/main.parameters.example.json savia/.out/main.parameters.json
# Edit savia/.out/main.parameters.json: hubNodeId = a new GUID ([guid]::NewGuid()), alertEmail = owner email.
az deployment group create --resource-group rg-savia-prod `
  --template-file savia/deploy/azure/main.bicep --parameters '@savia/.out/main.parameters.json' `
  --query properties.outputs
```

Keep the outputs: `registryName`, `sqlServerName`, `sqlDatabaseName`, `deployClientId`, `tenantId`.
`savia/.out/` is git-ignored, so the edited parameters never reach the repository.

### 3. Push the first images and create the app and the job

```powershell
$acr = "<registryName>"; $sha = git rev-parse HEAD
az acr login --name $acr
docker build --target api --tag "$acr.azurecr.io/savia-api:$sha" savia
docker build --target migrator --tag "$acr.azurecr.io/savia-migrator:$sha" savia
docker push "$acr.azurecr.io/savia-api:$sha"
docker push "$acr.azurecr.io/savia-migrator:$sha"
az deployment group create --resource-group rg-savia-prod `
  --template-file savia/deploy/azure/main.bicep --parameters '@savia/.out/main.parameters.json' `
  deployApps=true apiImage="$acr.azurecr.io/savia-api:$sha" migratorImage="$acr.azurecr.io/savia-migrator:$sha"
pwsh savia/deploy/migrate.ps1 -ResourceGroup rg-savia-prod -JobName caj-savia-migrate `
  -SqlServer "<sqlServerName>" -Database savia -MigratorImage "$acr.azurecr.io/savia-migrator:$sha" -RunId first
pwsh savia/deploy/smoke.ps1 -BaseUrl "https://$(az containerapp show -n ca-savia-api -g rg-savia-prod --query properties.configuration.ingress.fqdn -o tsv)"
```

Before the first migration the API revision may fail its sign-in check, because its database user does not exist yet; the migration job creates it.
`migrate.ps1` and `smoke.ps1` need PowerShell 7 (`pwsh`) and the Azure CLI.

### 4. Create the GitHub environment and variables

In GitHub, repository settings, create the environment `production`.
Add required reviewers, and limit deployment branches to the branch you deploy from.
Add these environment **variables** (none is a secret):

| Variable | Value |
| --- | --- |
| `AZURE_CLIENT_ID` | `deployClientId` output |
| `AZURE_TENANT_ID` | `tenantId` output |
| `AZURE_SUBSCRIPTION_ID` | the chosen subscription id |
| `SAVIA_RESOURCE_GROUP` | `rg-savia-prod` |
| `SAVIA_ACR_NAME` | `registryName` output |
| `SAVIA_API_APP` | `ca-savia-api` |
| `SAVIA_MIGRATE_JOB` | `caj-savia-migrate` |
| `SAVIA_SQL_SERVER` | `sqlServerName` output |
| `SAVIA_SQL_DATABASE` | `savia` |

### 5. Every later deploy

```powershell
gh workflow run savia-azure.yml --ref <branch>
gh run watch
```

A reviewer approves the `production` environment in GitHub; the workflow then pushes, backs up, migrates, smoke-tests and promotes or rolls back.

## Recovery commands

Manual rollback to the previous revision:

```powershell
az containerapp revision list -n ca-savia-api -g rg-savia-prod --query "[].{name:name,active:properties.active,traffic:properties.trafficWeight}" -o table
az containerapp ingress traffic set -n ca-savia-api -g rg-savia-prod --revision-weight "<previous-revision>=100"
```

Restore the database to a point in time (creates a new database; the old one stays):

```powershell
az sql db restore -g rg-savia-prod --server "<sqlServerName>" --name savia --dest-name savia-restored --time "<UTC timestamp from the deploy summary>"
```

Break-glass SQL access for a person, then switch back:

```powershell
az sql server ad-admin create -g rg-savia-prod --server-name "<sqlServerName>" --display-name "<Entra group>" --object-id "<group object id>"
# ... inspect ...
az sql server ad-admin create -g rg-savia-prod --server-name "<sqlServerName>" --display-name "<migrate identity name>" --object-id "<migrate identity client id>"
```

Re-running the template resets the administrator to the migrate identity as well.

## Not verified

- Nothing has run against Azure: no sign-in, no resource, no deploy, no spend.
- The workflow has not run on GitHub; the PR job is the first real test of `smoke.ps1` (it needs PowerShell 7, absent on this PC).
- `CREATE USER ... FROM EXTERNAL PROVIDER WITH OBJECT_ID` and managed identity sign-in to Azure SQL are untested; local proof used SQL logins.
- Change Tracking (migration V008) on Azure SQL Basic is untested (F14).
- Alert metric names and dimensions are from the Azure Monitor metric reference, not from a live resource.
- The Container Apps free grant and the Log Analytics free allowance were not in the price API response.

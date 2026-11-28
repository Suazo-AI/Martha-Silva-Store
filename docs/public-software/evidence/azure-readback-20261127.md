# Azure readback, 2026-11-27

Read-only `az` commands against resource group `rg-savia-prod`, run from Jason's signed-in CLI on SUAZO-PC.
Subscription id and object ids of people are left out; managed identity names are kept.
Nothing was changed.

## SEC-22: encryption at rest (TDE)

`az sql db tde show -g rg-savia-prod -s sql-savia-bukmlt -d <db> --query state`
- `savia`: `Enabled`.
- `savia-premig-1b1e001-1` (pre-migration copy): `Enabled`.

`az sql server tde-key show -g rg-savia-prod -s sql-savia-bukmlt --query serverKeyType`: `ServiceManaged`.
Backups of a TDE database are encrypted with the same key (Azure SQL behaviour, not observed directly).

## SEC-13 and SEC-21: SQL sign-in and transport

`az sql server show -g rg-savia-prod -n sql-savia-bukmlt`
- `administrators.administratorType`: `ActiveDirectory`.
- `administrators.azureAdOnlyAuthentication`: `true`; `az sql server ad-only-auth get` also returns `true`, so a SQL password cannot sign in.
- `minimalTlsVersion`: `1.2`.
- `publicNetworkAccess`: `Enabled`; the only firewall rule is `AllowAllWindowsAzureIps` (0.0.0.0).

`az containerapp revision show -n ca-savia-api --revision ca-savia-api--gc4b45ae-1` env `Savia__Sql__ConnectionString`:
`Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False`, with the client id of `id-savia-api-bukmlt`, and no password field.

## SEC-15: Key Vault

`az keyvault show -g rg-savia-prod -n kv-savia-bukmlt`
- `enableRbacAuthorization`: `true`.
- `enableSoftDelete`: `true`; `softDeleteRetentionInDays`: `90`.
- `enablePurgeProtection`: `true`.
- `publicNetworkAccess`: `Enabled`; `networkAcls`: none.

`az role assignment list --scope <vault id> --include-inherited`
- `Key Vault Secrets User` at vault scope: one service principal, `id-savia-api-bukmlt`.
- `Reader` at resource group scope: `id-savia-deploy-bukmlt` (management plane only; with RBAC it cannot read secrets).
- `Owner` at subscription scope: one user (the operator). Owner holds no Key Vault data role, but can grant one.

## SEC-47: telemetry personal data

`az resource show -n appi-savia-bukmlt --resource-type Microsoft.Insights/components`
- `DisableIpMasking`: not set (default: client IP is masked to 0.0.0.0).
- `DisableLocalAuth`: `true`; `RetentionInDays`: `90`; ingestion into `log-savia-bukmlt`.

Log Analytics query over 30 days (aggregates only; no row was read):

| Table | Rows | Client IP not 0.0.0.0 | Email in URL | Email in name or message | URL with a query |
| --- | --- | --- | --- | --- | --- |
| requests | 20,031 | 0 | 0 | 0 | 6 |
| traces | 113,297 | 0 | 0 | 0 | 0 |
| dependencies | 26,481 | 0 | 0 | 0 | 19 |

The email pattern is `[A-Za-z0-9._%+-]+(@|%40)[A-Za-z0-9-]+\.[A-Za-z]{2,}`, so it also matches `%40` (an encoded @).
Positive control, same workspace and same pattern (`print ... matches regex e`): `ana.prueba@example.com` true, `/x?m=ana.prueba%40example.com` true, `no email here` false, `a@bxcom` false.
The query JSON was written by Python, because an earlier hand-written file had invalid escapes; the counts above come from the corrected query.
Query parameter names in those URLs: `date`, `period` (`/api/v1/reports/*`), `code` (`/api/v1/catalog/lookup` on the e2e app), and `api-version`, `client_id`, `resource` (managed identity token calls to localhost).
None of them carry personal data.
The exceptions table had no rows in 30 days.

## Limits

- A regex finds emails, not every kind of personal data; names or phone numbers in free text were not searched.
- The readback is a point in time; a later code change could log personal data. `SafeLogTests.cs` guards the SQL error path only.
- SQL and Key Vault accept traffic from the public network; access is gated by Entra ID and RBAC, not by network rules.

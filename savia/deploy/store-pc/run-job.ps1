param([Parameter(Mandatory)][string]$Database, [Parameter(Mandatory)][string[]]$JobArgs, [switch]$WithNodeSecret,
      [string]$SecretFile, [ValidateSet('SAVIA_NODE_SECRET', 'SAVIA_STAFF_PASSWORD')][string]$SecretEnv)
# Runs one migrator mode as caj-savia-migrate on $Database. Prints only the execution name, status and its log lines.
# -WithNodeSecret passes TIENDA1's node secret (job secret node-secret-tienda1, added beforehand).
# -SecretFile with -SecretEnv passes the file's value as that env var through a temporary job secret, removed afterwards.
# Continue: Windows PowerShell 5.1 turns any az warning on stderr into a terminating error under Stop.
# Every failure that matters is checked explicitly below and thrown.
$ErrorActionPreference = 'Continue'
$image = 'acrsaviabukmlt.azurecr.io/savia-migrator:1b1e001625ad0617f60d784fe5ba697e5cbc7d16'
$client = '89d213c2-3050-4373-9033-e654fcfe98a5'
$conn = "Server=tcp:sql-savia-bukmlt.database.windows.net,1433;Database=$Database;Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;Connect Timeout=30;User Id=$client"
$argYaml = ($JobArgs | ForEach-Object { '"' + $_ + '"' }) -join ', '
$secretEnvYaml = if ($WithNodeSecret) { "`n  - name: SAVIA_NODE_SECRET`n    secretRef: node-secret-tienda1" } else { '' }
$tempSecret = $null
try {
if ($SecretFile) {
  if (-not $SecretEnv) { throw '-SecretFile needs -SecretEnv' }
  $tempSecret = 'run-job-' + [guid]::NewGuid().ToString('N').Substring(0, 12)
  $value = (Get-Content $SecretFile -Raw).Trim()
  az containerapp job secret set -n caj-savia-migrate -g rg-savia-prod --secrets "$tempSecret=$value" -o none 2>$null
  Remove-Variable value
  $names = @(az containerapp job secret list -n caj-savia-migrate -g rg-savia-prod --query "[].name" -o tsv)
  if ($names -notcontains $tempSecret) { throw "job secret $tempSecret was not added" }
  $secretEnvYaml += "`n  - name: $SecretEnv`n    secretRef: $tempSecret"
}
$yaml = @"
containers:
- name: migrate
  image: $image
  resources: {cpu: 0.5, memory: 1Gi}
  env:
  - name: Savia__Sql__ConnectionString
    value: "$conn"
  - name: AZURE_CLIENT_ID
    value: $client$secretEnvYaml
  args: [$argYaml]
"@
$file = Join-Path $env:TEMP "savia-job-$([guid]::NewGuid()).yaml"
# No BOM: Windows PowerShell 5.1 writes one with -Encoding utf8, and the job then ignores the whole override
# and runs its default template (a plain migrate on the production database).
[IO.File]::WriteAllText($file, $yaml)
$before = @(az containerapp job execution list -n caj-savia-migrate -g rg-savia-prod --query "[].name" -o tsv)
$out = az containerapp job start -n caj-savia-migrate -g rg-savia-prod --yaml $file --query name -o tsv 2>$null
Remove-Item $file
if (-not $out) {
  Start-Sleep 10
  $after = @(az containerapp job execution list -n caj-savia-migrate -g rg-savia-prod --query "[].name" -o tsv)
  $out = @($after | Where-Object { $before -notcontains $_ })[0]
  if (-not $out) { throw 'job start failed and no new execution is listed' }
}
"execution: $out"
do { Start-Sleep 15; $st = az containerapp job execution show -n caj-savia-migrate -g rg-savia-prod --job-execution-name $out --query properties.status -o tsv 2>$null } while ($st -in @('Running', 'Processing', '', $null))
"status: $st"
} finally {
  if ($tempSecret) {
    for ($i = 0; $i -lt 3; $i++) {
      az containerapp job secret remove -n caj-savia-migrate -g rg-savia-prod --secret-names $tempSecret --yes -o none 2>$null
      if (@(az containerapp job secret list -n caj-savia-migrate -g rg-savia-prod --query "[].name" -o tsv) -notcontains $tempSecret) { break }
      Start-Sleep 10
    }
    "temporary job secret removed: $(@(az containerapp job secret list -n caj-savia-migrate -g rg-savia-prod --query "[].name" -o tsv) -notcontains $tempSecret)"
  }
}
$ws = az monitor log-analytics workspace show -n log-savia-bukmlt -g rg-savia-prod --query customerId -o tsv
for ($i = 0; $i -lt 20; $i++) {
  $lines = az monitor log-analytics query -w $ws --analytics-query "ContainerAppConsoleLogs_CL | where ContainerGroupName_s startswith '$out' | project TimeGenerated, Log_s | order by TimeGenerated asc" --query "[].Log_s" -o tsv 2>$null
  if ($lines) { break }; Start-Sleep 30
}
$leak = az monitor log-analytics query -w $ws --analytics-query "ContainerAppConsoleLogs_CL | where ContainerJobName_s == 'caj-savia-migrate' | where Log_s has 'node-secret:' or Log_s has 'staff-password:' | count" --query "[0].Count" -o tsv
"secret lines in workspace: $leak"
$lines | Where-Object { $_ -notmatch 'node-secret:|staff-password:' }
# The override took effect only if the migrator connected to the database asked for.
if (-not ($lines -match "database $([regex]::Escape($Database))[,:]")) { "WRONG DATABASE: the log does not name $Database"; exit 1 }
if ($st -ne 'Succeeded') { exit 1 }

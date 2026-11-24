param([Parameter(Mandatory)][string]$Database, [Parameter(Mandatory)][string[]]$JobArgs, [switch]$WithNodeSecret)
# Runs one migrator mode as caj-savia-migrate on $Database. Prints only the execution name, status and its log lines.
$ErrorActionPreference = 'Stop'
$image = 'acrsaviabukmlt.azurecr.io/savia-migrator:1b1e001625ad0617f60d784fe5ba697e5cbc7d16'
$client = '89d213c2-3050-4373-9033-e654fcfe98a5'
$conn = "Server=tcp:sql-savia-bukmlt.database.windows.net,1433;Database=$Database;Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;Connect Timeout=30;User Id=$client"
$argYaml = ($JobArgs | ForEach-Object { '"' + $_ + '"' }) -join ', '
$secretEnv = if ($WithNodeSecret) { "`n  - name: SAVIA_NODE_SECRET`n    secretRef: node-secret-tienda1" } else { '' }
$yaml = @"
containers:
- name: migrate
  image: $image
  resources: {cpu: 0.5, memory: 1Gi}
  env:
  - name: Savia__Sql__ConnectionString
    value: "$conn"
  - name: AZURE_CLIENT_ID
    value: $client$secretEnv
  args: [$argYaml]
"@
$file = Join-Path $env:TEMP "savia-job-$([guid]::NewGuid()).yaml"
Set-Content $file $yaml -Encoding utf8
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
$ws = az monitor log-analytics workspace show -n log-savia-bukmlt -g rg-savia-prod --query customerId -o tsv
for ($i = 0; $i -lt 20; $i++) {
  $lines = az monitor log-analytics query -w $ws --analytics-query "ContainerAppConsoleLogs_CL | where ContainerGroupName_s startswith '$out' | project TimeGenerated, Log_s | order by TimeGenerated asc" --query "[].Log_s" -o tsv 2>$null
  if ($lines) { break }; Start-Sleep 30
}
$leak = az monitor log-analytics query -w $ws --analytics-query "ContainerAppConsoleLogs_CL | where ContainerJobName_s == 'caj-savia-migrate' | where Log_s has 'node-secret:' or Log_s has 'staff-password:' | count" --query "[0].Count" -o tsv
"secret lines in workspace: $leak"
$lines | Where-Object { $_ -notmatch 'node-secret:|staff-password:' }

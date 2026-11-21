<#
.SYNOPSIS
  Runs the SAVIA production migration in Azure as a one-off Container Apps job, after a backup.

.DESCRIPTION
  Used by .github/workflows/savia-azure.yml before a new API revision gets traffic.
  It can also be run by hand after `az login`.
  Steps:
    1. Record the point-in-time restore (PITR) timestamp.
    2. Copy the database to <db>-premig-<RunId> (a restorable full copy); keep the newest KeepCopies copies.
    3. Point the migration job at the new image and start one execution.
    4. Wait for the execution and fail if it does not succeed.
  The migrator (savia/deploy/migrator) is idempotent: applied files are skipped, changed files stop the run,
  and one run holds a SQL application lock. No secret is used: the job reaches SQL with its managed identity.

.EXAMPLE
  pwsh savia/deploy/migrate.ps1 -ResourceGroup rg-savia-prod -JobName caj-savia-migrate `
    -SqlServer sql-savia-abc123 -Database savia -MigratorImage acrsaviaabc123.azurecr.io/savia-migrator:<sha> -RunId <sha>
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ResourceGroup,
    [Parameter(Mandatory)] [string] $JobName,
    [Parameter(Mandatory)] [string] $SqlServer,
    [Parameter(Mandatory)] [string] $Database,
    [Parameter(Mandatory)] [string] $MigratorImage,
    [Parameter(Mandatory)] [ValidatePattern('^[A-Za-z0-9-]{1,40}$')] [string] $RunId,
    [ValidateRange(0, 5)] [int] $KeepCopies = 1,
    [ValidateRange(60, 7200)] [int] $TimeoutSeconds = 2100,
    [switch] $SkipBackup
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Invoke-Az {
    $output = & az @args --only-show-errors
    if ($LASTEXITCODE -ne 0) { throw "az $($args[0..2] -join ' ') failed with exit code $LASTEXITCODE" }
    return $output
}

$pitr = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
Write-Host "migrate: point-in-time restore target before this migration: $pitr"
if ($env:GITHUB_STEP_SUMMARY) {
    "Pre-migration PITR timestamp: ``$pitr`` (server $SqlServer, database $Database)" | Out-File -Append $env:GITHUB_STEP_SUMMARY
}

if (-not $SkipBackup) {
    $copy = ("$Database-premig-$RunId").ToLowerInvariant()
    if ($copy.Length -gt 128) { $copy = $copy.Substring(0, 128) }
    Write-Host "migrate: copying $Database to $copy (transactionally consistent copy, same server)"
    Invoke-Az sql db copy --resource-group $ResourceGroup --server $SqlServer --name $Database `
        --dest-name $copy --backup-storage-redundancy Local | Out-Null
    $copies = Invoke-Az sql db list --resource-group $ResourceGroup --server $SqlServer `
        --query "[?starts_with(name, '$Database-premig-')].{name:name, created:creationDate}" -o json | ConvertFrom-Json
    $stale = @($copies | Sort-Object created -Descending | Select-Object -Skip $KeepCopies)
    foreach ($old in $stale) {
        if ($old.name -eq $copy) { continue }
        Write-Host "migrate: removing older pre-migration copy $($old.name)"
        Invoke-Az sql db delete --resource-group $ResourceGroup --server $SqlServer --name $old.name --yes | Out-Null
    }
}
else {
    Write-Warning 'migrate: backup copy skipped; only the automatic PITR backups protect this run.'
}

Write-Host "migrate: job $JobName -> image $MigratorImage"
Invoke-Az containerapp job update --resource-group $ResourceGroup --name $JobName --image $MigratorImage | Out-Null
$execution = Invoke-Az containerapp job start --resource-group $ResourceGroup --name $JobName --query name -o tsv
$execution = "$execution".Trim()
if (-not $execution) { throw 'migrate: the job did not return an execution name' }
Write-Host "migrate: execution $execution started"

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$status = ''
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 10
    $status = ("" + (Invoke-Az containerapp job execution show --resource-group $ResourceGroup --name $JobName `
        --job-execution-name $execution --query properties.status -o tsv)).Trim()
    Write-Host "migrate: status $status"
    if ($status -in @('Succeeded', 'Failed', 'Stopped', 'Degraded')) { break }
}

if ($status -ne 'Succeeded') {
    Write-Host "migrate: execution $execution ended with '$status'. Logs: Log Analytics table ContainerAppConsoleLogs_CL, ContainerJobName_s == '$JobName'."
    Write-Host "migrate: the live revision was not changed. Restore options: copy $Database-premig-$RunId, or PITR to $pitr."
    exit 1
}
Write-Host "migrate: execution $execution succeeded"

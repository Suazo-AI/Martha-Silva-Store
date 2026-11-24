# Starts the TIENDA1 store host on http://127.0.0.1:5080. Secrets come from DPAPI files (this Windows user only) and are never printed.
$ErrorActionPreference = 'Stop'
$dir = $PSScriptRoot
$release = Get-Content "$dir\current-release.txt"
$ids = Get-Content "$dir\ids.json" | ConvertFrom-Json
function Get-Dp($f) { [Net.NetworkCredential]::new('', (Get-Content "$dir\$f" | ConvertTo-SecureString)).Password }
$running = Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" | Where-Object CommandLine -like "*SaviaStore*Savia.Api.dll*"
if ($running) { "already running: pid $($running.ProcessId)"; return }
# At sign-in Docker Desktop may not run yet: start it, then wait up to 5 minutes for the engine.
docker info --format '{{.ServerVersion}}' 2>$null | Out-Null
if ($LASTEXITCODE -ne 0 -and -not (Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue)) { Start-Process 'C:\Program Files\Docker\Docker\Docker Desktop.exe' }
for ($i = 0; $i -lt 60; $i++) { docker info --format '{{.ServerVersion}}' 2>$null | Out-Null; if ($LASTEXITCODE -eq 0) { break }; Start-Sleep 5 }
if ((docker inspect -f '{{.State.Running}}' savia-store-tienda1) -ne 'true') { docker start savia-store-tienda1 | Out-Null; Start-Sleep 15 }
$app = Get-Dp app.dpapi
$psi = [Diagnostics.ProcessStartInfo]::new('C:\Users\Jason\.dotnet-sdk-10.0.402\dotnet.exe', "`"$dir\$release\api\Savia.Api.dll`"")
$psi.WorkingDirectory = "$dir\$release\api"; $psi.UseShellExecute = $false
$e = $psi.Environment
$e['DOTNET_ROOT'] = 'C:\Users\Jason\.dotnet-sdk-10.0.402'
$e['ASPNETCORE_ENVIRONMENT'] = 'Production'
$e['ASPNETCORE_URLS'] = 'http://127.0.0.1:5080'
$e['Savia__Sql__ConnectionString'] = "Server=127.0.0.1,14350;Database=SAVIA_TIENDA1;User Id=savia_store_app;Password=$app;Encrypt=True;TrustServerCertificate=True"
$e['Savia__Web__Root'] = "$dir\$release\src\savia\web"
$e['Savia__Node__Kind'] = 'Branch'
$e['Savia__Node__NodeId'] = $ids.storeNode
$e['Savia__Node__BranchId'] = $ids.branch
$e['Savia__Node__LocationId'] = $ids.location
$e['Savia__Sync__HubUrl'] = 'https://ca-savia-api.ambitiousmeadow-f104c22d.mexicocentral.azurecontainerapps.io'
$e['Savia__Sync__NodeSecret'] = Get-Dp node-secret.dpapi
$e['Savia__Sync__IntervalSeconds'] = '60'
Remove-Variable app
New-Item -ItemType Directory -Force "$dir\logs" | Out-Null
$log = "$dir\logs\store-$(Get-Date -Format yyyyMMdd-HHmmss).txt"
# cmd redirects the host's output to the log file so the process outlives this shell.
$psi.FileName = 'cmd.exe'
$psi.Arguments = "/c `"`"C:\Users\Jason\.dotnet-sdk-10.0.402\dotnet.exe`" `"$dir\$release\api\Savia.Api.dll`" > `"$log`" 2>&1`""
$psi.CreateNoWindow = $true
$p = [Diagnostics.Process]::Start($psi)
"started: cmd pid $($p.Id), log $log"

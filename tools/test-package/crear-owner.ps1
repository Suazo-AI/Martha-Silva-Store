. "$PSScriptRoot\comun.ps1"
$cfg = Get-SaviaConfig
Set-SaviaEnvironment $cfg
& (Join-Path $Root 'app\Martha.Store.Api.exe') --internal-bootstrap-owner
Write-Host "Codigo de salida: $LASTEXITCODE (0 = Owner creado)"

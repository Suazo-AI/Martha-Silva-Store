. "$PSScriptRoot\comun.ps1"
$cfg = Get-SaviaConfig
Set-SaviaEnvironment $cfg

# Certificado HTTPS solo para localhost, guardado en .local. No se instala como confiable.
$pfx = Join-Path $Local 'localhost.pfx'; $pwdFile = Join-Path $Local 'localhost.pfx.key'
if (-not (Test-Path $pfx)) {
    $pass = [guid]::NewGuid().ToString('N')
    $cert = New-SelfSignedCertificate -DnsName 'localhost' -CertStoreLocation 'Cert:\CurrentUser\My' -NotAfter (Get-Date).AddYears(1) -FriendlyName 'SAVIA local'
    Export-PfxCertificate -Cert $cert -FilePath $pfx -Password (ConvertTo-SecureString $pass -AsPlainText -Force) | Out-Null
    Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)"
    Set-Content $pwdFile $pass -NoNewline
}
$env:Kestrel__Certificates__Default__Path = $pfx
$env:Kestrel__Certificates__Default__Password = (Get-Content $pwdFile -Raw)
$env:ASPNETCORE_URLS = "https://localhost:$($cfg.Port)"

Write-Host "Base: $($cfg.Server) / $($cfg.Database)" -ForegroundColor Green
Write-Host "Abrir: https://localhost:$($cfg.Port)/internal/login  (Ctrl+C para detener)" -ForegroundColor Green
Start-Process "https://localhost:$($cfg.Port)/internal/login"
& (Join-Path $Root 'app\Martha.Store.Api.exe')

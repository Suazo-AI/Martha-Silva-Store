# Configuracion local de SAVIA. Solo cambia variables de ESTE proceso; no toca otras apps ni conexiones.
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Local = Join-Path $Root '.local'
$ConfigFile = Join-Path $Local 'config.json'
New-Item -ItemType Directory -Force $Local | Out-Null

function Get-SaviaConfig {
    if (Test-Path $ConfigFile) { return Get-Content $ConfigFile -Raw | ConvertFrom-Json }
    Write-Host 'Primera vez: configuremos la base.' -ForegroundColor Cyan
    $server = Read-Host 'Servidor SQL (Enter = localhost)'
    if (-not $server) { $server = 'localhost' }
    $db = Read-Host 'Nombre de la base (Enter = SaviaInternalTest_Primo)'
    if (-not $db) { $db = 'SaviaInternalTest_Primo' }
    if ($db -notmatch '^SaviaInternalTest_[A-Za-z0-9_]{1,64}$') { throw 'La base debe llamarse SaviaInternalTest_<algo> (letras, numeros o _).' }
    $auth = Read-Host 'Autenticacion: W = Windows (Enter), S = usuario SQL'
    $cfg = [pscustomobject]@{ Server = $server; Database = $db; SqlUser = ''; Port = 5443 }
    if ($auth -match '^[sS]') { $cfg.SqlUser = Read-Host 'Usuario SQL' }
    $cfg | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8
    return $cfg
}

function Set-SaviaEnvironment($cfg) {
    $cs = "Server=$($cfg.Server);Database=$($cfg.Database);Encrypt=True;TrustServerCertificate=True;MultipleActiveResultSets=False;Connect Timeout=15"
    if ($cfg.SqlUser) {
        $sec = Read-Host "Contrasena SQL de $($cfg.SqlUser)" -AsSecureString
        $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
        $cs += ";User ID=$($cfg.SqlUser);Password=$plain"
    } else { $cs += ';Integrated Security=True' }
    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    $env:InternalSavia__Enabled = 'true'
    $env:InternalSavia__Cash__Currency = 'HNL'
    $env:InternalSavia__Cash__Exponent = '2'
    $env:ConnectionStrings__InternalSavia = $cs
}

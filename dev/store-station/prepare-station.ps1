# Prepares this computer to run the SAVIA cash register as a station.
#
# It creates the disposable rehearsal database the register will use and writes the station
# configuration. No credential is stored: the database connection uses Windows Integrated Security
# and the certificate password stays in the protected station folder.
param(
  [string]$DatabaseName = '',
  [string]$Currency = 'HNL',
  [int]$Exponent = 2,
  [string]$Server = 'localhost\SAVIATEST'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$station = "$env:ProgramData\Savia\station"
New-Item -ItemType Directory -Force -Path $station | Out-Null
if (-not $DatabaseName) { $DatabaseName = 'SaviaInternalTest_Golden_' + ([guid]::NewGuid().ToString('N')) }

$helper = Join-Path $root '..\..\tests\golden-path\GoldenPath.Sql\bin\Release\net10.0\GoldenPath.Sql.dll'
if (-not (Test-Path $helper)) {
  throw 'GoldenPath.Sql is not built. Run: dotnet build tests\golden-path\GoldenPath.Sql\GoldenPath.Sql.csproj -c Release'
}
$dotnet = if ($env:DOTNET_ROOT -and (Test-Path (Join-Path $env:DOTNET_ROOT 'dotnet.exe'))) { Join-Path $env:DOTNET_ROOT 'dotnet.exe' } else { 'dotnet' }
$env:MARTHA_TEST_SQL_CONNECTION = "Data Source=$Server;Initial Catalog=master;Integrated Security=true;Encrypt=true;TrustServerCertificate=false;Pooling=false;Connect Timeout=15"

# The helper creates and migrates the database, and refuses a name that already exists.
& $dotnet $helper create $DatabaseName
if ($LASTEXITCODE -ne 0) { throw "The rehearsal database $DatabaseName could not be created." }

Set-Content -Path (Join-Path $station 'connection.txt') -Value "Data Source=$Server;Initial Catalog=$DatabaseName;Integrated Security=true;Encrypt=true;TrustServerCertificate=false;Pooling=false;Connect Timeout=15" -Encoding ASCII
Set-Content -Path (Join-Path $station 'internal-cash.txt') -Value $Currency -Encoding ASCII
Set-Content -Path (Join-Path $station 'internal-cash-exponent.txt') -Value $Exponent -Encoding ASCII
Set-Content -Path (Join-Path $station 'station.json') -Value (@{ database = $DatabaseName; server = $Server; currency = $Currency; exponent = $Exponent; prepared = (Get-Date).ToString('o') } | ConvertTo-Json) -Encoding UTF8

"STATION READY"
"database: $DatabaseName"
"start the api with: $root\start-api.cmd"
"open the register with: $root\open-register.cmd"

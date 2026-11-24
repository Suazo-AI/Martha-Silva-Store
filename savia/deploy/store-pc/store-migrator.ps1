param([Parameter(Mandatory)][string[]]$MigratorArgs, [string]$Release = (Get-Content "$PSScriptRoot\current-release.txt"))
# Runs the store's migrator as sa against SAVIA_TIENDA1. Passwords come from DPAPI files and are never printed.
$ErrorActionPreference = 'Stop'
$sa = [Net.NetworkCredential]::new('', (Get-Content "$PSScriptRoot\sa.dpapi" | ConvertTo-SecureString)).Password
$env:DOTNET_ROOT = 'C:\Users\Jason\.dotnet-sdk-10.0.402'
$env:Savia__Sql__ConnectionString = "Server=127.0.0.1,14350;Database=SAVIA_TIENDA1;User Id=sa;Password=$sa;Encrypt=True;TrustServerCertificate=True"
Remove-Variable sa
try {
  & "$env:DOTNET_ROOT\dotnet.exe" "$PSScriptRoot\$Release\migrator\Savia.Migrator.dll" --migrations "$PSScriptRoot\$Release\src\savia\db\migrations" @MigratorArgs
  if ($LASTEXITCODE -ne 0) { throw "migrator exit $LASTEXITCODE" }
} finally { Remove-Item Env:Savia__Sql__ConnectionString }

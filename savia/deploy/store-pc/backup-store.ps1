# Full backup of SAVIA_TIENDA1 to C:\Users\Jason\SaviaStore\backups, checked with RESTORE VERIFYONLY; keeps 14 days.
# The sa password comes from a DPAPI file and is never printed. Exit code 0 only when the copy is verified.
$ErrorActionPreference = 'Stop'
$dir = $PSScriptRoot
$out = Join-Path $dir 'backups'; New-Item -ItemType Directory -Force $out | Out-Null
$log = Join-Path $dir 'logs\backup.txt'; New-Item -ItemType Directory -Force (Split-Path $log) | Out-Null
function Write-Log($m) { $line = "$((Get-Date).ToUniversalTime().ToString('u')) $m"; Add-Content -Path $log -Value $line -Encoding utf8; $line }
$name = "SAVIA_TIENDA1-$((Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')).bak"
$sa = [Net.NetworkCredential]::new('', (Get-Content "$dir\sa.dpapi" | ConvertTo-SecureString)).Password
try {
  if ((docker inspect -f '{{.State.Running}}' savia-store-tienda1) -ne 'true') { throw 'container savia-store-tienda1 is not running' }
  docker exec savia-store-tienda1 mkdir -p /var/opt/mssql/backup | Out-Null
  $sql = "BACKUP DATABASE SAVIA_TIENDA1 TO DISK=N'/var/opt/mssql/backup/$name' WITH COPY_ONLY, CHECKSUM, INIT; RESTORE VERIFYONLY FROM DISK=N'/var/opt/mssql/backup/$name' WITH CHECKSUM;"
  $r = docker exec -e SQLCMDPASSWORD=$sa savia-store-tienda1 /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -b -Q $sql 2>&1
  if ($LASTEXITCODE -ne 0) { throw "backup failed: $($r -join ' ')" }
  if (-not ($r -match 'is valid')) { throw "verify did not report a valid backup: $($r -join ' ')" }
  docker cp "savia-store-tienda1:/var/opt/mssql/backup/$name" (Join-Path $out $name) | Out-Null
  docker exec savia-store-tienda1 rm -f "/var/opt/mssql/backup/$name" | Out-Null
  $size = (Get-Item (Join-Path $out $name)).Length
  Get-ChildItem $out -Filter 'SAVIA_TIENDA1-*.bak' | Where-Object LastWriteTime -lt (Get-Date).AddDays(-14) | Remove-Item
  Write-Log "OK $name $size bytes, verified"
} catch { Write-Log "FAILED $($_.Exception.Message)"; exit 1 } finally { Remove-Variable sa -ErrorAction SilentlyContinue }

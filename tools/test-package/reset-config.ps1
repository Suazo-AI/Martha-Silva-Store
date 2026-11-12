Remove-Item (Join-Path $PSScriptRoot '.local\config.json') -ErrorAction SilentlyContinue
Write-Host 'Configuracion borrada. La proxima vez se vuelve a preguntar.'

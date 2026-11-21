@echo off
REM Starts the SAVIA cash register on this computer.
REM Reads the station configuration prepared by prepare-station.ps1. No secret is stored in this
REM file: the certificate password is read at run time from the protected station folder.
setlocal
set "STATION=%ProgramData%\Savia\station"
if not exist "%STATION%\station.json" (
  echo Station not prepared. Run: powershell -ExecutionPolicy Bypass -File prepare-station.ps1
  pause
  exit /b 1
)
for /f "usebackq delims=" %%p in ("%ProgramData%\Savia\station-tls\password.txt") do set "Kestrel__Certificates__Default__Password=%%p"
set "Kestrel__Certificates__Default__Path=%ProgramData%\Savia\station-tls\station.pfx"
set "ASPNETCORE_ENVIRONMENT=Development"
set "InternalSavia__Enabled=true"
set "ASPNETCORE_URLS=https://localhost:5001"
for /f "usebackq delims=" %%c in ("%STATION%\connection.txt") do set "ConnectionStrings__InternalSavia=%%c"
for /f "usebackq delims=" %%i in ("%STATION%\internal-cash.txt") do set "InternalSavia__Cash__Currency=%%i"
for /f "usebackq delims=" %%e in ("%STATION%\internal-cash-exponent.txt") do set "InternalSavia__Cash__Exponent=%%e"
title SAVIA cash register
"%~dp0..\..\backend\src\Martha.Store.Api\bin\Debug\net10.0\Martha.Store.Api.exe"
pause

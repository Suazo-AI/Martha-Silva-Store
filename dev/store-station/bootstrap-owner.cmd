@echo off
REM Creates the first Owner of this station in an interactive private console.
REM The operator types the values; no credential is read from or written to a file.
REM The console refuses redirected input, output or error, so it must run in this window.
setlocal
set "STATION=%ProgramData%\Savia\station"
if not exist "%STATION%\connection.txt" (
  echo Station not prepared. Run: powershell -ExecutionPolicy Bypass -File prepare-station.ps1
  pause
  exit /b 1
)
for /f "usebackq delims=" %%c in ("%STATION%\connection.txt") do set "ConnectionStrings__InternalSavia=%%c"
set "ASPNETCORE_ENVIRONMENT=Development"
set "InternalSavia__Enabled=true"
title SAVIA initial owner - private console
"%~dp0..\..\backend\src\Martha.Store.Api\bin\Debug\net10.0\Martha.Store.Api.exe" --internal-bootstrap-owner
echo.
echo Exit code: %ERRORLEVEL%
pause

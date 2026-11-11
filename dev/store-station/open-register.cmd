@echo off
REM Opens the cash register in its own window (no browser bars, no address bar).
REM The certificate is trusted by this machine, so the register opens without a warning.
start "" "msedge.exe" --app="https://localhost:5001/internal/" --window-size=1280,900

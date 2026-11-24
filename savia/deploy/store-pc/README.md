# Store PC (TIENDA1)

This PC runs the first store, TIENDA1, since 2026-11-24.
The scripts here are copies of the ones in `C:\Users\Jason\SaviaStore`, the folder they run from.
That folder also holds `ids.json` (node, branch, location and register ids; no secrets) and three DPAPI files.
A DPAPI file opens only for the Windows user who wrote it, on this PC.

| File | What it does |
| --- | --- |
| `start-store.ps1` | Starts the store host on `http://127.0.0.1:5080`; it syncs with the Azure hub every 60 s. Logs: `C:\Users\Jason\SaviaStore\logs`. |
| `store-migrator.ps1` | Runs the migrator on the store database `SAVIA_TIENDA1` as `sa`. Use it for store upgrades (RUNBOOK section 5) and store-side provisioning. |
| `run-job.ps1` | Runs one migrator mode on an Azure database as the `caj-savia-migrate` job; prints the execution, its log and the count of secret lines in the workspace. |
| `backup-store.ps1` | Full copy-only backup of `SAVIA_TIENDA1` with `CHECKSUM`, then `RESTORE VERIFYONLY`; writes `C:\Users\Jason\SaviaStore\backups\SAVIA_TIENDA1-<utc>.bak`, keeps 14 days, logs to `logs\backup.txt`. |

Scheduled tasks (Windows Task Scheduler, user Jason, `powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ...`):
- `SAVIA Tienda - arranque`: runs `start-store.ps1` at sign-in. It starts Docker Desktop if needed and waits up to 5 minutes for the engine.
- `SAVIA Tienda - respaldo`: runs `backup-store.ps1` every day at 22:30.

Parts:
- Database: container `savia-store-tienda1`, SQL Server 2022 Express (16.0.4305.5), volume `savia-store-tienda1-data`, port `127.0.0.1:14350`, restart `unless-stopped`.
- Host: `Savia.Api.dll` built from a clean `git archive` of the release named in `current-release.txt`.
- Host database user: `savia_store_app`, role `savia_api_host` only.

After a reboot the host starts when Jason signs in to Windows, not before. A store that must run without a sign-in needs a separate Windows account and a boot trigger.
Backups stay on this PC's disk. A copy off this PC is not set up.
Evidence: [STORE-PC-20261124](../../../docs/production-20261122/STORE-PC-20261124.md).

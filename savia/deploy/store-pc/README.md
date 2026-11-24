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

Parts:
- Database: container `savia-store-tienda1`, SQL Server 2022 Express (16.0.4305.5), volume `savia-store-tienda1-data`, port `127.0.0.1:14350`, restart `unless-stopped`.
- Host: `Savia.Api.dll` built from a clean `git archive` of the release named in `current-release.txt`.
- Host database user: `savia_store_app`, role `savia_api_host` only.

After a reboot: start Docker Desktop, then run `start-store.ps1`. Nothing starts the host by itself yet.
Evidence: [STORE-PC-20261124](../../../docs/production-20261122/STORE-PC-20261124.md).

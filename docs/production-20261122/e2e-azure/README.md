# Full order on the deployed hub (point 5)

Date: 2026-11-24 (UTC). Jason approved points 1-5 on 2026-11-24; this is point 5.
Result: a buyer's order went from the storefront in a real browser to the hub on Azure, then to the store, and was paid and fulfilled.

## Setup

The production hub `ca-savia-api` and its database `savia` were not used for writes.
The run used a temporary copy of both, deleted afterwards:

- Database `savia-e2e`: `az sql db copy` of `savia` (Basic).
- App `ca-savia-e2e`: the same image (`savia-api:1b1e0016`), identity, environment and SQL server as the hub.
  Differences: `Database=savia-e2e`, origin `http://127.0.0.1:8787`, and `Savia__Public__BotCheck=disabled` (no Turnstile key exists yet).
- Hub provisioning: the production job `caj-savia-migrate` on `savia-e2e`, with each password and the node secret passed as a temporary job secret.
- Store: a local store host (`Kind=Branch`) on this PC with its own database, syncing with `ca-savia-e2e` over HTTPS.
- Storefront: `prepare.py --config <scratch copy>` with `apiBase` set to the copy and `rosa-empolvado-pedreria-S` mapped to `DZ-0002`, served by `wrangler dev` on 127.0.0.1:8787. `site.config.json` is unchanged.

Tool: [e2e_azure.py](../../../savia/tools/rehearsal/e2e_azure.py) (`prepare`, `run`, `report`, `down`).
Transcript: [run-20261124.md](run-20261124.md).

## Results

| Step | Result |
| --- | --- |
| 1 | Hub (via the job): branch, owner, manager, cashier, store node. Each job log names `savia-e2e`; temporary secret removed; 0 secret lines in the log workspace |
| 5 | Store host starts; first sync round with the Azure copy |
| 6 | Owner signs in on the hub (`mustChangePassword` false), imports 3 products, sets DZ-0002 to C$550 |
| 7 | Products and the new price arrive on the store |
| 8 | Store receives 5 units of each (cashier scans, manager approves and posts) |
| 9 | Counter sale of DZ-0001 |
| 10 | Store consigns 2 units of DZ-0002; the hub public catalog shows `available: 2` |
| 11 | Order sent twice with one Idempotency-Key: 201 then 200, one order id, available 2 → 1 |
| 12 | Owner records the transfer (paid) and fulfils (fulfilled); the buyer's status page says fulfilled |
| 13 | Store DZ-0002 onHand 3; hub web available 1 |
| Browser | Product page shows size S "Última unidad" and M, L "Agotada" from the hub; bag, contact, delivery, "Pago manual"; order `WF9BC0DF3` shows "Reservado, pago pendiente", C$550 + C$500 delivery = C$1,050 ([screenshot](browser-order-page.png)); hub available 1 → 0 |

## Defect found and fixed during the run

`run-job.ps1` wrote the job override with `Set-Content -Encoding utf8`.
Under Windows PowerShell 5.1 that adds a byte-order mark, and the job then ignored the whole override.
Six executions ran the job's default template instead: a plain migrate on production `savia`, "applied now: nothing new".
No data changed, and no provisioning ran anywhere. The copy's first `prepare` was wrongly recorded as DONE; that entry was removed from the transcript.
Fixes:
- The override is written without a byte-order mark.
- The script exits 1 when the job log does not name the requested database.
- `az` warnings no longer abort the script before its cleanup, and the temporary secret is created inside the `try` whose `finally` removes it.
- `e2e_azure.py` calls `pwsh`, and `prepare --resume` replays a stopped prepare with the same ids (every provisioning step is a no-op for the same ids).
A temporary job secret left by the first failure was removed by hand; the job's secret list was read back empty.

## Cleanup (read back)

`ca-savia-e2e` and `savia-e2e` deleted; `az containerapp list` shows only `ca-savia-api`; databases are `savia`, `master`, `savia-premig-1b1e001-1`.
The job's secret list is empty. The local store database and its login were dropped. The production hub answers `/health/ready` 200.

## Limits

- The bot check was disabled on the copy. A real Turnstile pass is still not tested (W3).
- The store ran on this PC as a test host, not on the store PC's installed TIENDA1.
- The browser order was left reserved and unpaid; it was deleted with the copy. Payment and fulfilment were exercised on the scripted order only.
- The quantity menu in the bag offers 1-10 when the hub has 1; the hub would refuse with `out_of_stock`. Not changed here.
- Hub SQL balances were not read directly; the hub database is reachable only by the job.

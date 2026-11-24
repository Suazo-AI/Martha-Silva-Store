# Four-node sync rehearsal

One command starts a hub and three stores as real API processes, lets them sell and sync over real HTTP, and checks every database against a manifest written before the run.

```bash
python tools/rehearsal.py run all            # every scenario; exit 0 only if every verdict is PASS or XFAIL
python tools/rehearsal.py run replay         # one scenario
python tools/rehearsal.py selftest           # a missing expected sale must fail the run
python tools/rehearsal.py down               # remove the container and its volume
```

Run it from `savia/`.
Build the API and the migrator first (outputs are gitignored):

```bash
dotnet build src/Savia.Api/Savia.Api.csproj -c Release -o .out/rehearsal/api
dotnet build deploy/migrator/Savia.Migrator.csproj -c Release -o .out/rehearsal/migrator
```

Needs: Docker, Python 3.11+, the .NET 10 SDK (`SAVIA_DOTNET` overrides the path), free ports 14341, 5310-5313 and 5321-5323.

## Topology

| Node | Process | Database | URL |
|---|---|---|---|
| hub | `Savia.Api` `Kind=Cloud` | `SAVIA_SIM_R_hub` | `http://127.0.0.1:5310` |
| a, b, c | `Savia.Api` `Kind=Branch`, hosted `SyncWorker` every 5 s | `SAVIA_SIM_R_a/b/c` | `http://127.0.0.1:5311-5313` |
| proxy a, b, c | Python fault proxy between each store's worker and the hub | none | `http://127.0.0.1:5321-5323` |

- SQL runs in its own container `savia-sqlserver-rehearsal` on `127.0.0.1:14341`, from the image digest pinned in `infra/docker-compose.dev.yml`, Developer edition.
- The databases are cloned from the migrated template (`tools/db/saviadb.py`, `SAVIA_SQL_CONTAINER=savia-sqlserver-rehearsal`).
- Each store authenticates to the hub with a real node secret, provisioned by `Savia.Migrator --provision-node` ([PROVISIONING.md](PROVISIONING.md)); the hub keeps its SHA-256.
- Staff sign in over HTTP with passwords set by `Savia.Api provision-passwords`.
- Every password and secret is generated at run time; evidence is scrubbed before it is written.
- The driver uses the public HTTP API for tills, sales, returns and sign-in.
- Credit transfers run as the SQL procedures the product exposes, because no HTTP route exists for them yet (`sql:no-http-route` in the evidence).

## Identity

`--identity auto` (default) first starts the four hosts as a SQL login that is only in `savia_api_host` (granted by the migrator with `--grant-app-user`).
If they converge, every scenario runs with that login; otherwise the scenarios run as `sa` and `identity_probe.json` records the exact failure.
`--identity sa` or `--identity restricted` forces one.

## Manifests and checks

Each scenario has `tools/rehearsal/expected/<scenario>.json`, fixed before the run: every sale, till, return and transfer id, amount and expected effect.
Its SHA-256 is recorded in the evidence.
The checks iterate over the manifest, so an expected operation that never happened is reported as missing.

On every node (hub, a, b, c):

- each expected sale exists exactly once, at its store, with its total, line, quantity, tenders, stock movement and cash entry;
- sales marked `absent` do not exist; a `group` has exactly one sale present (the concurrent-spend race);
- no sale outside the manifest; per-store count and total; stock on hand;
- returns produce their credit; credit allocations; transfer status and override flag.

Across nodes:

- R1: every synced table hashes the same on all four databases;
- CONS: `audit.usp_CheckConservation` returns 0 rows on all four, except rows pinned in `conservation_allow` with a reason (a pinned row that disappears also fails, so pins cannot rot);
- the controls listed below.

`tests/test_rehearsal.py` unit-tests the manifest rules, the oracles and the fault proxy without SQL.

## Scenarios

| Scenario | What happens | Proves |
|---|---|---|
| `offline_sales` | Hub stopped; all three stores sell; hub restarted. | Store-and-forward: every offline sale reaches every node once. |
| `replay` | The proxy lets the hub commit A's push, then kills A before it hears the answer. Then B is killed after the hub answered a pull, before B applies it. | Lost answers are replayed without duplicates. |
| `hub_restart` | Hub killed after committing a push, before answering; stores keep selling; hub restarted. | Hub crash recovery. |
| `credit_transfer` | Return to store credit over HTTP; transfer A→B approved, dispatched, received and spent; two concurrent spends of the same remainder at A; hub cancels while a cut-off A dispatches. | Credit is conserved; exactly one concurrent spend wins; the offline dispatch wins with the override flag. |
| `restore_sale_before_rebuild` | A is restored from a backup taken before its till opened, opens a new till and sells while cut off, then the link returns. | The recovery lock (D-036): the restored store refuses the sale until its rebuild. PASS since V036. |
| `controls` | Negative controls. | See below. |
| `reference_data` | Cut-off A registers a customer and sells to it; the hub owner changes the item price; the link returns. | D-039: the customer and its sale reach every node with no Msg 547; the hub price reaches every store. |
| `schema_skew` | C's newest ledger row is removed (one migration behind); C sells; C runs `Savia.Migrator`. | D-041: the hub refuses C with `sync.schema_mismatch` (51856), C's `GET /api/v1/sync/status` names it, and C syncs after it migrates. |
| `hub_catalog` | The hub owner previews and imports 3 items over HTTP; A receives 5 units of one by scanning and sells 1; B tries to change that item's price. | D-039 (S9): the 3 items and barcodes reach every node with no stock; stock enters only at A by receiving (4 on hand on every node); B gets `409 catalog.managed_by_hub` and its `/me` says `catalogManagedByHub`. |

Negative controls (must fail as designed):

| Control | Expected |
|---|---|
| wrong node secret, another store's secret, no header | `401 sync.unauthorized` (a real secret returns 200) |
| B's credential revoked, then rotated with `--provision-node` | revoked `401`; rotated secret `200`; the secret before rotation `401` |
| A's push rewritten so a sale names store B | `403 sync.foreign_row` (SQL 51851) |
| A restored; the proxy hides `recover` from the push plan so A pushes without a rebuild token | `409 sync.rebuild_required` (SQL 51854), then A rebuilds by itself |
| `selftest`: an expected sale the driver never makes | the run is `FAIL`, and only for that sale and its store totals |

Verdicts: `PASS`; `FAIL`; `ERROR` (the driver crashed); `XFAIL` (the known red reproduced with its exact SQL error); `XPASS` (the red test passed: remove the marker).

## Evidence

Latest run, 2026-11-22: all nine scenarios PASS with `--identity restricted`, evidence in [paging-catalog-20261122/rehearsal](../evidence/paging-catalog-20261122/rehearsal/).
`schema_skew` re-applies the newest migration on a store, so the newest migration must run twice without error.
Each run writes `<scenario>.json` to `docs/evidence/rehearsal-20261121/` (override with `--evidence DIR`, skip with `--no-evidence`): phases with timings, events, every check, controls, sync rounds counted from the host logs, and the exchanges each proxy saw.
Host logs stay in `.out/rehearsal/runs/` (gitignored).
The baseline is in [rehearsal-20261121/README.md](../evidence/rehearsal-20261121/README.md).

## What it cannot prove

- Real store networks: latency, packet loss, NAT, captive portals, TLS termination and proxies. The link here is localhost through a Python proxy that is either up or cut.
- Real devices: tills, printers, scanners, Windows store PCs, power loss, disk-full, clock skew.
- Azure SQL Basic capacity: everything runs on SQL Server Developer in Docker, with no DTU limit and no Azure failover.
- Long runs and load: each scenario is minutes long with a handful of sales.
- Concurrency across stores for one credit: allocations are per store, so the concurrent spend is two sales at the same store.
- HTTP for credit transfers: they run through the SQL procedures.
- The restricted SQL identity unless `identity_probe.json` says it converged.

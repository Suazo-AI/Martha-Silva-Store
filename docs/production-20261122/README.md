# Production readiness program

Started: 2026-11-22. Owner: primary agent. Mode: OPERATE.
Mandate (Jason, 2026-11-22): take the engineering decisions, deploy, and deliver a production-ready store.
Revenue link: Martha can sell online and in three stores on one system.
Source at start: `Tony@37b6c06e`, CI 4 of 4 success (run 44991665004).

## What "production ready" means

Each row is a check that can fail. A row is `verified` only with evidence on the delivered artifact.
States: `verified`, `running`, `pending`, `blocked (input)`.

| ID | Check | Pass condition | State |
| --- | --- | --- | --- |
| H1 | Hub runs Tony HEAD on Azure | `/health/ready` 200; image tag equals the commit; ledger holds V001-V035; rollback revision named | verified 2026-11-22: revision `ca-savia-api--g6a962d5-1` at 100%, image `savia-api:6a962d55`, job `caj-savia-migrate-s39zgnj` applied V060-V061 (ledger through V061), rollback `ca-savia-api--g11ef361-1`, copy `savia-premig-6a962d55-1` |
| H2 | Restricted API identity runs sync on Azure SQL | a sync round as the managed identity returns 200 | pending: needs the stores and one node credential in the hub database. Evidence so far: `sync.CurrentFork` was created on Azure SQL by V036 (no value read back; `sync.LocalNode` may be empty there); the rehearsal runs all 9 scenarios as a login that is only in `savia_api_host` |
| H3 | Telemetry reaches Application Insights | one request visible in the workspace | verified 2026-11-22: 18 `AppRequests` and 9 `AppDependencies` in `log-savia-bukmlt` within 30 minutes of the deploy |
| S1 | Recovery lock (G6) | rehearsal `restore_sale_before_rebuild` PASS, not XFAIL | verified 2026-11-22 (V036, V052, V060): every write that moves stock or money is refused while recovering; the till shows tables done of total; rehearsal 9 of 9 PASS |
| S2 | Recovered-sale outbox (G7) | simulator `restore` PASS | verified 2026-11-22 (V036): simulator `restore` PASS; [evidence](../../savia/docs/evidence/sync-correctness-20261122/README.md) |
| S3 | Credit status has one writer (G8) | simulator and T-SQL test for the two-writer case PASS | verified 2026-11-22 (V037, V052): issuer procedures block and expire a credit; simulator `credit_status` PASS |
| S4 | Reference tables sync (G1) | a sale to a customer created offline reaches the hub without Msg 547 | verified locally 2026-11-22 (V053, 39 synced tables): rehearsal `reference_data` PASS over HTTP; [evidence](../../savia/docs/evidence/sync-completion-20261122/README.md) |
| S5 | Sync paging (G13) | rebuild of a 250,000-variant store completes; no response above 20 MB | verified locally 2026-11-22 (V060): on 250,000 variants a rebuild killed after 3 pages resumed and finished (313 pages, 1.58 M rows, 344 s), oracle clean on 4 nodes, largest response 6.75 MB; [evidence](../../savia/docs/evidence/paging-catalog-20261122/README.md). Open: empty round measured 397 and 597 ms on a busy host (target 500 ms); not run on Azure SQL Basic |
| S6 | Schema skew rule (G14) | a node with another ledger is refused with a named code | verified locally 2026-11-22: rehearsal `schema_skew` PASS (refused with 51856, syncs after it migrates) |
| S7 | Node provisioning command (G3) | one command creates a store credential; the secret prints once | verified locally 2026-11-22 (V054): the rehearsal provisions its stores with `migrator --provision-node`; revoke and rotate PASS; [guide](../../savia/docs/sync/PROVISIONING.md) |
| S8 | `sales.CashClosures` syncs | oracle shows 0 `cash.till_status_vs_closure` on replicated tills | verified 2026-11-22 (V038): rehearsal and simulator show 0 `cash.till_status_vs_closure` |
| P1 | Catalog import is fast | 1,000 rows under 3 s on the A-10 data set | verified locally 2026-11-22 (V059, V061): 1,000 rows over HTTP in 2.5, 1.4 and 1.4 s on a quiet machine; the preview refuses duplicate size and color |
| P2 | KPI business report | p95 under 1 s on the A-10 data set | verified 2026-11-22 (V058): p95 0.5-0.7 s on 250,000 variants, results equal to V040; [evidence](../../savia/docs/evidence/money-and-speed-20261122/README.md) |
| P3 | Search | p95 under 300 ms on the A-10 data set | verified 2026-11-22 (V041): p95 158 ms |
| P4 | Catalog and stock lists are paged | no screen response above 1 MB | verified 2026-11-22 (V042): largest page 162 KB |
| W1 | Public catalog comes from the hub | storefront reads products, prices and stock through a public read API | verified locally 2026-11-22 on the final tree (V063): day-zero run 2, one hub and one store from empty databases; the storefront order ran in a real browser against the hub public catalog; [DAY-ZERO](DAY-ZERO.md), [run 2](day-zero-evidence/run2.md). The deployed storefront is in demo mode |
| W2 | A real order is stored | browser to API to SQL: order row, stock reservation, idempotent retry | verified locally 2026-11-22 (V063): day-zero run 2, one Idempotency-Key sent twice gives 201 then 200 with one order code and one reservation; earlier: double click and last-unit race on `c4ca690f`. Not run on the deployed pair |
| W3 | Public API is safe | rate limit, input validation, CORS allow-list, no staff route reachable without sign-in | verified locally 2026-11-22 (.NET tests for 429, 413, 400, 403, CORS, 404 on a branch); not yet on Azure; real Turnstile not run |
| W4 | Payment | card payment through a provider, with a verified webhook | blocked (input): merchant account. The seam is built: provider interface, and a review path for a card capture the order cannot take (V057) |
| W5 | Order notification | the store team sees a new order in SAVIA | verified locally 2026-11-22 (V063): the hub screen "Pedidos web" in a real browser registered a payment and marked the order shipped. The store gets no notice of its own (D-044: the consigning store manager works the order on the hub) |
| W6 | Storefront deployed | Cloudflare deploy from a clean commit; version id, SHA and rollback recorded | verified 2026-11-22, demo mode: `https://martha-silva-preview.jason-suazof.workers.dev` (account `66ee81b7`, D-030) from a clean worktree at `7f54e216`; version `e6934b14-3fee-4963-9a84-b5511b27f302`; `/`, `/catalogo`, `/checkout`, `/pedido` 200, unknown path 404; CSP, COOP, nosniff, noindex and `Strict-Transport-Security: max-age=31536000; includeSubDomains` present; `ci.yml` run 45084868090 green. Rollback: `npx wrangler rollback de32eca6-aa7e-4e06-97da-acfd87d55b85 --name martha-silva-preview`. Open: live mode is not deployed |
| W7 | Storefront quality | Lighthouse performance, accessibility, best practices and SEO at 90 or more on mobile; security headers present | partial: accessibility 100, best practices 100; performance home 91, catalog 91-94, product 85, checkout 86-90; SEO stays low while `indexable` is false; [numbers](storefront-evidence/PERFORMANCE.md) |
| W8 | Real catalog | real products, prices, photos and stock | blocked (input): the store's data |
| W9 | Legal and contact | business name, phone, address, terms, privacy, returns | blocked (input): business details |
| W10 | Domain | custom domain with TLS | blocked (input): domain |
| D0 | Day-zero path with shipped tools only | from empty migrated databases: first hub owner, branches, staff, node credential, hub import, store sync, receiving, consign to web, browser order, manual payment, fulfil; no direct SQL | verified locally 2026-11-22 (V062-V063): two empty databases to a paid and fulfilled web order with migrator commands, routes and screens only; [DAY-ZERO](DAY-ZERO.md), [run 2](day-zero-evidence/run2.md). Browser legs (storefront order, hub "Pedidos web", store "Clientes") ran in the worker run; the primary reran steps 0-14 over HTTP ([run 3](day-zero-evidence/run3.md)). Not run on Azure or on a store host |
| D1 | Routes for steps the rehearsal does by SQL | customer creation and credit transfer dispatch and receipt have an API route and a screen | verified locally 2026-11-22 (V062-V063): `POST /customers` (store), credit transfer routes (request, dispatch, receive on a store; approve, cancel on the hub) and screens "Clientes" and "Traslados"; the rehearsal uses HTTP for them; no `sql:no-http-route` step remains |
| D2 | One installed, provisioned store | a store host runs outside the rehearsal, syncs with the Azure hub and consigns web stock | pending: no store host runs in production; the first online sale needs one |
| D3 | Store upgrade step | a written and tested step to update a store; the hub refuses a store on another schema version, so every hub migration stops that store's sync until it upgrades | verified locally 2026-11-22: day-zero run 2 steps 14.1-14.2: a hub-only migration makes the store refuse with `sync.schema_mismatch`; stop the store host, run the migrator on the store, start it, sync resumes. Steps in [DAY-ZERO](DAY-ZERO.md) and the runbook |
| D4 | Speed on the real tier | the A-10 measurements repeated on Azure SQL Basic (5 DTU, 2 GB) | pending: every speed number is from local Docker; a tier change is a cost decision |
| D5 | `main` holds the production code | Tony merged to main after review | pending: production runs images built from Tony |
| D6 | Storefront full check on Linux | workflow `ci.yml` green on the deployed commit | verified 2026-11-22: `ci.yml` run 45070405272 on Tony, Linux and Windows both success |
| O1 | Backup and restore drill | a point-in-time restore of the hub reads back; a store restore passes the rehearsal | pending |
| S9 | Catalog authoring on the hub (D-039) | import and item registration run on the hub without stock; a store cannot change catalog rows; stock enters by receiving | verified locally 2026-11-22 (V061): rehearsal `hub_catalog` PASS: the hub imports items with no stock, stores receive them, a store receives stock and sells, a store catalog write is refused with `catalog.managed_by_hub` |
| O2 | Runbook | deploy, rollback, node provisioning, restore and incident steps in one document | written 2026-11-22: [RUNBOOK](../../savia/docs/deploy/RUNBOOK.md); deploy and rollback steps ran 7 times; provisioning, opening web orders and the restore drill have not run on Azure |

## Inputs only Jason or Martha can give

These do not stop the engineering. Each one blocks only its row.

1. Card merchant account (W4). D-008 requires cards for production.
2. Real catalog: products, prices, photos, stock (W8). The 40 sample products and AI images are not inventory.
3. Business details for the footer, legal pages and structured data (W9).
4. Domain name (W10).
5. Azure trial upgrade before about 2026-12-12. Without it the hub stops.

## Order of work

1. Deploy `Tony@37b6c06e` to the hub (H1-H3). It applies V031-V035 on Azure SQL Basic for the first time.
2. Sync correctness: S1-S8. No real store connects to the hub before these pass.
3. Performance: P1-P4.
4. Public order path: W1-W3, W5, then W6-W7. Payment sits behind a provider interface (W4).
5. Operations: O1-O2.

Decisions taken for this program: [DECISIONS D-035 to D-041](../DECISIONS.md).
Progress is recorded in this table, in the area documents, and in the commit log.

Order path research and build plan (2026-11-22): [ORDER-PATH-SPEC](ORDER-PATH-SPEC.md).
Accepted by the primary: hub-owned web stock locations filled by consignment, guest checkout, hosted-page card payment behind `IPaymentProvider`, `manual` provider labelled as not card.
Provider recommendation: BAC E-Commerce gateway first, Pagadito as fallback; neither is contracted.

Integration 2026-11-22: order path `11f7fb3c`, performance `c4ca690f`, sync correctness (V036-V038) merged on top. Merged tree in a clean worktree: T-SQL 168, .NET 227 of 227, API host login 27 of 27, web 165 of 165, container proof PASS, rehearsal 6 of 6, simulator basic, replay, restore, credit_status and cancel_vs_dispatch PASS.
V038 sync order numbers moved to 21-23 because V048 holds 19-20. Azure still runs `37b6c06e` (V035).

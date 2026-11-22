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
| H1 | Hub runs Tony HEAD on Azure | `/health/ready` 200; image tag equals the commit; ledger holds V001-V035; rollback revision named | verified 2026-11-22: revision `ca-savia-api--g11ef361-1` at 100%, image `savia-api:11ef3616`, job `caj-savia-migrate-9ob7dpw` applied V052-V059 (ledger through V059), rollback `ca-savia-api--g996465b-1`, copy `savia-premig-11ef3616-1` |
| H2 | Restricted API identity runs sync on Azure SQL | a sync round as the managed identity returns 200 | pending: the migrator logged `API host permissions ensured for user id-savia-api-bukmlt`; a real round needs a node credential (S7). Without one, `POST /sync/v1/push` returns 401 |
| H3 | Telemetry reaches Application Insights | one request visible in the workspace | verified 2026-11-22: 18 `AppRequests` and 9 `AppDependencies` in `log-savia-bukmlt` within 30 minutes of the deploy |
| S1 | Recovery lock (G6) | rehearsal `restore_sale_before_rebuild` PASS, not XFAIL | verified 2026-11-22 (V036, V052): sale, till, receiving, returns, credit transfers and web consignment are refused while recovering; rehearsal 8 of 8 PASS. Open: rebuild progress display |
| S2 | Recovered-sale outbox (G7) | simulator `restore` PASS | verified 2026-11-22 (V036): simulator `restore` PASS; [evidence](../../savia/docs/evidence/sync-correctness-20261122/README.md) |
| S3 | Credit status has one writer (G8) | simulator and T-SQL test for the two-writer case PASS | verified 2026-11-22 (V037, V052): issuer procedures block and expire a credit; simulator `credit_status` PASS |
| S4 | Reference tables sync (G1) | a sale to a customer created offline reaches the hub without Msg 547 | verified locally 2026-11-22 (V053, 39 synced tables): rehearsal `reference_data` PASS over HTTP; [evidence](../../savia/docs/evidence/sync-completion-20261122/README.md) |
| S5 | Sync paging (G13) | rebuild of a 250,000-variant store completes; no response above 20 MB | pending: not built. The rebuild progress display waits for it |
| S6 | Schema skew rule (G14) | a node with another ledger is refused with a named code | verified locally 2026-11-22: rehearsal `schema_skew` PASS (refused with 51856, syncs after it migrates) |
| S7 | Node provisioning command (G3) | one command creates a store credential; the secret prints once | verified locally 2026-11-22 (V054): the rehearsal provisions its stores with `migrator --provision-node`; revoke and rotate PASS; [guide](../../savia/docs/sync/PROVISIONING.md) |
| S8 | `sales.CashClosures` syncs | oracle shows 0 `cash.till_status_vs_closure` on replicated tills | verified 2026-11-22 (V038): rehearsal and simulator show 0 `cash.till_status_vs_closure` |
| P1 | Catalog import is fast | 1,000 rows under 3 s on the A-10 data set | partial (V039, V059): no 503; set-based commit with equal results; 1,000 rows 2.1-7.0 s on a loaded machine. Open: set-based enqueue and a quiet measurement |
| P2 | KPI business report | p95 under 1 s on the A-10 data set | verified 2026-11-22 (V058): p95 0.5-0.7 s on 250,000 variants, results equal to V040; [evidence](../../savia/docs/evidence/money-and-speed-20261122/README.md) |
| P3 | Search | p95 under 300 ms on the A-10 data set | verified 2026-11-22 (V041): p95 158 ms |
| P4 | Catalog and stock lists are paged | no screen response above 1 MB | verified 2026-11-22 (V042): largest page 162 KB |
| W1 | Public catalog comes from the hub | storefront reads products, prices and stock through a public read API | built and proven locally in a real browser (`72e60da3`, [transcript](storefront-evidence/TRANSCRIPT.md)); the hub route answers on Azure; the deployed storefront is still in demo mode |
| W2 | A real order is stored | browser to API to SQL: order row, stock reservation, idempotent retry | verified locally 2026-11-22: real browser to local hub to SQL, double click gives one order, last-unit race gives one order; not yet on the deployed pair |
| W3 | Public API is safe | rate limit, input validation, CORS allow-list, no staff route reachable without sign-in | verified locally 2026-11-22 (.NET tests for 429, 413, 400, 403, CORS, 404 on a branch); not yet on Azure; real Turnstile not run |
| W4 | Payment | card payment through a provider, with a verified webhook | blocked (input): merchant account. The seam is built: provider interface, and a review path for a card capture the order cannot take (V057) |
| W5 | Order notification | the store team sees a new order in SAVIA | built (hub staff screen, web tests); not yet seen in a real browser |
| W6 | Storefront deployed | Cloudflare deploy from a clean commit; version id, SHA and rollback recorded | pending |
| W7 | Storefront quality | Lighthouse performance, accessibility, best practices and SEO at 90 or more on mobile; security headers present | partial: accessibility 100, best practices 100; performance home 91, catalog 91-94, product 85, checkout 86-90; SEO stays low while `indexable` is false; [numbers](storefront-evidence/PERFORMANCE.md) |
| W8 | Real catalog | real products, prices, photos and stock | blocked (input): the store's data |
| W9 | Legal and contact | business name, phone, address, terms, privacy, returns | blocked (input): business details |
| W10 | Domain | custom domain with TLS | blocked (input): domain |
| O1 | Backup and restore drill | a point-in-time restore of the hub reads back; a store restore passes the rehearsal | pending |
| S9 | Catalog authoring on the hub (D-039) | import and item registration run on the hub without stock; a store cannot change catalog rows; stock enters by receiving | pending: found 2026-11-22; only price changes work on the hub today |
| O2 | Runbook | deploy, rollback, node provisioning, restore and incident steps in one document | pending |

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

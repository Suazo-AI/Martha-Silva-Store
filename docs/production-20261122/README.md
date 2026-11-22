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
| H1 | Hub runs Tony HEAD on Azure | `/health/ready` 200; image tag equals the commit; ledger holds V001-V035; rollback revision named | pending |
| H2 | Restricted API identity runs sync on Azure SQL | a sync round as the managed identity returns 200 | pending |
| H3 | Telemetry reaches Application Insights | one request visible in the workspace | pending |
| S1 | Recovery lock (G6) | rehearsal `restore_sale_before_rebuild` PASS, not XFAIL | pending |
| S2 | Recovered-sale outbox (G7) | simulator `restore` PASS | pending |
| S3 | Credit status has one writer (G8) | simulator and T-SQL test for the two-writer case PASS | pending |
| S4 | Reference tables sync (G1) | a sale to a customer created offline reaches the hub without Msg 547 | pending |
| S5 | Sync paging (G13) | rebuild of a 250,000-variant store completes; no response above 20 MB | pending |
| S6 | Schema skew rule (G14) | a node with another ledger is refused with a named code | pending |
| S7 | Node provisioning command (G3) | one command creates a store credential; the secret prints once | pending |
| S8 | `sales.CashClosures` syncs | oracle shows 0 `cash.till_status_vs_closure` on replicated tills | pending |
| P1 | Catalog import is fast | 1,000 rows under 3 s on the A-10 data set | pending |
| P2 | KPI business report | p95 under 1 s on the A-10 data set | pending |
| P3 | Search | p95 under 300 ms on the A-10 data set | pending |
| P4 | Catalog and stock lists are paged | no screen response above 1 MB | pending |
| W1 | Public catalog comes from the hub | storefront reads products, prices and stock through a public read API | pending |
| W2 | A real order is stored | browser to API to SQL: order row, stock reservation, idempotent retry | pending |
| W3 | Public API is safe | rate limit, input validation, CORS allow-list, no staff route reachable without sign-in | pending |
| W4 | Payment | card payment through a provider, with a verified webhook | blocked (input): merchant account |
| W5 | Order notification | the store team sees a new order in SAVIA | pending |
| W6 | Storefront deployed | Cloudflare deploy from a clean commit; version id, SHA and rollback recorded | pending |
| W7 | Storefront quality | Lighthouse performance, accessibility, best practices and SEO at 90 or more on mobile; security headers present | pending |
| W8 | Real catalog | real products, prices, photos and stock | blocked (input): the store's data |
| W9 | Legal and contact | business name, phone, address, terms, privacy, returns | blocked (input): business details |
| W10 | Domain | custom domain with TLS | blocked (input): domain |
| O1 | Backup and restore drill | a point-in-time restore of the hub reads back; a store restore passes the rehearsal | pending |
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

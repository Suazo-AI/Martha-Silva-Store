# Threat map: Martha Silva web store

Version: 0.1
Date: 2026-11-27
Status: approved
Approval: Jason approved version 0.1 on 2026-11-27, including the LOGIN-07 and LOGIN-08 update of commit `c7e30bc4`.
Scope: every entry point of the storefront, the hub API `ca-savia-api`, the store node TIENDA1, CI/CD and the cloud consoles.
Code references are at commit `40132952` (branch `Tony`).
Control IDs `SEC-xx` are defined in [SECURITY-RULES](SECURITY-RULES.md).
Control IDs `LOGIN-xx` are defined in [LOGIN-RULES](LOGIN-RULES.md) (draft 0.1); the table below lists the ones this map cites.

## How to read this map

Threats use STRIDE letters: S spoofing, T tampering, R repudiation, I information disclosure, D denial of service, E elevation of privilege.
Risk is high, medium or low, with one reason.
Test status says what a repository test or evidence file proves today.
"Self-test owed" names the authorized test still needed before the first real client.
Self-tests run only against systems this project owns.
Short file names resolve as follows.
`*Tests.cs` files are in `savia/tests/Savia.Tests/`; `WebStore.cs`, `Sync.cs`, `Auth.cs` and `Tags.cs` are in `savia/src/Savia.Application/`; other `.cs` files are in `savia/src/Savia.Api/`.
`AZURE.md` and `RUNBOOK.md` are in `savia/docs/deploy/`; `STOREFRONT-DEPLOY.md`, `STORE-PC-20261124.md` and `public-api-azure/run-20261124.json` are in `docs/production-20261122/`; `main.bicep` is in `savia/deploy/azure/`.
No staging hub exists: `ca-savia-api` is production, so active scans run against a disposable local hub, not against Azure.

## Login controls cited

| ID | One-line description (from LOGIN-RULES) |
| --- | --- |
| LOGIN-01 | Protected routes refuse calls without a valid session (401). |
| LOGIN-02 | Same answer for unknown, disabled and locked accounts. |
| LOGIN-03 | Staff tokens are random and stored only as a hash. |
| LOGIN-06 | 5 failures lock the account for 15 minutes. |
| LOGIN-07, LOGIN-08 | Lockout counter stays in range and restarts after a lock (fixed 2026-11-27). |
| LOGIN-09 | Per-address sign-in limit that ignores forged forwarded hops. |
| LOGIN-13 | First password must be changed before other routes answer. |
| LOGIN-15 | Provisioning never prints given secrets. |
| LOGIN-16, LOGIN-17 | Role guards; web-order actions only for OWNER and MANAGER. |
| LOGIN-18 | ACCOUNTANT access to buyer contact fields (decision owed). |
| LOGIN-19 | Node credential stored as a hash, compared in fixed time, revocable. |
| LOGIN-21, LOGIN-22 | Buyer order token required; token expiry (gap). |
| LOGIN-25 | Deploy identity uses OIDC from the `production` environment. |
| LOGIN-26 | Multi-factor sign-in on Azure, Cloudflare and GitHub consoles. |

## Entry points

| ID | Entry point | Who can reach it | Data it touches | Main threats | Risk | Controls | Test status | Self-test owed |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| TM-01 | Storefront static pages: home, catalog, product, bag (`dist/*.html`). | Anyone on the internet. | Public catalog and prices; cart in browser storage. | S: a look-alike site. T: script injection through catalog text. D: absorbed by Cloudflare. | Low: no personal data and no write path. | SEC-10, SEC-19, SEC-43 | Headers tested (`tests/static_headers.py`). | ST-1 (ZAP baseline on the preview). |
| TM-02 | Storefront checkout form and order page (`checkout.html`, `pedido.html`, `src/integration-adapters.js`). | Anyone on the internet. | Name, email, phone, address, city, notes; order token kept in browser storage. | S: bots. I: a script that reads the stored order token. T: a changed price (refused: the hub sets prices, and an unknown price field is a 400). | High: personal data enters here. | SEC-01, SEC-02, SEC-10, SEC-35, SEC-43, LOGIN-21 | Order flow tested in a real browser against a disposable hub copy with the bot check off (`docs/production-20261122/e2e-azure/README.md`). Real Turnstile pass: gap (SEC-37). | ST-1 in live mode; real-token check (SEC-37). |
| TM-03 | Storefront `admin.html` demo panel. | Anyone on the internet. | Browser-local demo data only; in live mode the adapter answers only catalog, cart and order routes (`src/integration-adapters.js:255-260`). | S: a visitor or the owner takes it for the real admin. | Low: it cannot reach hub data. | None. Proposal: drop the page from the live build. | Gap: live-mode behaviour not tested. | Check the page in live mode before launch. |
| TM-04 | `GET /api/v1/public/catalog` | Anyone on the internet. | SKUs, available stock, prices. | D: scraping or flooding. I: stock levels are visible by design. | Low: public data, rate-limited. | SEC-29, SEC-34, SEC-45 | Tested: `WebStorePublicTests.cs`; Azure probe `docs/production-20261122/public-api-azure/run-20261124.json`. | ST-2. |
| TM-05 | `POST /api/v1/public/orders` | Anyone; CORS limits browsers only, not scripts. | Writes buyer contact and address; reserves stock. | S: bot orders. T: a crafted body. D: stock hoarding by rotating addresses and emails past the 2-unpaid cap. R: only hashes of the client address are kept. | High: personal data and stock. | SEC-01 to SEC-04, SEC-29, SEC-32, SEC-34 to SEC-38, SEC-45 | Tested in memory (`WebStorePublicTests.cs`, `WebOrderVerticalSliceTests.cs`) and on Azure (`run-20261124.json`). Real token pass: gap. | ST-2 with body fuzzing. |
| TM-06 | `GET /api/v1/public/orders/{id}` | Anyone who holds the order id and token. | Order code, status, total, lines (no contact details). | I: guessing an order. The token is an unkeyed SHA-256 of the buyer's own `Idempotency-Key`; the hub accepts any UUID, so a weak client key gives a weak token. | Medium: limited data, but a design weakness. | LOGIN-21, LOGIN-22, SEC-25, SEC-29 | Tested: `WebOrderVerticalSliceTests.cs` (`Order_status_needs_its_token`). | ST-2. Decide whether to key the token with a hub secret (proposal). |
| TM-07 | `GET` and `POST /api/v1/public/payments/{provider}/return` | Anyone; normally the buyer's browser after a hosted payment page. | Order status; redirects to `Savia:Public:OrderPageUrl`. | S: a forged "paid" return. T: redirect target (fixed by configuration, not by the request). | Medium: money state, guarded server-side. | SEC-39 | Tested: `WebStorePublicTests.cs`, `WebOrderVerticalSliceTests.cs`. | ST-2. |
| TM-08 | `POST /api/v1/public/payments/{provider}/webhook` | Anyone; meant for the card provider. | Payment records; order status. | S: a forged notice. T: a wrong amount (sent to staff review). D: replay. | Low today (no provider has a webhook); high once a card provider is added. | SEC-03, SEC-29, SEC-40, SEC-41 | Fake gateway only (`WebStorePublicTests.cs`). Real provider: gap. | Provider sandbox signature tests when the merchant account exists. |
| TM-09 | Staff sign-in `POST /api/v1/auth/login` and `POST /api/v1/auth/password` | Anyone on the internet (hub is public). | Staff accounts and sessions. | S: password guessing and credential stuffing. I: account enumeration. D: locking the owner out on purpose. | High: staff access exposes buyer data. | SEC-30, SEC-31, LOGIN-02, LOGIN-06, LOGIN-09, LOGIN-13 | Tested: `HostingTests.cs` (limit per address), `PasswordChangeTests.cs`. Lockout counter: `SignInLockoutTests.cs` (LOGIN-07, LOGIN-08). | ST-2 against the sign-in route; check that error replies do not reveal which accounts exist. |
| TM-10 | Staff API `/api/v1/*` (web orders, catalog, inventory, `/me`, `/sync/status`) and staff screens served by the hub at `/` (`savia/web`). | Signed-in staff; the routes are reachable from the internet. | Buyer contact and address (web-order list, up to 500 rows); catalog; stock. | E: a lower role uses a manager route. I: buyer data leak. T: stored script from buyer text on a staff screen. D: no rate limit. | High: largest store of personal data. | LOGIN-01, LOGIN-03, LOGIN-16, LOGIN-17, LOGIN-18, SEC-05, SEC-08, SEC-09, SEC-33, SEC-44 | Partly tested: a cashier is refused a refund action (403) in `WebOrderVerticalSlicePaymentReviewTests.cs:35-37`; 401 without sign-in on Azure (`run-20261124.json`); `innerHTML` ban (`savia/tests/test_rules.py`). No full role-by-route test. | ST-5 (role matrix); ST-2 signed-in scan on a local hub. |
| TM-11 | Staff photo upload `POST /api/v1/inventory/tag-extract` | Signed-in staff. | A label photo; local OCR; photos kept only if `Savia:Tags:KeepPhotos` is true. | D: large or many files. T: a crafted image against the image and OCR libraries. | Medium: staff-only, but it parses files. | SEC-07, LOGIN-16 | Size cap not tested. | Oversize and malformed-image tests on a local hub. |
| TM-12 | Store-node sync API `/sync/v1/state`, `/push/plan`, `/push`, `/pull` | Anyone can call it; only a valid node credential passes. | Store sales, stock and catalog rows. | S: a stolen node secret. T: rows of another node (refused). D: large or many requests (capped at 30,000,000 bytes and limited per address). | High: a stolen secret writes business data. | LOGIN-19, SEC-06, SEC-16, SEC-23, SEC-33 | Tested: `SyncTransportTests.cs`; 401 without credential on Azure (`run-20261124.json`). Body cap, JSON check and rate limit: tested in-process (SEC-06, SEC-33). | A credential rotation drill (`--provision-node rotate`). |
| TM-13 | Store PC: host on `127.0.0.1:5080`, SQL Server Express on `127.0.0.1:14350`, DPAPI secret files. | People and programs on the store PC under Jason's Windows account. | Store database, node secret, local backups. | I: a lost or stolen disk (no at-rest encryption evidence). E: other software on a development PC. D: the host starts only after Jason signs in. | High: the PC holds other credentials (`docs/production-20261122/STORE-PC-20261124.md:63`). | SEC-16, SEC-24 | Gap: no at-rest encryption or off-PC backup evidence. | BitLocker readback; separate Windows account (proposal); encrypted off-PC backup (proposal). |
| TM-14 | Hub `/health`, `/health/ready`, `/openapi/v1.json` | Anyone on the internet. | Liveness; a SQL connection per readiness call; the full route map. | I: the OpenAPI file lists staff routes. D: repeated readiness calls open SQL connections. | Medium: helps an attacker plan; no data. | SEC-33, SEC-48 | Tested in-process: readiness is rate limited (SEC-33); OpenAPI is not served in Production (SEC-48). | Read back on Azure 2026-11-27: `/openapi/v1.json` 404 on revision `ca-savia-api--g0ae5462-1` (`savia/docs/deploy/AZURE.md`). |
| TM-15 | Migration job `caj-savia-migrate` and provisioning commands (`--provision-node`, `--provision-staff`). | Operators with an Azure role; the deploy workflow. | Whole database schema (the migrate identity is the SQL Entra administrator); one-time passwords and node secrets. | E: SQL administrator rights. I: a printed secret stays in job logs (`savia/docs/deploy/RUNBOOK.md:97`). T: a bad migration. | High: full database control. | SEC-13, SEC-15, SEC-17, LOGIN-15 | Migration applied twice on an empty database in CI (`.github/workflows/savia-azure.yml:79`); 0 secret lines after provisioning (`STORE-PC-20261124.md:25`). Key Vault reference path not run. | Run RUNBOOK 3.1 once and read back the logs. |
| TM-16 | CI/CD and source: GitHub repository, Actions (OIDC deploy, AI bug workflows with write rights on issue labels), local hooks that push, manual Wrangler deploys from Jason's PC. | Repository collaborators; anyone who can open an issue or pull request; anyone with the PC's tokens. | Source code, build output, deploy rights to Azure and Cloudflare. | T: a malicious dependency or pull request. E: prompt injection into the AI bug workflow (`.github/workflows/bug-agent.yml`, `contents: write`). I: a secret in a commit. | High: one push can change the live site or hub. | SEC-11, SEC-12, SEC-17, SEC-26, SEC-27, LOGIN-25, LOGIN-26 | Hook secret check tested (`tests/test_progress.py`). Full-history scan, dependency scan and branch protection: gap. | ST-3, ST-4, ST-6; readback of branch protection and repository visibility. |
| TM-17 | Cloudflare dashboard and API: Worker `martha-silva-preview`, Turnstile widget, DNS later. | Jason's Cloudflare account and its API tokens. | Storefront content and headers; Turnstile keys. | S: account takeover. T: a changed storefront script (skimming of contact data). | High: full control of what buyers see. | LOGIN-26; least-privilege API tokens (not in repository). | Gap: not provable from the repository. | Jason reads back multi-factor sign-in and token scopes. |
| TM-18 | Azure portal and CLI: subscription, Container Apps, Azure SQL, Key Vault, Log Analytics. | Jason's Azure account and operators with roles. | All hub data, secrets, logs. | S: account takeover. I: database export. E: broad role assignments. I: the SQL firewall rule `AllowAllWindowsAzureIps` lets any Azure-hosted address try to connect; Entra-only sign-in limits it (`savia/deploy/azure/main.bicep:190-210`). | High: full data access. | SEC-13, SEC-15, SEC-22, LOGIN-26 | Gap: role assignments and multi-factor sign-in not read back. | Role review and multi-factor readback; private network access for SQL (proposal). |

## Authorized self-tests owed

| ID | Test | Target | Status |
| --- | --- | --- | --- |
| ST-1 | OWASP ZAP baseline (passive) scan. | Preview storefront `martha-silva-preview.jason-suazof.workers.dev`, demo and live mode. | Not run. |
| ST-2 | OWASP ZAP API scan from `/openapi/v1.json`, signed out and signed in, with order-body fuzzing. | A disposable local hub with a throwaway database, never `ca-savia-api`. | Not run. Proposal. |
| ST-3 | Dependency scan: `dotnet list package --vulnerable --include-transitive` and `npm audit`. | Repository. | Not run. |
| ST-4 | Full-history secret scan (for example gitleaks). | Repository, all reachable commits. | Not run. |
| ST-5 | Role-by-route authorization test for every staff route. | `savia/tests/Savia.Tests`. | Not written. |
| ST-6 | Container image scan (for example Trivy). | `savia-api` image. | Not run. |
| ST-7 | Paid external penetration test. | Storefront and hub. | Optional; Jason's money decision. |

## Not covered or not provable from the repository

- Live headers and current hub settings: the repository holds readback notes, not a live probe from today.
- Repository visibility and branch protection on GitHub.
- Whether the recovered original Cloudflare Worker (`originals/cloudflare/`) still runs anywhere.
- Card payment: no provider exists, so TM-08 has no real-provider threat test.

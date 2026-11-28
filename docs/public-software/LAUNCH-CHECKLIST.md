# Launch checklist: Martha Silva web store

Version: 0.1
Date: 2026-11-27
Status: approved
Approval: Jason approved version 0.1 on 2026-11-27, including the LOGIN-07 and LOGIN-08 update of commit `c7e30bc4`.
Sources: [SECURITY-RULES](SECURITY-RULES.md), [LOGIN-RULES](LOGIN-RULES.md), [DATA-RULES](DATA-RULES.md), [THREAT-MAP](THREAT-MAP.md), all version 0.1.
Rule: `C:/Users/Jason/AI-OS/rules/public-software.md` (2026-11-25).

## Launch rule

Launch means: the storefront in live mode on a public URL takes real orders into the production hub.
Launch stays blocked while any row below is not `tested` with linked evidence.
A row may instead show `accepted`, but only with Jason's written risk acceptance and its date.
An agent summary is not evidence; each evidence cell must point to a test, a probe file or a readback in this repository.
When a source document changes a control, update its row here in the same commit.

## Status now

| Status | Meaning | Rows |
| --- | --- | --- |
| tested | Evidence in the repository exercises the control | 37 |
| partial | Part of the control is tested; the rest is only built | 5 |
| built | The code or config exists; no test proves it | 27 |
| gap | Not built | 28 |
| Total | | 97 |

Result: launch is blocked. 60 of 97 control rows lack full evidence, and 6 of 7 self-tests are not run.

## Security controls (SECURITY-RULES)

| ID | Control | Status | Evidence |
| --- | --- | --- | --- |
| SEC-01 | The public order body is strict JSON; unknown fields are refused with 400 `validation`. | tested | `savia/tests/Savia.Tests/WebStorePublicTests.cs` (`Unknown_field_is_400`); Azure probe `docs/production-20261122/public-api-azure/run-20261124.json`. |
| SEC-02 | Every order field is checked and trimmed before save: 1-20 lines, quantity 1-10, no repeated SKU, length limits per field, email shape, provider `manual` or `card`, locale `es` or `en`, bot token up to 2048 characters. | built | No test exercises each field limit. The email check is minimal (an `@` not at either end). |
| SEC-03 | A public request body is capped at 16 KB while it is read, not only from `Content-Length`. | tested | `WebStorePublicTests.cs` (`Body_over_16_KB_is_413`); Azure probe `run-20261124.json`. |
| SEC-04 | `Idempotency-Key` must be a UUID; a reused key with a different body is refused (409 `idempotency_conflict`). | tested | `savia/tests/Savia.Tests/WebOrderVerticalSliceTests.cs:37` (409 `idempotency_conflict`); `savia/db/tests/webstore/090_web_order_replay_and_unpaid_limit.sql`. A non-UUID key is not tested. |
| SEC-05 | Every staff route validates its body before save. | gap | Validation exists in services (example: `WebOrderVerticalSlicePaymentReviewTests.cs:38-39`), but no inventory proves every staff input is checked. Audit owed. |
| SEC-06 | The sync push body has a size cap and a schema check at the endpoint. | tested | `SyncTransportTests.cs` (`Hub_refuses_a_sync_body_that_is_not_one_json_object_or_is_too_large_before_sql`): six malformed bodies give 422 `sync.malformed`; 30,000,001 bytes give 422 `sync.too_large`. The schema check is one JSON object; field-level checks stay in SQL. Rows owned by another node are refused (`Hub_refuses_rows_owned_by_another_node`). |
| SEC-07 | A tag photo upload is multipart only, staff only, at most 6 MB, and read locally (no external OCR). | built | No test sends a photo over 6 MB. |
| SEC-08 | SQL runs as stored procedures or fixed SQL text, always with typed parameters; user text never becomes SQL text. | built | A manual search at `40132952` found no SQL built by string interpolation; no automated check exists. |
| SEC-09 | Staff screens write buyer text with `textContent`; `innerHTML`, `outerHTML` and `insertAdjacentHTML` are banned in `savia/web`. | tested | `savia/tests/test_rules.py`. |
| SEC-10 | The storefront escapes catalog and order text before it inserts HTML. | built | No test injects markup into storefront templates. |
| SEC-11 | No secret, key file, `.env`, database or cookie file enters a commit. | tested | `tests/test_progress.py` (`test_secret_in_index_blocks_even_if_worktree_cleaned`, `test_frozen_import_retains_secret_and_mode_guards`). The pattern list covers only a few token formats. |
| SEC-12 | A full-history secret scan (for example gitleaks) runs in CI and before each release. | gap | No scanner in `.github/workflows/`. The last full review was manual (`docs/SECURITY.md`, 2026-10-24). |
| SEC-13 | The hub reaches Azure SQL with managed identities; no SQL password exists for the hub. | built | Readback of the API connection string in `docs/production-20261122/STORE-PC-20261124.md` (H2 section). |
| SEC-14 | The Turnstile secret lives only in the Container App secret `turnstile-secret`, read as `secretref`; it is never printed. | built | Not in `main.bicep`. `STOREFRONT-DEPLOY.md:39` and `RUNBOOK.md:185` say Key Vault; they disagree with AZURE.md and must be corrected. Proposal: move it to a Key Vault reference. |
| SEC-15 | Key Vault uses RBAC only, soft delete 90 days and purge protection; only the API identity reads secrets. | built | The operator account has no data role (`STORE-PC-20261124.md:22`). |
| SEC-16 | The sync API refuses any call without a valid node credential. | tested | `SyncTransportTests.cs` (`Hub_refuses_a_call_without_a_valid_node_credential`); Azure probe 401 in `run-20261124.json`. The hub keeps only the SHA-256 of the secret and the store keeps it in a DPAPI file for one Windows user (built; see LOGIN-19). The Key Vault path (RUNBOOK 3.1) has not run. |
| SEC-17 | CI signs in to Azure with OIDC from the `production` environment only; no Azure secret is stored in GitHub; actions are pinned by commit SHA. | built | The deploy job has not run on GitHub (`savia/docs/deploy/CHECKLIST.md:15`); deploys so far were manual. |
| SEC-18 | Production settings set by CLI are in code, so a template redeploy cannot drop them. | gap | `Savia__Public__AllowedOrigins`, `Savia__Public__OrderPageUrl` and the Turnstile `secretref` are absent from `main.bicep`. A redeploy with `deployApps=true` would likely replace the env list, and orders would then fail closed (inference from the template, not tested). |
| SEC-19 | The storefront is HTTPS only and sends HSTS (one year, subdomains). | tested | `tests/static_headers.py` (run by `tests/check.py:93`). `STOREFRONT-DEPLOY.md:4` and `:76` disagree on HSTS; the built file has it. |
| SEC-20 | The hub ingress refuses plain HTTP; the app adds HSTS outside Development. | built | The hub HSTS header is not asserted by a test. |
| SEC-21 | Hub to Azure SQL uses TLS 1.2 or later with certificate validation. | built |  |
| SEC-22 | Azure SQL data and backups are encrypted at rest (TDE). | gap | Readback owed (`az sql db tde show`). |
| SEC-23 | Store-to-hub sync uses HTTPS. | built |  |
| SEC-24 | Store PC data is encrypted at rest and backups leave the PC encrypted. | gap | SQL Server Express has no TDE; no BitLocker evidence; backups stay on the same disk (`STORE-PC-20261124.md:68`). Local SQL uses `TrustServerCertificate=True` on loopback only (`start-store.ps1:21`). |
| SEC-25 | Bearer secrets are stored only as hashes: order access token, client address, request body, staff session token, node secret. | built | `WebOrderVerticalSliceTests.cs` (`Order_status_needs_its_token`) proves the token is required, not that only the hash is stored. Staff token hashing is tested under LOGIN-03. |
| SEC-26 | Builds restore locked dependencies; base images are pinned by digest. | built |  |
| SEC-27 | A dependency vulnerability scan runs in CI (.NET, npm). | gap | `npm ci --no-audit`; no Dependabot; no `dotnet list package --vulnerable`. |
| SEC-28 | Patch cadence (proposal): critical CVE in a used component within 72 hours; .NET SDK and runtime digest bump monthly; npm and Wrangler monthly; store PC Windows Update automatic and SQL Express cumulative update checked monthly. | gap | Proposal only. No owner or calendar exists yet. |
| SEC-29 | Public routes allow 60 requests per client address per minute (fixed window, no queue); excess gets 429 `rate_limited`. | tested | `WebStorePublicTests.cs` (`Too_many_requests_from_one_client_is_429`); Azure probe: 70 GETs gave 60 × 200 and 10 × 429 (`run-20261124.json`). The counter is in memory per replica; with 2 replicas the real limit can reach 120. |
| SEC-30 | Staff sign-in and password change allow 10 attempts per client address per minute on Azure. | tested | `savia/tests/Savia.Tests/HostingTests.cs` (`Login_limit_is_per_client_address_and_ignores_forged_earlier_hops`). The value 10 is not exercised on Azure, and the password route limit is not tested. Account lockout belongs to LOGIN-RULES. |
| SEC-31 | The client address is the proxy's last hop only; a forged `X-Forwarded-For` is ignored. | tested | Same HostingTests test as SEC-30. |
| SEC-32 | At most 2 unpaid orders per email and per client address hash. | tested | `savia/db/tests/webstore/090_web_order_replay_and_unpaid_limit.sql`. |
| SEC-33 | Staff routes, sync routes, `/health/ready` and `/openapi/v1.json` have a rate limit. | tested | `HostingTests.cs` (`Staff_sync_and_readiness_routes_are_limited_per_client_address_only_when_configured`): with `Savia:Hosting:PerMinute=3`, the fourth call to `/api/v1/me`, `/health/ready` and `/sync/v1/state` gets 429; `/health` stays 200. Azure sets 300 (`deploy/azure/main.bicep`). The counter is in memory per replica. `/openapi/v1.json` is not served in Production (SEC-48). |
| SEC-34 | CORS applies to public routes only: listed origins, GET and POST, three headers, never credentials. | tested | `WebStorePublicTests.cs` (`Cors_allows_only_listed_origins_without_credentials`); Azure probe `run-20261124.json`. |
| SEC-35 | Turnstile is checked server-side before any stock is reserved; a missing secret or no siteverify answer refuses the order. | tested | `WebOrderVerticalSliceTests.cs` (`Failed_bot_check_reserves_nothing`); Azure probe 403 with no secret (`run-20261124.json`). |
| SEC-36 | With the secret set, a forged token is refused through siteverify. | built | Operator note in `AZURE.md:183` only; no raw probe file in the repository. |
| SEC-37 | A real Turnstile token passes end to end from the live storefront. | gap | Not run. |
| SEC-38 | `Savia:Public:BotCheck=disabled` can never take effect in Production. | tested | `HostingTests.cs` (`A_production_host_refuses_to_start_with_the_bot_check_off`); guard in `WebStoreHosting.cs` and `Program.cs`. |
| SEC-39 | Only a server-side provider answer records a payment; a browser return alone never marks an order paid. | tested | `WebStorePublicTests.cs` (`A_browser_claim_alone_is_never_a_verified_payment`); `WebOrderVerticalSliceTests.cs` (`Card_return_is_not_payment_until_the_gateway_confirms_and_webhooks_must_be_signed`). |
| SEC-40 | A webhook signature is checked before the body is read; a repeat delivery records nothing new. | tested | Fake gateway only: `WebStorePublicTests.cs` (`Fake_gateway_rejects_an_unsigned_webhook_before_reading_it`). |
| SEC-41 | The real card provider's webhook signature and return confirmation are implemented and tested. | gap | No card provider exists (merchant account missing). |
| SEC-42 | The store never collects or stores card numbers; card entry happens only on the provider's hosted page. | built | Card data rules are in DATA-RULES. |
| SEC-43 | The storefront sends CSP (script by hash, `frame-ancestors 'none'`), `nosniff`, Referrer-Policy, Permissions-Policy, COOP and `X-Robots-Tag: noindex` until launch. | tested | `tests/static_headers.py`. `style-src` still allows `'unsafe-inline'`. Live readback: `STOREFRONT-DEPLOY.md:4-6`. |
| SEC-44 | The hub sends CSP (`default-src 'self'`, `frame-ancestors 'none'`), `nosniff` and `Referrer-Policy: no-referrer` on every response. | tested | `HostingTests.cs` (`Every_response_carries_the_security_headers`). |
| SEC-45 | Public routes answer only public error codes; an internal error says "Error interno." plus a trace id. | tested | `WebStorePublicTests.cs` (`AssertPublicAsync` checks the public code). |
| SEC-46 | Application logs name order ids, paths and error codes, never contact details; the client address is kept only as a hash. | partial | Every logged exception goes through `SafeLog.Describe`: code, SQL number, procedure, line and stack, never the message. `SafeLogTests.cs` (`A_sql_error_that_quotes_an_email_is_logged_without_it`) uses a real SQL duplicate key that quotes an email. No test scans every log template, and the address hash is not tested here. |
| SEC-47 | Telemetry (Application Insights) holds no personal data: client IP masking and URL contents are confirmed. | gap | Readback owed. `TelemetryTests.cs` only proves the host starts. |
| SEC-48 | The OpenAPI document is not public in Production. | tested | `HostingTests.cs` (`The_openapi_document_is_served_outside_production_only`): 404 in Production, 200 in Testing. |

## Login controls (LOGIN-RULES)

| ID | Control | Status | Evidence |
| --- | --- | --- | --- |
| LOGIN-01 | Protected routes refuse calls without a valid session (401) | tested | `savia/tests/Savia.Tests/VerticalSliceTests.cs:166`; Azure: `docs/production-20261122/public-api-azure/README.md` |
| LOGIN-02 | Same answer for unknown, disabled and locked accounts | tested | `VerticalSliceTests.cs:166` |
| LOGIN-03 | Tokens are random and stored only as a hash | tested | `VerticalSliceTests.cs:166` |
| LOGIN-04 | Logout ends the token | tested | `VerticalSliceTests.cs:166` |
| LOGIN-05 | Staff session ends after 12 hours | built | No test |
| LOGIN-06 | 5 failures lock the account for 15 minutes | partial | `PasswordChangeTests.cs:52` asserts the lock after 5 failures, not its length |
| LOGIN-07 | Lockout counter stays inside the SQL CHECK range | tested | `savia/tests/Savia.Tests/SignInLockoutTests.cs` (25 wrong passwords, 5 lock cycles, every answer 401); reproduced before the fix on 2026-11-27: 409 `db.reference` instead of 401 |
| LOGIN-08 | Lockout counter resets when a lock ends | tested | `savia/tests/Savia.Tests/SignInLockoutTests.cs` (25 wrong passwords, 5 lock cycles, every answer 401) |
| LOGIN-09 | Per-IP login limit, ignores forged forwarded hops | tested | `HostingTests.cs:66,76`; not exercised on Azure |
| LOGIN-10 | Public routes limited to 60 per minute per IP | tested | Azure: `public-api-azure/README.md` |
| LOGIN-11 | Password length 10-200 and differs from old | built | No direct test |
| LOGIN-12 | PBKDF2-SHA256, 600,000 iterations | built | No direct test |
| LOGIN-13 | First password must be changed; other routes 403 | tested | `PasswordChangeTests.cs:78`; `savia/db/tests/security/310_password_change.sql` |
| LOGIN-14 | Password change ends other sessions | tested | `PasswordChangeTests.cs:34` |
| LOGIN-15 | Provisioning never prints given secrets; shared password refused by default | tested | `PasswordChangeTests.cs:149`; `PilotProvisioningTests.cs:19` |
| LOGIN-16 | Role guards refuse other roles (403) | tested | `OwnerPilotTests.cs:28,32,68`; `OwnerDecisionsRound4Tests.cs:83,108,138,146`; `LocalCatalogRejectTests.cs:61-65,84-100`; `HubCatalogTests.cs:40,56` |
| LOGIN-17 | Web order actions limited to OWNER and MANAGER | partial | Refund review only: a cashier gets 403 `auth.role_required` (`savia/tests/Savia.Tests/WebOrderVerticalSlicePaymentReviewTests.cs:35-37`); other web order actions have no role-denial test |
| LOGIN-18 | ACCOUNTANT cannot read buyer contact fields | gap | Decision for Jason |
| LOGIN-19 | Node credential refused when wrong, for another node or revoked; stored as hash; fixed-time compare | partial | `SyncTransportTests.cs:17`; `NodeProvisioningTests.cs`; `savia/db/tests/sync/280_provision_node.sql`; Azure: `public-api-azure/README.md` |
| LOGIN-20 | Node secret comes from config or environment, never Git | built | Code read |
| LOGIN-21 | Buyer order status needs its token; wrong token reads as not found | tested | `WebOrderVerticalSliceTests.cs:41` |
| LOGIN-22 | Buyer order token expires | gap | Proposal in section 2 |
| LOGIN-23 | Staff can be disabled and passwords reset through a route or command | gap | Direct SQL only |
| LOGIN-24 | SQL host login is only a member of the API host role | tested | `ApiHostLoginTests.cs:16` |
| LOGIN-25 | Deploy identity uses OIDC, environment `production`, cannot read secrets | built | Reviewer setting unknown, owed to Jason |
| LOGIN-26 | MFA on Azure, Cloudflare and GitHub consoles | gap | Unknown, owed to Jason |
| LOGIN-27 | Expired sessions are purged | gap | `security.Sessions` grows without limit |

## Data controls (DATA-RULES)

| ID | Control | Status | Evidence |
| --- | --- | --- | --- |
| DATA-01 | Card data is never collected or stored | built | Code search on 2026-11-27; no test |
| DATA-02 | Order status answer holds no personal data (test checks the street address is absent) | tested | `savia/tests/Savia.Tests/WebOrderVerticalSliceTests.cs:41` |
| DATA-03 | Buyer IP is not stored; only an unsalted hash | built | Hash is still personal data (pseudonymous) |
| DATA-04 | Contact fields have length limits | built | No direct test |
| DATA-05 | Sync payload for a web order excludes address and phone | built | Migration comment; no test |
| DATA-06 | Staff tokens, node secrets and order tokens stored only as hashes | partial | `savia/tests/Savia.Tests/VerticalSliceTests.cs:166` |
| DATA-07 | Telemetry kept 30 days; no local keys | built | IP masking in Application Insights not verified |
| DATA-08 | Azure SQL backups kept 7 days | built | `AZURE.md:97-104` |
| DATA-09 | Checkout form cleared from the browser after submit | built | No browser test cited |
| DATA-10 | Browser `pending` key holds no contact fields and expires | gap | Proposal in section 4 |
| DATA-11 | Expired and cancelled unpaid orders lose contact fields | gap | Sweep keeps them forever |
| DATA-12 | Delivered orders lose contact fields after the tax-law period | gap | Period unknown |
| DATA-13 | Expired sessions are deleted | gap | `security.Sessions` |
| DATA-14 | ClientHash and order token hash are blanked on schedule | gap | Proposal in section 4 |
| DATA-15 | Buyer access, correction and deletion can be served | gap | Manual process proposal in section 5 |
| DATA-16 | Store customer correction and deletion | gap | No route |
| DATA-17 | ACCOUNTANT cannot read buyer contact fields | gap | Same as LOGIN-18 |
| DATA-18 | Store PC backups have an encrypted off-PC copy | gap | Decision for Jason |
| DATA-19 | Store PC runs under a service account, not Jason's account | gap | `STORE-PC-20261124.md:63,68` |
| DATA-20 | Privacy notice names recipients (Cloudflare, Azure), the hub country and retention | gap | For lawyer review |
| DATA-21 | Transfer of data to Mexico reviewed under Ley 787 | gap | For lawyer review |
| DATA-22 | Data file registered under Ley 787 Art. 22 | gap | Unknown, owed to Jason |

## Entry points (THREAT-MAP)

Each entry point is launch-ready only when its controls are `tested` and its owed self-test has run.

| ID | Entry point | Risk | Test status | Self-test owed |
| --- | --- | --- | --- | --- |
| TM-01 | Storefront static pages: home, catalog, product, bag (`dist/*.html`). | Low: no personal data and no write path. | Headers tested (`tests/static_headers.py`). | ST-1 (ZAP baseline on the preview). |
| TM-02 | Storefront checkout form and order page (`checkout.html`, `pedido.html`, `src/integration-adapters.js`). | High: personal data enters here. | Order flow tested in a real browser against a disposable hub copy with the bot check off (`docs/production-20261122/e2e-azure/README.md`). Real Turnstile pass: gap (SEC-37). | ST-1 in live mode; real-token check (SEC-37). |
| TM-03 | Storefront `admin.html` demo panel. | Low: it cannot reach hub data. | Gap: live-mode behaviour not tested. | Check the page in live mode before launch. |
| TM-04 | `GET /api/v1/public/catalog` | Low: public data, rate-limited. | Tested: `WebStorePublicTests.cs`; Azure probe `docs/production-20261122/public-api-azure/run-20261124.json`. | ST-2. |
| TM-05 | `POST /api/v1/public/orders` | High: personal data and stock. | Tested in memory (`WebStorePublicTests.cs`, `WebOrderVerticalSliceTests.cs`) and on Azure (`run-20261124.json`). Real token pass: gap. | ST-2 with body fuzzing. |
| TM-06 | `GET /api/v1/public/orders/{id}` | Medium: limited data, but a design weakness. | Tested: `WebOrderVerticalSliceTests.cs` (`Order_status_needs_its_token`). | ST-2. Decide whether to key the token with a hub secret (proposal). |
| TM-07 | `GET` and `POST /api/v1/public/payments/{provider}/return` | Medium: money state, guarded server-side. | Tested: `WebStorePublicTests.cs`, `WebOrderVerticalSliceTests.cs`. | ST-2. |
| TM-08 | `POST /api/v1/public/payments/{provider}/webhook` | Low today (no provider has a webhook); high once a card provider is added. | Fake gateway only (`WebStorePublicTests.cs`). Real provider: gap. | Provider sandbox signature tests when the merchant account exists. |
| TM-09 | Staff sign-in `POST /api/v1/auth/login` and `POST /api/v1/auth/password` | High: staff access exposes buyer data. | Tested: `HostingTests.cs` (limit per address), `PasswordChangeTests.cs`. Lockout counter: `SignInLockoutTests.cs` (LOGIN-07, LOGIN-08). | ST-2 against the sign-in route; check that error replies do not reveal which accounts exist. |
| TM-10 | Staff API `/api/v1/*` (web orders, catalog, inventory, `/me`, `/sync/status`) and staff screens served by the hub at `/` (`savia/web`). | High: largest store of personal data. | Partly tested: a cashier is refused a refund action (403) in `WebOrderVerticalSlicePaymentReviewTests.cs:35-37`; 401 without sign-in on Azure (`run-20261124.json`); `innerHTML` ban (`savia/tests/test_rules.py`). No full role-by-route test. | ST-5 (role matrix); ST-2 signed-in scan on a local hub. |
| TM-11 | Staff photo upload `POST /api/v1/inventory/tag-extract` | Medium: staff-only, but it parses files. | Size cap not tested. | Oversize and malformed-image tests on a local hub. |
| TM-12 | Store-node sync API `/sync/v1/state`, `/push/plan`, `/push`, `/pull` | High: a stolen secret writes business data. | Tested: `SyncTransportTests.cs`; 401 without credential on Azure (`run-20261124.json`). Body cap, JSON check and rate limit: tested in-process (SEC-06, SEC-33). | A credential rotation drill (`--provision-node rotate`). |
| TM-13 | Store PC: host on `127.0.0.1:5080`, SQL Server Express on `127.0.0.1:14350`, DPAPI secret files. | High: the PC holds other credentials (`docs/production-20261122/STORE-PC-20261124.md:63`). | Gap: no at-rest encryption or off-PC backup evidence. | BitLocker readback; separate Windows account (proposal); encrypted off-PC backup (proposal). |
| TM-14 | Hub `/health`, `/health/ready`, `/openapi/v1.json` | Medium: helps an attacker plan; no data. | Tested in-process: readiness is rate limited (SEC-33); OpenAPI is not served in Production (SEC-48). | Read back 404 for `/openapi/v1.json` on Azure after the next hub deploy. |
| TM-15 | Migration job `caj-savia-migrate` and provisioning commands (`--provision-node`, `--provision-staff`). | High: full database control. | Migration applied twice on an empty database in CI (`.github/workflows/savia-azure.yml:79`); 0 secret lines after provisioning (`STORE-PC-20261124.md:25`). Key Vault reference path not run. | Run RUNBOOK 3.1 once and read back the logs. |
| TM-16 | CI/CD and source: GitHub repository, Actions (OIDC deploy, AI bug workflows with write rights on issue labels), local hooks that push, manual Wrangler deploys from Jason's PC. | High: one push can change the live site or hub. | Hook secret check tested (`tests/test_progress.py`). Full-history scan, dependency scan and branch protection: gap. | ST-3, ST-4, ST-6; readback of branch protection and repository visibility. |
| TM-17 | Cloudflare dashboard and API: Worker `martha-silva-preview`, Turnstile widget, DNS later. | High: full control of what buyers see. | Gap: not provable from the repository. | Jason reads back multi-factor sign-in and token scopes. |
| TM-18 | Azure portal and CLI: subscription, Container Apps, Azure SQL, Key Vault, Log Analytics. | High: full data access. | Gap: role assignments and multi-factor sign-in not read back. | Role review and multi-factor readback; private network access for SQL (proposal). |

## Self-tests owed (THREAT-MAP)

| ID | Test | Target | Status |
| --- | --- | --- | --- |
| ST-1 | OWASP ZAP baseline (passive) scan. | Preview storefront `martha-silva-preview.jason-suazof.workers.dev`, demo and live mode. | Not run. |
| ST-2 | OWASP ZAP API scan from `/openapi/v1.json`, signed out and signed in, with order-body fuzzing. | A disposable local hub with a throwaway database, never `ca-savia-api`. | Not run. Proposal. |
| ST-3 | Dependency scan: `dotnet list package --vulnerable --include-transitive` and `npm audit`. | Repository. | Not run. |
| ST-4 | Full-history secret scan (for example gitleaks). | Repository, all reachable commits. | Not run. |
| ST-5 | Role-by-route authorization test for every staff route. | `savia/tests/Savia.Tests`. | Not written. |
| ST-6 | Container image scan (for example Trivy). | `savia-api` image. | Not run. |
| ST-7 | Paid external penetration test. | Storefront and hub. | Optional; Jason's money decision. |

## Not part of this checklist, still required for production

- Card payment with a verified webhook (checklist row W4 in `docs/production-20261122/README.md`; D-008).
- Real catalog (W8), confirmed legal texts (W9) and the custom domain (W10).
- A real Turnstile token pass on the live storefront.

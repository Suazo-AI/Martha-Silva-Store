# Security rules: Martha Silva web store

Version: 0.1
Date: 2026-11-27
Status: approved
Approval: Jason approved version 0.1 on 2026-11-27, including the LOGIN-07 and LOGIN-08 update of commit `c7e30bc4`.
Scope: storefront (Cloudflare Worker `martha-silva-preview`), hub API `ca-savia-api` (Azure Container Apps, Azure SQL), store node TIENDA1 (store PC), CI/CD.
Code references are file:line at commit `40132952` (branch `Tony`); lines drift after that commit.
Related documents: [THREAT-MAP](THREAT-MAP.md), [LOGIN-RULES](LOGIN-RULES.md), [DATA-RULES](DATA-RULES.md).

## How to read this document

Each control has one ID, one status and one evidence link.
`built` means the code or configuration exists in the repository.
`tested` means a named test or a repository evidence file exercises the control.
`gap` means the control is missing, or it exists outside the repository and has no readback.
A value marked "proposal" needs Jason's decision.
Paths with a folder are relative to the repository root.
Short file names resolve as follows.
`*Tests.cs` files are in `savia/tests/Savia.Tests/`; `WebStore.cs`, `Sync.cs`, `Auth.cs` and `Tags.cs` are in `savia/src/Savia.Application/`; other `.cs` files are in `savia/src/Savia.Api/`.
`AZURE.md` and `RUNBOOK.md` are in `savia/docs/deploy/`; `STOREFRONT-DEPLOY.md`, `STORE-PC-20261124.md` and `public-api-azure/run-20261124.json` are in `docs/production-20261122/`; `main.bicep` is in `savia/deploy/azure/`.

## 1. Input validation before save

| ID | Rule | Where | Status | Evidence or note |
| --- | --- | --- | --- | --- |
| SEC-01 | The public order body is strict JSON; unknown fields are refused with 400 `validation`. | `savia/src/Savia.Api/PublicEndpoints.cs:21-24,140-160` | tested | `savia/tests/Savia.Tests/WebStorePublicTests.cs` (`Unknown_field_is_400`); Azure probe `docs/production-20261122/public-api-azure/run-20261124.json`. |
| SEC-02 | Every order field is checked and trimmed before save: 1-20 lines, quantity 1-10, no repeated SKU, length limits per field, email shape, provider `manual` or `card`, locale `es` or `en`, bot token up to 2048 characters. | `savia/src/Savia.Application/WebStore.cs:54-55,73-91,214-220` | built | No test exercises each field limit. The email check is minimal (an `@` not at either end). |
| SEC-03 | A public request body is capped at 16 KB while it is read, not only from `Content-Length`. | `PublicEndpoints.cs:19,140-150,173-191` | tested | `WebStorePublicTests.cs` (`Body_over_16_KB_is_413`); Azure probe `run-20261124.json`. |
| SEC-04 | `Idempotency-Key` must be a UUID; a reused key with a different body is refused (409 `idempotency_conflict`). | `PublicEndpoints.cs:49-61` | tested | `savia/tests/Savia.Tests/WebOrderVerticalSliceTests.cs:37` (409 `idempotency_conflict`); `savia/db/tests/webstore/090_web_order_replay_and_unpaid_limit.sql`. A non-UUID key is not tested. |
| SEC-05 | Every staff route validates its body before save. | services under `savia/src/Savia.Application/` | partial | Audit `docs/public-software/evidence/sec05-staff-input-audit.md`: 31 staff JSON routes, 21 validated and 10 partial before the fix. Gaps 1-12 reproduced red, then fixed: length checks before the procedures truncate (`Guard.MaxLength`), `Guard.Id` against the empty id, `Guard.Currency`, null array elements refused, `V065` widens the import work table, CHECK failures map to 422 `db.check`, and unreadable staff bodies return 400 `input.body`. Tests: `StaffInputValidationTests.cs` and `DbErrorsTests.cs`. Still owed: a red test for some ids (`CashCountId`, `ClosureId`, `TransferId` and others), one invalid-body test per remaining route (gap 13), and gap 14. |
| SEC-06 | The sync push body has a size cap and a schema check at the endpoint. | `savia/src/Savia.Api/SyncEndpoints.cs` (`BodyAsync`) | tested | `SyncTransportTests.cs` (`Hub_refuses_a_sync_body_that_is_not_one_json_object_or_is_too_large_before_sql`): six malformed bodies give 422 `sync.malformed`; 30,000,001 bytes give 422 `sync.too_large`. The schema check is one JSON object; field-level checks stay in SQL. Rows owned by another node are refused (`Hub_refuses_rows_owned_by_another_node`). |
| SEC-07 | A tag photo upload is multipart only, staff only, at most 6 MB, and read locally (no external OCR). | `savia/src/Savia.Api/TagsEndpoints.cs:16-37`; `savia/src/Savia.Application/Tags.cs:32` | built | No test sends a photo over 6 MB. |
| SEC-08 | SQL runs as stored procedures or fixed SQL text, always with typed parameters; user text never becomes SQL text. | `savia/src/Savia.Infrastructure/SqlGateway.cs:40-75` | built | A manual search at `40132952` found no SQL built by string interpolation; no automated check exists. |
| SEC-09 | Staff screens write buyer text with `textContent`; `innerHTML`, `outerHTML` and `insertAdjacentHTML` are banned in `savia/web`. | `savia/tools/rules.py:89`; CI `.github/workflows/savia-v2.yml:52` | tested | `savia/tests/test_rules.py`. |
| SEC-10 | The storefront escapes catalog and order text before it inserts HTML. | `src/app.js` (`esc()` in templates) | built | No test injects markup into storefront templates. |

## 2. Secrets

| ID | Rule | Where | Status | Evidence or note |
| --- | --- | --- | --- | --- |
| SEC-11 | No secret, key file, `.env`, database or cookie file enters a commit. | pre-commit hook `.githooks/pre-commit` calling `tools/progress.py:45-55,99-105` | tested | `tests/test_progress.py` (`test_secret_in_index_blocks_even_if_worktree_cleaned`, `test_frozen_import_retains_secret_and_mode_guards`). The pattern list covers only a few token formats. |
| SEC-12 | A full-history secret scan (for example gitleaks) runs in CI and before each release. | none | tested | `.github/workflows/security-scans.yml` job `secrets`: gitleaks (pinned by digest) on all refs with `.gitleaks.toml` and 15 reviewed fingerprints in `.gitleaksignore`; CI run 46094975837 (Security scans, green): 363 commits scanned, no leaks. Runs on push, pull request and weekly. Full mirror run: `docs/public-software/evidence/scans-20261127/st4-full-mirror.txt`. |
| SEC-13 | The hub reaches Azure SQL with managed identities; no SQL password exists for the hub. | `savia/deploy/azure/main.bicep:7,93-99,283` | tested | Readback 2026-11-27 (`docs/public-software/evidence/azure-readback-20261127.md`): Entra-only authentication `true`, so no SQL password can sign in; the API connection string uses `Active Directory Managed Identity` with no password. |
| SEC-14 | The Turnstile secret lives only in the Container App secret `turnstile-secret`, read as `secretref`; it is never printed. | Azure, set by CLI; recorded in `savia/docs/deploy/AZURE.md:183` | built | Live: Container App secret `turnstile-secret`, read as `secretref` (`savia/docs/deploy/AZURE.md:183`). `main.bicep` now declares it as a Key Vault reference (`kv-savia-bukmlt`, secret `turnstile-secret`, API identity), so the template holds no value. The live move is pending: it needs a second secret and a 0% revision, and a probe that tells a wrong secret from a wrong token (SEC-37); the dummy-token 403 cannot. |
| SEC-15 | Key Vault uses RBAC only, soft delete 90 days and purge protection; only the API identity reads secrets. | `main.bicep:165-180,510-515` | tested | Readback 2026-11-27 (`docs/public-software/evidence/azure-readback-20261127.md`): RBAC on, soft delete 90 days, purge protection on; the only data role is `Key Vault Secrets User` for `id-savia-api-bukmlt`. The subscription Owner can still grant itself a data role. Network access is public; RBAC is the gate. |
| SEC-16 | The sync API refuses any call without a valid node credential. | `savia/src/Savia.Application/Sync.cs:42-49,67-72`; `savia/deploy/store-pc/start-store.ps1:1` | tested | `SyncTransportTests.cs` (`Hub_refuses_a_call_without_a_valid_node_credential`); Azure probe 401 in `run-20261124.json`. The hub keeps only the SHA-256 of the secret and the store keeps it in a DPAPI file for one Windows user (built; see LOGIN-19). The Key Vault path (RUNBOOK 3.1) has not run. |
| SEC-17 | CI signs in to Azure with OIDC from the `production` environment only; no Azure secret is stored in GitHub; actions are pinned by commit SHA. | `main.bicep:100-111`; `.github/workflows/savia-azure.yml:116-125` | built | The deploy job has not run on GitHub (`savia/docs/deploy/CHECKLIST.md:15`); deploys so far were manual. |
| SEC-18 | Production settings set by CLI are in code, so a template redeploy cannot drop them. | `main.bicep` env list (around line 335-365) | partial | `main.bicep` now holds `Savia__Public__AllowedOrigins`, `Savia__Public__OrderPageUrl`, the Turnstile `secretref`, the ingress CORS policy and a traffic pin (`apiTrafficRevision`). A what-if against the live app (`docs/public-software/evidence/sec18-whatif-20261127.md`) showed all of them removed before the fix and none removed after it. Not exercised: a real redeploy; it would stop on the Key Vault reference until SEC-14 is moved (expected, not tested). |

## 3. Encryption

| ID | Rule | Where | Status | Evidence or note |
| --- | --- | --- | --- | --- |
| SEC-19 | The storefront is HTTPS only and sends HSTS (one year, subdomains). | `build-inputs/static/_headers`; `dist/_headers:9` | tested | `tests/static_headers.py` (run by `tests/check.py:93`). `STOREFRONT-DEPLOY.md:4` and `:76` disagree on HSTS; the built file has it. |
| SEC-20 | The hub ingress refuses plain HTTP; the app adds HSTS outside Development. | `main.bicep:307`; `savia/src/Savia.Api/Hosting.cs:79` | built | The hub HSTS header is not asserted by a test. |
| SEC-21 | Hub to Azure SQL uses TLS 1.2 or later with certificate validation. | `main.bicep:190,283` (`Encrypt=True;TrustServerCertificate=False`) | tested | Readback 2026-11-27 (`docs/public-software/evidence/azure-readback-20261127.md`): server `minimalTlsVersion` 1.2; live connection string `Encrypt=True;TrustServerCertificate=False`. |
| SEC-22 | Azure SQL data and backups are encrypted at rest (TDE). | Azure platform default; not set in `main.bicep` | tested | Readback 2026-11-27 (`docs/public-software/evidence/azure-readback-20261127.md`): TDE `Enabled` on `savia` and on the pre-migration copy, service-managed key. |
| SEC-23 | Store-to-hub sync uses HTTPS. | `start-store.ps1:27` | built | |
| SEC-24 | Store PC data is encrypted at rest and backups leave the PC encrypted. | store PC | gap | SQL Server Express has no TDE; no BitLocker evidence; backups stay on the same disk (`STORE-PC-20261124.md:68`). Local SQL uses `TrustServerCertificate=True` on loopback only (`start-store.ps1:21`). |
| SEC-25 | Bearer secrets are stored only as hashes: order access token, client address, request body, staff session token, node secret. | `PublicEndpoints.cs:162-164`; `WebStore.cs:236-240`; `savia/src/Savia.Application/Auth.cs:55,62`; `Sync.cs:49` | built | `WebOrderVerticalSliceTests.cs` (`Order_status_needs_its_token`) proves the token is required, not that only the hash is stored. Staff token hashing is tested under LOGIN-03. |

## 4. Updates and patches

| ID | Rule | Where | Status | Evidence or note |
| --- | --- | --- | --- | --- |
| SEC-26 | Builds restore locked dependencies; base images are pinned by digest. | `savia/Dockerfile:8-9`; `savia-azure.yml:50`; `.github/workflows/ci.yml:108` (`npm ci`) | built | |
| SEC-27 | A dependency vulnerability scan runs in CI (.NET, npm). | none | tested | `.github/workflows/security-scans.yml` job `dependencies`: `dotnet list --vulnerable --include-transitive` after a locked restore, and `npm audit --audit-level=high` in 3 lockfiles; CI run 46094975837 (Security scans, green): 7 .NET projects with no vulnerable packages, 0 npm findings. No Dependabot. |
| SEC-28 | Patch cadence (proposal): critical CVE in a used component within 72 hours; .NET SDK and runtime digest bump monthly; npm and Wrangler monthly; store PC Windows Update automatic and SQL Express cumulative update checked monthly. | this document | gap | Proposal only. No owner or calendar exists yet. |

## 5. Rate limits and abuse

| ID | Rule | Where | Status | Evidence or note |
| --- | --- | --- | --- | --- |
| SEC-29 | Public routes allow 60 requests per client address per minute (fixed window, no queue); excess gets 429 `rate_limited`. | `savia/src/Savia.Api/WebStoreHosting.cs:44-59` | tested | `WebStorePublicTests.cs` (`Too_many_requests_from_one_client_is_429`); Azure probe: 70 GETs gave 60 × 200 and 10 × 429 (`run-20261124.json`). The counter is in memory per replica; with 2 replicas the real limit can reach 120. |
| SEC-30 | Staff sign-in and password change allow 10 attempts per client address per minute on Azure. | `Hosting.cs:46-55`; `main.bicep:357` | tested | `savia/tests/Savia.Tests/HostingTests.cs` (`Login_limit_is_per_client_address_and_ignores_forged_earlier_hops`). The value 10 is not exercised on Azure, and the password route limit is not tested. Account lockout belongs to LOGIN-RULES. |
| SEC-31 | The client address is the proxy's last hop only; a forged `X-Forwarded-For` is ignored. | `Hosting.cs:32-41` | tested | Same HostingTests test as SEC-30. |
| SEC-32 | At most 2 unpaid orders per email and per client address hash. | `savia/db/migrations/V049__web_order.sql`; error 51746 | tested | `savia/db/tests/webstore/090_web_order_replay_and_unpaid_limit.sql`. |
| SEC-33 | Staff routes, sync routes, `/health/ready` and `/openapi/v1.json` have a rate limit. | `savia/src/Savia.Api/Hosting.cs` (`StaffPolicy`) | tested | `HostingTests.cs` (`Staff_sync_and_readiness_routes_are_limited_per_client_address_only_when_configured`): with `Savia:Hosting:PerMinute=3`, the fourth call to `/api/v1/me`, `/health/ready` and `/sync/v1/state` gets 429; `/health` stays 200. Azure sets 300 (`deploy/azure/main.bicep`). The counter is in memory per replica. `/openapi/v1.json` is not served in Production (SEC-48). |

## 6. CORS, bot check and payments

| ID | Rule | Where | Status | Evidence or note |
| --- | --- | --- | --- | --- |
| SEC-34 | CORS applies to public routes only: listed origins, GET and POST, three headers, never credentials. | `WebStoreHosting.cs:35-43,63-64` | tested | `WebStorePublicTests.cs` (`Cors_allows_only_listed_origins_without_credentials`); Azure probe `run-20261124.json`. |
| SEC-35 | Turnstile is checked server-side before any stock is reserved; a missing secret or no siteverify answer refuses the order. | `savia/src/Savia.Api/BotCheck.cs:20-44`; `PublicEndpoints.cs:67-68` | tested | `WebOrderVerticalSliceTests.cs` (`Failed_bot_check_reserves_nothing`); Azure probe 403 with no secret (`run-20261124.json`). |
| SEC-36 | With the secret set, a forged token is refused through siteverify. | Azure revision `ca-savia-api--0000003` | built | Operator note in `AZURE.md:183` only; no raw probe file in the repository. |
| SEC-37 | A real Turnstile token passes end to end from the live storefront. | storefront live mode plus hub | gap | Not run. |
| SEC-38 | `Savia:Public:BotCheck=disabled` can never take effect in Production. | `WebStoreHosting.cs:27-29` | tested | `HostingTests.cs` (`A_production_host_refuses_to_start_with_the_bot_check_off`); guard in `WebStoreHosting.cs` and `Program.cs`. |
| SEC-39 | Only a server-side provider answer records a payment; a browser return alone never marks an order paid. | `savia/src/Savia.Api/Payments.cs:5-7,86-91`; `PublicEndpoints.cs:112-128` | tested | `WebStorePublicTests.cs` (`A_browser_claim_alone_is_never_a_verified_payment`); `WebOrderVerticalSliceTests.cs` (`Card_return_is_not_payment_until_the_gateway_confirms_and_webhooks_must_be_signed`). |
| SEC-40 | A webhook signature is checked before the body is read; a repeat delivery records nothing new. | `Payments.cs:39-40`; `WebStore.cs:246` | tested | Fake gateway only: `WebStorePublicTests.cs` (`Fake_gateway_rejects_an_unsigned_webhook_before_reading_it`). |
| SEC-41 | The real card provider's webhook signature and return confirmation are implemented and tested. | none | gap | No card provider exists (merchant account missing). |
| SEC-42 | The store never collects or stores card numbers; card entry happens only on the provider's hosted page. | `Payments.cs` (manual provider only); storefront has no card fields | built | Card data rules are in DATA-RULES. |

## 7. Headers, errors and logs

| ID | Rule | Where | Status | Evidence or note |
| --- | --- | --- | --- | --- |
| SEC-43 | The storefront sends CSP (script by hash, `frame-ancestors 'none'`), `nosniff`, Referrer-Policy, Permissions-Policy, COOP and `X-Robots-Tag: noindex` until launch. | `build-inputs/static/_headers`; `dist/_headers:2-10` | tested | `tests/static_headers.py`. `style-src` still allows `'unsafe-inline'`. Live readback: `STOREFRONT-DEPLOY.md:4-6`. |
| SEC-44 | The hub sends CSP (`default-src 'self'`, `frame-ancestors 'none'`), `nosniff` and `Referrer-Policy: no-referrer` on every response. | `Hosting.cs:24-26,80-87` | tested | `HostingTests.cs` (`Every_response_carries_the_security_headers`). |
| SEC-45 | Public routes answer only public error codes; an internal error says "Error interno." plus a trace id. | `PublicEndpoints.cs:173-220` | tested | `WebStorePublicTests.cs` (`AssertPublicAsync` checks the public code). |
| SEC-46 | Application logs name order ids, paths and error codes, never contact details; the client address is kept only as a hash. | `savia/src/Savia.Infrastructure/SafeLog.cs`; `PublicEndpoints.cs:123,162-164`; `WebStoreHosting.cs` | partial | Every logged exception goes through `SafeLog.Describe`: code, SQL number, procedure, line and stack, never the message. `SafeLogTests.cs` (`A_sql_error_that_quotes_an_email_is_logged_without_it`) uses a real SQL duplicate key that quotes an email. No test scans every log template, and the address hash is not tested here. |
| SEC-47 | Telemetry (Application Insights) holds no personal data: client IP masking and URL contents are confirmed. | `Hosting.cs:63-74`; `main.bicep:361-362` | tested | Readback 2026-11-27 (`docs/public-software/evidence/azure-readback-20261127.md`): IP masking not disabled; over 30 days, 0 of about 160,000 rows hold a client IP or an email; URL query keys are `date`, `period`, `code` and token-call keys only. A regex check, not a full personal-data search. |
| SEC-48 | The OpenAPI document is not public in Production. | `savia/src/Savia.Api/Program.cs:22` | tested | `HostingTests.cs` (`The_openapi_document_is_served_outside_production_only`): 404 in Production, 200 in Testing. Azure answers 404 since revision `ca-savia-api--g0ae5462-1` (`savia/docs/deploy/AZURE.md`). |

## Overlap with LOGIN-RULES

Some controls appear in both documents; the launch checklist keeps one row for each pair.
SEC-29 and LOGIN-10 (public rate limit); SEC-30, SEC-31 and LOGIN-09 (sign-in limit); SEC-16 and LOGIN-19 (node credential); SEC-17 and LOGIN-25 (deploy identity).

## Open contradictions in existing documents

- Turnstile secret location: Container App secret (`AZURE.md:183`) versus Key Vault (`STOREFRONT-DEPLOY.md:39`, `RUNBOOK.md:185`).
- HSTS: added (`STOREFRONT-DEPLOY.md:4`) versus "waits for the final domain" (`STOREFRONT-DEPLOY.md:76`); `dist/_headers` has it.

# Login rules: Martha Silva web store and SAVIA hub

Version: 0.1
Date: 2026-11-27
Status: approved
Approval: Jason approved version 0.1 on 2026-11-27, including the LOGIN-07 and LOGIN-08 update of commit `c7e30bc4`.

Scope: the SAVIA hub (`savia/src`, Azure Container Apps) and the store PCs (Branch nodes).
The legacy `backend/` directory and the demo admin in `src/` are out of scope.
The demo admin sets `s.admin=true` with no credential check (`src/store-api.js:189`); it is not security and must never reach production.
"Proposal" marks a value that Jason must approve.
"Unknown, owed to Jason" marks a fact that the repository cannot show.

## 1. Kinds of user

| User | Signs in with | Where checked |
|---|---|---|
| OWNER (Jason or the store owner) | Login name and password; then a bearer token | `savia/src/Savia.Application/Auth.cs:40-56` |
| Staff roles: MANAGER, SELLER, CASHIER, INVENTORY, ACCOUNTANT | Login name and password; then a bearer token | Same as above |
| Store node (machine identity) | Header `SaviaNode <guid>.<secret>` | `savia/src/Savia.Application/Sync.cs:67-76` |
| Buyer (no account) | Order token in header `X-Order-Token`, only for order status | `savia/src/Savia.Api/PublicEndpoints.cs:103` |
| CI and deploy identity | GitHub Actions OIDC to an Azure managed identity; environment `production` | `.github/workflows/savia-azure.yml:122-125` |
| Cloudflare preview deploy | Repository secret `CLOUDFLARE_PREVIEW_API_TOKEN` | `.github/workflows/ci.yml:128,139` |
| Azure, Cloudflare and GitHub console admins | Each vendor's own sign-in | Outside the repository |

Anonymous routes: `/api/v1/auth/login`, `/api/v1/public/*`, `/health`, `/health/ready`, `/openapi/v1.json`.
The `/sync/v1/*` routes need a node credential, not a staff session.

## 2. Sessions and tokens

| Item | Value | Source |
|---|---|---|
| Staff token | 32 random bytes, base64url; SQL keeps only the SHA-256 | `Auth.cs:53`, `Auth.cs:111` |
| Staff session life | 12 hours, fixed (no sliding renewal) | `Auth.cs:36` |
| Staff token in the browser | `sessionStorage`, memory fallback | `savia/web/api.mjs:44` |
| Session check | Not revoked, not expired, staff enabled, same security version | `savia/src/Savia.Infrastructure/AuthStore.cs:58-66` |
| Node secret | SQL keeps only the SHA-256; compare in fixed time | `Sync.cs:49`, `Sync.cs:73` |
| Node secret life | No expiry; ends only on rotate or revoke | `savia/docs/sync/PROVISIONING.md` |
| Buyer order token | SHA-256 of `order-token:` plus the Idempotency-Key; SQL keeps its hash | `savia/src/Savia.Application/WebStore.cs:236-238` |
| Buyer order token life | No expiry | `savia/db/migrations/V051__web_order_reads.sql:36` |
| Buyer order token in the browser | `localStorage`, then `sessionStorage`, then memory | `src/integration-adapters.js:148-149` |

Proposal: keep the staff session at 12 hours, and add an idle limit of 30 minutes for till PCs.
Proposal: end the buyer order token 180 days after the order is delivered or cancelled.
The status answer holds no personal data, so the token risk is low.

## 3. Permission matrix

Legend: Y = allowed; - = refused (403).
Most store actions also need an assignment to that branch (`savia/src/Savia.Application/Core.cs:45-50`).

| Action | OWNER | MANAGER | SELLER | CASHIER | INVENTORY | ACCOUNTANT |
|---|---|---|---|---|---|---|
| Set prices, costs, commission rates, return window, catalog import | Y | - | - | - | - | - |
| Approve exceptions, close the till, read sales reports | Y | Y | - | - | - | - |
| Sell, open and use the till, returns, customers | Y | Y | - | Y | - | - |
| Receive goods, print tags | Y | Y | - | Y | Y | - |
| Count and move stock, quality report, consign stock to the web store | Y | Y | - | - | Y | - |
| Read own commissions and team KPI | Y | Y | Y | - | - | - |
| Read catalog and stock on the hub | Y | Y | - | - | - | Y |
| List web orders (includes buyer name, email, phone, address) | Y | Y | - | - | - | Y |
| Web order: mark paid, fulfill, cancel, refund, accept, release | Y | Y | - | - | - | - |

Sources: `savia/src/Savia.Domain/Roles.cs:9-38`; guards in `savia/src/Savia.Application/`: `Catalog.cs:59,76,107,121`, `Commissions.cs:26,33`, `Reports.cs:20,25,34,39,49`, `Returns.cs:21,58`, `Cash.cs:28,44`, `Sales.cs:23`, `Customers.cs:24,31`, `Receiving.cs:30,120`, `Tags.cs:41`, `Inventory.cs:22`, `WebStore.cs:146,155-196,205`.
SELLER cannot record a sale (`Sales.cs:23`).
No staff member holds CASHIER today (`Roles.cs` comment).
Proposal: ACCOUNTANT sees web order totals and codes, but not buyer contact fields.

## 4. Failed attempts, lockout and rate limits

| Rule | Value | Source |
|---|---|---|
| Per-account lockout | 5 failures lock the account for 15 minutes | `Auth.cs:34-35`, `AuthStore.cs:44-51` |
| Same answer for unknown, disabled or locked account | `BadCredentials` | `Auth.cs:43-45` |
| Wrong current password on change | Counts toward the lockout | `Auth.cs:82` |
| Per-IP login limit | 10 per minute on Azure; off when the setting is 0 | `savia/src/Savia.Api/Hosting.cs:43-55`, `savia/deploy/azure/main.bicep:353-358` |
| Public routes | 60 per minute per IP, then 429 | `PublicEndpoints.cs:29` |
| Bot check on new web orders | Cloudflare Turnstile, fail closed | `PublicEndpoints.cs:67` |
| Node credential failures | 401; no lockout and no rate limit | `SyncEndpoints.cs:26` |

Fixed defect (2026-11-27, reproduced first):
- Before: the end of a lock did not reset the counter, so one wrong password locked the account again.
- Before: the counter kept climbing past the SQL limit of 20 (`savia/db/migrations/V001__baseline.sql:151`); the 21st counted failure returned 409 `db.reference` instead of 401.
- Now: a failure after an ended lock counts 1, and the count stops at the lock limit (LOGIN-07, LOGIN-08).

## 5. Password rules

| Rule | Value | Source |
|---|---|---|
| Length | 10 to 200 characters | `Auth.cs:75-76` |
| New must differ from old | Yes | `Auth.cs:86-87` |
| Hash | PBKDF2-HMAC-SHA256, 600,000 iterations, fixed-time compare | `savia/src/Savia.Infrastructure/Pbkdf2PasswordHasher.cs:9,28` |
| First password | Printed once or read from Key Vault; account must change it | `docs/production-20261122/DAY-ZERO.md`; migration V064 |
| Must-change account | Reaches only change, logout and me; 403 elsewhere | `savia/src/Savia.Api/Endpoints.cs:18-19` |
| Shared pilot password | Refused unless `SAVIA_PILOT_ALLOW_SHARED=1` | `savia/src/Savia.Api/Provisioning.cs:27-31` |
| Password change effect | Ends all other sessions of that person | `AuthStore.cs:74-81` |
| Scope | One password per database (hub and each store) | `DAY-ZERO.md` |

No breached-password list and no complexity rule exist.
Proposal: keep length as the only rule, and add a check against a short list of common passwords.

## 6. MFA for consoles

| Console | MFA status |
|---|---|
| Azure (Entra) | Unknown, owed to Jason |
| Cloudflare | Unknown, owed to Jason |
| GitHub (account and `production` environment reviewers) | Unknown, owed to Jason |

The staff login has no MFA.
Proposal: require MFA on all three consoles before launch; staff MFA is not required for the pilot.

## 7. Revoking access

| What | How today | Source |
|---|---|---|
| One staff session | Logout | `Auth.cs:91-92` |
| All sessions of one person | Password change by that person | `AuthStore.cs:74-81` |
| Disable a staff member | No route or command; direct SQL only (`IsEnabled=0`) | Gap |
| Reset another person's password | `SetPasswordAsync` exists but no endpoint calls it | `Auth.cs:95-99` |
| Store node | Migrator revoke; the next call gets 401 | `savia/docs/sync/PROVISIONING.md` |
| Rotate node secret | Migrator rotate; no overlap window | Same |
| Deploy identity | Remove the federated credential in Azure | `savia/docs/deploy/AZURE.md:71-82` |
| Break-glass SQL admin | Entra group that Jason sets | `AZURE.md:71-82` |

Staff accounts exist per database.
Revoking a person means acting on the hub and on each store PC.

## 8. Controls

| ID | Control | Implementation | Status | Evidence |
|---|---|---|---|---|
| LOGIN-01 | Protected routes refuse calls without a valid session (401) | `Endpoints.cs:12-23` | tested | `savia/tests/Savia.Tests/VerticalSliceTests.cs:166`; Azure: `docs/production-20261122/public-api-azure/README.md` |
| LOGIN-02 | Same answer for unknown, disabled and locked accounts | `Auth.cs:43-45` | tested | `VerticalSliceTests.cs:166` |
| LOGIN-03 | Tokens are random and stored only as a hash | `Auth.cs:53,111` | tested | `VerticalSliceTests.cs:166` |
| LOGIN-04 | Logout ends the token | `Auth.cs:91-92` | tested | `VerticalSliceTests.cs:166` |
| LOGIN-05 | Staff session ends after 12 hours | `Auth.cs:36`, `AuthStore.cs:58-66` | built | No test |
| LOGIN-06 | 5 failures lock the account for 15 minutes | `Auth.cs:34-35`, `AuthStore.cs:44-51` | tested (5 failures lock); built (15 minutes) | `PasswordChangeTests.cs:52` asserts the lock after 5 failures, not its length |
| LOGIN-07 | Lockout counter stays inside the SQL CHECK range | `AuthStore.cs` `RecordSignInAsync`: the count stops at the lock limit | tested | `savia/tests/Savia.Tests/SignInLockoutTests.cs` (25 wrong passwords, 5 lock cycles, every answer 401); reproduced before the fix on 2026-11-27: 409 `db.reference` instead of 401 |
| LOGIN-08 | Lockout counter resets when a lock ends | `AuthStore.cs` `RecordSignInAsync`: a failure after an ended lock counts 1 | tested | `savia/tests/Savia.Tests/SignInLockoutTests.cs` (25 wrong passwords, 5 lock cycles, every answer 401) |
| LOGIN-09 | Per-IP login limit, ignores forged forwarded hops | `Hosting.cs:43-55,78` | tested | `HostingTests.cs:66,76`; not exercised on Azure |
| LOGIN-10 | Public routes limited to 60 per minute per IP | `PublicEndpoints.cs:29` | tested | Azure: `public-api-azure/README.md` |
| LOGIN-11 | Password length 10-200 and differs from old | `Auth.cs:75-76,86-87` | built | No direct test |
| LOGIN-12 | PBKDF2-SHA256, 600,000 iterations | `Pbkdf2PasswordHasher.cs:9,28` | built | No direct test |
| LOGIN-13 | First password must be changed; other routes 403 | `Endpoints.cs:18-19` | tested | `PasswordChangeTests.cs:78`; `savia/db/tests/security/310_password_change.sql` |
| LOGIN-14 | Password change ends other sessions | `AuthStore.cs:74-81` | tested | `PasswordChangeTests.cs:34` |
| LOGIN-15 | Provisioning never prints given secrets; shared password refused by default | `Provisioning.cs:27-31` | tested | `PasswordChangeTests.cs:149`; `PilotProvisioningTests.cs:19` |
| LOGIN-16 | Role guards refuse other roles (403) | `Roles.cs:9-38` and guards in section 3 | tested | `OwnerPilotTests.cs:28,32,68`; `OwnerDecisionsRound4Tests.cs:83,108,138,146`; `LocalCatalogRejectTests.cs:61-65,84-100`; `HubCatalogTests.cs:40,56` |
| LOGIN-17 | Web order actions limited to OWNER and MANAGER | `WebStore.cs:155-196` | tested in part | Refund review only: a cashier gets 403 `auth.role_required` (`savia/tests/Savia.Tests/WebOrderVerticalSlicePaymentReviewTests.cs:35-37`); other web order actions have no role-denial test |
| LOGIN-18 | ACCOUNTANT cannot read buyer contact fields | `WebStore.cs:146` allows it | gap | Decision for Jason |
| LOGIN-19 | Node credential refused when wrong, for another node or revoked; stored as hash; fixed-time compare | `Sync.cs:43-76` | tested (refusal, revoke); built (hash, fixed time) | `SyncTransportTests.cs:17`; `NodeProvisioningTests.cs`; `savia/db/tests/sync/280_provision_node.sql`; Azure: `public-api-azure/README.md` |
| LOGIN-20 | Node secret comes from config or environment, never Git | `SyncEndpoints.cs:59-64` | built | Code read |
| LOGIN-21 | Buyer order status needs its token; wrong token reads as not found | `WebStore.cs:64-70`, `V051__web_order_reads.sql:36` | tested | `WebOrderVerticalSliceTests.cs:41` |
| LOGIN-22 | Buyer order token expires | None | gap | Proposal in section 2 |
| LOGIN-23 | Staff can be disabled and passwords reset through a route or command | None | gap | Direct SQL only |
| LOGIN-24 | SQL host login is only a member of the API host role | Role `savia_api_host` in the migrations | tested | `ApiHostLoginTests.cs:16` |
| LOGIN-25 | Deploy identity uses OIDC, environment `production`, cannot read secrets | `savia-azure.yml:122-125`; `AZURE.md:71-82` | built | Reviewer setting unknown, owed to Jason |
| LOGIN-26 | MFA on Azure, Cloudflare and GitHub consoles | Outside repository | gap | Unknown, owed to Jason |
| LOGIN-27 | Expired sessions are purged | None | gap | `security.Sessions` grows without limit |

Test files without a path are in `savia/tests/Savia.Tests/`.

## 9. Decisions for Jason

1. Approve the role set: OWNER, MANAGER, SELLER, INVENTORY, ACCOUNTANT; keep or drop CASHIER.
2. Name the staff member for each role (open decision 6).
3. Decide if ACCOUNTANT may see buyer contact fields (LOGIN-18).
4. Approve the buyer token life proposal (LOGIN-22).
5. Confirm MFA on Azure, Cloudflare and GitHub, and the `production` environment reviewers (LOGIN-25, LOGIN-26).
6. Approve the idle limit proposal for till PCs.

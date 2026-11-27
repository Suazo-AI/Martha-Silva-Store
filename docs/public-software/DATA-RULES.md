# Data rules: Martha Silva web store and SAVIA hub

Version: 0.1
Date: 2026-11-27
Status: draft, awaiting Jason's approval
Approval: pending

Scope: personal data in the SAVIA hub, the store PCs, the storefront browser code, telemetry, logs and backups.
The legacy `backend/` directory and `docs/DATABASE.md` describe an older system and are out of scope.
"Proposal" marks a value that Jason must approve.
"For lawyer review" marks a legal reading that a Nicaraguan lawyer must confirm.
Today no code deletes or blanks personal data anywhere; every "deletion method" below is a proposal unless it says "built".

## 1. Inventory of personal data

| Field | Table or location | Why needed | Who can read it | Retention | Deletion method |
|---|---|---|---|---|---|
| Buyer name, phone, email, city, street address, delivery notes | `webstore.OrderAddresses` (`savia/db/migrations/V001__baseline.sql:1219`) | Deliver and contact about the order | OWNER, MANAGER, ACCOUNTANT (web order list) | Actual: forever. Proposal: see section 4 | None today. Proposal: blank the fields by job |
| Order code, totals, lines, expiry | `webstore.Orders` (`V049`) | Sell, reserve stock, account | Same as above; buyer with token sees code, status, total, lines | Actual: forever | Keep for tax records; holds no contact fields |
| Order token hash | `webstore.Orders.AccessTokenHash` (`V049:10-15`) | Buyer checks order status | Nobody reads it; compare only | Actual: forever, no expiry | Proposal: blank 180 days after the order ends |
| ClientHash (SHA-256 of `client:` plus IP, no salt) | `webstore.Orders.ClientHash` (`savia/src/Savia.Api/PublicEndpoints.cs:163-164`) | Limit unpaid orders per client | Hub database only | Actual: forever | Proposal: blank after 30 days |
| Manual bank reference | `webstore.Payments.ExternalPaymentId` (`V001:1309`) | Match a bank transfer to an order | OWNER, MANAGER | Actual: forever | Keep for tax period |
| Refund reference | `webstore.PaymentReviews.RefundReference` (`V057`) | Prove a refund | OWNER, MANAGER | Actual: forever | Keep for tax period |
| Store customer name, email, phone, ID document number | `crm.Customers` (`V001:226`, `V053:17-19`) | Store credit, returns, receipts | CASHIER, MANAGER, OWNER at the branch | Actual: forever | None; no update or delete route exists |
| Customer name on a sale | `sales` tables | Receipt and returns | Till roles at the branch | Actual: forever | Keep for tax period |
| Supplier email, phone | `sourcing.Suppliers` | Buy stock | Not verified | Actual: forever | Proposal: delete when the supplier ends |
| Staff login name, display name, password hash, failed sign-ins, lock time | `security.Staff` (`V001:134`) | Sign-in | No app route lists staff passwords or lock data; database admins can read the table | Actual: forever | Proposal: disable on exit; blank name after tax period |
| Staff sessions (token hash, expiry) | `security.Sessions` (`V001:189`) | Sign-in | Nobody reads it; compare only | Actual: forever, never purged | Proposal: delete 30 days after expiry |
| Seller commission rates, staff names on sales and seller list | `sales.SellerRates`, `sales` tables | Pay commissions | OWNER sets rates; SELLER, CASHIER, MANAGER, OWNER list sellers (`Commissions.cs:19`); a seller reads own commissions | Actual: forever | Keep for payroll and tax period |
| Branch assignment history | `security.BranchAssignmentAudit` | Audit | Database admins | Actual: forever | Keep |
| Change history before and after values | `audit.EntityChanges` (`V001:1723`) | Audit | Database admins | Empty today; no procedure writes it | Not applicable |
| Change tracking rows | SQL change tracking (`V008:10`) | Sync between hub and stores | Sync process | Actual: 30 days | Built: SQL removes them |
| Sync payload for a new web order | `sync.Outbox` | Tell the store about an order | Sync process | Actual: kept in the outbox | Payload has no address or phone (`V049` comment) |
| Staff bearer token | Browser `sessionStorage`, memory fallback (`savia/web/api.mjs:44`) | Keep staff signed in | That browser tab | Ends with the tab or 12 hours | Built: logout or tab close |
| Checkout form (name, email, phone, address, city, department) | Browser `sessionStorage` (`src/app.js:257-258`) | Keep the form across pages | That browser tab | Until submit or tab close | Built: cleared at `src/app.js:541,924` |
| Pending order (Idempotency-Key plus full contact) | Browser `localStorage` key `martha-live-v1:pending` (`src/integration-adapters.js:238`) | Retry the same order safely | That browser | Cleared on success (`:243-244`); kept forever after a failure | Gap; proposal in section 4 |
| Buyer order token | Browser `localStorage`, then `sessionStorage`, then memory (`src/integration-adapters.js:148-149`) | Show order status later | That browser | Actual: forever | None |
| Favorites, newsletter dismissed | Browser `localStorage` | Convenience | That browser | Forever | User clears the browser |
| Buyer IP address | Sent to Cloudflare Turnstile siteverify (`savia/src/Savia.Api/BotCheck.cs:30`) | Bot check | Cloudflare | Cloudflare's terms | Not stored by SAVIA |
| Request data, IP addresses, errors | Azure Application Insights and Log Analytics (`savia/deploy/azure/main.bicep:129`) | Find faults | Azure console admins | Actual: 30 days | Built: Azure removes them |

Customers created at a store sync by the owner rule (`V053:69`).
The exact set of databases that receive customer rows needs confirmation.

## 2. Where the data lives

| Place | What | Facts | Source |
|---|---|---|---|
| Azure SQL, region `mexicocentral` | All hub tables | Entra-only sign-in; managed identities | `savia/deploy/azure/main.bicep:12`; `savia/docs/deploy/AZURE.md:71-82` |
| Azure SQL backups | Point-in-time restore | 7 days (`main.bicep:41`); template default is Geo (`main.bicep:49`), but `AZURE.md:100` says zone-redundant because geo is refused in that region; deployed value not verifiable from the repository | `AZURE.md:97-104` |
| Pre-migration database copies | Full copy before each migration | Newest 1 kept | `savia/deploy/migrate.ps1:28` |
| Store PC SQL Server | Store tables, customers, sales | Runs under Jason's Windows account | `docs/production-20261122/STORE-PC-20261124.md:63,68` |
| Store PC backups | Daily `.bak` | 14 days kept; on the same PC disk only; no off-PC copy | `savia/deploy/store-pc/backup-store.ps1:20` |
| Buyer and staff browsers | Section 1 browser rows | Each device holds its own copy | Section 1 |
| Telemetry and logs | Application Insights, Log Analytics | 30 days; managed identity; local keys off | `main.bicep:129`; `savia/src/Savia.Api/Hosting.cs:63-74`; `AZURE.md:118` |
| Cloudflare | Buyer IP for the bot check; static storefront | Vendor holds request logs under its terms | `BotCheck.cs:30` |

The hub is outside Nicaragua.
Ley 787 rules on transfer abroad are not reviewed (for lawyer review).

## 3. Card data

Card data is never stored, sent or read by this system today.
A search on 2026-11-27 of `savia/src`, `savia/web`, `src` and `build-inputs/static` found no card field (English and Spanish terms, all file types).
Payment today is a manual bank transfer with a reference; the only payment provider is `ManualPaymentProvider` (`savia/src/Savia.Api/WebStoreHosting.cs:30`).
Cards are required for production, and the provider is still pending (`AGENTS.md`).
Proposal: the card provider must use its own hosted page, so card numbers never reach SAVIA or the storefront.
Any change to this rule needs a new version of this document.

## 4. Retention and deletion (all proposals)

| Data | Proposal |
|---|---|
| Unpaid web order that expired (30-minute hold, `V049:113`; sweep in `savia/src/Savia.Api/WebStoreHosting.cs:74-165`) | Blank the contact fields in `webstore.OrderAddresses` 30 days after expiry; keep code, lines and totals |
| Cancelled web order with no payment | Same as an expired order |
| Paid and delivered web order, refunds, bank references, sales | Keep for the tax-law period; the period is unknown and owed to a lawyer; then blank the contact fields |
| ClientHash | Blank 30 days after the order is created |
| Buyer order token hash | Blank 180 days after the order ends |
| Store customer | Keep while the customer has credit or bought in the last 2 years; then blank name, email, phone and ID document |
| Staff sessions | Delete 30 days after expiry |
| Former staff | Disable on the last day; keep name on sales for the tax-law period |
| Browser `pending` key | Store only the Idempotency-Key and order lines, not contact fields; clear it after 24 hours |
| Store PC backups | Keep 14 days; add an encrypted off-PC copy |

A deletion job must run on the hub and on each store PC.
Blanked rows still exist in backups until the backups age out (7 days on Azure, 14 days on store PCs).

## 5. Buyer rights under Ley 787 (for lawyer review)

| Right | Rule | Source | Status in system |
|---|---|---|---|
| Notice of controller, purpose and data collected | Ley 787 Art. 7 | Primary: official text, La Gaceta N° 61, 29 Mar 2012, http://legislacion.asamblea.gob.ni/normaweb.nsf/9e314815a08d4a6206257265005d21f9/e5d37e9b4827fc06062579ed0076ce1d (`docs/production-20261122/LEGAL-RESEARCH-20261123.md:43`) | Notice exists (`build-inputs/static/ayuda.html:17`, section `privacidad`); it names no recipients (Cloudflare, Azure), no hub country and no retention time |
| Access to own data | Ley 787 Art. 7, 17, 19; answer within 10 business days | Secondary: `docs/production-20261122/LEGAL-SOURCES.md:31` | Notice offers requests by WhatsApp or phone; no route, manual SQL only |
| Correction | Same articles; correct within 5 business days | Secondary: `LEGAL-SOURCES.md:31` | No route to correct a web order or customer |
| Deletion | Same articles | Secondary: `LEGAL-SOURCES.md:31` | No route and no job |
| Consent for news and marketing | Ley 787 Art. 6, 25, 26 | Secondary: `LEGAL-SOURCES.md` | Newsletter consent handling not reviewed here |
| Register the data file, including retention time | Ley 787 Art. 22 (a)-(h) | Primary: same official text; read in `LEGAL-RESEARCH-20261123.md` | Registration status unknown; the regulator inside MHCP (Art. 28) may not operate |

The deadlines come from a secondary source and must be checked against the official text.
Ley 842 (consumer protection) applies to sales terms; it is covered in `LEGAL-SOURCES.md`, not here.
The store's legal name and RUC are missing; the notice needs both.

Proposal for the manual process until routes exist:
1. The buyer asks by WhatsApp or phone, as the notice says, and gives the order code.
2. The OWNER confirms identity by the email or phone on the order.
3. The OWNER answers access within 10 business days and correction within 5.
4. A deletion request blanks contact fields unless the tax-law period still applies.
5. The OWNER records date, request and answer, without copying the personal data.

## 6. Controls

| ID | Control | Implementation | Status | Evidence |
|---|---|---|---|---|
| DATA-01 | Card data is never collected or stored | No card fields in `savia/src` or `src/`; manual provider only (`WebStoreHosting.cs:30`) | built | Code search on 2026-11-27; no test |
| DATA-02 | Order status answer holds no personal data (test checks the street address is absent) | `savia/src/Savia.Application/WebStore.cs:64-70`; `V051__web_order_reads.sql:36` | tested | `savia/tests/Savia.Tests/WebOrderVerticalSliceTests.cs:41` |
| DATA-03 | Buyer IP is not stored; only an unsalted hash | `PublicEndpoints.cs:163-164` | built | Hash is still personal data (pseudonymous) |
| DATA-04 | Contact fields have length limits | `WebStore.cs:73-91` | built | No direct test |
| DATA-05 | Sync payload for a web order excludes address and phone | `V049` outbox payload | built | Migration comment; no test |
| DATA-06 | Staff tokens, node secrets and order tokens stored only as hashes | `Auth.cs:111`; `Sync.cs:49`; `WebStore.cs:236-238` | tested (staff token); built (node secret, order token) | `savia/tests/Savia.Tests/VerticalSliceTests.cs:166` |
| DATA-07 | Telemetry kept 30 days; no local keys | `main.bicep:129`; `Hosting.cs:63-74` | built | IP masking in Application Insights not verified |
| DATA-08 | Azure SQL backups kept 7 days | `main.bicep:41` | built | `AZURE.md:97-104` |
| DATA-09 | Checkout form cleared from the browser after submit | `src/app.js:541,924` | built | No browser test cited |
| DATA-10 | Browser `pending` key holds no contact fields and expires | `src/integration-adapters.js:238` stores them | gap | Proposal in section 4 |
| DATA-11 | Expired and cancelled unpaid orders lose contact fields | None | gap | Sweep keeps them forever |
| DATA-12 | Delivered orders lose contact fields after the tax-law period | None | gap | Period unknown |
| DATA-13 | Expired sessions are deleted | None | gap | `security.Sessions` |
| DATA-14 | ClientHash and order token hash are blanked on schedule | None | gap | Proposal in section 4 |
| DATA-15 | Buyer access, correction and deletion can be served | None | gap | Manual process proposal in section 5 |
| DATA-16 | Store customer correction and deletion | `CustomersEndpoints` has GET and POST only | gap | No route |
| DATA-17 | ACCOUNTANT cannot read buyer contact fields | `WebStore.cs:146` allows it | gap | Same as LOGIN-18 |
| DATA-18 | Store PC backups have an encrypted off-PC copy | `backup-store.ps1:20` keeps local only | gap | Decision for Jason |
| DATA-19 | Store PC runs under a service account, not Jason's account | None | gap | `STORE-PC-20261124.md:63,68` |
| DATA-20 | Privacy notice names recipients (Cloudflare, Azure), the hub country and retention | `build-inputs/static/ayuda.html:17` lacks them | gap | For lawyer review |
| DATA-21 | Transfer of data to Mexico reviewed under Ley 787 | None | gap | For lawyer review |
| DATA-22 | Data file registered under Ley 787 Art. 22 | None | gap | Unknown, owed to Jason |

## 7. Decisions for Jason

1. Approve or change each retention value in section 4.
2. Ask a lawyer for the tax-law retention period, the transfer rule for Mexico and the Art. 22 registration.
3. Supply the legal name and RUC for the privacy notice.
4. Decide where store PC backups go off the PC, and who holds the key.
5. Approve the manual rights process in section 5 until routes exist.
6. Decide if ACCOUNTANT keeps access to buyer contact fields.
7. Choose the card provider and confirm the hosted-page rule in section 3.

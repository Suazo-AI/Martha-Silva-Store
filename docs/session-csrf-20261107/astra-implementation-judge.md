# Session-bound CSRF implementation judgment

**REVISE — one P2 defect in prepared N8 acceptance coverage.** The provider and combined client increment are supported within their stated scope. No product-code defect was found. Production remains **NO-GO**. This advisory judgment does not replace primary acceptance.

Reviewed frozen HEAD: `6708709b4bda8a2638acb995d9ae1b91fc60d257`.
Managed checkout: `C:/Users/Jason/.t3/worktrees/github/t3-41220236`.
Actual exposed identity: SUAZO-PC / T3 Code / Codex / `gpt-6-astra/xhigh`; requested and exposed settings agree. Internal reasoning/billing telemetry is unavailable.
Agent-awareness ran at entry and before writing. Windows process inspection failed; liveness remains unknown. Assigned report ownership and isolated checkout were retained.
The repository started clean. No subagents were used.

**P2 — successful N8 writes do not prove preservation of other rows.**

Locations: `backend/tests/Martha.Store.Api.Tests/InternalAcceptanceHttpSqlTests.cs:423–431,458–463`.

Sale verification checks selected new-row fields, table-count increments and target `OnHand - 1`, then excludes all five changed tables from equality. Directory similarly excludes all Items and Operations. An unrelated stock balance, existing sale, item or operation could change while these assertions still pass. The sale also does not directly prove unchanged Reserved or Available minus one.

This misses the accepted preimplementation requirement that all other rows remain unchanged. The worker accurately disclosed this limitation; it is an incomplete test oracle, not demonstrated production corruption. SQL execution alone cannot close it.

Owner: primary, through a bounded test correction. Preserve independent full-table rejection fingerprints. For successful writes, compare pre-existing rows by identity, exclude only identified inserted rows, and allow only the intended stock-row field changes. Assert unchanged Reserved and Available minus one. Preserve original keys/bodies and exact replay equality.

Closure: inspect those assertions against the frozen requirement, then execute corrected N8 only under separately authorized SQL scope. I did not patch tests because this assignment permits only this report. No extra control is requested merely for review ritual.

**Backend source and historical framework proof**

`InternalSecurity.cs:51–62` calls `Replace` after `AddAntiforgery`; repository registration search found no later competing provider. The new provider at `InternalSessionAntiforgeryAdditionalDataProvider.cs:9–27` is stateless. It requires one authoritative authenticated identity and one session claim across the principal, canonical nonempty GUID-D, and ordinal additional-data equality. Missing, malformed, duplicate and distributed claims fail closed. Anonymous principals use empty data; authenticated legacy empty data fails. Generation has a fixed exception without claim values; no logging was added.

Authority remains persisted server state: `InternalCookieEvents.ValidatePrincipal` rebuilds the principal after `InternalSecurityService.ValidateSession`; `InternalSecurityRules.Principal:25–31` emits the canonical session claim. Login creates a different session and revokes predecessors. The provider is not a replacement for authentication or transactional revalidation.

`InternalSessionAntiforgeryTests.cs:45–61,134–150` uses real TestServer antiforgery and ephemeral DataProtection. Only authentication selection is synthetic. The fixture's claims agree with the production principal shape. Same account/non-session claims and the retained cookie isolate S1→S2. Both the common filter and actual Directory validator reject T1 before handlers; S1 admission and three S2 admissions, including repeated and separately issued tokens, prevent vacuous rejection.

Invalid generation/validation, malformed and mixed principals, cross-user, transport/header/cookie and legacy controls are present. Existing `InternalSecurityTests.cs:196–224` exercises anonymous login admission to `401 invalid_credentials`. Directory's anonymous-first mixed principal correctly reaches its existing 401 guard; provider failure is asserted separately. HTTP is exercised through the common filter; Directory's route-group HTTPS guard is source-inspected only.

Mutation responses/headers and formatted logs are scanned for fixture secrets. Coverage caveat: the separately generated legacy token at test lines 117–120 is not added to the receiving fixture's secret list. This does not establish a leak; the diagnostic assertion is narrower than an exhaustive token audit.

Historical evidence records red **2 failures**, initial green **54/55**, then corrected/final **55/55**. Primary's receipt records parsing original red/final TRX with matching hashes. I inspected public phase/case evidence and independently verified its source bindings; I did not reopen private backend TRX or rerun/build a server. **637 is discovery only.**

**N8 preparation otherwise preserves the controls**

The backend diff adds 76 N8 lines without deleting old controls. `InternalAcceptanceHttpSqlTests.cs:393–466` uses real HttpSession login, preserves the antiforgery cookie, asserts changed persisted session, old-session revocation and current security version/expiry. Cashier identity is also checked through /me.

Rejected writes require **400/csrf_invalid** or Directory **400/invalid_csrf**, distinguishing CSRF from authentication/role failure. Complete fingerprints immediately bracket each rejected write after login. The unchanged ADO.NET oracle at `:695–719` enumerates and hashes all 20 tables, including Staff, Sessions and Operations; it does not use the 17-table business projection. Fresh tokens reuse the exact body/key and explicit replay checks full fingerprint equality. Prepared/compiled evidence does **not** establish SQL behavior.

**Combined client proof accepted within mock scope**

`session-transition.test.mjs:32–96,99–141` mounts the real commerce, supply and review modules with real staff/auth clients. All three whitespace-sensitive raw references share sessionStorage. Same actor/version survives logout/login/remount; original keys/bodies remain intact and no automatic business POST occurs.

Separate gates hold HTTP responses, already validated client results, and old CSRF renewals until after S2/remount. Outcome assertions prove each release was observed. The event-loop checkpoint drains these promise continuations; assertions do not rely solely on a fixed sleep or snapshot before delivery. Current DOM, verified session and raw storage remain unchanged. Failed renewal preserves all references, and explicit continuation uses the original key/body and a fresh S2 token. Double-click continuation yields one POST. No session IDs were added to pending identity.

The fixture deliberately returns recovery 404, including after simulated commits. That isolates pending-state behavior; its map and cookie/token markers are not a coherent persistence/server oracle. Found-operation recovery, real cookies, cross-tab behavior and SQL idempotency are outside this proof.

I independently read all eight referenced private control logs: hashes/counts match, **14 expected assertion failures**, and restored source hashes plus all eight test copies match their bindings. Historical process exits are recorded as 1. Controls detect removed auth/mount guards, automatic resend, reference/key rewriting and omitted renewal. They were not rerun.

**Fresh verification, bindings and limits**

Executed once:

```powershell
$env:NODE_PATH='C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules'
node --test dev/savia-staff-ui/session-transition.test.mjs
```

**13/13 PASS**, exit **0**, **4150.5043 ms**, zero failures/cancellations/skips. Cached jsdom only; no downloads.

All **10/10 CANDIDATE LF hashes equal exact HEAD blobs**. All blobs are LF; normalization was CRLF→LF only. Five working RAW hashes differ from the canonical receipt solely through CRLF conversion. Independently matched worker **4 changed / 112 compiled-export / 17 unchanged-client** bindings and client **5 unchanged inputs / 5 artifacts**. Product inputs are unchanged from `030b64f`.

Auxiliary log parsing encountered a Unicode regex transport error and UTF-16 decoding error; ASCII escapes and BOM-aware decoding resolved them. A guessed helper filename was absent; the explicit static import located InternalJudgeTests. No access denial remains.

NOT RUN: new backend/server build or repro, SQL, containers, full suites, browser, network/CI, publication, deployment or account/security mutations. Parent full-suite session 84742 was not queried and is not completed evidence here. Exact-HEAD CI remains unconfirmed.

Only changed path: `docs/session-csrf-20261107/astra-implementation-judge.md`. Report RAW/LF SHA256 accompanies the handoff.
Next: primary closes P2 before accepting N8 preparation; SQL and exact-SHA CI remain separate gates.
Lesson applied: whole-table exclusions cannot prove exact permitted row deltas.

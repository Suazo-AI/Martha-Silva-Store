# Internal staff security — implementation, not production acceptance

One business per isolated SAVIA instance. Staff is not a public customer login or a tenant model.

## Integration contract

- Register `services.AddInternalSecurity()` and the scoped `InternalDbContext` only when the separately guarded internal feature is enabled.
- Place the host's error handler before `UseAuthentication()` then `UseAuthorization()`. Map `MapInternalSecurity()` only inside the feature gate.
- Apply `.RequireInternalCsrf()` to every unsafe internal business route/group. The helper validates an ASP.NET antiforgery header+cookie pair, including anonymous login. It requires HTTPS on unsafe methods. The host must require HTTPS and `Cache-Control: no-store` across all internal pages/API, not just this module.
- Policies: `internal.owner`, `internal.manage`, `internal.sell`, `internal.inventory`, `internal.read`. Authentication scheme `InternalSavia`. Roles are exactly `Owner`, `Manager`, `Cashier`, `Inventory`.
- The business command runner must call `InternalSecurityService.ValidateSession(principal, ct)` **inside its transaction** and enforce the operation's current role policy before effects/replay. Middleware validation alone cannot fence concurrent staff changes.
- Use per-instance protected, durable ASP.NET Data Protection keys for a real deployment. Review key ACLs/encryption, unique app identity, HTTPS termination and explicitly trusted proxies; never accept arbitrary forwarded headers. No deployment/key store/account is provisioned here.

## HTTP flow

1. `GET /internal/api/security/csrf` over HTTPS returns `{ token, headerName }` and a Secure/HttpOnly/SameSite=Strict host-only cookie. Never put the token in a URL or persistent browser storage.
2. `POST .../login` with JSON `{ loginName, password }` and `X-CSRF-TOKEN`. Neither role nor actor is accepted. Login failures are generic. Successful login returns safe staff fields and absolute expiry; it invalidates previous sessions for the staff member.
3. Fetch `/csrf` **again after login** because antiforgery tokens bind to the authenticated identity. Read `/me` as needed. Use that header for every mutation.
4. `POST .../logout` revokes the persisted session before deleting the browser cookie. Fetch a fresh anonymous CSRF token before another login.
5. Owner-only `GET/POST .../staff`, `PUT .../staff/{id}`, and `POST .../staff/{id}/password` manage staff. Update/reset require the current `version` from safe staff responses. Listing is bounded to 200 entries with `truncated`; this is not an unbounded directory/export.

Auth and antiforgery cookies are `__Host-` prefixed, Path=/, no Domain, Secure, HttpOnly, SameSite=Strict. Session tickets have absolute 8-hour expiry, no sliding renewal, and are validated against persisted session + enabled staff + exact role + security version on **every request**. A missing/unavailable database never grants a mock identity or falls back to client state.

Five failed password verifications lock the persisted account for 15 minutes. Admission is additionally bounded per process: ten attempts/IP/minute, 120 total/minute, four in flight, at most 4,096 address buckets. The proxy configuration affects the observed transport address. This is not a distributed rate-limit guarantee; deployment needs a reviewed edge/shared limit if horizontally scaled.

Credential mutations use their own serializable transactions rather than business idempotency records: passwords, hashes and secret-derived fingerprints are never written to operation replay payloads. Creation has a unique normalized login; updates/reset use optimistic `version` checks. Uncertain writes must be reconciled via safe staff state; do not blindly retry credential creation/reset or infer success from a timeout. All staff changes rotate the security version and revoke sessions. Disabling/demoting the last enabled owner is rejected atomically. Database concurrency/transaction failures must remain unavailable/unknown, not automatic provider fallback.

## First owner — code only, never automatically run

`InternalOwnerBootstrap.CreateInitialOwner(loginName, displayName, password, ct)` is an explicit offline service, not an endpoint, startup hook or seed. It refuses bootstrap once **any** staff row exists, even if all identities are disabled. It never overwrites existing users or acts as a recovery bypass. There is no default login/password.

An operator must separately authorize and implement/review a private maintenance invocation with confirmed isolated database, no shell history/logged password, and explicit secret handling. None has been invoked during implementation. Account recovery, MFA, security-event retention and production operational acceptance remain follow-on release/security gates, not claims of this lot.

## Verification and limits

`InternalSecurityTests` use pure state tests, EF model metadata, ASP.NET policies and real TestServer antiforgery/cookie handling without opening SQL. They do not demonstrate database transactions, successful persisted login, browser interoperability or production readiness.

`InternalSecuritySqlTests` are opt-in under `MARTHA_INTERNAL_TEST_SQL_CONNECTION` and otherwise explicitly skipped. They create/drop a generated `MarthaInternal_Test_*` database on a separately authorized disposable SQL Server, use synthetic fixtures and never invoke bootstrap. They exercise the current relational model with `EnsureCreated`, not release migrations. Do not set this variable or run a SQL container without the required authorization/licensing review. No real PII or operator credentials belong in tests or source control.

Framework reference: [ASP.NET Core cookie authentication](https://learn.microsoft.com/aspnet/core/security/authentication/cookie?view=aspnetcore-10.0), [ASP.NET Core antiforgery](https://learn.microsoft.com/aspnet/core/security/anti-request-forgery?view=aspnetcore-10.0). The pinned SDK/framework is the executable compatibility check; no new packages were introduced.

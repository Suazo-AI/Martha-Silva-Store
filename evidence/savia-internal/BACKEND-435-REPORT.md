# Independent judge — final source candidate

## Result

**Source verification PASS; end-to-end operational SAVIA is not accepted.**

Exact tested HEAD: `bab81bf3e8553ab771e1cc6a46c09f5d6831fb2b` = integrated `1a3b19e` plus judge `b226eff8` and `bab81bf3`.

- Locked restore: PASS (SDK 10.0.402, runtime 10.0.13).
- Final Release build: **0 warnings / 0 errors**. Initial xUnit2031 style warning was corrected without changing the assertion; both logs retained.
- Complete .NET suite: **435 PASS / 56 SQL SKIPPED / 0 FAIL**, 491 total.
- Independent judge class: **72 PASS / 2 SQL SKIPPED**.
- UI: three JS syntax checks, nine transport-double auth tests and five jsdom tests PASS. Existing jsdom 26.1.0 reused; no installation/version change. These are not browser or SQL tests.

`summary.json` contains exact class counts, skip reasons and evidence hashes. Baseline evidence remains separate: 1171c6d = 45 PASS / 21 SQL SKIPPED; first integrated b1eb4be = 318 PASS / 48 SQL SKIPPED. Counts are not additive.

## Independently established

- Real Program private APIs default off, only explicit Development gate opens them; enabling internal mode does not enable synthetic V1/V2.
- Every protected private API route/verb rejects no identity and tampered cookie/forged actor-role headers before business storage. Only login/CSRF API endpoints are anonymous.
- HTTPS including case-insensitive paths, no-store and security headers; real antiforgery token issuance and missing/invalid token rejection without DB configuration.
- UI login/JS/CSS resources return 200 without prefilled identities; private app/client sources return 401. Canonical routes redirect correctly without trailing-slash endpoint ambiguity.
- Fixed command-scope/role matrix; SQL connection test-prefix/MARS guards; binary unique actor/scope/key operation identity; seven audit types reject tracked EF modification/deletion before a SQL connection opens.
- Offline internal migration/model/source checks passed in the full suite. This does not prove migration application.
- All prior V1/V2 implementation, tests and existing migrations remain unchanged. Only prior files modified: InternalDbContext, additive Program wiring, API csproj six embedded UI resources. SDK/package locks and all package versions unchanged; test project unchanged. Diff whitespace checks pass.

## Findings closed before final verification

1. Eager cookie-event and public-login service dependencies could resolve missing DB options before anonymous/CSRF decisions. Security builder deferred resolution; real Program checks passed.
2. Duplicate slash/non-slash UI endpoints would be ambiguous. Root replaced duplicate mappings with canonicalization middleware (539a4d4); independent UI requests passed.
3. Independent judge's xUnit assertion-style warning was corrected in bab81bf with an equivalent predicate overload; no test expectation was relaxed.

## Gates still open

| Action / target | Reason | State |
| --- | --- | --- |
| SQL persistence/concurrency/session tests on an authorized disposable SQL Server | No authorized configured runtime; all 56 SQL cases explicitly skipped (21 synthetic, 35 internal) | Pending; not attempted |
| Actual HTTP login/cookie issuance/logout/role-change/disable with SQL | Two independent opt-in tests are now encoded; require both authorization flags plus private endpoint | Pending; skipped |
| Apply internal migration / inspect live schema | Offline model/script checks are not execution | Pending; not attempted |
| Database-enforced append-only audit | Current migration has no custom SQL/immutability triggers; verified guard covers tracked EF writes, not raw SQL/ExecuteUpdate | Unproven |
| Complete staff workflows | Hosted UI is a read-only customer/item slice; sale/purchase/receipt actions are explicitly unavailable, and directory first-page limitation remains | Not complete |
| Browser/accessibility/mobile/business acceptance | No real browser or operational business session was exercised | Pending |
| Deployment / production accounts / bootstrap | Not authorized by this implementation lot | Not attempted |

No SQL server/container, EULA acceptance, seed/bootstrap, production account, paid resource, push or deployment occurred. No secrets/appsettings/.env files were introduced. No test was rewritten to manufacture a pass; only new judge-owned tests were added and a lint-equivalent assertion form corrected.

## Integrated identity verification

Root integrated commit `e22437b832789bc67b65363f2b981545838eb6be` has identical Git contents for `backend/`, `dev/` and `global.json` to the exact judge-tested HEAD above. No tracked uncommitted integration changes existed at verification. The passing source evidence therefore applies by checked content equality; no runtime/SQL/browser gate changes.

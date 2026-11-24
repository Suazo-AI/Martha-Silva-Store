# Evidence: public web order path, hub side (2026-11-22)

Task `savia-order-path-backend-20261122`, checklist rows W1, W2, W3 and W5, plus the W4 seam.
Base commit: `5ae5133f`. Design and settings: [`../../webstore/ORDER-PATH.md`](../../webstore/ORDER-PATH.md).
Delivered as uncommitted edits plus a patch; nothing was committed, pushed or deployed.

## Result

| Check | Command | Exit | Count | File |
|---|---|---|---|---|
| T-SQL red | `python tools/db/saviadb.py test` with V047–V051 moved aside | 1 | 10 new tests fail, 6 earlier tests pass | `tsql-red.txt` |
| T-SQL green | `python tools/db/saviadb.py test` | 0 | 161 pass | `tsql-green.txt` |
| .NET red | `dotnet test --filter PaymentProviderContract\|PublicAbuse\|WebOrderVerticalSlice`, routes unwired | 1 | 10 fail, 12 pass of 22 | `dotnet-red.txt` |
| Sweep red | `dotnet test --filter FullyQualifiedName~Sweep_skips`, before per-order isolation | 1 | 1 fail | `sweep-red.txt` |
| .NET green | same filter as .NET red | 0 | 23 pass | `dotnet-green.txt` |
| Web red | `node --test "savia/web/tests/*.test.mjs"` before the screen existed | 1 | `ERR_MODULE_NOT_FOUND` | `web-red.txt` |
| Web green | `node --test "savia/web/tests/*.test.mjs"` from the repo root | 0 | 146 pass | `web-green.txt` |
| Full check | `python tools/check.py --isolated` | 0 | T-SQL 161, .NET 223, API-host pass 18, rules 9 of 9 | `check-isolated.txt` |
| Web orders as the API host login | `SAVIA_TEST_SQL_LOGIN=api_host dotnet test --filter FullyQualifiedName~Savia.Tests.WebOrderVerticalSlice` | 0 | 8 pass | `apihost-green.txt` |

The API-host pass in `check.py` filters on `Savia.Tests.VerticalSlice`, which does not match `WebOrderVerticalSliceTests`.
The last row runs those tests as the login that holds only role `savia_api_host`, so the role is proven enough for the web-order path.

`python tools/rules.py`: 9 of 9 pass after `--accept-migrations` for V047–V051 only.

## What was built

- Migrations V047–V051: the web location per store, consignment and release with apply-once tables, the order procedure with the no-oversell lock, expiry, verified payment, `payment_review`, and the JSON reads.
- T-SQL tests `db/tests/webstore/070` to `160`.
- Api: public routes (hub only), staff routes, CORS allow-list, 16 KB cap, strict JSON, per-address rate limit, `IBotCheck` (Turnstile and disabled), `IPaymentProvider` with the manual provider, and the expiry sweep.
- Tests: `FakeHostedGateway` (test project only), provider contract, abuse controls and the vertical slice.
- Web: the "Pedidos web" staff screen, hub only, with its logic and API calls.

## Defects found and fixed

1. A null client hash went to SQL as `nvarchar`, so order creation failed with SQL error 257 (500 `internal`).
   The vertical slice found it; a typed `varbinary(32)` parameter fixed it.
   The failing output was not saved; this note is the only record.
2. One due order the sweep could not settle (a captured amount that differs from the order, SQL 51706) aborted the whole pass.
   Every later pass stopped at the same order, so no order behind it expired and its stock stayed reserved.
   Review found it; a new test reproduced it (`sweep-red.txt`).
   Each order is now settled on its own, and the consignment step no longer blocks expiry.
   Such an order stays `reserved` with only a log line, so staff see it as unpaid and could cancel an order whose card was charged.

## Limits

- The .NET and web tests were written after the code.
  Their red state comes from unwiring the routes; 12 of the first 22 tests have no red state, nor do the two web mount tests.
- The staff screen is tested with a fake DOM: mount, list, buttons per status and the empty-reference stop.
  No real browser ran it, and the confirmation dialog was not exercised.
- The test server has no client address, so the per-address limits and the proxy setting are not tested against real addresses.
- A chunked body over 16 KB (no `Content-Length`) is not tested; only a body with a length is.
- Not run: the browser tests of spec 4.5 (they need the storefront in `src/`, outside this task), real Turnstile, and a real card provider.

## Edits outside the owned paths

- `db/tests/security/110_*.sql` and five `db/tests/sync/*.sql`: the expected count of sync-tracked tables went from 18 to 20.
- `tests/Savia.Tests/ApiHostLoginTests.cs`: the same count, 18 to 20.
- `src/Savia.Domain/Errors.cs` and `src/Savia.Infrastructure/ServiceRegistration.cs`: minimal wiring for the new errors and store.
- `web/tests/roles.test.mjs` and `web/tests/navigation-ux.test.mjs`: the new menu row, a product decision.

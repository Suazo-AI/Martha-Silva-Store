# Return lifecycle correction

Local result: **117/117 web tests and 22/22 mocked Chrome checks pass**. Independent acceptance remains pending.

Base: `ba8ff2ba10935e99fc268ebbe5eae130f72c1cca`. Exact source bindings and commands are in [RESULT.json](RESULT.json).

## Corrections

The previous Astra review returned `REVISE`. Context spreading lost inherited session and role properties. All three return wrappers now inherit the context. Initial entry and both cancellation remounts preserve the current session.

A retired route correctly suppresses ordinary stale notifications. Failed approval cleanup now uses a separate no-argument root method with one fixed, non-private notice. It cannot carry an old receipt, account or approval token.

Successful, validated receipt lookup and POST confirmation clear the previous uncertainty message. Failed, malformed or uncertain responses preserve the operation and warning. Exchange lookup alone still cannot confirm the exchange.

Only `savia/web/app.mjs`, `savia/web/screens/return.mjs` and `savia/web/tests/return-lifecycle.test.mjs` differ from the previous review source. SQL, financial request bodies and the prior correction files remain unchanged.

## Evidence

- Real red assertions precede product corrections. The first CF2 fixture failed too early; its corrected setup then reproduced the missing notice. Both logs remain preserved.
- `node --test savia/web/tests/*.test.mjs`: **117 PASS**, zero failures or skips, exit `0`.
- Browser run 1: **21/22**, exit `1`. The desktop cancellation test used a retained closed-dialog button before the next confirmation opened.
- Browser run 2 waits for `dialog[open] #confirm-no`: **22/22**, exit `0`, **15.125 seconds**. Product bytes did not change between browser runs.
- [Browser audit](browser/AUDIT.json): **17/17 source bindings**, **18/18 served bindings**, zero external requests, eight expected synthetic console events. Browser/server closed; loopback closure checked.
- Two AFTER recordings pass `ffprobe`. The recovered mobile screenshot shows both receipt links and no obsolete warning. Full video timelines were not reviewed.
- `git diff --check`: exit `0` before evidence-document updates. HEAD and index remain unchanged.

The browser fixture executes the application's actual root and route-context declarations with inherited getters. It mounts the real return module with simulated HTTP. It does not boot the complete router or login flow.

## Frozen acceptance checks

1. A prototype-shaped route context permits initial return entry with the current actor and roles.
2. Direct draft cancellation restores editable entry without POST or a live retired form.
3. Cancelling replay confirmation restores editable entry without POST or stale callback effects.
4. Failed temporary-approval cleanup remains visible after retirement through a fixed, non-private notice.
5. Ordinary retired notifications and late lookup/modal changes remain suppressed.
6. Confirmed lookup and POST clear obsolete uncertainty; malformed or uncertain responses preserve intent and warnings.
7. Session, actor, scope, hash and disposal fences remain effective. GET uncertainty never becomes financial rejection or exchange confirmation.
8. Existing return recovery, strict receipts and financial request identity remain intact. SQL changes stay separately qualified.

## Remaining closure

Primary must obtain a fresh Astra/xhigh verdict and adjudicate it. Worker results are not primary acceptance.

The previous aggregate check failed in Windows symlink fixtures with `WinError 1314`. Security settings and assertions were not weakened. Require exact-candidate Linux evidence under a new runtime scope.

SQL, real API, browser-to-API-to-SQL, full routing/login, physical devices and CI remain unverified for this overlay. No commit, push, merge or deploy occurred. Tony hooks publish and start SQL CI, so a commit requires the next concrete publication/runtime authorization.

Lesson applied: use the actual route-context shape in lifecycle tests. Wait for a new visible dialog before sending keys.

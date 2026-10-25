# Frontend regression checks

These are **jsdom DOM simulations**, not browser automation or real-browser layout/visual tests. They load all 47 published HTML templates and their real catalog, browser-local API, and app scripts. Dialog/layout/media browser primitives are stubbed; native focus trapping, actual rendering, responsive layout and image delivery still require real-browser checks. Catalog assertions use the full 40-product preview, while the served fixture gate independently checks its original IDs and 120 sample variants.

Install reproducible isolated dependencies and run:

```sh
npm ci --prefix tests/frontend-deps --cache /tmp/martha-npm-cache --no-audit --no-fund
node tests/frontend-runtime.cjs
```

Optional `FRONTEND_APP` and `FRONTEND_API` absolute paths select baseline files for regression reproduction.

Coverage: 47 template mounts; malformed favorites/checkout state recovery; catalog Back/Forward, sort, empty result and reset; product zoom focus; modal stock errors with quantity rollback; successful quantity focus; rapid add-button repeat guard; final-item removal and focus restoration; admin refresh/logout/login.

The GET default is an integration compatibility fix with the hardened API, not a claim that baseline pages could not load. Against original app/API, malformed favorites, filter history, modal quantity errors and quantity focus failures were reproduced.

## Dual integration UI

The DOM checks include a visible SAVIA / SISFAIN (CGA) selection; explicit local-only, unconfigured statuses; isolated carts, checkout contact data and recent-order hints; removing cross-mode order URLs; missing-module fail-closed behavior and retry; pending-operation mode locking and repeated clicks; no automatic order creation on mount; and BFCache mode restoration without mutating an in-flight operation. These checks load `integration-adapters.js` between the local API and app. `window.marthaStoreApi` diagnoses the active local model; the legacy `marthaDemoApi` is not the storefront transport.

No HTTP transport is configured in the storefront. These tests do not establish compatibility with a real SAVIA deployment or a CGA API, a connected .NET backend, real payments, visual layout or mobile-browser behavior.

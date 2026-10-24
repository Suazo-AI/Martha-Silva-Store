# Frontend regression checks

These are **jsdom DOM simulations**, not browser automation or real-browser layout/visual tests. They load all nine published HTML templates and their real catalog, browser-local API, and app scripts. Dialog/layout/media browser primitives are stubbed; native focus trapping, actual rendering, responsive layout and image delivery still require real-browser checks.

Install reproducible isolated dependencies and run:

```sh
npm ci --prefix tests/frontend-deps --cache /tmp/martha-npm-cache --no-audit --no-fund
node tests/frontend-runtime.cjs
```

Optional `FRONTEND_APP` and `FRONTEND_API` absolute paths select baseline files for regression reproduction.

Coverage: nine template mounts; malformed favorites/checkout state recovery; catalog Back/Forward, sort, empty result and reset; product zoom focus; modal stock errors with quantity rollback; successful quantity focus; rapid add-button repeat guard; final-item removal and focus restoration; admin refresh/logout/login.

The GET default is an integration compatibility fix with the hardened API, not a claim that baseline pages could not load. Against original app/API, malformed favorites, filter history, modal quantity errors and quantity focus failures were reproduced.

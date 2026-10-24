# Demo QA — 2026-10-24

Scope: independent private Martha Site, 9 pages / 2 recovered products. The original workers.dev store is not modified. Browser-local data only, no production security/payment/D1/SISFAIN claim.

## Verified
- 23 backend regression tests against actual published two-product fixture.
- 11 jsdom DOM simulations, including all page mounts, malformed favorites/checkout state, Back/Forward filters, empty/reset/sort, zoom focus, quantity stock error inside dialog, quantity rollback/focus, repeated add clicks and local admin refresh/logout/login.
- Nine-page local link, fragment anchor, image/srcset and ARIA reference checks.
- JavaScript syntax checks.

## Fixes
- Removed dangling mega-menu ARIA controls and repaired El edit de Martha anchor.
- Mobile hero JPEG fallback now selects portrait instead of desktop crop.
- Saved state validation, safe one-slot raw recovery backup and actionable error when recovery cannot preserve old data.
- Pending payment reservations release after 30 minutes.
- Malformed requests and prototype-like order IDs reject coherently; invalid quantities/totals cannot corrupt the demo state.
- Catalog controls/results resync on browser history changes.
- Mini-bag quantity errors are visible inside dialog, selected amount rolls back and focus is restored.
- GET inference kept compatible between frontend and hardened local adapter.

## Not verified
Real-browser end-to-end, iPhone scrolling, layout/screen reader behavior, LCP, CLS, INP and multi-tab locking. Published private URL presents login in the assistant cloud browser; the cloud browser cannot reach executor localhost. These limitations do not justify a public-lag-fixed or pixel-perfect claim.

## Repeat
npm ci --prefix tests/frontend-deps
node --test tests/backend.cjs
node tests/frontend-runtime.cjs
python3 tests/structure.py

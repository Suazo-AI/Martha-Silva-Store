# Storefront deploy (W6 preparation)

Status on 2026-11-22: the demo-mode build is deployed to the preview; the live store is not.
The primary ran `npx wrangler deploy --config <clean worktree>/wrangler.jsonc` at `7f54e216` (adds `Strict-Transport-Security`): version `e6934b14-3fee-4963-9a84-b5511b27f302`, previous version `de32eca6-aa7e-4e06-97da-acfd87d55b85` (built at `30b071ff`).
The CI deploy job in step 6 is not enabled (no `CLOUDFLARE_DEPLOY_ENABLED` variable and no preview token), and every deploy to this account so far was made with Wrangler by hand.
The live build was exercised only locally: `wrangler dev` against a local hub with a disposable database.

## What turns the live store on

`site.config.json` holds the only switch, the `storefront` section:

| Field | Value | Effect at build time |
|---|---|---|
| `apiBase` | the hub origin, `https://...` with no path; empty keeps the demo store | adds the origin to CSP `connect-src`, adds a `preconnect` link, blanks the recovered prices in the HTML, drops `offers` from the JSON-LD |
| `turnstileSiteKey` | the public Turnstile site key; empty means no widget | adds `https://challenges.cloudflare.com` to `script-src` and `frame-src` |
| `skus` | storefront variant id to hub SKU, one to one | a variant with no SKU shows as not available |

`prepare.py` refuses a path, a query, plain `http` (except loopback), a bad site key, an unknown variant and two variants on one SKU.
The site key is public by design; the Turnstile secret never goes in this repository.

The hub must match the storefront:

- `Savia:Public:AllowedOrigins` = the storefront origin (for example `https://martha-silva-preview.<subdomain>.workers.dev`).
- `Savia:Public:OrderPageUrl` = `<storefront origin>/pedido.html`.
- `Savia:Public:Turnstile:Secret` in Key Vault `kv-savia-bukmlt`; `Savia:Public:BotCheck` must not be `disabled`.
- Every SKU in `skus` must be consigned to the web on the hub, or it shows as sold out.

## Steps

1. From a clean commit on the deploy branch, set `storefront.apiBase`, `storefront.turnstileSiteKey` and `storefront.skus`.
2. Run `python3 prepare.py`, then `python3 tests/check.py` and `python3 tests/static_headers.py`.
   Checked locally with a live test config (`https://api.example.test`): every stage passed except the symlink tests, which need a symlink privilege this Windows host lacks; CI runs on Linux.
   The DOM suites run the demo adapter even on a live build; live behavior is covered by `tests/integration-adapters.test.js` and the end-to-end run.
3. Check the built policy: `grep Content-Security-Policy dist/_headers` must list the hub origin once in `connect-src` and Turnstile in `script-src` and `frame-src`.
4. Record the new snapshot with `python3 tools/verify_release_snapshot.py --record`, review the diff, and commit.
5. Run `npm run deploy:check` (dry run, no credentials).
6. Deploy through the existing CI job only (`docs/CLOUDFLARE-CD.md`): it needs Jason's approval, `CLOUDFLARE_DEPLOY_ENABLED=true` and a push to `main`.
   The job runs `npm run deploy:preview` and the read-only smoke check.
7. Record the Wrangler version id, the commit SHA and the smoke result in the W6 row of `README.md`.

## Checks after the deploy

- `curl -sI <storefront>/` shows the CSP with the hub origin, `Cross-Origin-Opener-Policy` and `Permissions-Policy`.
- A product page shows the hub price; an unmapped size shows "Agotada".
- One test order with an `example.test` address reaches the hub staff list, and the order page reloads.
- The Turnstile widget renders with no CSP error in the console.

## Rollback

- Code: `npx wrangler rollback <previous-version-id>` for `martha-silva-preview`, or Deployments > Rollback in the dashboard.
  Check the Worker name first; never select `martha-silva-demo`.
- Back to the demo store: commit an empty `storefront.apiBase`, rebuild and deploy.
  With an empty `apiBase` the build has no hub origin, no Turnstile and the demo prices.
- The first deploy has no previous version; stop CD and ask for the preview to be withdrawn instead.
- A rollback does not touch the hub: orders already placed stay reserved until staff act or the sweep expires them.

## Open before a public launch

- Lighthouse mobile performance is below 90 on every audited page (61 to 87); the demo build scores the same or lower, so the cause predates this work.
  Main costs: 1.0 to 1.5 s of blocking scripts and oversized product images.
- Lighthouse cannot trace a page that sends `Cross-Origin-Opener-Policy: same-origin` (`NO_NAVSTART`); scores were taken with that one header removed.
- HSTS waits for the final domain; `X-Robots-Tag: noindex` and `indexable:false` stay until launch.
- `hreflang` needs separate English URLs; English is a client-side switch today.
- The business fields in `site.config.json` (`name`, `telephone`, `email`, `address`, `geo`, `openingHours`) are empty and are not emitted.
- The public catalog price excludes tax and the hub order total includes it, so a taxed item costs more at the order page than on the product page.
- Shipping is known only after the order exists; there is no public quote endpoint.

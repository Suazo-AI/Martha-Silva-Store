# Packet P8: B1 SEO, AIEO and GMB readiness

You are the builder (Claude Sonnet 5.5). The judge (Claude Opus) accepts only from its own checks.
Output: KISS; finish with the YAML below only.

## Workspace and rules

Same as packet P1 (`C:/Users/Jason/.t3/worktrees/github/frontend-finish-f84c41ce23a85739/docs/storefront-loop-20261120/packets/P1-A1-A5.md`, sections Workspace, Owned paths, Return).
Apply every `*.patch` in PATCHES_DIR in name order with `git apply --index` before you start (000–013; 012 is the accepted P7 loader, 013 adds the judge `seo` check and two loader sub-checks).
Read `docs/storefront-loop-20261120/PROMPT.md` sections "Decisions already made (frozen)", "Track B" (the SEO/AIEO/GMB bullet) and every "Amendment"; amendments win.
Jason's decision: the domain comes later. Build everything config-driven with `siteUrl` empty and `indexable:false`.
The judge check is `seo` in `tests/storefront_scorecard/slices.py` (functions `seo_audit` and `seo`). Read it first; it is the contract. Never edit it.

Owned:
- new `tools/seo_generate.py`;
- new `site.config.json` at the repo root;
- the HTML pages in `build-inputs/static/` (only inside the generated region below);
- new `build-inputs/static/robots.txt` and `build-inputs/static/llms.txt`;
- `tests/static_headers.py`: one allowed change only, so its inline-script test ignores `<script type="application/ld+json">`; every other assertion stays;
- `tests/page-hashes.json` and the path pin the new files move.

Not owned: `src/`, `styles.css`, `_headers`, `catalog.js`, `prepare.py`, `tests/check.py`, `wrangler.jsonc`, the judge files.

## Contract (frozen)

Generator: `python tools/seo_generate.py [--root DIR] [--config FILE] [--check]`.
- `--root` defaults to the repo root; it reads `<root>/build-inputs/static/catalog.js` and `*.html`, and writes only there.
- `--config` defaults to `<repo>/site.config.json`.
- `--check` writes nothing and exits 1 when any file would change, 0 otherwise. A second normal run changes nothing.
- It reads only `catalog.js`, the config and the HTML pages. It never reads image files, the network or the clock.
- It refuses (exit ≠ 0, writes nothing) when `indexable` is true while `catalog.mode` is `local_test` or the brand or any product has `commercial_status` `sample`.
- Generated output depends only on its inputs: switching the config back restores the exact original bytes.

Config `site.config.json`, shipped exactly as: `siteUrl ""`, `indexable false`, `business` an object whose values are all empty (`name`, `telephone`, `email`, `address`, `geo`, `openingHours`). Business values are never emitted in this slice, even when set.

Head region: one `<!-- seo:start -->` … `<!-- seo:end -->` block per page, inside `<head>`, after `<meta name="description">`.
- Do not change `<title>`, the loader gate `<script>`, or anything outside the region except the existing description and robots meta, which move into the region.
- The loader gate bytes and its CSP hash stay identical; `python tools/loader_codemod.py --check` stays 0.

Pages:
- Indexable set (43): `index.html`, `catalogo.html`, `ayuda.html` and the 40 `producto-<slug>.html` from `catalog.js` order.
- Non-indexable (5): `404.html`, `admin.html`, `bolsa.html`, `checkout.html`, `pedido.html`. They get the markers and `robots noindex,nofollow` only.
- Robots meta: `index,follow` on the indexable set only when `indexable` is true; otherwise `noindex,nofollow` everywhere.
- URL rule: `U(path) = siteUrl + path`, with `/` for the home and `/<file>` for others. With `siteUrl` empty, JSON-LD and `llms.txt` use root-relative paths.

Every indexable page:
- `meta description` 50–160 characters, unique across the 43. Product descriptions come from catalog fields (name, category, color, description). Never invent material, price claims, stock or reviews.
- `<title>` stays; titles must be unique (they are today).
- `og:title` = title, `og:description` = description, `og:site_name` = `brand.name`, `og:type` `product` or `website`, `og:locale` `es_NI`, `twitter:card` `summary_large_image`, `twitter:title`, `twitter:description`.
- Only when `siteUrl` is set: `<link rel="canonical">`, `og:url`, `og:image` and `twitter:image` (absolute; on products the first catalog image).
- Exactly one `<script type="application/ld+json">` inside the region, with `{"@context":"https://schema.org","@graph":[…]}`:
  - every page: `Organization` (`name`, `sameAs` = the `brand.social` URLs; `url` only with `siteUrl`) and `WebSite` (`name`, `inLanguage` `es-NI`; `url` only with `siteUrl`);
  - catalog: `BreadcrumbList` (2 items) and `ItemList` (40 `ListItem`: `position`, `url`, `name`, in catalog order);
  - product: `BreadcrumbList` (3 items, home first, last = product name) and `Product` (`name`, `description`, `sku` = id, `image` = all catalog images, `brand`, `color`, `category`, `offers` = one `Offer` per variant in catalog order with `sku` = variant id, `price` = `price_minor/100` with 2 decimals, `priceCurrency`, `availability` `https://schema.org/InStock` if stock > 0 else `OutOfStock`, `itemCondition` `NewCondition`, `url`).
  - Never: `aggregateRating`, `review`, `address`, `telephone`, `geo`, `openingHours`, `email`, `LocalBusiness`, `ClothingStore`, or any `source_url`.
  - Escape `<` in JSON as `\u003c` so the block cannot close early.

Files:
- `robots.txt`: closed state `User-agent: *` and `Disallow: /`, no Sitemap line. Open state (siteUrl set and indexable): allow, disallow the 5 non-indexable pages, and `Sitemap: <siteUrl>/sitemap.xml`.
- `sitemap.xml`: only when siteUrl is set and indexable is true; exactly the 43 URLs. Otherwise the generator deletes it.
- `llms.txt`: always; first line `# Martha Silva Store` (brand name), a one-line summary, then links to the catalog and every product (name, category, display price `$175.00`). No NAP.

## Checks (run and report exact values)

1. `python -B prepare.py`; `python tools/seo_generate.py --check` 1 on base, 0 after; second run 0 changes; every earlier codemod `--check` 0 (storefront_markup_codemod, price_format, remove_dead_vendor, footer_wordmark_codemod, menu_pill_codemod, loader_codemod); `python tools/pin_page_hashes.py --check` exits 0; `python tools/verify_release_snapshot.py` counts the new path total (its known "Public/control paths differ" failure stays).
2. Judge slices: `python -X utf8 tests/storefront_scorecard/slices.py --out <TEMP>/p8-slices.json --port 18640` → grid, footer, title, pill, transition, loader and seo all true. `seo` covers config, served pages (raw bytes), `--check`, and the flip test (sample refuses, live emits the domain set, revert restores bytes).
3. Scorecard: `python -X utf8 tests/storefront_scorecard/scorecard.py --out <TEMP>/p8.json --skip-vitals --port 18641`. Must equal champion 012: purchase 4/4, axe 0, enSpanish 0, priceBad 0, console 0/0, no overflow, 404 ok, stages nonzero only asset-audit and catalog-staging. JS bytes unchanged (511,650); HTML may grow.
4. `node tests/localization-runtime.cjs`, `node tests/frontend-runtime.cjs`, `node tests/desktop-gallery.cjs`, `python -m unittest tests.responsive_images`, `python tests/static_headers.py` exit 0.
5. Validate 3 JSON-LD blocks (home, catalog, one product) with a local parser and report their `@type` lists. No network validator.
6. No new file under `src`; new files under `build-inputs/static` are only `robots.txt` and `llms.txt`.

## Return YAML

```yaml
model: <exact model id>
patch: <absolute PATCH_OUT>
files_changed: [..]
generator: {check_before: .., changed_files: .., check_after: .., second_run_changes: .., refuses_sample_indexable: ..}
slices: {grid: .., footer: .., title: .., pill: .., transition: .., loader: .., seo: .., failing_evidence: ..}
scorecard: {purchase: .., axe: .., enSpanish: .., priceBad: .., console: .., budget_js: .., stages_nonzero: ..}
jsonld_types: {home: .., catalog: .., product: ..}
gaps: [..]
```

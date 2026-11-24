# Storefront mobile performance (W7)

Result: home and catalog reach 90 or more in demo and live mode.
The product page rises from 67 to 85 and stays below 90.
Checkout stays at 90 (demo) and 86 to 88 (live), the same as before within noise.
Source commit: `60722372`. Raw numbers: [performance-lighthouse.json](performance-lighthouse.json).

## Before and after

Lighthouse 12.8.2 mobile preset, median of 3 interleaved runs per build and page.
"Before" is commit `60722372`; "after" is the final change set.

| Page | Mode | Perf before | Perf after | Runs after | LCP before → after | TBT before → after | CLS before → after | Transfer before → after |
|---|---|---|---|---|---|---|---|---|
| Home `/` | demo | 88 | 91 | 79, 91, 92 | 2.9 s → 2.9 s | 255 → 216 ms | 0.003 → 0.004 | 2900 → 1861 KiB |
| Home `/` | live | 91 | 91 | 92, 87, 91 | 2.7 s → 2.9 s | 182 → 190 ms | 0.001 → 0.001 | 2906 → 1867 KiB |
| Catalog `/catalogo` | demo | 88 | 91 | 92, 91, 88 | 3.5 s → 3.2 s | 173 → 99 ms | 0.001 → 0.001 | 2672 → 2668 KiB |
| Catalog `/catalogo` | live | 90 | 94 | 94, 90, 97 | 3.3 s → 2.8 s | 149 → 126 ms | 0 → 0.001 | 2678 → 2673 KiB |
| Product `/producto-rosa-empolvado-pedreria` | demo | 67 | 85 | 89, 85, 82 | 14.3 s → 3.4 s | 389 → 128 ms | 0.001 → 0.001 | 4526 → 1430 KiB |
| Product `/producto-rosa-empolvado-pedreria` | live | 66 | 85 | 83, 89, 85 | 14.5 s → 3.4 s | 342 → 256 ms | 0.001 → 0.001 | 4531 → 1434 KiB |
| Checkout `/checkout` | demo | 91 | 90 | 90, 90, 93 | 3.2 s → 3.2 s | 0 → 0 ms | 0 → 0 | 368 → 364 KiB |
| Checkout `/checkout` | live | 88 | 86 | 89, 86, 86 | 3.9 s → 3.8 s | 0 → 0 ms | 0 → 0 | 370 → 366 KiB |

Accessibility is 100 on every run before and after.
Best practices rises from 96 to 100 on every page: the `/favicon.ico` 404 console error is gone.
Single runs on this host swing by up to 20 points, so the earlier worker's single-run baseline (home 61) was replaced by these medians.

## Changes, largest gain first

Step 1 was built and measured on its own; steps 2 and 3 share one build; step 4 was measured on top of them.
Each build ran against the baseline in the same interleaved round.

1. **Video poster as WebP derivative** (23 product pages).
   The `<video poster>` pointed to the 2.1 MB generated PNG, which Lighthouse counts before first paint.
   It now points to the same-width WebP derivative from the responsive manifest (for example `01-front-v1-1024.webp`).
   Product demo: 70 → 84, LCP 5.4 → 3.9 s, transfer 4526 → 2432 KiB.
   Fidelity of all 23 swapped posters against their PNG: same pixel size, mean channel delta 1.5-2.4, max 56, PSNR 36.0-41.1 dB; 48,202 → 2,821 KiB in total.
   These WebP files are the derivatives the gallery already shows for the same photos.
   `tests/green-header.cjs` now expects the derivative on the page while the catalog keeps the original PNG.
2. **Related-product carousel `sizes`** (41 pages, 18,840 attributes, only inside `.product-carousel`).
   `(max-width: 599px) 50vw` became `(max-width: 599px) 144px`, which is the rendered card width below 600 px.
   The browser had picked 720w and 1086w files for 144 px cards.
   The catalog grid keeps `50vw` because its one-column view can fill the screen.
   Home transfer 2900 → 1861 KiB.
3. **Empty `data:` icon** (all 48 pages, through `tools/seo_generate.py`).
   It stops the `/favicon.ico` request that returned 404; best practices 96 → 100.
4. **Preload of the mobile gallery clone** (40 product pages, `media="(max-width:1023px)"`).
   On mobile the first gallery item is a clone of the last photo, so it is the LCP element.
   The preload makes the browser fetch it at about 90 ms instead of after the CSS and fonts; LCP load delay 1.35 s → 0.11 s.
   Product demo after steps 1-3: 83; after step 4: 85.

## Visual and behaviour checks

- Pixel diff: agent-browser full-page screenshots (reduced motion, a new browser session per capture) at 390 × 844 and 1440 × 900, base against final, compared with Pillow per pixel (largest channel delta above 8).
  Home, catalog and checkout: 0 changed pixels at both widths.
  Product: about 10,400-10,900 pixels change, 94 or fewer by more than 32 levels and none by more than 64.
  The changed box matches the `<video>` element (390 × 520 at 390 px, 422 × 633 at 1440 px), so it is the poster: PNG before, WebP after.
  Captures that reused one browser session showed extra differences on home and catalog; they vanished with a new session per capture, so they came from cached `srcset` picks.
- `srcset` effect: with a cold cache the browser now picks the 360w file instead of the 720w file for 144 px cards on screens at DPR 2.5 or less.
- Real layout check: carousel cards render 144 CSS px wide at 390 (DPR 1 and 3), 412 (DPR 1.75) and 599 px (DPR 1 and 2).
  The chosen file is at least as wide as the card in device pixels on every loaded card, before and after.
- `node tests/localization-runtime.cjs`: 19/19 (ES/EN). `node tests/frontend-runtime.cjs`: 22/22 (demo, empty `apiBase`).
- `node --test tests/integration-adapters.test.js`: 27 pass, 0 fail (live adapter contract).
- Every other `tests/check.py` stage passes; `asset-audit.py` and `catalog-staging.py` stop with WinError 1314 (symlink privilege) on this host.

## 2026-11-23: Latin font subsets

Result: product page median 73 → 82 (4 interleaved rounds, same host, same load).
First contentful paint went from about 2.5 s to 1.7 s. Font bytes on that page went from 224 KB to 69 KB.

| Build | Scores | Median | Font files requested |
|-------|--------|--------|----------------------|
| before | 67, 74, 73, 73 | 73 | `font-1`, `font-2`, `font-4`, `font-7` (76 + 77 + 35 + 36 KB) |
| after | 85, 81, 82, 82 | 82 | `font-1-latin`, `font-2-latin`, `font-4-latin`, `font-7-latin` (21 + 21 + 13 + 14 KB) |

- Cause found first: the score follows how many bytes start before the first paint.
  The same build scored 74-87 depending on that cut-off. Fonts were 224 KB of it, and they were complete files.
- Knock-out test on one page (3 rounds): no fonts alone 84, no carousels alone 79, both removed 93, base 82.
  Only fonts were cheap to change without changing content.
- Change: each font gets a Latin WOFF2 subset (`font-N-latin.woff2`), declared after the complete face with a Latin `unicode-range`.
  Each complete face now declares `unicode-range` equal to its own character map.
  So the browser never downloads a complete file for a character the font does not have (the page uses `⌄`, which Manrope lacks).
- The complete WOFF2 and TTF files are unchanged and still served for any character outside the Latin range.
- Built by `python tools/responsive_fonts.py`; `tests/responsive_fonts.py` checks byte-reproducible subsets, that each subset keeps every Latin character of its font, identical descriptors, and the frozen CSS baseline.
- Browser check at 390 px: only the four Latin files load; `document.fonts` shows the same four faces loaded. A screenshot diff against the old build shows no text change (only anti-aliasing on the gallery dots).
- Published path count 1557 → 1565 (`tools/verify_release_snapshot.py`, `tests/test_release_snapshot.py`).
- Limit: Lighthouse cannot load the deployed URL (`NO_NAVSTART` under `Cross-Origin-Opener-Policy`), so the gain is a local paired measurement, not a deployed one.
- Still open for 90 on the product page: the carousels (78 cards) start 14 card images before first paint. Changing that changes content or layout.

## Method

- Server: `wrangler dev` on the `prepare.py` output with the repository `_headers`, so compression and cache headers match Cloudflare Pages.
  `Cross-Origin-Opener-Policy` was removed from the local copy only, because Lighthouse fails with `NO_NAVSTART` under it.
- Live mode: a build with a temporary `apiBase` pointing to a local stub hub that answers the public catalog after 600 ms; `site.config.json` was not touched.
- Each round interleaves builds page by page, so host load hits every build equally; the CPU benchmark index ranged 1836-3131.

## Limits

- The product page stays at 85.
  Its LCP is now mostly render delay: style and layout of a 236 KB page with 78 cards and 164 pictures under 4× CPU throttling.
  Reaching 90 needs fewer cards on first paint or lighter markup, which changes content or layout; not done here.
- Live checkout stays at 86-88.
  Its LCP element is an `<h2>` that appears after the hub catalog request; the score follows hub latency.
  Real hub latency was not measured.
- A `content-visibility` trial on carousel sections did not beat noise and changed image loading timing; it was dropped.
- Not used: `immutable` cache headers and extra inline scripts (forbidden by `tests/static_headers.py`), font subsetting of the pinned files (Latin subsets were added beside them on 2026-11-23).
- Accessibility 100 comes from Lighthouse's axe-based audits; a standalone axe run was not repeated.
- Scores are lab simulations on a shared, busy host, not field data from phones.
- No deployed URL was measured.

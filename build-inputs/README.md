# Self-contained recovered demo build

## Current integration

The authorized public capture expands this branch to 47 HTML templates, 40 sample
products and 120 variants. `static/research/assets/` preserves 777 captured media
paths; fonts and animation vendors are local under `static/prototypes/`. Inputs
remain separate from the inert historical Worker. `catalog.js` supplies shared
media metadata instead of repeating it in each HTML. Run `python3 prepare.py`
after every input change, then `python3 tests/check.py --install` on first use
and `python3 tests/check.py` thereafter. The builder requires exactly the 40
catalog product pages plus seven shared pages, copies bytes without network or
transformation, and rejects stale output. One historical JPEG remains unavailable;
see `../docs/ASSET-COMPLETENESS.md`. The notes below describe the earlier baseline.

`static/` contains the **24 existing, user-owned published snapshot files** other
than the two JavaScript source files. They were copied byte-for-byte from `dist/`
at recovered commit `e6299ee`: nine HTML templates, catalog, stylesheet, demo
notice, and existing image assets. No additional products or invented media were
introduced. There are no orders, SQLite databases, credentials, or npm dependencies.

`prepare.py` assembles these files plus `src/app.js`, `src/demo-api.js`, and `src/integration-adapters.js` into the
27-file `dist/` tree, using only Python 3's standard library. There is no install,
network access, BeautifulSoup dependency, sibling directory, or ignored recovery
input. Output bytes do not depend on timestamps or absolute checkout paths.

```sh
python3 prepare.py
bash tests/check.sh --install  # first QA run only
bash tests/check.sh
# Alternatively build without touching the published snapshot:
python3 prepare.py --output /tmp/martha-demo-build
```

Edit markup, CSS, catalog data and media in `build-inputs/static/`; edit behavior
in `src/`, then regenerate and check `dist/`. The current catalog remains limited
to the two recovered products. Shared markup is intentionally captured in each
page, so common-header changes must be applied consistently to all nine templates.
The builder refuses unexpected files in the destination; use an empty destination
when comparing builds rather than deleting unknown content automatically.

## Recovery boundary and verification

This is **deterministic assembly of the recovered snapshot**, not a restoration of
the historical editorial generator. The former `prepare.py` transformed an external
`martha-editorial` tree and ignored recovery files. Those original transformations
remain in Git history, but are no longer required to continue this two-product demo.

The recovery build was verified in an isolated clean Git worktree with `dist/`
absent, no adjacent editorial/recovered directory, and no Python third-party
packages required. Generated output matched all **26 baseline files byte-for-byte**
(SHA-256 and path-set comparison); a repeated build was also identical. All 23
backend tests, 11 DOM simulations, nine-page structure checks and seven JavaScript
syntax checks passed afterward. Byte equivalence preserves the existing artifact,
but **does not establish real-browser visual equivalence**: no screenshot, rendering,
responsive, or real-browser interaction test was performed.

## Responsive generated image delivery (2026-11-05)

`python tools/responsive_images.py` creates WebP candidates under
`static/responsive-images/` from existing authorized `static/generated-luxury/*.png`.
Pillow 12.3.0 and its installed libwebp are required only for derivative generation.
No network or installation is part of the script. It preserves whole frames at
360px, 720px and original width, without upscaling, quality 82, method 6, LANCZOS.
The manifest binds original and derivative SHA256, dimensions, byte sizes and versions.
Run `python prepare.py` after regeneration. Never edit generated files manually.
HTML and dynamic cards prefer WebP; PNG sources, zoom, original paths and IA labels
remain intact. Browsers without WebP retain the original heavy PNG delivery.
The generator does not rewrite use sites; new originals need explicit source references.
See `docs/release-20261105/responsive-images/README.md` for scoped lab evidence and gaps.

## Complete WOFF2 delivery

Run `python tools/responsive_fonts.py` with FontTools 4.67.0 / Brotli 1.2.0.
The eight original TTF files remain unchanged and remain CSS fallbacks.
No subsetting or typeface changes. Embedded copyright and OFL URLs are retained.
See `docs/release-20261105/responsive-followup/fonts.json` for source hashes,
complete table verification and observed license metadata. WOFF2 head checksum
and compression bit 11 are the only normalized table fields. Run prepare.py.

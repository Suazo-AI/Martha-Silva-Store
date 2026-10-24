# Safe catalog integration (offline staging only)

```sh
python tests/catalog-staging.py
python tools/stage_catalog.py > /tmp/martha-catalog-staging.json
```

The default inputs are `originals/cloudflare/catalog-extracted.json`,
`dist/catalog.js`, and `evidence/asset-source-manifest.json`. Run after the
original archive is included. Before that, pass `--original /local/path/catalog-extracted.json`.
Optional `--asset-root /local/import` checks an offline `research/assets/...`
folder. There are no downloads or JavaScript execution. Output goes only to
stdout; redirect to a review location, never a published catalog.

## Observations, not inventory

The recovered catalog observed on 2026-10-24 contains **40 products, 120 variants,
and 170 original gallery references**, all explicitly `commercial_status: sample`.
The valid current demo has **2 products / 6 variants**, using selected replacement
images. **38 additional records are staging candidates, not published products.**
With the existing demo assets, none of the 40 original galleries is complete at
its exact original paths. This is not full photo recovery. A selected WebP or
hero image does not prove recovery of the original multi-image JPG gallery.

The report preserves original price and stock only under `commercial_evidence`,
using `sample_price_minor` and `sample_stock` labels. It is intentionally **not**
a directly importable DEMO_CATALOG or stock seed. Every record has
`publish_allowed: false`, including existing demo products; this means this
report authorizes no new publication, not that it disables the current demo.
The script neither reads nor overwrites runtime/local-storage/database stock,
orders, payments, or customer data. Current demo files are only read.
Input SHA-256 values make a saved report traceable and deterministic.

## Activation gate

1. Recover all original gallery files using an authorized local source. Exact
   paths must appear in the manifest and have non-empty, non-symlink local files.
2. Manually review image validity, product identity, and usage suitability.
   File presence alone does **not** verify that bytes are a correct photo.
3. Verify price, currency, variants and actual stock with the owner; recovered
   sample values are not a source of live commercial truth.
4. Obtain separate explicit activation review and use a reviewed migration that
   preserves current inventory. This tool has no activation or deployment mode.

Even with complete media, the commercial verification and activation blockers
remain. Unknown manifest paths, traversal, external media URLs, duplicate IDs,
empty files and symlinks cannot count as recovered media. No missing-photo
product is added to the demo. `dist`, build inputs and original evidence remain
unchanged.

# Asset completeness and offline recovery

## Authorized public capture — 2026-10-25 UTC

The separate integration branch now uses the public original's 40 sample products, 120 variants and 170 gallery positions. The authorized same-origin transfer produced 840 HTTP-200 files (133,283,783 bytes): 47 HTML, eight CSS/JS resources, eight TTF and 777 media. Every retained file matched its transfer SHA-256 and byte count. The original app transport and Worker remain inert; the import selects media, fonts and vendors only, while HTML/CSS are integrated separately.

One historical JPEG returned HTTP 404: `/research/assets/martha-gala/f1bf4e3664d34cd4.jpg`. It is retained as an explicit missing reference and never synthesized. The historical `--require-complete` gate remains FAIL at 777/778. Current rendered source references are a separate 777/777 set; `STORE_MEDIA` itself references 774 of them. Availability is distinct from product identity and browser visual review. The six `sample_image=true` groups remain marked as samples.

The snapshot and disconnected-PC statements below are historical evidence for the base revision, not the current authorized transfer. Import hashes, browser decoding/visual review and final output hashes must be recorded separately before claiming completion.

## Verified snapshot (2026-10-24)

This is an **offline local checkout audit**, not a new inspection of the original PC or a claim about the live deployment.

| Evidence | Products | Variants | Gallery references |
| --- | ---: | ---: | ---: |
| Original `parity-v2/catalog-fixture.json` | 40 | 120 | 170 |
| Separate `observed-catalog.json` | 40 | 120 | 170 |
| Current demo `dist/catalog.js` | 2 | 6 | 2 |

`reference/media.json` independently lists 40 products and 170 primary images. These counts are measured, not inferred from a brief. Variants are sample catalog records, **not verified commercial inventory**. Gallery references are not necessarily unique source photographs.

The original reference media, body, head, CSS and catalog evidence together identify **778 unique allowlisted media paths** (responsive derivatives, image formats and videos included). Only **1** of these exact original paths is present under demo `dist/assets`. The original catalog uses JPEG paths: **0 of its 170 exact primary JPEG paths** are present. This does **not** mean the demo lacks photos: the rose dress uses the recovered WebP version, and dorado uses a recovered `/hero/` image, with 10 responsive JPG/WebP hero derivatives. There are **11 actual local media files**, and both selected demo images exist with recorded SHA-256 hashes. Existing `missing.svg` is excluded, not counted as recovered imagery.

The demo intentionally retains only `dorado` and `rosa-empolvado-pedreria`; **38 original products are not published in this fixture**. No asset substitution, placeholder creation, catalog expansion, dist modification, publication, or fetch of original URLs is performed by this audit.

## Files and repeatable checks

- `evidence/asset-source-manifest.json`: sanitized original product IDs, variant counts, media paths and hashes/byte counts of six allowlisted evidence inputs. No source URLs, prices, customer records, credentials or original source text.
- `evidence/asset-completeness.json`: per-path presence and SHA-256/byte counts where bytes exist, plus selected demo image verification.
- `tools/audit_assets.py`: standard-library, offline audit. Reads media only at manifest-listed paths; rejects symlinked files/ancestors. Does not copy assets or execute source JavaScript.

```sh
python3 tools/audit_assets.py
python3 tests/asset-audit.py
# Refresh sanitized evidence only when those six known local inputs are available:
python3 tools/audit_assets.py --source-root /path/to/evidence-parent
# Fail closed on incomplete originals; expected to fail against current demo:
python3 tools/audit_assets.py --require-complete --output /tmp/asset-gate.json
```

Exit 0 without `--require-complete` means the selected demo images exist and the report was generated; **it does not mean the original catalog is complete**. Completeness uses all 778 original media references; review source-specific requirements before changing that gate. Hashes attest to bytes observed now, not original photographic provenance where no trusted original hash exists.

## Import procedure when the original PC is available

1. Reconnect the explicitly authorized original computer. Do not attempt unavailable or denied original URLs, alternate hosts or access workarounds. Current blocker is missing original media bytes on an offline PC.
2. On a recovery branch, use a new **private staging directory outside `dist`** with layout `research/assets/...`. Request only the media paths in `asset-source-manifest.json` from the authorized original project. Preserve their relative path spelling. Do not export the entire PC, repository, browser profile or databases.
3. Transfer **only allowlisted referenced `.jpg`, `.jpeg`, `.png`, `.webp`, `.mp4`, `.webm` media**. Exclude SQLite/D1 files, orders, customer/contact data, credentials, `.env`, cookies, tokens, logs, backups, `.git`, archives and symlinks. Review content before transfer: a media extension alone does not prove a file is safe or is the correct garment. Reject unrelated files rather than importing them. No blanket recursive copy from the original project.
4. Hash approved source files on the PC and retain a private transfer manifest. Use the supported file-transfer channel; after materialization, compare destination SHA-256 values to source hashes. This audit provides destination hashes but cannot establish missing source hashes while the PC is offline.
5. Run from this checkout:
   ```sh
   python3 tools/audit_assets.py --staging /path/to/private-staging \
     --require-complete --output /tmp/recovered-asset-audit.json
   ```
   Missing or symlink-rejected references fail the gate. Inspect image pixels and play videos; validate dimensions, MIME/decoding, duplicates, garment identity, original vs derived images, responsive sets and product-to-image mapping. Do not replace missing assets with unrelated/generated substitutes.
6. Review the report and resolve missing references against the actual original project. A stale reference may require an explicitly documented evidence correction, never silently declaring completeness. Keep the current two-product demo intact until an independently reviewed import/build change is authorized.
7. In a separate authorized integration change, copy only approved media and update catalog/build mappings; preserve the known working two-product demo as rollback. Run catalog, backend, frontend, structure and real-browser visual checks before requesting publication. The current audit does **not** authorize or perform deployment and does not restore live stock, payment, orders or SISFAIN/D1 state.

## Exact stopping condition

The original-media recovery remains blocked until approved original bytes are accessible and their transfer and visual mapping are verified. Metadata coverage is complete enough to enumerate the gap; it is not a recovery of those bytes. No network fallback is attempted.

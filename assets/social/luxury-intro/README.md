# Authentic editorial photography — cloud delivery

**Ready:** six unchanged supplied originals, 44 responsive JPEG/WebP derivatives,
and per-file SHA-256/dimension/provenance records. All derivative decodes,
dimensions and metadata checks passed. This work ran in the cloud workspace,
not on Suazo PC or the laptop.

## Delivery

- Inputs remain untouched in `../new-instagram/` and are not copied into public
  static assets by this change.
- New deployable files are only
  `../snapshot/build-inputs/static/editorial/{post-id}-{width}.{webp,jpg}`.
- `editorial-provenance.json` links each derivative to its exact original hash,
  source post URL, source owner attribution, width, height, bytes and SHA-256.
  The owner verification is inherited from the supplied transfer manifest,
  not a new live verification of Instagram ownership.
- `prepare_editorial.py` is the reproducible serial converter. It performs no
  network access. Only the allowlisted six original JPEGs are read.
- `conversion-log.txt` records the completed conversion and per-file dimensions
  and byte sizes.

| Photo / intended role | Original pixels | Responsive widths |
| --- | --- | --- |
| `DdXjMXIFHwT` — lead silver/nude gown | 2400 × 3196 | 480, 640, 960, 1440 |
| `Dd-ETr6BL2V` — supporting pink gown | 1320 × 2347 | 320, 480, 640, 960 |
| `DdwJTglRMBn` — supporting purple gown | 1320 × 2347 | 320, 480, 640, 960 |
| `DeSHKZPKTNp` — white lace gallery | 1320 × 2347 | 320, 480, 640, 960 |
| `DeSG5J1KzHb` — white bridal ballgown gallery | 640 × 1136 | 320, 480, 640 |
| `DbZdVj6q2vn` — pink ballgown rear-view gallery | 640 × 1136 | 320, 480, 640 |

The two 640-pixel originals should remain modest: preferably no more than
320 CSS pixels wide for a 2× display, and never the lead hero. The white bridal
source is visibly softer than the other supplied images. No derivative can
restore detail that is absent from the original.

## Framing and compression

The entire delivered source frame is retained. No crop, stretch, added image,
retouch, color grade or upscaling was performed. Proportions use the explicit
target width and rounded proportional height (at most half a pixel of rounding).
Source-edge framing is inherited rather than reconstructed. Rounded black
corners visible on the pink, purple and lace photos are already source pixels.

Pillow 12.3.0 uses LANCZOS downsampling, WebP quality 86/method 6 (libwebp 1.6.0),
and progressive optimized JPEG quality 88 with 4:4:4 chroma (JPEG library 6.2).
JPEG is a fallback; WebP should be the preferred `<picture>` source. At 960 pixels
wide the lead WebP is **116,874 bytes** versus **224,481 bytes** for JPEG and
950,933 bytes for the full original. All 44 alternatives together occupy
4,330,537 bytes; a page should not download every alternative.

No EXIF, XMP, comments or ICC profiles are copied into derivatives. The supplied
originals themselves had zero EXIF tags and no ICC profile. Output decodes were
checked for metadata absence; originals were hash-checked before and after.

## Actual verification performed

Executed in this cloud workspace:

```sh
python3 evidence-media/prepare_editorial.py | tee evidence-media/conversion-log.txt
```

- 6/6 original files matched the supplied SHA-256, byte count and dimensions.
- 6/6 original files remained byte-identical after conversion.
- 44/44 derivatives decoded as RGB with their expected dimensions and no copied
  private metadata.
- 44/44 derivative hashes independently matched `editorial-provenance.json`
  after generation; directory contents exactly matched that manifest.
- Actual source pixels for all six originals were viewed before conversion.
- Actual derivative pixels were viewed for `DdXjMXIFHwT-960.webp`,
  `Dd-ETr6BL2V-480.webp`, `DdwJTglRMBn-480.webp`,
  `DeSHKZPKTNp-480.webp`, `DeSG5J1KzHb-320.webp` and
  `DbZdVj6q2vn-320.webp`. They retained source identity and framing; no new visual
  artifacts that prevent their intended display were observed in these samples.
- The independent quality reviewer also compared these same six derivative
  samples with all six original photos on 2026-10-26. Source identity, face,
  frame and inherited hem limits were retained; no media P1/P2 was found in
  that spot review. This is not a visual review of every one of the 44 files.

## Integration checks still required

This is media preparation, not an integrated build or browser QA result.
The integrator must verify all actual browser decodes, `srcset` selection,
intrinsic dimensions, rendered geometry, contain fit, lead-only high priority,
below-fold lazy loading, translated alt text, and small-photo display limits.
Suggested authored Spanish/English descriptions are in the provenance manifest.
Photos are editorial only: they have no asserted product ID, price or stock.

No full build, project tests, browser run, deployment, push, inventory/payment
change, or edit to the original Cloudflare site was performed by this media agent.
Historical asset completeness remains a separate audit and is not resolved by
these six new editorial photographs.

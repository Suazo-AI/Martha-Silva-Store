# Green photograph candidate, 2026-10-28

Status: source integrated; asset review accepted; storefront build, automated
tests, real-browser review and release acceptance remain pending. This document
does not establish publication or recovery of missing photographic detail.

Base: `e2a475961a0056ac6609a86e34a2a58c05e37707`. The separate desktop carousel
candidate `fd760def920ea242a39fb7631ac5dda6e1fafc29` is excluded. JavaScript and
CSS remain unchanged from the base. Historical originals and fixtures remain
intact. The active catalog has 169 photograph positions, rather than the
historical 170, because already clipped Green G2 is omitted from the active
gallery under the existing reviewed Green contract.

## Per-photograph inventory

Coordinates are source pixels, right/bottom exclusive. Parents are the recovered
maximum WebP derivatives, not camera originals. `selection.json` records their
SHA-256 hashes, all 18 preserved source files, each of the 22 new files and its
dimensions/bytes/hash, the exact responsive lists and their expected uses.

| Photo | Parent | ROI | Native crop | Active uses / observed limitation |
| --- | --- | --- | --- | --- |
| G1 front | 800 x 1067 | 100,44,670,1058 | 570 x 1014 | Main, cards, thumb, zoom, video poster; original softness retained |
| G2 three-quarter | 800 x 1067 | none | none | Source crown already clipped; preserved but excluded, not reconstructed |
| G3 side | 800 x 1067 | 100,44,670,1058 | 570 x 1014 | Gallery, hover, thumb, zoom; smaller subject scale retained |
| G4 back | 800 x 1067 | 100,44,670,1058 | 570 x 1014 | Gallery, thumb, zoom, clone; train naturally hides feet |
| G5 detail | 432 x 576 | 0,88,432,487 | 432 x 399 | Gallery, thumb, zoom, clone; detail only, resolution limited |

The observable correction is removal of baked-in dark/cream padding, using
individually inspected ROIs. No sharpening, reconstruction, generative backdrop,
upscaling, garment reshaping or color grading was applied. Existing source blur,
compression and limited detail cannot be claimed recovered. A better authorized
original of the same photograph or a faithful new product capture is needed for
more real detail. Video frames are unchanged; replacing the poster does not
remove padding embedded in the videos.

## Reproduction and asset evidence

`cloud-variant-execution.py` is the exact executed cloud delivery recipe. Its
parent/output paths are explicit; it refuses an existing output directory and
checks parent hashes. It uses Pillow 12.3.0, RGB crop, LANCZOS downsizing only,
lossless WebP method 6 and JPEG quality 95 / subsampling 0 / progressive encoding.
Reproduction must run on an admitted image executor with the exact parents;
it has not been executed on Tony. Eleven WebP RGB comparisons passed in the
cloud executor. JPEG encodings are recompressed, not pixel-identical copies.

Native PNGs and ROI overlays are preserved in the delivery archive, SHA-256
`ef6415a1a8517edd906772da9fceaecb5c127cf9ff5a9ce74d8b7c1f10c431dc`.
The original delivery manifest SHA-256 is
`e0678fa0324a741433199ed6e11a5078e2c91997fba734feafb3ec88de15362c`.
That raw manifest retains its historical pending flags; the independent
`selection.json` approves only the four reviewed assets for source integration.
It is not release acceptance. A critic viewed all 11 JPEG variants natively;
the judge accepted the native crops and ROI overlays with the recorded limits.

## Pending release gates

Expected assembly: 926 runtime files (904 base + 22 new), 43 modified base
bodies (42 HTML + catalog), 861 unchanged base bodies. A deployment marker is
counted separately. Every file must be checked against the frozen manifest.

Required commands on a permitted executor with complete public inputs:

```text
python prepare.py
python tests/check.py --install
node --test tests/green-header.cjs tests/product-share.cjs tests/luxury-editorial.cjs
python tools/audit_assets.py --output /tmp/green-asset-audit.json
python tools/audit_assets.py --require-complete --output /tmp/green-historical-gap.json
```

The second audit command is expected to fail for the known historical 777/778
gap; retain that result. A passing ordinary audit does not prove complete
recovery. Do not modify historical evidence counts to make the candidate pass.

Real-browser checks must cover the exact built artifact, ES/EN, all four
photographs and currentSrc/body hashes, thumbs/dots, video index 4, zoom/focus,
header/hem/crown framing, cards/hover, Share/Back, favorites and a second SKU.
Compare before/after at the same viewport, DPR, browser zoom and scroll. Check
mobile/tablet, breakpoint transitions and short desktop only on actually
available surfaces. Record any unavailable coverage. Lossless variants have
higher payloads; selected bytes and lazy/zoom loading remain unmeasured.

Publish only after independent critic and judge acceptance of that exact
artifact. Recheck the live Worker/base immediately before promotion and preserve
full rollback version `efd1cceb-3e4f-43b0-bdbc-9264c13e8123`. Verify the 65
new/changed bodies and a bounded live smoke after promotion. No public QA route
or temporary deployment is authorized as a substitute for private review.

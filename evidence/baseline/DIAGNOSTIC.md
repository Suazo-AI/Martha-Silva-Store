# Green dress PDP — bounded baseline visual diagnostic

URL: `https://martha-silva-preview.martha-silva-denis.workers.dev/producto-verde-brillo-cuello-cruzado?lang=es`

Marker observed once: **e9e9609b9cda6f52abd0db1b35b570f3b83156b4 / 902 files**.
No source/runtime edits, candidate tests, or publication. Existing 39-PDP evidence remains untouched. Owned tab 10 closed.

## Findings and safe scope

1. **Most visible beige space and the black bars are encoded into G1–G4, not CSS letterboxing.** The runtime-source files visibly include beige side padding and a black video matte along the top/right/bottom. Changing only the frame background or applying generic `cover` does not safely solve this. Removing encoded matte would require a carefully bounded presentation crop or an independently verified clean source; do not stretch, recolor, invent detail, or crop the head/garment.
2. **G1 becomes obscured by the sticky header while scrolling.** At scrollY 757, G1 has sticky `top:0`, rectangle `(0,0,388.328,517.766)`. The header is also sticky `top:0`, z-index 100, rectangle `(0,0,1165,106)`. The screenshot confirms that G1's head and upper torso are behind the header. This is header overlap, not missing source content. A SKU-scoped header-safe sticky offset (or disabling that sticky behavior for this PDP) addresses this issue without changing image pixels or product proportions.
3. **G2 already has the top of the hair clipped in its encoded scene.** This exists in the local 800px source and in the browser; CSS cannot recover missing content. Preserve its content; use G1 rather than G2 when a fully intact head/full garment is mandatory.

Observed root: `main#main[data-page="product"][data-product-id="verde-brillo-cuello-cruzado"]`. Scope any parent-owned change to this SKU, not the global gallery. The `.product-detail` section itself has no product ID. Buttons have `data-gallery-index="0"` through `"4"`. The exact live-query-verified selectors are `.gallery-photo[aria-label="Ampliar fotografía 1"] img` through photo 5, each with count 1. A stable SKU-prefixed data-index selector can be composed from those observed attributes; that composed selector was not separately live-query-verified in this diagnostic.

## Per-image source comparison

| Frame | Current selected file | Source framing diagnosis |
|---|---|---|
| G1 | `01-front-full-length-480.webp` | Full head, dress hem, and shoe retained. Beige side padding plus black top/right/bottom matte. Best full-product lead among these views. Header masks its top only after scrolling. |
| G2 | `02-three-quarter-front-full-length-480.webp` | Same encoded matte. Top of hair touches/is clipped at the photographic scene's top boundary already in source; garment/hem remains. No additional CSS crop at initial page state. |
| G3 | `03-side-full-length-480.webp` | Same encoded matte; head, garment, and shoes visible. Person is smaller/farther away within the original photographic scene. Enlarging to match G1 would discard scene context; do not assume a generic crop is safe. |
| G4 | `04-back-full-length-480.webp` | Same encoded matte. Back-view head and full dress hem retained; confirmed source and scrolled page view. |
| G5 | `05-detail-crop-432.webp` | Intentional waist/skirt/slit detail, not full-person imagery. Beige top/bottom padding is encoded. Missing head/hem here is a detail composition, not CSS damage; keep labeled as detail. |

Local comparison files were the unchanged **runtime derivatives** under `martha-product-share-20261026/dist/research/assets/store-media/verde-brillo-cuello-cruzado/`: G1–G4 800×1067 and G5 432×576. They are not claimed to be original masters. Existing zoom measurements were reused, not rerun across the catalog.

## Geometry

- DOM viewport: 1180×757, DPR 1, `visualViewport.scale=1`; no resize or zoom emulation.
- Initial G1–G5 image/frame boxes: **388.328×517.766 CSS px**, `object-fit:scale-down`, centered, zero padding and border. G1 starts at `(0,175)`; G2 at `(388.328,175)`; G3–G5 continue down the right rail.
- Density-corrected natural dimensions: 393×524 for all five selected responsive images. These are recorded separately from encoded file headers.
- Selected encoded sizes: G1–G4 480×640; G5 432×576. Local SHA joins are in `selected-image-frame-join.json`.
- Since the density-corrected intrinsic dimensions exceed the boxes, `scale-down` resolves to its contain branch. The full encoded canvas paints at approximately **388.324×517.766**. Computed CSS horizontal letterbox is under **0.004 px total**, vertical zero. Thus the large beige strips/black matte are inside the image canvas, not gaps between its CSS frame and its painted canvas.
- The approximate threshold scan in `encoded-padding-analysis.json` supports the encoded-padding diagnosis, but compression-edge values make its bounds **unsuitable as an automatically approved crop**. Visually, the 800px G1–G4 canvases have roughly 100px beige sides; the scene runs about x100–670 and y44–1058, with matte to its right/top/bottom.

## Evidence

- `baseline-initial.jpg`: normal-scale initial state, G1 and G2.
- `baseline-scroll-g3.jpg`: normal scrollY 757; proves G1/header overlap, with right rail transitioning G3→G4.
- `baseline-scroll-g4.jpg`: normal scrollY about 1098; full G4 scene and start of detail.
- `live-baseline.json`: marker, exact URL, initial currentSrc/natural dimensions/frame/fit/loading measurements.
- `scroll-header-geometry.json`: measured sticky/header overlap.
- `selected-image-frame-join.json`: currentSrc → runtime path → existing manifest SHA/header dimensions, plus supported scale-down contain geometry.
- `encoded-padding-analysis.json`: read-only decoded-pixel statistics on this SKU's 9 WebP variants only.

CUA returned screenshot rasters of 1165×747 while DOM viewport readings were 1180×757. No manual scaling was applied. Do not equate screenshot raster coordinates to CSS pixels; use the recorded DOM geometry for exact layout measurements. No source image was modified.

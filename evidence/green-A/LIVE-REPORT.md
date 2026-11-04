# Green A live verification

**PASS — observed desktop scope.** No material Green A geometry failure found.

Live marker matches source `704b2e160106b709880ad7c22febd25adb6181d6`, 902 runtime files, expected app `8ee8deb…` and CSS `955550d…` hashes. These are browser-read deployment-marker values, not raw response-body hashes.

## Before → after at identical observed state

URL: `https://martha-silva-preview.martha-silva-denis.workers.dev/producto-verde-brillo-cuello-cruzado?lang=es`

Viewport **1180×757, DPR1, visualViewport.scale1, scrollY757**:

| Measurement | Baseline e9e9609 | Green A |
|---|---:|---:|
| Header bottom | 106 | 106 |
| Lead frame top | 0 | **106** |
| Lead frame bottom | 517.765625 | **623.765625** |
| Lead frame width × height | 388.328125 × 517.765625 | Unchanged |
| Header overlap height | 106 | **0** |

`after-scrollY757.jpg` visually confirms the lead photo's complete head and hem are visible below the header. `before-scrollY757.jpg` is the unchanged earlier diagnostic screenshot of the same viewport/scroll state. Initial-state before/after screenshots are also retained.

Exact verified selector:
`main[data-product-id="verde-brillo-cuello-cruzado"] .gallery-photo[data-gallery-index="0"] img`

The same `01-front-full-length-480.webp` is selected and complete. Encoded dimensions remain recorded as 480×640 from the existing verified photo ledger; browser natural dimensions are 393×524. Supported scale-down/contain geometry gives a full encoded-canvas rectangle approximately 388.324×517.766 at y106. No stretching or CSS cropping was observed. This does **not** claim baked matte, G2's source hair clipping, or blur has been fixed.

## Secondary checks

- Green lead computed `top:106px`, `max-height:651px`. Actual height517.766 does not hit the cap. **Short-height cap remains unexercised live**.
- All five green image buttons have `scroll-margin-top:106px`. Clicking thumbnail3 targets G3 correctly; the resulting G3 frame is fully below the header, top238.766/bottom756.531, with the thumbnail retaining focus. Its 480-WebP is complete.
- Share can be reached by Tab from the preceding favorite control. Keyboard Return copies the exact product URL to the clipboard and retains focus on the Share button. No outbound destination opened and no message sent.
- Initial pointer activation showed “Enlace copiado” but returned an empty documented clipboard read and BODY focus. This anomaly is preserved in `share-check.json`; it is not silently counted as a successful copy. The separate keyboard activation's real URL/retained focus are recorded in `share-keyboard-copy-check.json`.
- One other SKU, `rosa-empolvado-pedreria`, retains baseline initial dimensions/source and at scrollY757 still has lead top0, max-height none, and scroll-margin0. This verifies the observed green-only scope, not a global layout fix.

## Limits and evidence

Mobile and short-height live validation are **pending** under the no-forced-resize/no-emulation constraint. Only the supported actual viewport was exercised. No source edits, new deployment, alternate HTTP client, data URL, or pixel transformation occurred. Marker was read once; selected filenames are unchanged, but image response bodies were not newly hashed.

Files: `initial.json`, `scrollY757.json`, `rail-thumbnail-3.json`, Share checks, `unaffected-rosa.json`, before/after screenshots, `verification.json`, and `artifact-manifest.json`.

CUA returned normal screenshot rasters1165×747 while the DOM viewport was1180×757; no manual resizing was applied. Exact geometry is from DOM measurements, not screenshot-pixel assumptions.

Owned cloud tab12 was closed after verification.

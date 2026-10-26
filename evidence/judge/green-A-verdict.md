# GREEN cut A — bounded source/static acceptance

2026-10-26 06:08 UTC. Candidate: `/workspace/scratch/14cff504045e/martha-green-occlusion-A-20261026`.

**PASS at source/static fidelity level for the desktop green-PDP sticky-header occlusion fix. No source-level blocker found. This is not rendered/browser acceptance or a global photo-quality approval.**

## Independently checked
- Full902-path dist comparison against current share/e9 copy: only `app.js` and `styles.css` differ. All780 raster paths, catalog and all47HTML paths are unchanged.
- Source app SHA `8ee8deb77dd6608023f0d315c2451aafa248f58e77658b881717e9de09470ba8` and CSS SHA `955550d32bc9b1fb1c826abf30b65730e41fc0074a932a2d66276c08d37f0189` match the freeze and dist bytes.
- App adds only measured sticky-header height to the existing initial/resize/ResizeObserver sync function. Other banner/language/integration rows are not included in that new sticky-only measure.
- New CSS is scoped to desktop≥1024px and exact `main[data-product-id="verde-brillo-cuello-cruzado"]`. It adds scroll margin to gallery photos and sticky top/max-height to the direct lead photo. It does not introduce global cover, transformations, stretching, source substitutions or zoom changes.
- Existing `.gallery-photo img,.gallery-clone img{object-fit:scale-down;object-position:center}` remains in force. A constrained container therefore does not newly crop the source via cover, although actual used box/painted dimensions need browser verification.
- Read the actual terminal full-check log:139 cases pass. Focused r2 log:6/6 DOM/static checks pass. No suites were rerun by judge. Preserved first focused log5/6 failure was the test pattern matching `width:` within `min-width:1024px`, not a demonstrated production width override.

## Accurate claim
“Desktop green-gallery sticky offset and box-height cap account for the measured sticky header.”

The source comment “No image or sizing changes” is imprecise: image bytes are unchanged, but the max-height cap can change the desktop container and painted image size. Do not repeat that comment as a result claim.

## Still pending / excluded
- **Actual rendering:** no candidate-native-browser screenshots or computed/painted geometry were available to this judge. Parent's controlled integration/release procedure and subsequent live verification remain parent-owned. Verify the exact delivered hashes, scrolled lead crown below header, complete visible hem, normal and short desktop windows, a header-height change, rail-photo scroll targets, and mobile/otherSKU regression. DOM simulation is not that proof.
- **Unchanged existing issues:** no baked matte/black-border removal, no G2 source-cut exclusion, no ROI integration, no blur recovery, no detail-photo suppression, no otherSKU fix. These remain separate tasks; do not present A as satisfying all photo instructions.
- **Scope:** no catalog products deleted or added, no AI preview integrated, no new external-source/authenticity claim.

Numerical evidence: `green-A-source-check.json`.

## Explicit narrow release decision — 06:09 UTC

**ACCEPT GREEN A for a controlled release, conditional on immediate post-activation CUA verification and rollback to the prior version for material failure.** Parent states publication of this reviewed green fix is already authorized and owns activation/rollback. The judge finds no concrete source-level blocker: the diagnosed baseline106px occlusion, exact bounded two-file delta, preserved image fitting/source bytes,145 distinct passing checks and full902-path comparison justify this limited risk-managed release.

This decision does not convert the pending browser check into a pass. Before reporting the fix successful, confirm delivered app/CSS identity; desktop scrolled lead head and visible hem; rail scroll targets; Share; and mobile/otherSKU regression. Material failure means, for example, persistent new occlusion, clipping/distortion of garment/head, broken gallery controls/share, or out-of-scope layout regression. Roll back rather than silently broadening the fix.

No B/ROI, AI-image, headcut suppression, product removal or catalog expansion requirement is imported into this A decision. Conversely, this A decision clears none of those independent tasks.

### Supported-browser condition clarified — 06:11 UTC
Parent confirms the authorized cloud browser is fixed at1180×757 and exposes no supported resize/mobile API. **Mobile and short-viewport actual-browser checks are explicitly pending, not hard prerequisites for this bounded controlled release.** No emulation, devtools or unsupported workaround is requested.

Required immediate post-activation evidence is the supported1180×757 desktop: delivered app/CSS hashes, scrolled lead crown/visible hem, rail targets, Share and an otherSKU regression check at that same viewport. Roll back for a material failure there. The exact media-query/SKU source isolation supports unchanged mobile rules, not real-device proof. If the new max-height cap is inactive at this viewport, its short-viewport behavior remains unexercised and must not be called visually validated. This clarification narrows the earlier suggested viewport test list; it does not invent missing coverage or broaden the release scope.

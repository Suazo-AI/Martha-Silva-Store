# Martha product-share live browser verification

Observed 2026-10-26 04:25–04:30 UTC on the existing main published origin, using a single owned cloud Chrome tab (6). No alternate QA route, localhost, user-computer access, purchase, real data, outbound social share, or recipient action.

## Release gate — PASS
Browser-read `/deployment.json`:
- SHA `e9e9609b9cda6f52abd0db1b35b570f3b83156b4`
- Runtime files: 902
- app.js: `d381978579b3558fe49cf5ab103c4bf52a3debb38b14bc824efd9399f7d48959`
- locale-en.js: `9f779e3ba5099a9399a357e70c85e063001742febc3918aa79e2ea81e89ff4b2`
- styles.css: `e0a002902eace0d8b9734f8b4473a1f6e7e29ba629522799aef5eae326a1256a`

Parent-supplied deployment ID: `205cf823313b46678779b08957424bd5` (activation was owned by publisher, not this audit).

## Actual viewport
innerWidth 1180, innerHeight 757, DPR 1, visualViewport.scale 1. Saved full-viewport `getScreenshot` PNGs are tool-scaled to 1165×747. No mobile, high-DPR, or alternate browser claim.

## Browser checks — PASS
- `/producto-novia?lang=es` displays **Compartir producto**, a real button with tabindex 0, enabled, minimum measured height 44px.
- Share control is the immediate sibling after the product form, directly beneath Add to bag / Favorites controls. Its location at the initial fold was y722–766 CSS px; keyboard focus scrolls it fully into view.
- Natural keyboard Tab order was verified: Favorites → Compartir producto. Enter activates the share button and returns it enabled.
- ES visible live status: **Enlace copiado. Ya podés compartirlo.** Status element uses `role=status`, `aria-live=polite`, `aria-atomic=true`.
- Language control changes document to `lang=en`, URL `?lang=en`, button to **Share product**, and response to **Link copied. You can now share it.** English Enter activation also succeeds.
- Actual copied URL payloads were verified using Control+V into the page's local search field **without submitting**; test text was then cleared and search closed:
  - ES: `https://martha-silva-preview.martha-silva-denis.workers.dev/producto-novia.html?lang=es`
  - EN: `https://martha-silva-preview.martha-silva-denis.workers.dev/producto-novia.html?lang=en`
- Both payloads are clean product URLs, with only the appropriate language query and no fragment or session/order/tracking parameters.

## Limits (do not overclaim)
- No native OS share sheet was observed. Actual browser path reached clipboard-success UI. Native OS/app sharing remains unverified; no outbound action was attempted.
- Manual-copy fallback remained hidden because clipboard copying succeeded naturally. Its failure path is not claimed as live-browser verified; no API monkey-patching or simulated failure was used.
- Direct documented clipboard.readText returned empty despite successful app write. The safe, non-submitted Control+V check independently verified actual payloads; do not report the connector's blank as app failure.
- Read-only DOM evaluation does not expose navigator here; attempted feature inspection errored and was dropped. No conclusion about native navigator.share availability is drawn from that tool limitation.

## User-requested real screenshot
`share-es-user-picture.png` is the unmodified real published-page screenshot, with focus ring on Compartir producto and copied-message visible below it. No generative recreation or site alteration.

Button at capture in CSS coordinates: x824.65625, y356, width155.453125, height44. In tool-scaled 1165×747 screenshot, approximate button region x814–968, y351–395; center near (891,373). Caption: **Está debajo de «Guardar en favoritos»: «Compartir producto».**

Other evidence: release-marker.json; share-es/en-initial/after JSON and PNGs; share-es/en-clipboard-paste.txt; share-tab-order.json.

Owned tab 6 closed after evidence capture. This report verifies only the product-share release, not the paused photo-quality candidate.

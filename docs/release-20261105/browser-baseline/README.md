# Browser baseline returned to primary

Task `savia-browser-baseline-20261105`, VALIDATE. Worker return, not acceptance or READY.
Source HEAD `6f304a7571a554bb8968e081a14985829aee3dfb` matched the assignment.
SUAZO-PC, Codex `gpt-6.1-sol`, requested/effective high per session runtime and awareness metadata.
T3-managed worktree `C:/Users/Jason/.t3/worktrees/github/t3-f0b6371f`; clean initial status.
Chrome `156.0.8078.80`, Playwright `1.62.1`, installed dependencies only.

## Observed

One sample per route/condition. CSS viewports 360x800 and 1366x768, DPR 1; no physical-device emulation claim.
Normal samples waited for load plus 5 seconds without scrolling.
Completed CDP network bytes include protocol overhead; Resource Timing bytes and selected-image dimensions/bytes are recorded separately.
Pending or unrequested resources are excluded. This uncompressed loopback server does not reproduce production delivery.

| Route | Mobile completed network bytes | Desktop completed network bytes | Normal response/layout |
| --- | ---: | ---: | --- |
| /index.html | 35,195,193 | 47,249,267 | 200; no horizontal overflow |
| /catalogo.html | 36,407,867 | 53,423,091 | 200; no horizontal overflow |
| /producto-amarillo.html | 29,882,466 | 29,882,466 | 200; no horizontal overflow |

All six normal samples had zero observed page errors and failed requests.
Passive final mobile LCP candidates: 424 / 568 / 772 ms, respectively; no layout-shift entries in these windows.
These are local passive candidates, not field CWV or Lighthouse results. Representative INP is NOT RUN.

JS-enabled catalog control reached `/producto-amarillo.html?lang=es`.
The exact-path verifier excluded the query and timed out after 10 seconds; destination DOM confirms arrival.
Classify this as a verifier error, not a demonstrated navigation defect; do not rerun to hide it.
The native no-JS catalog link reached `/producto-amarillo.html`, HTTP 200.

All three no-JS pages exposed readable text, native internal anchors and the visible warning:
“Activá JavaScript para elegir una talla y completar la compra de prueba.”
Warning rectangles were 360x60. Other native links were inventoried, not exhaustively clicked.
Size selection and purchase are unavailable without JS; commerce support was not claimed or transacted.
No-JS completed network bytes were 179,634,794 / 170,171,264 / 170,252,784.

CDP accepted 50,000 bytes/s down and up, 400 ms latency, and CPU slowdown rate 6.
This configures 400 Kbps down; effective physical throughput was not independently calibrated.
All three degraded samples received document HTTP 200 but timed out waiting for load at 40 seconds.
Completed bytes: 1,163,504 / 506,119 / 1,004,346; incomplete in-flight resources are additional, uncounted demand.
Readable DOM and zero horizontal overflow were observed at timeout; this is not a speed pass.

Warm offline reload reused each original normal-mobile page/context after the later groups.
All three reloads failed with `net::ERR_INTERNET_DISCONNECTED`, zero completed bytes.
No service-worker controller was observed on normal pages. Cache/SW defaults were retained.
Offline failure is observed behavior, not an acceptance failure; offline operation was not required.
No transaction was attempted, and offline app DOM inspection was unavailable after failed navigation.

## Two demonstrated priorities

1. Initial viewport image demand is large. For example, mobile index selected `champagne/01-front-v1.png`: 2,285,034 body bytes, 2,285,334 Resource Timing transfer bytes. Actual selected PNGs dominate the waterfall across all three routes. Smallest next path: authorize responsive derivatives for measured images, preserve provenance, and compare the same views/windows before and after. Owner: frontend/assets. Correction attempted: none, validation-only authority.
2. Degraded loads exceeded 40 seconds on all three routes. Smallest next path: reduce the measured initial image demand, then repeat this bounded profile on the authorized changed candidate. Owner: frontend/assets. The exact contribution of images versus other requests under throttle remains unisolated; no universal speed threshold was invented.

## Evidence and commands

- [RESULT.json](RESULT.json): structured observations, gaps, commands, private evidence paths/hashes and limitations.
- [source-manifest.json](source-manifest.json): 2,171 inputs including all dist, src and static input files, plus build/config/reference/driver sources.
- [driver.mjs](driver.mjs): evidence-specific driver; SHA256 `7353a4f88e2451e10f57082147aea4000a9acaaaae290f5ac8fff98c308935d2`.
- [summarize.mjs](summarize.mjs): moves full observations to the private directory and produces the compact return.

From this worktree: `node docs/release-20261105/browser-baseline/driver.mjs` exited 0.
Then `node docs/release-20261105/browser-baseline/summarize.mjs` exited 0.
Driver elapsed 213,682 ms; 17 conservatively counted navigation actions, within the 18 limit.
Every one of 692 served-file entries matched frozen dist hashes; all 2,171 frozen files remained unchanged afterward.
SHA256 uses exact filesystem bytes without CRLF/LF normalization; it does not assert raw-byte identity with Git blobs.
Source manifest SHA256: `aa0f687ecc7f17d8a3faebde2598b7ffb676ae6ee905913f51f463fe982f2b7a`.

Private raw files remain only under `C:/Users/Jason/MARTHA-SILVA/test-runs/browser-baseline-20261105/t3-f0b6371f/`.
`observations.json` SHA256: `8da2920d22e150e6efc237a37d303fa3f86e4f8288466493fcb0cd829f584291`.
`server-log.json` SHA256: `556ea8a11fb270bc8d2fa331557b51b01ec4c90515405774365e296565bea911`.
No browser profiles were retained. No screenshots/video were needed for these DOM/network findings.
Proxy denied external destinations and non-GET requests. Chrome and the ephemeral 127.0.0.1 server closed in finally.

## Gaps and next action

Production delivery, devices, other browsers, accessibility/visual acceptance, field CWV/INP, payments, external submissions, staff/backend/N5 and SQL are NOT RUN.
No product files, parent checkout/index, staging, commits, pushes or deployments were changed.
Cost/tokens are unknown; no paid APIs, installs or browser downloads were used.
Tooling gaps and the resolved UTF-8 summary-read error are retained in RESULT.json.
Lesson applied: classify destination observations separately from a strict URL predicate; retain the failed verifier and do not manufacture a passing rerun.
Primary should directly inspect RESULT.json and its private raw bindings, then decide whether to authorize the smallest image change.

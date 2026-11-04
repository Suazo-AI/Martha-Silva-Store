# Local original-media review

Date: 2026-10-24. Browser: local Google Chrome, headless CDP, isolated profile. Source: recovered authorized mirror served only on 127.0.0.1:8011. No remote browser navigation, web-security bypass, original-site mutation, or deployment.

- `node media-qa.mjs`: completed; 725/725 images decode successfully, all with natural dimensions. `image-decode-result.json` records every relative path and dimension.
- Nine contact sheets capture all 170 active gallery positions; every image decodes. All nine screenshots were visually inspected: garments and cropped garment details visible, no broken placeholders. Historical SAMPLE labels remain explicit.
- `node video-qa.mjs`: completed; 52/52 MP4/WebM load and produce a canvas frame at recorded currentTime=0 with nontrivial pixel range. `video-decode-result.json` records dimensions, duration, recorded currentTime, and pixel range. `video-contact.png` was visually inspected across all52 initial frames; garments visible and consistent.

Review scope supports import of the previously permitted HTTP-200 media allowlist. It does not authorize replacing the absent legacy404 or claiming commercial inventory, production integration, copyright verification, full-resolution manual review of every derivative, midpoint-frame verification (the harness requested a seek but all52 recorded times were0), complete video playback/audio QA, accessibility, mobile app behavior, or performance results.

Reproduction: run a loopback Python HTTP server rooted at `../original-mirror-staging` on port8011; launch Chrome with a dedicated profile and CDP bound to127.0.0.1:9223 (normal security/sandbox); run both `.mjs` scripts with Node24. Scripts save JSON reports and screenshots here, outside repository inputs.

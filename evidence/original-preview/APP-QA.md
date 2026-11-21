# Local browser QA for original storefront preview

Date:2026-10-24. Source served only at http://127.0.0.1:8010/; isolated Chrome profile, Chrome/156.0.8078.47. No original-site changes, Cloudflare calls, remote application writes, or deployment by this reviewer.

Outcome:99/99 broad browser checks passed, then7/7 focused checks passed after the final hover-video correction. No functional blocker remains in this scope. The broad run preceded that last app.js edit; the final check was targeted, not a second complete47page run. Original HTML/catalog/CSS hashes are identical across these phases.

## Broad run, before final hover restoration

- All47 templates mount at1440x1000 and pass layout checks at390x844 mobile emulation; no horizontal document overflow. No uncaught runtime exceptions, unexpected external requests, or final broad-run HTTP errors.
- Catalog40products; real filter dialog, color filter, and browser Back returning40results.
- Product photo opens native zoom dialog and decodes; native size/add/bag interactions work.
- SAVIA1line -> SISFAIN0lines -> add SISFAIN1line -> SAVIA1line after navigation. Separate carts and explicit local-simulation wording.
- Mobile native menu opens/closes; gallery next changes actual scrollLeft and active dot.
-8816 local href occurrences across47 pages: zero missing local files or fragments. Four social URLs recorded only, not followed.
- Pixel review of desktop home/product/bag and mobile home/catalog/product/menu/gallery/bag/checkout/video screenshots. All47 mobile screenshots saved; manual pixel review limited to the stated subset.

Broad app.js SHA-256: `4661fd969305839c61e945f6502be183c5b0f05340fc1dc208b0a46c68fbd040`. Every broad HTML hash is in `app-qa-result.json` -> `hashes`.

## Final focused run, after hover restoration

- Real pointer entering a product card starts its recovered WebM, readyState4/currentTime1.1133s; leaving pauses it.
- Reduced-motion emulated in Chrome blocks hover loading: src=null, paused=true, time0.
- saveData=true simulated through navigator.connection getter likewise blocks loading. This is a preference-guard test, not a physical network-saving mode certification.
- Native manual gallery control remains paused/time0 until clicked; real play click yields readyState4, paused=false, time1.9254s of6s. No play by intersection or page mount.
- Three final targeted mode/menu/gallery checks pass again; settled mobile menu x0,width390, headingx16. These are in addition to the three hover checks and one manual playback check.

Final SHA-256:

- app.js: `b0d5b729c6888c690ce940a8d3da8a94fcadc8b324301d587ca43a043cf215f8`
- catalog.js: `c2d5ed59e03dd68b8e279a33bbce27f120ddb0ca29ff260bb2ec38bdf2df726f`
- index.html: `90b4e3f4520888678300e3bb5d01cf7c9412137d0f2727791d1ee38e427c8a08`
- producto-rosa-empolvado-pedreria.html: `8ba0961c91b0c34b51fd5e3a756f74f4bd597c7964ca1b9994a9e52934158f3e`

Complete final hashes and focused evidence are in `app-qa-result.json` -> `final_hashes` / `final_focal`.

## Commands and source scope

`node app-qa.mjs` produced the99check broad result. `node hover-qa.mjs`, `node manual-video-qa.mjs`, and `node targeted-qa.mjs` produced the final focused results; `python links-qa.py` checked hrefs. All scripts/reports/screenshots are outside repository inputs in this folder. `MEDIA-QA.md` documents725image decodes,170gallery positions and52video frames; their recorded video frame times are0, so midpoint review is not claimed.

Only owned sources changed during this follow-up:25 PDP templates defer src to exact data-src/data-webm, and app.js hydrates visible controlled videos without auto-play while restoring original reduced-motion/saveData guards for pointer hover. Hero stays a photograph. Parent regenerated dist; reviewer never edited dist. Node syntax and owned Git diff whitespace checks pass.

## Limits

Chrome emulation is not a physical mobile device or Safari/Firefox test. No accessibility audit, performance benchmark, native BFCache certification, blocked-storage browser simulation, real backend/payment/fulfillment/inventory claim, or exact screenshot comparison against a live original is made. Previous DOM tests cover storage/BFCache separately.

The first exploratory load saw optional implicit favicon.ico404; the repeated broad run reused the isolated profile cache and emitted no HTTP errors. No favicon source edit was made. Hero has no video; card hover requires pointer interaction and gallery play requires the native control.

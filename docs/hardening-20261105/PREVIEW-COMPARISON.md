# Public preview comparison — 2026-11-05

Host SUAZO-PC. Primary: T3 Code / Codex / gpt-6.1-sol, xhigh.
Canonical HEAD: 6d8d53c964ca07cf173e3683a7660624d955aa4c.

## Read-only findings

- Denis: https://martha-silva-preview.martha-silva-denis.workers.dev/
- Jason: https://martha-silva-demo.jason-suazof.workers.dev/
- Both returned HTTP 200 for home, app.js and styles.css through a normal browser.
- Denis's index.html and app.js match their LF-normalized Git blobs at c4e0e48ab60dd7e7fb3aabb2169844a09543e640, dated 2026-10-30T23:52:08-05:00.
- Denis's styles.css and catalog.js match current canonical files. Its home and app.js differ from current HEAD.
- Jason's queried deployment: 380c6c64-cb2e-4b6a-8631-cb1a466c6e23, version 77bffec9-e5bc-4f56-9596-6c5b4057463f at 100%, created 2026-10-30T04:57:39.812425Z.
- Jason's source commit remains unidentified. Its home/app/styles differ from canonical HEAD. catalog.js returned 404.
- Neither published deployment.json was present (both 404). Do not infer an exact published source SHA.
- Jason serves CSP and nosniff; Denis's four sampled 200 responses expose neither header.
- Neither page overflowed horizontally in sampled browser DOM at 390px. This is not physical-device acceptance.

## File SHA256 (LF normalized)

| Site | File | SHA256 |
| --- | --- | --- |
| Denis | index.html | 6e96ebba9772d9317740d071110f6aba6300f7cdc8b5187bd17b4c22b262b31e |
| Denis | app.js | 40cb7c411d9bf52ae4de19ac79b34a9ad43b6f0d0977fdcc90e96446e45e3da3 |
| Denis | styles.css | 9d7cb94e0e57c89fa884294de04a0baf8bfd1362ddc4de9a45aa2939a79ca679 |
| Denis | catalog.js | 1495e8a10a2cde56ddb0087051c327949389f775977f41b7d4b676f37f3cd343 |
| Jason | index.html | 0c1821ee1e05620ed24ef1b8704cf302fd7a6a566126a73e703a3ec95c56f46a |
| Jason | app.js | 82cece2c36322d20ceab2303c88a58c920d6b10c698d0de490e7f4afb6b41adc |
| Jason | styles.css | 424d8e5757b3c1f4d01be66d2c35ab717d73f01a8ff37283fd62eb36c3fe4892 |

## Visual recommendation, separate from measured facts

Jason's explicit correction supersedes the primary's earlier recommendation: use Jason's style, layout and frontend.
Keep only the images from Denis. Denis's editorial composition is not the selected frontend.
Integrate that combination into the current project, preserving working behavior and responsive assets.
Use a new preview in Jason's account, preserving both existing publications (D-030).
The existing publications remain preserved. No remote mutation has occurred yet.

Desktop 1280x800: Denis has an editorial layout with explicit CTA and three dress images. Jason shows a full-width carousel.
Mobile 390x844: Denis shows the same hierarchy. Jason displayed a timed discount modal that obscures the storefront.
This is a design judgment, not conversion evidence. Both are simulated storefronts; no payment or real inventory acceptance.

## Browser failures and correction

T3 desktop snapshots succeeded. Mobile snapshots failed twice per tab with:
`Preview snapshot failed: Preview automation snapshot timed out after 15000ms.`
Switched under the browser fallback rule to chrome-devtools-axi after suazo-axi doctor exit 0.
Native window resize returned 504x844 instead of 390x844; explicit `emulate --viewport 390x844x1` succeeded.
Mobile screenshots were inspected. A subsequent attempt to dismiss Jason's modal returned exit 1; that dismissal is not accepted or used as evidence.
All four owned browsing tabs were closed; the pre-existing selected Chrome page was restored. No global browser stop was issued.

Screenshots and interactive comparison are private local evidence:
`C:/Users/Jason/MARTHA-SILVA/test-runs/hardening-20261105/comparison.html`.
Simplified plain-English version: `C:/Users/Jason/MARTHA-SILVA/test-runs/hardening-20261105/comparison-plain-english.html`.
They are not build inputs. No credentials, cookies, customer data or private conversations imported.

NOT RUN: physical devices, full checkout, real API/SQL/payments, accessibility certification or production acceptance.

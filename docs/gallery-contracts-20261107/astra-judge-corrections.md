# REVISE — two bounded verification corrections

Advisory review complete. Primary owns acceptance and serial integration. No new product defect is established. Preserve the chosen Jason storefront, Denis imagery and independent SQL work.

Task: `savia-gallery-outcome-judge-7bce17f-20261107-01`; mode VALIDATE; status returned.

**Identity.** SUAZO-PC / Windows / T3 Code / Codex. Requested `gpt-6-astra`, `reasoningEffort:xhigh`; runtime instructions and agent-awareness expose `gpt-6-astra/xhigh`. Provider usage, tokens and billing: unknown. No delegation. Review ran approximately 10:55–11:02 UTC, 2026-11-07, within 20 minutes.

**Exact candidate.** `C:/Users/Jason/MARTHA-SILVA/github`, HEAD `7bce17f65b6a49b64443349d76f3a98b76e4b347` plus frozen overlay. All paths below refer to that candidate unless marked judge scratch. My managed worktree has the same committed HEAD; its old tests were not used.

`primary/CANDIDATE.json` RAW SHA256: `887aa3c93db9ed9e3e67d80511ee93a7c3473a6de7cc0229f7a7251017520f88`.
All **23/23 entries matched at start and end**, including byte lengths, RAW hashes and declared CRLF-to-LF hashes. UTF-16 logs remained RAW. All **6/6 IMPORT product bindings** match the worker; `dist/app.js` and `dist/styles.css` also match their current inputs. The committed delta from `c5ee743` contains only supply BOM/docs/progress changes.

Reviewed test hashes:

- `tests/desktop-gallery.cjs`: `58258777f44e7c48827584129cf5dba3b7537ee307485896962ddc18fcd68c7a`.
- `tests/gallery-browser-contracts.cjs`: `5dd68125720a09c9a2b5b387c1c2f8dfefd42af13fd638c04769509de0bbcc94`.

Original rejection RAW hash independently matches `50b69c56d7491668a5e104ced4ca297afccfdddcae9f416d12e6eb1d92d239a7`.

## Necessary corrections

**F1 — Medium: the required desktop keyboard viewport was not exercised.**
`tests/gallery-browser-contracts.cjs:284–298,313` resizes the desktop page to **1440x900 before keyboardJourney**, without restoring 1280x900. Repro: follow those calls and inspect `primary/browser/browser-contracts.json`: initial resource width 1280, resized width 1440, then the journey. The PNG named `browser-contracts-desktop-1280x900.png` is **1440x900**. Its gallery content is real, but its viewport label is wrong. Mobile's 780x1688 pixels correctly represent 390x844 at DPR2.

Impact: acceptance 4's **1280x900 keyboard journey** remains unproven; acceptance 7's viewport attribution is inaccurate. Existing desktop keyboard evidence proves 1440x900. Necessary correction: run the journey before resize, or explicitly restore 1280x900 afterward. Assert and serialize actual journey dimensions; capture the correctly labeled screenshot. Primary owns correction and one focused 1280x900 recheck. No product/layout change is needed.

**F2 — Medium: a replacement fetch can satisfy the browser-delivery gate.**
`tests/gallery-browser-contracts.cjs:112,118–129` uses `context.request.get(currentSrc)` when the browser-response map has no entry. `assertResource` accepts that result without checking its origin.

Repro: judge scratch `resource-origin-probe.cjs` extracts the exact candidate functions. The observed-response control passes without a fetch. An empty response map plus a successful mocked replacement fetch also passes, with `response.source="context.request"`. Exit **0** confirms the reproduced verifier blind spot; no HTTP occurred.

Impact: a future green result can establish resource availability without establishing browser delivery. **The existing primary measurements did not use the fallback**; their actual response evidence remains valid. Necessary correction: require an observed browser response for acceptance, with explicit origin. Keep any replacement request diagnostic only. Primary owns correction; completion requires the missing-observation control to fail and the observed-response control to pass. Product bytes stay unchanged.

## Earlier objections and dispositions

| Original objection | Current disposition |
|---|---|
| 1. Absence assertions/equivalence | Resolved for the frozen controls. `tabindex-zero` and measured `430px` both pass; assertions permit native or optional navigation outcomes. |
| 2. Keyboard bypass/focused photo | Real Tab/Shift+Tab/Enter/Space/Home/End now run; photo-scroll then Tab and zoom activation are exercised. Desktop viewport gap remains F1. |
| 3. Self-comparing sizes | Original tautology resolved. Independent hint bounds reject `1px`; actual dimensions/DPR/currentSrc/responses support present selections. Response-origin sensitivity remains F2. |
| 4. Attribution/screenshots/index claims | Historical judge authority is disclaimed; worker versus corrected primary evidence is separated. Screenshots show galleries. Four-slide binding and ten-failure arithmetic are accurate. Desktop viewport attribution remains F1. |

| Historical ID | Independent adjudication |
|---|---|
| DG01 | Selection, control focus, gallery-only scrolling and photo access supported; required 1280 keyboard evidence pending F1. |
| DG03 | Actual focused-photo scroll reaches index 2; retained photo goes off-screen, next Tab reaches a visible photo and keyboard zoom succeeds. This supports usability at the exercised sizes, not universal accessibility. F1 remains. |
| DG04 | Resize/index/no-feedback simulation retained. Actual resource selections justified below. Gate hardening requires F2. |
| DG06 | Required Space, Shift+Tab and video paths now throw on failed checks; outer catch records failure and sets nonzero exit. Modified/media isolation observed. Native Home/End are permitted; no custom handler required. F1 remains. |
| DG10 | Pending-destination race, interruption and derived wrap/last/previous checks retained. Real arrow Enter/Space outcomes supported at 1440 and 390. F1 remains. |

Versioned expectations are historical text, not acceptance. This review independently evaluates the observations; unsupported inference alone does not close an ID.

## Verified evidence and limits

Retained logs independently recount: baseline **14/14**, bad-sizes **11/14** with **3 failures**, no-activation **4/14** with **10 failures**, tabindex-zero **14/14**, measured-sizes **14/14**. Their retained `CONTROL_RESULT` exits are **0/1/1/0/0**. These are reused executions, not fresh judge DOM runs.

Corrected primary browser JSON records **2 runs, 0 failures**, zoom open/source/Escape/focus-return true, video reached in both runs, and zero blocked/failed/HTTP-error entries. Resource evidence: desktop 720w, HTTP200, **86,518 bytes**; mobile DPR2 1024w, HTTP200, **140,962 bytes**. Independently read source files measure **360x540, 720x1080, 1024x1536**. Rendered bounds and selected candidates are consistent. Geometry, wrap/video, resize, race/interruption, history simulations, photo identity, variant selection and Share checks remain in source.

Fresh commands from judge worktree, both exit 0:

```powershell
node docs/gallery-contracts-20261107/judge-corrections-scratch/resource-origin-probe.cjs
python docs/gallery-contracts-20261107/judge-corrections-scratch/verify-bindings.py
```

Exactly **1 focused Node invocation; 0 browser driver runs; no retries**. Repeating unchanged Chrome evidence would not repair F1. Details: [probe](judge-corrections-scratch/resource-origin-probe.json), [bindings/counts](judge-corrections-scratch/bindings-and-counts.json).

No access blocker. Corrections were not applied because candidate writes are forbidden to this judge. Only this report and owned scratch were written. S-LEGACY remains `todo`; Issue #4 was untouched. NOT RUN: physical devices, screen readers, native BFCache, SQL/backend/.NET/Docker, full suite/631, CI, publication or production. No before/after recording or production-readiness claim.

Lesson applied: validate evidence origin and actual viewport, not green labels. **Next primary action:** fix F1/F2 in the tests, retain unchanged passing evidence, and verify only the affected paths before acceptance.

# Packet P7: B4d home loader (high risk)

You are the builder (Claude Sonnet 5.5). The judge (Claude Opus) accepts only from its own checks.
Output: KISS; finish with the YAML below only.

## Workspace and rules

Same as packet P1 (`C:/Users/Jason/.t3/worktrees/github/frontend-finish-f84c41ce23a85739/docs/storefront-loop-20261120/packets/P1-A1-A5.md`, sections Workspace, Owned paths, Return).
Apply every `*.patch` in PATCHES_DIR in name order with `git apply --index` before you start (000–011; 010 is the accepted P6, 011 adds the judge `loader` check).
Owned: `src/app.js`, `build-inputs/static/styles.css`, `build-inputs/static/_headers` (CSP hash only), `tests/static_headers.py`, one new `tools/` codemod, the HTML inputs it changes, and `tests/page-hashes.json`.
Read `docs/storefront-loop-20261120/PROMPT.md` sections "One motion system", "Code architecture", item 4 of "Build per element", and every "Amendment"; amendments win.
Inspiration only: Jason's Osmo loader video. Copy no Osmo code, CSS, text or assets.
Reuse the motion tokens (`--ms-ease`, `--ms-dur-s`, `--ms-dur-m`, `--ms-dur-l`, `--ms-radius`, JS `MOTION`). No literal durations or easings in effect code.

## Slice

- Home page only, first home visit of the browser session only. Never on Barba navigations, repeat visits, reduced motion or without JS.
- "MARTHA" and "SILVA" rise from a mask; a gap opens between them and cycles 3 or 4 existing catalog images; the last image is the home hero image and grows to full screen with `--ms-radius` from the bottom center, handing off to the existing `[data-intro]` fade in `motion()`.
- At most 1.6 s. Any key, click, tap, wheel or scroll ends it at once and leaves the page usable.
- The first painted frame of a fresh session is the loader: no flash of the page. Without JS nothing of the loader shows.
- A CSS failsafe removes the loader after 3 s if `app.js` never runs.
- No new image file. Markup lands through an idempotent `tools/` codemod with `--check`; re-pin page hashes.
- Focus, scroll position and screen-reader output are unaffected after the loader ends; the loader is `aria-hidden`.

## Critic findings (Opus review; follow them unless you prove one wrong)

- `[data-intro]` exists on no page today, so `motion()` fades nothing (`src/app.js:560`). Add `data-intro` to the first slide's `.ho-copy` through the codemod, and run the intro when the loader ends, not under it.
- The hero is a 3-slide carousel (two pictures per slide on desktop, one on mobile), below the page chrome, with `object-position` 12%/18% and a 1.06→1 scale over 7 s. "Full screen" means: the last loader image grows to the box of `.ho-slide[data-active] .ho-m:first-child`, matching its `object-position` and current scale, then the overlay fades over `durS`.
- Real numbers: `index.html` has 8 deferred scripts; the path pin is 1556.
- Mechanism (chosen): one small inline gate script in `<head>`, after `styles.css`, allowed by its exact `'sha256-…'` in `_headers` `script-src` (no `'unsafe-inline'`). It sets `html.ms-loading` and `performance.mark('ms-loader-start')` only when sessionStorage is readable and has no flag, reduced motion is off, and the navigation type is not `reload` or `back_forward`; it sets the flag at once. No new file, no path-pin move, `prepare.py` unchanged.
  - You may update `tests/static_headers.py` so it asserts the exact `script-src 'self' 'sha256-…'` and adds a test that hashes the inline bytes of `index.html` and compares them to `_headers`.
  - Rejected: an external sync script (a blocking revalidation round trip on every index load) and CSS-only (cannot read sessionStorage; repeat visits would flash).
- `.ms-loader{display:none}` by default; shown only under `html.ms-loading`. No-JS shows nothing.
- Markup right after `<body>`, outside `<main data-barba="container">`, `aria-hidden="true"` and `inert`. Remove the node and the html class when it ends; write `performance.mark('ms-loader-end')`.
- Cycle images: existing `/responsive-images/<id>/01-front-v1-360.webp`; race each `decode()` against `MOTION.durS`. The last image copies the hero `<img>` `srcset` and `sizes` exactly, so the browser reuses the same file. Animate transform or clip only, so it does not become a late LCP element.
- End on `pagehide` and on `pageshow` with `persisted`. Exit listeners are passive and never call `stopPropagation` (viewHistory uses capture listeners, `app.js:169`). Exit on `pointerdown` (set `pointer-events:none`, the first click is swallowed on purpose), `keydown` without `preventDefault`, `wheel` and `touchmove`.
- Do not lock scroll and never call `focus()`. Loader z-index above `--z-menu`.
- If `app.js` starts more than 1.6 s after the gate mark, or GSAP is missing, end at once.
- CSS failsafe: an animation of `--ms-loader-failsafe` (3 s token) to `visibility:hidden;opacity:0`. Nothing else may depend on `html.ms-loading`.

## Checks (run and report exact values)

1. `python -B prepare.py`; the new codemod `--check` 1 on base, 0 after, second run 0 changes; every earlier codemod `--check` 0; `python tools/pin_page_hashes.py --check` exits 0; `python tools/verify_release_snapshot.py` still counts 1556 paths (its other known failure stays).
2. Judge slices: `python -X utf8 tests/storefront_scorecard/slices.py --out <TEMP>/p7-slices.json --port 18600` → grid, footer, title, pill, transition and loader all true. The `loader` check covers: CSP hash match with one inline script in `<head>`; 3 fresh visits (start mark, end−start ≤ 1650 ms, node and class gone, focus on body, scrollY 0, `[data-intro]` present); LCP median ≤ 800 ms, LCP element not in the loader, CLS ≤ 0.05; repeat visit, reload, reduced motion and Barba entry show none; with `app.js` aborted the loader shows at about 0.6 s and is hidden by 3.8 s.
3. Scorecard: `python -X utf8 tests/storefront_scorecard/scorecard.py --out <TEMP>/p7.json --skip-vitals --port 18601`. Must equal champion 010: purchase 4/4, axe 0, enSpanish 0, priceBad 0, console 0/0, no overflow, 404 ok, stages nonzero only asset-audit and catalog-staging. JS may grow by at most 5,000 B over 506,819.
4. `node tests/localization-runtime.cjs`, `node tests/frontend-runtime.cjs`, `node tests/desktop-gallery.cjs`, `python -m unittest tests.responsive_images`, `python tests/static_headers.py` exit 0.
5. No new file under `build-inputs/static` or `src`.
6. A screen recording outside the repo (agent-browser `record start`) of a fresh home visit at 1440 and 390, plus 4 key frames from each.

## Return YAML

```yaml
model: <exact model id>
patch: <absolute PATCH_OUT>
files_changed: [..]
codemod: {name: .., check_before: .., changed_files: .., check_after: .., second_run_changes: ..}
gate: {bytes: .., sha256: .., conditions: ..}
slices: {grid: .., footer: .., title: .., pill: .., transition: .., loader: .., failing_evidence: ..}
scorecard: {purchase: .., axe: .., enSpanish: .., priceBad: .., console: .., budget_js: .., stages_nonzero: ..}
recordings: [..]
gaps: [..]
```

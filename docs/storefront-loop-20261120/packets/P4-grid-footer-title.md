# Packet P4: B4c grid FLIP + B4e footer reveal and wordmark + tab title

You are the builder (Claude Sonnet 5.5). The judge (Claude Opus) accepts only from its own checks.
Output: KISS; finish with the YAML below only.

## Workspace and rules

Same as packet P1 (`C:/Users/Jason/.t3/worktrees/github/frontend-finish-f84c41ce23a85739/docs/storefront-loop-20261120/packets/P1-A1-A5.md`, sections Workspace, Owned paths, Return).
Apply every `*.patch` in PATCHES_DIR in name order with `git apply --index` before you start; the last one adds the judge checks `tests/storefront_scorecard/slices.py`.
Read `docs/storefront-loop-20261120/PROMPT.md` sections "One motion system", "Code architecture", items 3, 5 and 7 of "Build per element", and every "Amendment"; amendments win.
Pages: 48 (`tests/site-pages.json`). After any page change run `python tools/pin_page_hashes.py` and include `tests/page-hashes.json` in your patch.
Inspiration only: Jason's Osmo videos 4 (grid flip) and 6 (footer parallax). Copy no Osmo code, CSS, text or assets.

## Motion tokens (first use; later packets reuse them)

Define once in `styles.css` `:root`: `--ms-ease` (one ease-out curve), `--ms-dur-s` (≤ 300 ms), `--ms-dur-m` (≤ 500 ms), `--ms-radius`.
Mirror them in one frozen JS object at the top of `src/app.js` (e.g. `const MOTION = {...}`), read from the CSS custom properties at init. Effect code uses no literal durations or easings.

## Slices

B4c Grid. The catalog already has a working toggle (`.grid-views`, `[data-cols][data-cols-key=cd|cm]`, handler near `src/app.js:698` sets `--cd`/`--cm`). Keep the control and its markup.
- Animate column changes with a manual FLIP using GSAP core only (no Flip plugin): cards move and scale to their new box in ≤ `--ms-dur-m` with a small stagger; text never scales (fade only).
- Reuse the same FLIP helper for filter and sort reflow only if it stays small; otherwise report it as a gap.
- Persist the choice per key in `localStorage` `martha-grid-v1` (JSON `{cd, cm}`), restored on load and after Barba navigation; wrap storage in try/catch.
- Reduced motion or no GSAP: switch instantly, no transform.
- Listeners on the existing `pageScope` AbortController; kill tweens when it aborts.

B4e Footer. On all 48 pages:
- Add a full-width wordmark `<p class="footer-wordmark" aria-hidden="true">MARTHA SILVA</p>` as the last child of `footer.site-footer`, through one idempotent `tools/` codemod with `--check` (never hand edits, never JS-injected).
- Cormorant Garamond (already loaded), sized with container-query units and no JS so its text fills 98–100 % of the footer content width at 320–1920 px, without horizontal overflow.
- Reveal: the footer sits under the content and is uncovered as the page scrolls (CSS `position: sticky` bottom reveal or equivalent, no ScrollTrigger, no Lenis). A dark veil that fades as it is uncovered is optional progressive enhancement (CSS scroll-driven animation under `@supports`), never required.
- Newsletter, text and links keep content and layout (D-030). Reduced motion: static footer with the wordmark.
- Must not break: the toast, dialogs, the checkout page, mini-bag, or the 404 page.

B4e Tab title. One named handler beside the existing `visibilitychange` listener (`src/app.js`, near the `videoMotion` listener; not inside `videoMotion`).
- Hidden: save `document.title`, set the away title in the active language: bag has items → `Tu bolsa te espera · MARTHA SILVA` / `Your bag is waiting · MARTHA SILVA`; else `Vuelve pronto · MARTHA SILVA` / `Come back soon · MARTHA SILVA`.
- Visible: restore the saved title only if the away title is still showing. After a Barba navigation the restored title is the new page's.
- The HTML `<title>` never changes.

## Checks (run and report exact values)

1. `python -B prepare.py`; codemod `--check` 1 on base, 0 after, second run 0 changes; `python tools/pin_page_hashes.py --check` exits 0.
2. Judge slices: `python -X utf8 tests/storefront_scorecard/slices.py --out <TEMP>/p4-slices.json --port 18500` → `{"grid": true, "footer": true, "title": true, "pass": true}`. Report any failing sub-key with its evidence.
3. Scorecard: `python -X utf8 tests/storefront_scorecard/scorecard.py --out <TEMP>/p4.json --skip-vitals --port 18501`. Must equal the champion: purchase 4/4, axe 0 violations, enSpanish 0, priceBad 0, console 0/0, no overflow, 404 ok, stages nonzero only asset-audit and catalog-staging. JS bytes may grow by at most 6,000 B over 495,038.
4. `node tests/localization-runtime.cjs`, `node tests/frontend-runtime.cjs`, `node tests/desktop-gallery.cjs`, `python -m unittest tests.responsive_images` exit 0.
5. Screenshots (outside the repo) of the footer at 390 and 1440, and the catalog at 1440 in "2" and "4": list their paths.

## Return YAML

```yaml
model: <exact model id>
patch: <absolute PATCH_OUT>
files_changed: [..]
motion_tokens: {css: .., js: ..}
codemod: {name: .., check_before: .., changed_files: .., check_after: .., second_run_changes: ..}
slices: {grid: .., footer: .., title: .., failing_evidence: ..}
scorecard: {purchase: .., axe: .., enSpanish: .., priceBad: .., console: .., budget_js: .., stages_nonzero: ..}
screenshots: [..]
gaps: [..]
```

## Judge note after round 0 (REJECTED)

Grid, title, codemod, tokens and scorecard passed the judge; keep them.
Rejected for one defect: `.site-footer{position:sticky;bottom:0;z-index:-1}` is taller than the viewport (about 1300 px at 390, 1002 px at 1440).
A sticky bottom element taller than the viewport never moves, so its top part stays hidden at every scroll position.
Measured: the newsletter input, its button and "Ver entrega y devoluciones" are never clickable at 390 or 1440; "Vestidos de fiesta" also at 390. Keyboard focus cannot reveal them either.
Judge patch `005-judge-footer-reach.patch` adds `footer.reach390` and `footer.reach1440`: every visible footer control must be hit-testable at some scroll position. The champion passes it.

Round 1:
- Start from the rejected patch `<OS temp>/sf-loop/P4r0-rejected.patch` (apply it after 000–005) and change only the footer reveal.
- The reveal must never hide content: for example, keep the footer in normal flow and reveal only the wordmark band, or enable the sticky reveal only when the footer fits the viewport (a CSS-only condition is preferred; a measured custom property is acceptable if small).
- All slices checks, including the new reach keys, must pass; everything else from round 0 must stay equal.
- Also screenshot `/404.html` and `/checkout.html` at 390 and 1440 and inspect them.

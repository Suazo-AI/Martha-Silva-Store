# Packet P10: B5 detail polish (CSS consolidation + audited fixes + EN meta)

You are the builder (Claude Sonnet 5.5). The judge (Claude Opus) accepts only from its own checks.
Output: KISS; finish with the YAML below only. Another builder (P9, B3 micro-interactions) works in parallel; respect the ownership split exactly.

## Workspace

- Fresh git worktree at commit `2ad4713` (champion 014 is committed there). No patch series to apply.
- Never commit, push, stash-pop, or touch other worktrees. Keep screenshots and scratch files outside the worktree (OS temp).
- Static vanilla-JS storefront. `python -B prepare.py` byte-copies inputs into `dist/` (excluded from your patches). CSP: no new inline script.
- Read `AGENTS.md`, `DESIGN.md`, `docs/CODE-MAP.md`, then `docs/storefront-loop-20261120/PROMPT.md` sections "Judge defaults", "Code architecture" and every "Amendment".
- Copy `node_modules` for the frontend tests from `C:/Users/Jason/.t3/worktrees/github/frontend-finish-f84c41ce23a85739/tests/frontend-deps/node_modules` if your worktree lacks it.

## Owned (P10)

- `build-inputs/static/styles.css` lines 1–737 only (everything before the `:root{--ms-ease…}` motion section). Never edit line 738 onward; P9 appends there in parallel.
- `build-inputs/static/i18n.js`, `build-inputs/static/locale-en.js`: append your strings in one contiguous block marked `// B5` (P9 appends its own block).
- `tools/seo_generate.py` only if item 3 needs it (keep `--check` and the judge `seo` check green).
- HTML pages only through an idempotent `tools/` codemod with `--check` (or `seo_generate.py`), then re-pin `tests/page-hashes.json` with `python tools/pin_page_hashes.py`.
- Not owned: `src/app.js` (write any JS-needing fix as a proposal in `gaps`), `_headers`, `prepare.py`, `tests/check.py`, `tests/storefront_scorecard/`, `savia/`, `wrangler.jsonc`.
- D-030: keep Jason's style, layout and composition. Fix defects; do not redesign. Any composition change is a proposal in `gaps`, not code.

## Item 1: CSS consolidation (deliver as its own patch, P10a)

`styles.css` (136,879 B) repeats large blocks: lines 3–15 equal 419–431, 17–50 equal 433–466, 52–59 equal 468–475, 263–415 equal 571–723 (about 50 KB). The later copy wins the cascade.
- Remove the redundant earlier copies and any other rule that is fully overridden for every element on every page, so that computed styles stay identical.
- Proof (required): a script outside the repo that, for every page in `tests/site-pages.json` at 390 and 1440 (plus states: mobile menu open, search dialog open, size guide open, bag drawer open, checkout steps 1–3), dumps `getComputedStyle` of every element plus `::before`/`::after` for all properties, before and after. Report the number of differing (element, property) pairs: it must be 0. Also report bytes before/after.
- No visual or behavior change in P10a.

## Item 2: audited detail fixes (patch P10b, applied after P10a)

Audit with a real browser (agent-browser) at 390 and 1440, ES and EN: catalog, product, bag (drawer and page), checkout steps, pedido, ayuda, 404.
Look for exact, provable defects of a premium store, for example: misaligned baselines or edges, inconsistent spacing against the 8 px grid, text clipping or orphaned single words in buttons, hit areas below 44×44 px on touch, inconsistent focus rings, inconsistent price/label typography between card, product and bag, missing `:hover`/`:focus-visible` parity, images without stable aspect boxes, empty or dead-end states, inconsistent casing of labels.
- Fix at most 12, highest impact first, CSS (lines 1–737) or locale strings only.
- For each: selector or file:line, screenshot before/after (outside repo), and a measured value (px, ratio, count) that proves the fix.
- Do not touch transitions, animations or transforms (P9 owns motion).

## Item 3: EN head metadata

When the language is EN, `document.title` is already translated; the meta description, `og:title`, `og:description`, `twitter:title`, `twitter:description` stay Spanish.
Make the existing i18n layer translate them on toggle (strings from `catalog.js` fields or locale entries; never invented claims). Static bytes stay Spanish (Google sees ES; no `hreflang`). If this needs `src/app.js`, put it in `i18n.js` instead; if impossible without `app.js`, record it in `gaps`.

## Checks (run and report exact values)

1. `python -B prepare.py`; every codemod `--check` 0 (storefront_markup_codemod, price_format, remove_dead_vendor, footer_wordmark_codemod, menu_pill_codemod, loader_codemod, seo_generate); `python tools/pin_page_hashes.py --check` 0.
2. Computed-style diff for P10a: 0 differing pairs; list the states covered.
3. Judge slices: `python -X utf8 tests/storefront_scorecard/slices.py --out <TEMP>/p10-slices.json --port 18720` → all true.
4. Scorecard: `python -X utf8 tests/storefront_scorecard/scorecard.py --out <TEMP>/p10.json --skip-vitals --port 18721`: purchase 4/4, axe 0, enSpanish 0, priceBad 0, console 0/0, no overflow, 404 ok; CSS bytes down by at least 40,000.
5. `node tests/localization-runtime.cjs`, `node tests/frontend-runtime.cjs`, `node tests/desktop-gallery.cjs`, `python tests/static_headers.py` exit 0.

## Return

Two patches, P10b relative to P10a: build P10a, save `git diff --binary -- . ':(exclude)dist' > <TEMP>/sf-loop/P10a-css.patch` after `git add -N .`; then `git add -A` (index only, never commit), continue with items 2–3, and save `git add -N . && git diff --binary -- . ':(exclude)dist' > <TEMP>/sf-loop/P10b-polish.patch`.

```yaml
model: <exact model id>
patches: {P10a: <abs path>, P10b: <abs path>}
files_changed: [..]
css: {bytes_before: .., bytes_after: .., computed_diff_pairs: .., states: [..]}
fixes: [{id: .., where: .., defect: .., measure_before: .., measure_after: ..}]
en_meta: {done: .., how: ..}
slices: {..}
scorecard: {purchase: .., axe: .., enSpanish: .., priceBad: .., console: .., budget_css: .., stages_nonzero: ..}
proposals: [..]
gaps: [..]
```

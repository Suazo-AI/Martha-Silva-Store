# Packet P9: B3 micro-interactions

You are the builder (Claude Sonnet 5.5). The judge (Claude Opus) accepts only from its own checks, including a hidden `micro` check that enforces the contract below.
Output: KISS; finish with the YAML below only. Another builder (P10, B5 polish) works in parallel; respect the ownership split exactly.

## Workspace

- Fresh git worktree at commit `2ad4713` (champion 014 is committed there). No patch series to apply.
- Never commit, push, stash-pop, or touch other worktrees. Keep screenshots, recordings and scratch files outside the worktree (OS temp).
- Static vanilla-JS storefront. `python -B prepare.py` byte-copies inputs into `dist/` (excluded from your patch). CSP `script-src 'self' 'sha256-…'`: no new inline script.
- Read `AGENTS.md`, `DESIGN.md`, `docs/CODE-MAP.md`, then `docs/storefront-loop-20261120/PROMPT.md` sections "Judge defaults", "One motion system", "Code architecture" and every "Amendment".
- Copy `node_modules` for the frontend tests from `C:/Users/Jason/.t3/worktrees/github/frontend-finish-f84c41ce23a85739/tests/frontend-deps/node_modules` if your worktree lacks it.

## Owned (P9)

- `src/app.js`: only the micro-interaction code (small named functions next to the handlers they serve; no rewrite, no refactor beyond the lines needed).
- `build-inputs/static/styles.css`: ONLY a new section appended at the very end of the file, starting with the comment `/* B3 micro-interactions */`, plus new tokens appended to the existing `:root{--ms-…}` rule at line ~738. Do not edit, delete or reorder any line before line 738: P10 rewrites that region in parallel.
- `build-inputs/static/locale-en.js` / `i18n.js`: only new strings this slice adds (append; P10 also appends there, so keep your additions in one contiguous block marked `// B3`).
- New cases inside existing `tests/*.cjs`.
- Not owned: HTML pages, `_headers`, `prepare.py`, `tests/check.py`, `tests/storefront_scorecard/`, `savia/`, `wrangler.jsonc`.

## Slice: feedback, not effects

Jason's rule: micro-interactions are feedback for an action the shopper just took. No decorative motion, no new effect, no layout change. Premium means calm, fast and exact.

Tokens (DESIGN.md "Transiciones"): add `--ms-micro-fade:200ms; --ms-micro-slide:300ms; --ms-micro-ease:cubic-bezier(.25,.1,.25,1)` and mirror them in `MOTION` as `microFade`, `microSlide`, `microEase` (reuse the existing parser). No literal durations or easings in effect code.

Required feedback (each must exist and work in ES and EN, at 390 and 1440):
1. Press: primary buttons (`[data-add]`, `[data-sticky-add]`, checkout continue/pay buttons, `.plp-quick`, size buttons) scale to between .97 and .99 on `:active`, transform only, `--ms-micro-fade`.
2. Add to bag on the product page: on success the `[data-add]` button sets `data-state="added"` and shows "Agregada" / "Added" with a check icon (inline SVG, `aria-hidden`) for 1.2–1.8 s, then returns to its idle label and `data-state` removed. Width must not change (no layout shift). The existing toast/announcement stays the single live-region message; do not add a second one.
3. Bag count: every header bag counter that increases runs one transform-only bump (scale ≤ 1.2) over `--ms-micro-slide`. Decreases do not bump.
4. Favorite: toggling `[data-favorite]` runs one transform-only pop on its icon (scale ≤ 1.25) over `--ms-micro-slide`; `aria-pressed` updates exactly as today.
5. Toast `#toast`: enters with opacity 0→1 plus translateY (≤ 12 px) over `--ms-micro-slide`, leaves with opacity over `--ms-micro-fade`.
6. Size choice (product page and `.plp-sizes`): the selected state gets an indicator that animates with transform (e.g. `scaleX` underline) over `--ms-micro-fade`; color changes stay instant.
7. Errors (`[data-error]`, `[data-product-error]`, checkout field errors): appear with opacity over `--ms-micro-fade`; no shake.

Hard rules:
- Every animation or transition you add animates only `transform` and/or `opacity`, with duration ≤ 300 ms. The judge reads `document.getAnimations()` during each interaction.
- `prefers-reduced-motion: reduce`: no animation runs; every state change (label, count, aria) still happens.
- No CLS: zero `layout-shift` entries caused by these interactions.
- Double click on add: still exactly one line added (existing `withButton` guard).
- Hover styles only under `@media (hover:hover)`.
- No new file under `build-inputs/static` or `src`; JS bytes may grow by at most 3,000 B over 511,650 (scorecard `budget.js`).
- Use Web Animations (`element.animate`) or CSS classes; restart-safe (rapid repeated clicks never stack animations or leave a stuck class).

## Checks (run and report exact values)

1. `python -B prepare.py`; every codemod `--check` 0 (storefront_markup_codemod, price_format, remove_dead_vendor, footer_wordmark_codemod, menu_pill_codemod, loader_codemod, seo_generate); `python tools/pin_page_hashes.py --check` 0; `python tools/verify_release_snapshot.py` reports only "Publication bytes differ" (expected after input edits) or PASS.
2. Your own browser proof (agent-browser per `C:/Users/Jason/.agents/skills/agent-browser/SKILL.md`, or the scorecard's Playwright helpers): for items 1–7 log the animated properties and durations from `document.getAnimations()`, the `data-state` timeline, the bag count, and layout-shift entries; repeat with reduced motion.
3. Judge slices: `python -X utf8 tests/storefront_scorecard/slices.py --out <TEMP>/p9-slices.json --port 18700` → all true.
4. Scorecard: `python -X utf8 tests/storefront_scorecard/scorecard.py --out <TEMP>/p9.json --skip-vitals --port 18701`: purchase 4/4, axe 0, enSpanish 0, priceBad 0, console 0/0, no overflow, 404 ok.
5. `node tests/localization-runtime.cjs`, `node tests/frontend-runtime.cjs`, `node tests/desktop-gallery.cjs`, `python tests/static_headers.py` exit 0.

## Return

`git add -N .` then `git diff --binary -- . ':(exclude)dist' > <TEMP>/sf-loop/P9-micro.patch`.

```yaml
model: <exact model id>
patch: <absolute path>
files_changed: [..]
items: {press: .., added_state: .., bag_bump: .., favorite: .., toast: .., size: .., errors: ..}
animations_seen: [{item: .., properties: [..], duration_ms: ..}]
reduced_motion: {animations: .., states_ok: ..}
cls: ..
slices: {..}
scorecard: {purchase: .., axe: .., enSpanish: .., priceBad: .., console: .., budget_js: .., stages_nonzero: ..}
gaps: [..]
```

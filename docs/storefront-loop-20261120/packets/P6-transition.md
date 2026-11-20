# Packet P6: B4a page transition (high risk)

You are the builder (Claude Sonnet 5.5). The judge (Claude Opus) accepts only from its own checks.
Output: KISS; finish with the YAML below only.

## Workspace and rules

Same as packet P1 (`C:/Users/Jason/.t3/worktrees/github/frontend-finish-f84c41ce23a85739/docs/storefront-loop-20261120/packets/P1-A1-A5.md`, sections Workspace, Owned paths, Return).
Apply every `*.patch` in PATCHES_DIR in name order with `git apply --index` before you start (000–009; 008 is the accepted P5, 009 adds the judge `transition` check).
The `transition` check samples every frame in the page: window coverage at 9 points (bottom center first, monotonic growth, full within 800 ms), outgoing page still, no scroll reset before cover, mounted h1 and no Spanish in the EN window, history fade with scroll restore, reduced motion instant, double click, menu navigation focus, and 10 navigations without reload, leaks, `.page-window` or inline `clip-path`.
Read `docs/storefront-loop-20261120/PROMPT.md` sections "One motion system", "Code architecture", item 1 of "Build per element", and every "Amendment"; amendments win.
Inspiration only: Jason's Osmo video 1 (rounded window rising from the bottom center). Copy no Osmo code, CSS, text or assets.
Reuse the motion tokens; add at most one `--ms-dur-l` (≤ 700 ms) mirrored in `MOTION`. No literal durations or easings in effect code.
Owned: `src/app.js`, `build-inputs/static/styles.css`. No page markup change is expected; if one is needed, use a codemod with `--check` and re-pin hashes.

## Slice

Barba runs only between home, catalog and product pages (`prevent` in `barba.init`). Keep that.
- Forward navigations (link clicks, not history): the next page appears inside a rounded window (`--ms-radius`) that grows from the bottom center to full screen in at most `--ms-dur-l`.
- The window shows the next page only after it is mounted, translated (EN when the language is EN) and rendered. Today `mountPage` runs in `after`, which follows `enter`; restructure so mounting happens before the window becomes visible, without running it twice.
- The outgoing page stays still under the window (no jump from `scrollTo(0,0)`). Reset the scroll only after the window covers the viewport.
- Animate `clip-path` or transform/opacity only. Keep the editorial transition first in `transitions` (`tests/desktop-gallery.cjs` reads `transitions[0]`).
- Back and forward (history) keep today's 120 ms fade and scroll restoration. Reduced motion or no GSAP keeps today's instant swap.
- Focus: after the swap, focus follows today's `viewHistory.shouldFocus` rule; never leave focus on a removed node.
- A second click during a transition must not break the page (`preventRunning:true` stays). The 4 s Barba timeout must not fire on a normal navigation.
- No leaks: GSAP global timeline children return to 0 and exactly one Barba container remains after 10 navigations.
- No full reloads: a Barba `force` reload fails the check (it hides hook errors).
- Mobile menu: after a navigation from a link inside `#mobile-menu`, focus ends in `main`, not on the pill toggle. Champion 008 fails this today (`menuNav390`).

## Critic findings (Opus review of Barba 2.10.3 and `src/app.js`; follow them unless you prove one wrong)

- Barba inserts the next container right after the current one and removes the current one just before `after`. `mountPage` uses global queries (`$('main')`), so mounting in `beforeEnter`/`enter` as-is would mount and focus the outgoing page. Fix the DOM order first.
- Suggested forward order (no `sync`):
  - `beforeLeave`: `viewHistory.begin`, `stopMotion`, close menu and search dialogs at once without animation and drop the menu return-focus target, set `inert` on the current container, header and `.menu-pill`.
  - `leave`: no fade on forward; keep the 120 ms fade on history.
  - `beforeEnter`: put the next container in a fixed `.page-window` holder before the current page, fully clipped; run `mountPage` once, bounded to 3× `durL`; then `MarthaI18n.apply` on it, decode visible images with a short limit, wait 2 frames. History and reduced motion: remove the current container yourself, then mount.
  - `enter`: tween `clip-path` from `inset(100% 50% 0 50% round var(--ms-radius))` to `inset(0)` over `MOTION.durL`, inside a `gsap.context`.
  - End of `enter`, in one frame: remove the current page, put the next one back in flow, remove the holder, clear inline props, `scrollTo(0,0)`, remove `inert`.
  - `after`: focus by `shouldFocus`, falling back to `main` when `activeElement` is `body` or disconnected; `viewHistory.finish`; `ctx.revert()`. Never call `mountPage` again here.
- Window sits above the page and below the header (`--z-header`) and pill (`--z-menu`); offset its content by `--store-chrome-height` so nothing shifts at the swap.
- Use `clip-path`, not transform: a transform breaks fixed children such as `[data-sticky-buy]`. Base the clip on the viewport.
- Product to product: global queries such as `$$('[data-add]')` must not touch the outgoing page.
- Back pressed during a forward transition may force a full load; record what happens in `gaps`.

## Checks (run and report exact values)

1. `python -B prepare.py`; every codemod `--check` 0; `python tools/pin_page_hashes.py --check` exits 0.
2. Judge slices: `python -X utf8 tests/storefront_scorecard/slices.py --out <TEMP>/p6-slices.json --port 18570` → grid, footer, title, pill and transition all true. Report any failing sub-key with its evidence.
3. Scorecard: `python -X utf8 tests/storefront_scorecard/scorecard.py --out <TEMP>/p6.json --skip-vitals --port 18571`. Must equal champion 008: purchase 4/4, axe 0 violations, enSpanish 0, priceBad 0, console 0/0, no overflow, 404 ok, stages nonzero only asset-audit and catalog-staging. JS may grow by at most 5,000 B over 501,928.
4. `node tests/localization-runtime.cjs`, `node tests/frontend-runtime.cjs`, `node tests/desktop-gallery.cjs`, `python -m unittest tests.responsive_images` exit 0.
5. Screenshots outside the repo: a mid-transition frame at 390 EN and at 1440 ES (home to product).

## Return YAML

```yaml
model: <exact model id>
patch: <absolute PATCH_OUT>
files_changed: [..]
design: <how mount, window, scroll reset and focus are ordered>
slices: {grid: .., footer: .., title: .., pill: .., transition: .., failing_evidence: ..}
scorecard: {purchase: .., axe: .., enSpanish: .., priceBad: .., console: .., budget_js: .., stages_nonzero: ..}
screenshots: [..]
gaps: [..]
```

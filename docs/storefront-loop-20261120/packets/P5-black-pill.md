# Packet P5: B4b mobile navigation as a solid black pill

You are the builder (Claude Sonnet 5.5). The judge (Claude Opus) accepts only from its own checks.
Output: KISS; finish with the YAML below only.

## Workspace and rules

Same as packet P1 (`C:/Users/Jason/.t3/worktrees/github/frontend-finish-f84c41ce23a85739/docs/storefront-loop-20261120/packets/P1-A1-A5.md`, sections Workspace, Owned paths, Return).
Apply every `*.patch` in PATCHES_DIR in name order with `git apply --index` before you start (000–007; 006 is the accepted P4, 007 adds the judge `pill` check).
Read `docs/storefront-loop-20261120/PROMPT.md` sections "One motion system", "Code architecture", item 2 of "Build per element", and every "Amendment"; amendments win.
Jason's decision: no glass anywhere. The pill is solid classic black like the header, with the morph of reference video 2. Copy no Osmo code, CSS, text or assets.
Pages: 48 (`tests/site-pages.json`); `checkout.html` has no menu and gets no pill. After any page change run `python tools/pin_page_hashes.py` and include `tests/page-hashes.json`.
Reuse the P4 motion tokens (`--ms-ease`, `--ms-dur-s`, `--ms-dur-m`, `--ms-radius`, JS `MOTION`); no literal durations or easings in effect code.

## Slice

Below 1024 px (the current `.menu-toggle` breakpoint):
- A pill fixed at the bottom center holds the MARTHA SILVA wordmark and the menu button. It replaces the header menu button: exactly one visible `[data-menu-toggle]` on the page.
- Markup lands through one idempotent `tools/` codemod with `--check` (never hand edits, never JS-injected). Keep `aria-controls="mobile-menu"`, `aria-expanded` and the ES/EN label keys.
- Solid black background with alpha 1, no `backdrop-filter`; text contrast at least 4.5:1. Targets at least 44×44 px. Bottom offset respects `env(safe-area-inset-bottom)` and stays within 48 px of the viewport bottom.
- Open: the existing native `<dialog id="mobile-menu">` opened by `openDialog` stays the single source of truth (`showModal`, Esc, focus return). The card visibly grows from the pill (bottom center, `--ms-radius`) to its final size; links stagger in; the button icon becomes an X.
- Close (button, Esc, link, backdrop): content fades, the card shrinks back toward the pill, then `dialog.close()` runs. Esc must run the close animation too (handle the dialog `cancel` event).
- Reduced motion or no GSAP: open and close instantly, same final states.
- The toast (`#toast`) sits fully above the pill. Focused elements are never hidden behind the pill (WCAG 2.4.11): use `scroll-padding-bottom` and page bottom padding as needed.
- From 1024 px up nothing changes: no pill, header pixels unchanged.

## Checks (run and report exact values)

1. `python -B prepare.py`; the new codemod `--check` 1 on base, 0 after, second run 0 changes; all earlier codemods `--check` 0; `python tools/pin_page_hashes.py --check` exits 0.
2. Judge slices: `python -X utf8 tests/storefront_scorecard/slices.py --out <TEMP>/p5-slices.json --port 18550` → grid, footer, title and pill all true. Report any failing sub-key with its evidence. The `dialog` sub-check samples the card area about 60 ms after the click (plus CLI latency) and needs it below 80 % of the final area, and needs the dialog still open about 60 ms after Esc; under reduced motion both must be instant.
3. Scorecard: `python -X utf8 tests/storefront_scorecard/scorecard.py --out <TEMP>/p5.json --skip-vitals --port 18551`. Must equal champion 006: purchase 4/4, axe 0 violations, enSpanish 0, priceBad 0, console 0/0, no overflow, 404 ok, stages nonzero only asset-audit and catalog-staging. JS may grow by at most 5,000 B over 499,581.
4. `node tests/localization-runtime.cjs`, `node tests/frontend-runtime.cjs`, `node tests/desktop-gallery.cjs`, `python -m unittest tests.responsive_images` exit 0.
5. Keyboard pass at 390 with agent-browser: Tab to the pill button, Enter opens, Tab cycles inside the dialog, Esc closes, focus returns. Report the accessibility-tree snapshot lines for the button and the dialog. A real screen reader stays unverified.
6. Screenshots outside the repo: 390 and 1023 closed; 390 open; a mid-open frame at 390; 390 with the toast visible; 1440 header before and after (report a pixel diff).

## Return YAML

```yaml
model: <exact model id>
patch: <absolute PATCH_OUT>
files_changed: [..]
codemod: {name: .., check_before: .., changed_files: .., check_after: .., second_run_changes: ..}
slices: {grid: .., footer: .., title: .., pill: .., failing_evidence: ..}
scorecard: {purchase: .., axe: .., enSpanish: .., priceBad: .., console: .., budget_js: .., stages_nonzero: ..}
keyboard: {snapshot: .., result: ..}
header_1440_diff: ..
screenshots: [..]
gaps: [..]
```

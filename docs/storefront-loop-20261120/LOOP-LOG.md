# Loop log

## 2026-11-20 · Jason's go

Source: Jason's message ("go", Claude and OpenCode only, Lenis/ScrollTrigger is the judge's call, brands like "SHE" and lululemon).
Change: added "Amendment: Jason's go" to `PROMPT.md`; routes, A8, CSS footer reveal and the text brand wall follow from it.
Evidence for A8: `lenis` is declared at `src/app.js:204` and destroyed at `:480`, never assigned; no ScrollTrigger or registerPlugin call in `src/`, `tests/` or `tools/`.

## 2026-11-20 · Phase 0

Harness: `tests/storefront_scorecard/scorecard.py`, frozen by `MANIFEST.sha256`, saved as `patches/000-scorecard.patch`.
Two harness bugs fixed before freezing: agent-browser's daemon held the stdout pipe open (now writes to a file), and clicks at the viewport edge missed (now centers the target first).
Calibration (2 runs; counts are exact between runs once the purchase completes; vitals are local and only relative):
purchase 4/4; EN Spanish 171 (the 5 known strings); axe serious 6 color-contrast, region 52, heading-order 8, landmark-one-main 4 (server 404 page); price tokens bad 2,946 live, 3,354 static; GSAP warnings 92–100; size L → 0 results; missing URL → server 404 page; stages 0 except asset-audit and catalog-staging (WinError 1314).
Third calibration run skipped: counts were identical; noise only matters for vitals.
Merge decision: A1–A5 run as one low-risk packet (P1), each with its own check; A6 and A7+A8 stay separate high-risk packets.
Critic (Opus, read-only) on A6/A7: use a fixed `en-US` formatter; `locale-en.js:103` holds a `US$` key; A8 must remove the 3 tags from the 47 pages in the same patch; path count becomes 1,556; one shared page-list source for the pins.

## P1 judged: ACCEPT
Builder claims matched the judge's own scorecard on every metric.
Out-of-scope edit: tests/responsive_images.py reversal; accepted as temporary, P3 replaces it.

## P2 judged: ACCEPT
All builder claims matched the judge scorecard. One formatter fixed to en-US; codemod idempotent.

## P3 judged: ACCEPT
All builder claims matched. Track A complete. prepare.py refuses stale dist files: deleted vendor files must be removed from dist too.

## B0 spec page written
`B0-SPEC.html`: 6 decisions for Jason, 8 videos verified (bytes, SHA256, duration), mockups, SEO baseline. Finding: catalog already has a working 2/3/4 column toggle; B4c animates it instead of adding a new control. Waiting for approval.

## Jason: brand wall removed
Spec page and PROMPT amended; video 7 marked discarded.

## 2026-11-20 P4 launched

Judge patch `004-judge-slices.patch` (sha256 950e3e3ad56a533b30304b1e67cbb5649750e2ff75dbba7460a642b9725fd66a) freezes `slices.py` in MANIFEST.
Calibration on champion 003: grid, footer and title all false, as expected.
P4 builder launched: Sonnet 5.5, effort high, worktree; patch out `$TEMP/sf-loop/P4-grid-footer-title.patch`.

## 2026-11-20 P4 round 0 rejected

Slices grid/footer/title true and scorecard equal to champion (JS +4,543 B), but my own check found the sticky footer hides the newsletter permanently at 390 and 1440.
Judge patch `005-judge-footer-reach.patch` (sha256 cd65d347d5b5da23a8a1823bcd25272c87e7c332d97148e470aa741b47a0bb86) adds the reach check; champion passes, P4r0 fails.
Round 1 relaunched with footer-only fix.

## 2026-11-20 P4 round 1 ACCEPTED (champion 006)

Patch `patches/006-P4-grid-footer-title.patch` sha256 f48f0ff3f3a6a823842643769e642b650bb8b484a15a50d8fd5b594ebcf496af.
Judge evidence: `scorecards/006-P4.json` and `scorecards/006-P4-slices.json`.
Slices grid, footer (with reach390 15/15 and reach1440 16/16) and title all true.
Scorecard equal to champion 003 except JS 499,581 B (+4,543), CSS +898 B, HTML +62 B per page, home requests 103 -> 99.
Footer reveal: footer in normal flow; only the wordmark is sticky behind opaque blocks. Visual check: no leak mid-page at 390, partial reveal at 1440, 404 and checkout fine.
Applied uncommitted to the main checkout; prepare.py, pin check and codemod check pass.
Judge gap: MANIFEST.sha256 hashes scorecard.py over the CRLF working copy but slices.py over the LF blob; normalise both to LF in the next judge patch.
Gaps kept: optional dark veil not built; FLIP on filter/sort reflow has no dedicated test; wordmark stacking relies on an opaque main.

## 2026-11-20 P5 launched

Judge patch `007-judge-pill.patch` (sha256 e36899c398aae25e6b7a2383490488153be9e2271985887990b173e977dee357) adds the `pill` check and normalises MANIFEST to LF blob hashes (scorecard.py d4f79f47, slices.py 1acaee71).
Calibration on champion 006: closed390/1023, toast, focus and the dialog morph fail (no pill yet); none1024/1440 and dialogReduced pass.
Packet `packets/P5-black-pill.md`; builder Sonnet 5.5 high, worktree, ports 18550/18551.

## 2026-11-20 P5 ACCEPTED (champion 008)

Patch `patches/008-P5-black-pill.patch` sha256 3af7068f4e4dcfb49328733070e267552ba94ed34a4e00e00f2a6f3e76cf7beb.
Judge evidence: `scorecards/008-P5.json`, `scorecards/008-P5-slices.json`: grid, footer, title, pill all true.
Pill: rgb(17,17,17) alpha 1, no backdrop, contrast 18.88, button 44x44, 16 px from bottom, centred; none at 1024/1440. Card area 19,488 at 60 ms vs 214,800 final; still open 60 ms after Esc; reduced motion instant.
Toast above the pill; 0 focused elements obscured on index (207), catalog (196), product (275) and bag (23).
Scorecard equal to 006 except JS 501,928 B (+2,347), CSS +2,042 B, HTML +271 B, menu-state gsapChildren 0 -> 4 (running open tween; judge leak test: 0 after settle and after 6 open/close cycles).
Visual review: 390 closed, open, mid-open and toast screenshots fine.
Limits: a click within ~50 ms of Esc lands on the modal backdrop and does not reopen; iOS safe area, real devices and screen reader unverified; header below 1024 px lost the hamburger (heart moves left), by design.

## 2026-11-20 P6 judge prep and launch

- Opus critic reviewed the P6 plan; findings folded into `packets/P6-transition.md` (DOM order, single mount in beforeEnter, inert, clip-path not transform, focus fallback).
- Judge patch `009-judge-transition.patch` (sha256 `0d6a242bfcb5fdf47bb4c101fbba4fb96f718693d86c6304cc61646bff6bdd7c`) adds the `transition` slice; `slices.py` LF hash `bd6d36b5fb8c0a6db4a0b422a5fa4c73c009eee4b53fdd2d765c212469977d97`.
- Calibration on champion 008: forward window fails (expected); back, reduced, doubleClick and tenNavs pass.
- New real defect found: `menuNav390` fails on 008; focus stays on the pill toggle after a menu navigation. P6 must fix it.
- Long animation frames reach 173 ms on 008 under headless load; recorded only, not gated.
- P6 builder launched: Sonnet 5.5 high, worktree, ports 18570/18571.

## 2026-11-20 P6 accepted (champion 010)

- Patch `010-P6-transition.patch` (Sonnet 5.5 high). Files: `src/app.js`, `styles.css`, `tests/desktop-gallery.cjs` (adds the `beforeEnter` call the router now needs; no assertion changed).
- Judge run: all 5 codemod checks 0, pins 0, node tests 0, responsive_images 0, slices all true.
- Transition: window 605 ms (token `--ms-dur-l` 640ms), 6 partial frames, bottom first, monotonic, outgoing still, no early scroll reset, EN window without Spanish, back restores scroll, reduced instant, menuNav390 focus MAIN, tenNavs clean.
- Scorecard equal to 008 except budget: JS 506,819 (+4,891, limit 5,000), CSS 136,226 (+553).
- Builder's "stale manifest" claim was false: LF index-blob hashes match.
- Nits for later: `menu.returnFocus = null` is dead (close uses the closure trigger); `outgoing` clears in `finally` even after the 3x durL timeout; wheel scroll during the window is not locked; back during a forward transition untested; LoAF up to 243 ms headless, recorded only.

## 2026-11-20 P7 judge prep and launch

- Opus critic: `[data-intro]` exists on no page; hero is a 3-slide carousel; real counts are 8 deferred scripts and 1556 paths.
- Mechanism chosen: inline head gate allowed by an exact CSP `sha256` in `_headers`; no new file, no path-pin move. External sync script rejected (blocking revalidation on every visit); CSS-only rejected (repeat-visit flash).
- Judge patch `011-judge-loader.patch` (sha256 `f4f3687a9d1fc659a5cefa30ab230f64f592960561f0202a0d98200ed7bbda60`); `slices.py` LF `a018692f41610eb6af92e6fa5de8d90649d0202bd5280b075bb11731b729cdaa`.
- The judge server sends `_headers`, so a wrong hash blocks the gate and fails `fresh`.
- Calibration on 010: csp, fresh and failsafe fail (not built); repeat, reload, reduced and barba pass; LCP median 312/484 ms across two runs, limit 800 ms.
- P7 builder launched: Sonnet 5.5 high, worktree, ports 18600/18601.

## 2026-11-20 P7 judged: ACCEPT as champion 012

- Patch `012-P7-loader.patch` sha256 `474777062a6fac07d302e54ace1bc54457353faca741e6135f24abaf6b7110ec`; scorecards `012-P7.json`, `012-P7-slices.json`.
- Judge run on 000–011 + candidate: prepare ok; 6 codemods `--check` 0; pins 0; 3 node tests, `responsive_images` and `static_headers` exit 0.
- Slices: grid, footer, title, pill, transition, loader all true.
- Loader: CSP 1 inline script, gate 350 B, hash in `script-src`; fresh spans 1495/1396/1441 ms; LCP median 224 ms (hero IMG, not in loader); CLS max 0.0036; repeat, reload, reduced, Barba show none; failsafe shown early, hidden late.
- Scorecard vs 010: only JS +4,831 B (511,650), CSS +2,161 B, HTML index +1,878 B, home requests 99 -> 102 (3 lazy 360 webp). Everything else equal.
- Code review: exit listeners passive, no `stopPropagation`, no `focus()`, `pagehide`/`pageshow persisted` handled, late start and missing GSAP end at once. `static_headers.py` is stricter (exact script-src, hash of inline bytes, rejects `unsafe-inline`).
- Accepted deviations: no `inert` (it let a click hit the hidden hero CTA); the image grows from the gap box, not the bottom center; `[data-intro]` fades on every home mount.
- Known unrelated failure: `verify_release_snapshot` "Public/control paths differ" (snapshot renewal pending).
- Untested: Safari, Firefox, screen reader, bfcache, touch tap swallow. CSP change is local-only evidence.

## 2026-11-20 Judge patch 013 (SEO check + loader interrupt/hand-off)

- Patch `013-judge-seo.patch` sha256 `6cf96c29fe30f672c1e43e7a120689c67806b91e6f971788a6814a94f11df412`; `slices.py` LF `1ff8e4ef11bac4d3c550877d10069011d4fa2408938113df5188a70a9891bb11`.
- `loader.csp` now counts only executable inline scripts (JSON-LD excluded).
- New `loader.interrupt`: tap at the hidden hero CTA at 0.25 s ends the loader, no navigation, wheel then scrolls. On 012: pass (span 918 ms, scroll 400).
- New `loader.handoff`: grown layer files equal the active slide files. On 012: pass (dorado+negro 720w at 1440, dorado at 390; 0 mismatches). The keys-1440 Champagne final frame came from the paused scratch build, not a defect.
- New `seo` check: config, served raw bytes, generator `--check`, flip test on a scratch copy. On 012: fails as expected (439 audit failures, no generator).
- Flake: 1 of 4 loader runs had LCP null in 2 of 3 visits under load (spans ~1580 ms); 2 repeats passed (LCP 92–292 ms). Watch it.
- Offers stay (approved spec); the generator refuses `indexable:true` while the catalog is `sample`/`local_test`. Report this guard to Jason.
- P8 builder launched: Sonnet 5.5 high, worktree, ports 18640/18641.

## 2026-11-20 P8 SEO ACCEPTED (champion 014)

- Patch `014-P8-seo.patch` sha256 `e66ec15d613506b0cf493d29c49e85445544f1f482db5ed4b7763337e3673c4b` = builder patch `1f3994ec…935d` plus a judge fix in `.gitattributes`.
- First judge run failed `seo.check` and `seo.flip.revertRestoresBytes`: with `core.autocrlf=true`, Git wrote `robots.txt` and `llms.txt` with CRLF while the generator writes LF.
- Fix: `build-inputs/static/*.txt text eol=lf` and `dist/*.txt text eol=lf`. Rerun: `seo` true; `--check` 0; pins 0.
- Slices grid, footer, title, pill, transition, loader (incl. interrupt and handoff) and seo all true. Loader spans ~1435 ms, LCP median 96 ms.
- Scorecard equal to 012 except HTML bytes (catalog +5,937, home +1,191, product +2,356), public files 1558 -> 1560, home requests 102 -> 104.
- The +2 requests are not from SEO: the region loads no resource (no `src`/`href` with `siteUrl` empty). Treated as loader/carousel timing variance.
- Units: localization, frontend-runtime, desktop-gallery, responsive, static_headers, release test all 0. `verify_release_snapshot` keeps its known failure.
- Main checkout: `git apply` wrote CRLF before `.gitattributes` applied; the generator rewrote both files as LF; `--check` 0.
- Gaps: EN meta descriptions stay Spanish (locale files not owned). No live structured-data validator was used.

## 2026-11-20 Checkpoint commit to Tony (P1–P8)

- Jason approved commit, snapshot re-record and push to `Tony`. The commit lands directly on `Tony` (on `62f54f7`); the progress hook only commits there.
- Reconstruction check: base `0147124` plus patches 000–014 equals this checkout except 3 dead vendor inputs (`lenis.css`, `lenis.min.js`, `ScrollTrigger.min.js`) that patch 003 deletes; removed now.
- `python tools/verify_release_snapshot.py --record`, then verify: PASS, 1558 public paths, 48 pages, 40 products, 120 variants.
- `python tests/check.py`: stops at `tests/asset-audit.py` with 3 `WinError 1314` symlink-privilege errors (Windows host, file unchanged). Later stages run by hand: test_check, test_sync_progress, test_delivery_status, delivery_status --check, structure, frontend-runtime, localization-runtime and JS syntax pass; `catalog-staging.py` has the same 2 symlink errors.
- `patches/*.patch` stay local (002 is 10.3 MB, over the 8 MiB hook limit, and all duplicate this commit). `PATCHES.sha256` records their hashes.
- Next: EN meta descriptions, then B3 micro-interactions, then B5 polish.
- CI on `81b8cc8`: Recovered demo CI, Backend synthetic slice, SAVIA Azure hub, Bug proof and Progress digest pass. SAVIA judge failed: `tests/browser-mock-validation.mjs` asserted exactly 47 public pages; P4 added `404.html` (48).
- Fix: the test now compares `dist/*.html` with `tests/site-pages.json`, the same list `verify_release_snapshot` uses. Local run with Playwright: 50 passed, 0 failed, the 404 page mounts without errors.

## 2026-11-20 P9 (B3 micro-interactions) accepted, P10a (CSS dedup) accepted

- Builders: Sonnet 5.5 high, worktrees from `2ad4713`. P10 stopped at the usage limit after P10a; P10b (audited fixes, EN head meta) not done.
- P10a: `styles.css` 136,879 → 86,427 B. Judge proof: result equals the original minus exactly lines 3–15, 17–50, 52–59, 263–415; each block is byte-identical to its later copy (419–431, 433–466, 468–475, 571–723), so the later copy already won the cascade. The runtime computed-style diff was not run.
- P9: press scale .98, "Agregada"/"Added" + check for 1.5 s with fixed width, bag bump 1.2 on increase only, favorite pop, toast enter/leave, size underline `scaleX`, error fade. JS 513,442 B (+1,792).
- Judge edits on P9: restored the `.button` background/color hover fade that P9 had removed (D-030).
- New judge check `micro` in `tests/storefront_scorecard/slices.py` (MANIFEST updated): transform/opacity only, ≤ 300 ms from `getAnimations()`, added-state timeline and width, bag bump only on increase, favorite, toast by visible state, size, errors without shake, no stuck animation after 5 rapid clicks, no layout shift from feedback targets, reduced motion = 0 animations with states intact, double-click = one line. On `2ad4713` it fails (no B3); on P10a+P9 it passes twice in a row.
- Checks on `2ad4713`+P10a+P9: prepare 0; 7 codemods `--check` 0; pins 0; snapshot only "Publication bytes differ" (needs `--record` at commit); localization-runtime, frontend-runtime, desktop-gallery, static_headers 0; slices grid, footer, title, pill, transition, loader, seo, micro true; scorecard purchase 4/4, axe 0, enSpanish 0, priceBad 0, console 0/0, overflow none, 404 ×4; asset-audit and catalog-staging exit 1 (known WinError 1314).
- Not tested: real iPhone Safari; checkout field-error fade and `.plp-sizes` underline in a real browser (CSS present).
- Next: P10b (audited fixes + EN head meta), then a commit with Jason's approval.

## 2026-11-20 P10b (B5 polish) partly accepted

- Accepted: the `// B5` block in `build-inputs/static/locale-en.js`, with 4 EN meta descriptions (ayuda, catálogo, inicio, novias-encaje). The builder reports 219/219 meta strings translate in EN.
- Rejected: the 44 px touch-target block (`@media(max-width:1023px)`). At 390 px it changes the layout: ayuda help-navigation 58→104 px, catálogo grid-views 70→129 px wide, tabs 33→44 px, page heights +35 to +103 px. D-030 forbids composition changes. Side-by-side evidence was kept outside the repo.
- WCAG 2.5.8 AA asks for 24×24 px; 44 px is AAA or Apple guidance. Proposal for Jason: grow hit areas without layout change, such as a transparent pseudo-element with negative inset, checked per control for overlap.

## 2026-11-20 Checkpoint commit to Tony (P9, P10a, P10b meta)

- Jason approved the commit and push to `Tony` ("Dale"). Deploy is not approved.
- `python tools/verify_release_snapshot.py --record`, then verify: PASS.
- Final tree judge: slices grid, footer, title, pill, transition, loader, seo, micro all true; scorecard purchase 4/4, axe 0, enSpanish 0, priceBad 0, console 0/0, overflow none, 404 ×4, CSS 90,066 B per page.
- `python tests/check.py`: exit 1 only at asset-audit (3) and catalog-staging (2) `WinError 1314` symlink errors; all other stages 0.
- Not tested: real iPhone Safari; P10a runtime computed-style diff.
- Next: Jason decides on layout-neutral touch targets; domain, real catalog, deploy and payments stay pending.

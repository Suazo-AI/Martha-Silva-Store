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

## 2026-11-20 Deploy of `9845c83` to `martha-silva-preview` (D-030 destination)

- Jason approved the deploy ("Hace deploy"). Account `66ee81b7eafd0371097df646a80865bd`; the Worker did not exist, so the deploy created it.
- URL: https://martha-silva-preview.jason-suazof.workers.dev. Version `792ad3bf-8688-4257-9739-41c50ca828e6`. Wrangler 4.158.0, `wrangler.jsonc` unchanged, `dist` equal to commit `9845c83` (1,560 files, all tracked).
- Readback: all 48 pages, all 23 code/text files and 120 random media files return 200 with the same SHA-256 as `dist`. Headers: CSP, `nosniff`, `Referrer-Policy`, `X-Robots-Tag: noindex, nofollow`.
- Browser (agent-browser, 390 px): home, catálogo and producto-negro render with correct titles and H1, no horizontal overflow, no console errors. EN meta description translates.
- The original Worker `martha-silva-demo` is unchanged: version `77bffec9-e5bc-4f56-9596-6c5b4057463f` before and after, home 200 with 311,230 B.
- Known gap: a missing URL returns 404 with an empty body, because `not_found_handling` is `none`; `dist/404.html` is not served.
- Rollback: later versions use `wrangler rollback`. Removing this first version needs `wrangler delete --name martha-silva-preview`, with Jason's approval.
- Not tested live: full purchase flow, iPhone Safari, Lighthouse.

## 2026-11-21 Photo-crop fix (heads and shoes) and 404 page

- Report from Jason (iPhone, `producto-rosa-empolvado-pedreria`): the model's head was cut at the top of the gallery.
- Cause: 8 front photos are 2:3 (1024×1536); the 3:4 `object-fit:cover` frames hide 11.1 % of their height. A centered crop cut heads in the phone gallery, cards and category tiles.
- Site-wide audit (agent-browser, all public pages × 390/768/1440, 4,661 cover images, 0 errors) found no other body crop, except the home hero `ho-m` at 1440 (see open decision).
- Fix in `build-inputs/static/styles.css`: head-safe default `object-position:50% 0` for gallery ≤1023, cards and tiles; then one focal rule per photo, `img[src*="/<slug>/01-front"]`, set from measured head-top and shoe positions. The rules match the image in every context (gallery, cards, tiles, thumbnails, bag, mega menu, page transition).
- Fresh-cache audit after the fix: no head cut in 46 photo × context × width combinations. Trimmed: blanco-perlado train 6.3 %, rosa-empolvado hem 5.8 % (gown only), rojo shoe sole 0.7 %.
- Desktop mega menu (hidden until hover, not in the audit) shows rosa in a 280×360 (7:9) frame: computed from the rule, top crop 3.0 % (head starts at 3.3 %), bottom 11.3 % (gown only).
- Visual check at 390 px: rosa gallery, home cards (negro, azul-gris), catálogo cards (rosa, gris-perla) show complete heads and shoes.
- `wrangler.jsonc`: `not_found_handling` `none` → `404-page` (Jason approved), so Cloudflare serves `dist/404.html` with status 404; `tests/test_deployment.py` updated to match.
- Checks: slices grid, footer, title, pill, transition, loader, seo, micro all true; scorecard purchase 4/4, axe 0, enSpanish 0, priceBad 0, console 0/0, overflow none, 404 ×4, CSS 91,168 B; localization-runtime, frontend-runtime, desktop-gallery, static_headers, pin_page_hashes `--check`, `tests.test_deployment` 0; `tests/check.py` exit 1 only at asset-audit `WinError 1314` (known symlink privilege).
- Judge: Claude Sonnet subagent, ACCEPT (OpenCode DeepSeek free route failed: usage limit). Not measured: thumbnails, cart lines and bag drawer (same per-photo rule by `src`), widths other than 390/768/1440.
- Open decision for Jason: the home hero at 1440 shows a 720×713 cover frame; on negro, champagne and novia-satinada it hides 22.6 % at the bottom (shins and shoes). The full figure cannot fit without a layout change or new art (D-030).

## 2026-11-21 Redeploy of `8ba843f` to `martha-silva-preview`

- Jason approved commit and redeploy ("dale, commit y redeploy cuando pase"). Commit `8ba843f` on `Tony`, SYNCED, remote SHA equal.
- Version `7b04f0d5-4c77-4a0e-85c6-936f85c8757b`; Wrangler uploaded 1 changed file (`styles.css`), 1,558 already present.
- Readback: live `styles.css` SHA-256 equals `dist`; a missing URL returns 404 with the exact `dist/404.html` body (16,683 B); CSP, `nosniff`, `Referrer-Policy`, `X-Robots-Tag: noindex, nofollow` present; home, catálogo and producto-rosa-empolvado-pedreria 200.
- Browser at 390 px (live): rosa gallery `object-position` `50% 21%`, head complete, no horizontal overflow.
- Original `martha-silva-demo` unchanged: version `77bffec9-e5bc-4f56-9596-6c5b4057463f` (100 %), home 311,230 B.
- Rollback: `wrangler rollback` to `792ad3bf-8688-4257-9739-41c50ca828e6`.
- Not tested: real iPhone Safari, Lighthouse, live purchase flow.

## 2026-11-21 P11: remove demo wording from the public store

- Request from Jason: the store must look like the final client delivery, with no demo wording.
- Builder: Claude Sonnet. Judge: Claude Opus.
- Public pages: removed the demo banner and the integration panel; payment step is one "Confirmar pedido" button (`data-test-payment="approved"` kept); order code `MS-0001`; coupon `BIENVENIDA10`.
- Six "Muestra" products renamed: Gala Rubí, Gala Oro, Gala Destello, Novia Velo, Novia Alba, Novia Encaje. Product badges "Muestra" removed.
- Placeholder copy removed: "por confirmar" size cells and notes, the "DETALLES Y CUIDADO" accordion item on 40 product pages, "contacto pendiente" on `ayuda.html`. Size guide now lists S, M, L only.
- `README.txt` (public) and `catalog.js` `brand.policies` rewritten without demo wording; catalog hash updated in the contract fixture and the 20261030 evidence.
- `admin.html`: removed the orphan banner and integration panel markup (their CSS and JS were gone, so they rendered as raw text). The builder had not updated its shared chrome, so it now uses the same header, mega menu, footer and dialogs as `pedido.html`. Copy: "Administrar la tienda", "Los cambios se guardan en este navegador."; login text states the panel has no authentication of its own. The hidden login value is still `demo`.
- Footer: the builder had removed the "Privacidad" link from every page; restored on all 49 pages, plus the in-page "Privacidad" link on `ayuda.html` (`#privacidad` still exists).
- Incident: a scratch script named `html.py` shadowed the standard `html` module and re-applied the builder's text edits whenever a script imported `http.server` from the worktree. It removed the footer link a second time; caught by the snapshot drift check, renamed, and the link restored. Lesson: never name a scratch script after a standard module.
- `locale-en.js`: English pairs follow the new admin copy; dropped pairs for deleted copy.
- Judge change: `scorecard.py` adds `DEMO_RE` and reports `demoHits` over visible text, `placeholder`, `aria-label`, `alt`, `title`, page title and meta description, on every page including admin. Fill data uses a neutral name and `BIENVENIDA10`. `MANIFEST.sha256` re-frozen.
- Static sweep of `dist` (html, js, txt, json, xml), including `og:`/`twitter:` meta, JSON-LD and `llms.txt`: only "muestra" as a verb in two descriptions and internal names (`demo-api.js`, `DEMO_CATALOG`, storage keys). SAVIA/SISFAIN messages in `integration-adapters.js` cannot render: `src/app.js` always uses the local adapter.
- Test coverage: the builder deleted 9 mode-switch tests; added one memory-only test (cart and order survive BFCache with `localStorage` blocked) in `tests/frontend-runtime.cjs`.
- Checks: prepare, codemods, SEO, pins (48 pages), snapshot 20261105 PASS, node and Python suites green; scorecard purchase 4/4, demoHits 0, enSpanish 0, priceBad 0, axe 0, console 0/0, overflow none, 404 ×4, small390 952 (950 before; +2 likely from the restored "Privacidad" links). Evidence: `%TEMP%/sf-loop/p11-judge/final4`.
- Admin spacing (pre-existing, same on the live preview; Jason approved the fix): `styles.css` gives admin headings `line-height:1.2`, 40 px between sections, 24 px under the notice, and stacks the toolbar heading above its buttons under 600 px. Checked in a browser at 390 and 1440.
- Known failures, not caused by P11: `check.py` stops at `asset-audit` with `WinError 1314`; `green-header.cjs` fails 2 of 6 checks, same at HEAD.
- Browser at 1440 and 390: header sticks at top 0, mega menu flush under header, no banner gap.
- Left for the client: real measurements, composition and care, business contact, privacy text, payment wording ("Pago aprobado" without a real payment), delivery rates $5 and $8. `noindex` kept. Image folder names (`generated-luxury`, `prototypes`, `research`) still appear in URLs.
- Jason approved commit and redeploy, including the admin spacing fix ("Si, también hazlo").

## 2026-11-21 Redeploy of `2a75ea17` to `martha-silva-preview`

- Version `ccdd315b-e76a-452a-bb68-1eaf0dd34164`; 57 files uploaded, 1,502 already present. Rollback target: `7b04f0d5`.
- Readback: `styles.css`, `app.js`, `locale-en.js`, `catalog.js` and `README.txt` match `dist` by SHA-256.
- `/`, `/admin`, `/ayuda` and `/producto-gala-rubi` match `dist` when fetched with redirects followed; `*.html` URLs answer 307 to the pretty path.
- A missing URL answers 404; `x-robots-tag: noindex, nofollow` present; no banner, "demo de prueba" or `PRUEBA10` text on the home page.
- `martha-silva-demo` unchanged at `77bffec9` (100 %).

## 2026-11-21 Decision: home hero at 1440

- Jason: the home hero at 1440 is fine and not cropped; leave it as it is ("El hero de home está bien, no se ve cortado deja eso ahí").

## 2026-11-21 P12: the published store reads as the final store (local, not committed)

- Jason: "no hagas alusión a que fue generado con IA o es un prototipo de ninguna manera, ya estamos migrando a que la página entera se vea Operational".
- Public folder names: `prepare.py` publishes the source folders under neutral names from `build-inputs/public-paths.json` and rewrites root-relative references in text files.
- Mapping: `assets/research/assets/store-media/` → `assets/photos/`; `research/assets/store-media/` → `photos/`; `generated-luxury/` → `looks/`; `generated-illustrations/` → `illustrations/`; `prototypes/` → `lib/`.
- The repository keeps the old folder names, because AGENTS.md requires provenance names in source and the frozen evidence is keyed by them.
- `responsive-images/manifest.json` is no longer published; no runtime code reads it.
- `lib/vendor/` stays byte-identical; `prepare.py` refuses to rewrite it.
- Code renames: `src/demo-api.js` → `src/store-api.js`, `DEMO_CATALOG` → `STORE_CATALOG`, demo/test/simulated wording in public JS replaced by neutral terms, `sample_image` → `editorial_image`, `commercial_status` `sample` → `unlisted`, mode `local_test` → `local`, payment hooks `test-payment` → `payment`.
- The SAVIA HTTP contract adapter moved to `src/savia-http-adapter.js`, which is not published; `tests/integration-adapters.test.js` loads it from there.
- Browser storage keys changed without migration (`martha-store-state-1`, `martha-store-lock`, `martha-favorites`, `martha-newsletter-dismissed`). Carts, orders and favorites saved by earlier preview visitors reset once.
- New check `tests/public_names.py` (stage in `tests/check.py`): no provenance or test wording in published paths or text, and every root-relative asset reference resolves. Negative control on the previous `dist`: 28,170 hits and 1 unresolved reference.
- New helper `tests/public-paths.cjs` mirrors `public_path`/`public_bytes` for Node tests; it reproduces all 1,556 published static files byte for byte.
- `tests/green-header.cjs` (failing 2 of 6 since the luxury selection, commit `c4e0e48a`): the whole-`styles.css` e2a hash was retired, the scoped Green CSS checks stay; the four-photo crop contract now follows `evidence/releases/20261030/luxury-selected-assets.json` (3 Green images) through the catalog and the page gallery. `docs/DECISIONS.md` has no entry for that luxury selection.
- The brand hero entry in `catalog.js` pointed to a missing file read by no code; it is now `null`.
- Embedded metadata, not changed: 158 published PNG files (156 under `looks/`, 2 under `illustrations/`) carry C2PA content credentials naming OpenAI/ChatGPT and the IPTC `trainedAlgorithmicMedia` source type. They are byte-pinned by the release evidence. Removing them needs Jason's decision.
- Client data from Jason: phone and WhatsApp `+505 8856 5666`; returns allowed for one month. The help page `#devoluciones` now says one month from delivery, and `#contacto` adds `tel:+50588565666` and `https://wa.me/50588565666` next to Instagram. `catalog.js` `brand.contact` and `brand.policies.returns` carry the same values; catalog pin `e3a6affe…`, 217,538 bytes.
- The local order engine does not yet enforce the one-month window; the help text states the policy.
- Regression found and fixed: after the payment rename, `src/app.js` still read `b.dataset.testPayment`, so "Confirmar pedido" would send no outcome and fail with "Elegí un resultado de pago.". Reproduced in jsdom (`dataset.testPayment` is `undefined`); now reads `dataset.confirmPayment`. Node suites did not click that button; the scorecard does.
- Order event `test_refund_completed` renamed `refund_completed` in `src/store-api.js` and `src/app.js`.
- Checks after these changes: prepare, page pins, SEO check, release snapshot record and verify, `public_names`, the 4 codemod checks, 11 Node suites, `green-header` 6/6, and 8 Python suites pass. `asset-audit` and `catalog-staging` fail only the symlink tests (`WinError 1314`, no symlink privilege on this Windows host).

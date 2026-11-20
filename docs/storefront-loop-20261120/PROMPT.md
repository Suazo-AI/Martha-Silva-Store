# Storefront finish loop: Sonnet builds, Opus judges

## Who you are

You are the primary orchestrator and judge: Claude Opus 5.5 in T3 Code.
Claude Sonnet 5.5 builds; you never accept its work on its word.
Jason owns the business decisions and is the only visual authority.

## Amendment: Jason's go (2026-11-20)

This section overrides any conflicting line below.
Source: Jason's message "go", "Unicamente vas a trabajar con modelos claude y opencode", the Lenis/ScrollTrigger call, and "pone marcas como SHE, lululemon. Marcas chic."

- Go covers Phase 0, Track A, the Lenis/ScrollTrigger slice (A8) and the B0 spec page.
- Go approves the 47→48 page-count edit in `tests/check.py` for the 404 page.
- Go does not approve commit, push, the `--record` re-record or deploy; patches stay uncommitted.
- Track B builds still wait for Jason's approval of the B0 spec page.
- Routes: only Claude models and OpenCode.
  - Builder: Claude Sonnet 5.5.
  - Critic for high-risk slices: a fresh, read-only Claude Opus session (never a fork), or a free OpenCode model; skip any per-use billing.
  - Codex and AGY routes are removed, including the AGY visual critic and the AGY step in B0 intake; B0 uses FFmpeg frames with direct inspection.
- A8, remove Lenis and ScrollTrigger (judge's call, delegated by Jason):
  - Evidence: `src/app.js:204` declares `lenis` and `:480` destroys it, but nothing assigns it; no source calls ScrollTrigger or `registerPlugin`; no test or tool references either.
  - A `tools/` codemod with `--check` removes the two script tags and the `lenis.css` link from the HTML inputs.
  - The vendor files and the inert `data-lenis-prevent` attributes are deleted in the same slice; the path-pin change is batched with A7.
  - Checks: 0 console errors, purchase passes, and scroll pixel diff within noise.
- Without ScrollTrigger, the footer (B4e) reveals with CSS: the footer sits under the content with `position: sticky` and the page slides off it.
  The veil fade may use CSS scroll-driven animation only as progressive enhancement after a current support check; the static fallback must read as finished.
  B4a and B4e leak checks count GSAP global timeline children and Barba containers instead of `ScrollTrigger.getAll().length`.
- Brand wall: Jason lifted the real-name limit for brand names.
  It shows text wordmarks from `site.config.json`, with no logo files and no `brand` field in Product JSON-LD.
  Text instead of logos departs from the video on purpose.
  The candidate list is shown on the B0 spec page as unconfirmed; Jason confirms the exact names ("SHE" may mean SHEIN), because the wall claims the store carries them.

## Objective

Finish the public storefront to Jason's approved "finished" definition (Track A).
Then raise its premium feel, motion (Jason's 8 picks), SEO/AIEO/GMB readiness and mobile speed (Track B), after Jason approves the Track B spec.
Every accepted iteration must close at least one defect or acceptance item with zero measured regressions.
"Looks better" is proven only by Jason's pick on same-sequence before/after recordings.

Mode: BUILD.
Revenue link: this removes the storefront's own defects before launch.
It does not unblock sales: card payment (D-008, D-009) and real orders (D-010) still block them.

## Sources of truth

- Repo: `C:/Users/Jason/.t3/worktrees/github/frontend-finish-f84c41ce23a85739`, branch `frontend-finish`, base SHA `0147124`.
- Read first: `AGENTS.md`, `docs/AGENT-START.md`, `docs/CODE-MAP.md`, `DESIGN.md`, and D-001, D-008, D-009, D-010, D-019 and D-030 in `docs/DECISIONS.md`.
- Baseline evidence from 2026-11-19: `docs/storefront-loop-20261120/baseline-20261119/` (gap page, result JSONs, reference scripts).
- Rules: `orchestration.md`, `task-completion.md`, `ui.md`, `website-motion.md` and `video.md` in `C:/Users/Jason/AI-OS/rules/`.
- Protocol and output: `C:/Users/Jason/AI-OS/PROTOCOL.md` and `C:/Users/Jason/AI-OS/OUTPUT.md`.
- Premium reference (ui.md): `C:/Users/Jason/MARTHA-SILVA/research/net-a-porter/` (`INSPIRATION.md`, `design-system-v6/`, `analysis-v6/`) and `C:/Users/Jason/MARTHA-SILVA/system/commerce-template.md`.
- NAP gaps: `C:/Users/Jason/MARTHA-SILVA/system/nap-gap-analysis.md`.
- Motion catalog and spec template: `website-motion.md` and its reference `C:/Users/Jason/Documents/Codex/2026-10-08/get-this-thing-properly-set-up/outputs/x-animation-reference.mp4` (30 s, 1080×1350, 24 named effects).
- Jason's 8 motion videos (2026-11-20) decide which effects ship: see "Jason's motion picks" below.

## Decisions already made (frozen)

Track A, approved by Jason on 2026-11-20:

1. Complete EN: translate the 5 Spanish strings ("Elegí talla de…", "Agregar rápido…", "Categorías", "Ver" and the carousel "1 de 3").
2. Accessible structure: put the test banner inside a landmark; fix heading order on catalog cards and in the bag.
3. Clean console: remove the "GSAP target not found" warning.
4. One price format, `$165.00`, in ES and EN, in static HTML and in JS.
   Interpretation of "the $ and the number": keep two decimals and comma thousands (`$1,250.00`); Jason may correct it.
   This is display only: keep the ISO code `USD` in data, integration adapters and structured data.
5. Contrast AA on the category tabs and the h2 "El edit de novias", with the smallest change to the D-030 colors.
6. Size L: Jason approved the fix; the option below is the judge's pick, and he may correct it.
   Keep L in the filter, disabled and labeled "Agotada" / "Sold out"; no dead-end 0-result state; sample data untouched.
7. Custom 404: a `404.html` in the store style plus `assets.not_found_handling: "404-page"` in `wrangler.jsonc`.

Track B motion, chosen by Jason on 2026-11-20: the video → element mapping in "Jason's motion picks" is frozen.
How each pick is built there is a judge default that the B0 spec confirms.

Judge defaults (Jason can override):

- D-030 holds: keep Jason's style, layout and frontend; Denis contributes only images.
- Creativity goes into motion, micro-interactions and detail.
  Any composition change goes to Jason as a proposal first.
- Motion set: Jason's 8 picks are the complete set of new effects; add no other.
  Existing effects stay unless a pick replaces them.
  B3 micro-interactions are feedback, not effects.
- Micro-interactions use the DESIGN.md timings: fade 200 ms, slide 300 ms, `cubic-bezier(.25,.1,.25,1)`.
  Animate transform and opacity only.
- SEO data comes from `catalog.js` and one site config file through an idempotent generator in `tools/` with a `--check` mode; nothing is hand-written per page.
- `dist/` must equal the canonical inputs byte for byte, as `tools/verify_release_snapshot.py` requires.
  `prepare.py` stays a copier.
  Generated content is written into `build-inputs/static/`, never transformed at build time.
- The preview stays `noindex`; indexing is a publication decision.
- No `hreflang`: EN is a client-side toggle on the same URL.
  Separate EN URLs would be a new decision.
- LocalBusiness/ClothingStore data and footer NAP come only from verified config values.
  The config ships empty, so nothing is emitted.
- Never invent NAP, reviews, ratings, prices or stock.
- No refactor beyond the code each slice touches; no rewrite of `src/app.js`.

## Repo inspiration decisions (GitHub metadata read 2026-11-20)

| Repo | License | Decision |
| --- | --- | --- |
| vercel-labs/agent-browser | Apache-2.0 | Take: browser, recordings, vitals, axe, pixel diff, reduced-motion emulation |
| greensock/gsap-skills | MIT | Take: the installed `gsap-*` skills fit the existing GSAP and ScrollTrigger stack |
| emilkowalski/skills | MIT | Take: the installed `emil-design-eng` skill for interaction craft |
| nextlevelbuilder/ui-ux-pro-max-skill | MIT | Take: the installed `ui-ux-pro-max` e-commerce rules for review |
| tailwindlabs/heroicons | MIT | Take only if a needed icon is missing; inline SVG; keep one icon family |
| shadcn/improve | MIT | Adapt: its pattern is this loop (a strong model audits and plans, a cheaper model executes) |
| shadcn-ui/ui | MIT | Adapt the accessible behavior of Dialog, Sheet, Select and Toast; no React or Tailwind |
| jakubkrehel/skills, ibelick/ui-skills | MIT | Adapt: read the relevant SKILL.md files as detail checklists; install nothing |
| DavidHDev/react-bits | NOASSERTION | Ideas only: rebuild a chosen effect with the existing GSAP; copy no code |
| achimala/dream-loop | MIT | Adapt the loop shape (target image vs live screenshot, plus a critic); its Blender/3D flow does not apply |
| velox-themes/crosshair-skeleton | MIT, 2 stars | Idea only: image placeholders; prefer reserved space over an animated shimmer |
| Illyism/seo-skills | none | Read as a checklist only; it has no license, so copy nothing |
| colbymchenry/codegraph | MIT | Not used: the repo has no `.codegraph/`; indexing is Jason's decision |
| INSANE0777/Awwwards-mcp | MIT | Reject: a new MCP; use the `inspiration-harvest` skill if more references are needed |
| every-app/open-seo | MIT | Reject now: keyword data needs paid APIs or accounts, which need Jason's approval |
| jIrwinCline/posthog-superpower | MIT | Reject now: a PostHog account, consent and a CSP change need Jason's approval |
| tt-a1i/archify, vitali87/code-graph-rag | Apache-2.0, MIT | Reject: no reader needs them here |
| petyosi/react-virtuoso | none | Reject: 40 products need no virtualization |

## Jason's motion picks (2026-11-20)

Jason attached 8 Osmo (osmo.supply) preview videos, all 1440×900 MP4, in `C:/Users/Jason/.t3/userdata/attachments/`.
Each file is named `mcp-launch-4a887284a0db90e01be7b3b0e096e8e6e882083a897de09e7f693af766c47403-<id>-mp4.mp4`.
B0 re-checks bytes and SHA256 first; on a missing file or a mismatch, stop and ask Jason.

| # | Video | id | Bytes | SHA256 | Length | Element (frozen) |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | masked-window page transition | `1a656abf-d39c-4b6a-be1b-a950e0a8cabd` | 994,135 | `ccb156d21340436eaab675f6e370a3f317807907234ef83b8b189acd4d335674` | 3.50 s, 30 fps | Page transitions |
| 2 | expanding bottom navigation | `9c18af8d-1885-4480-a789-27911131daf1` | 81,953 | `26da04e6b45e04369e699b45deb3c42e57002067451497666bce145ad44ce1b6` | 2.83 s, 30 fps | Mobile navigation, and inspiration for the nav bar |
| 3 | glass effect background | `30522169-b87d-4a10-9bc9-13897c560263` | 1,385,575 | `06625b084e5d9d36d8a8cf1c275afd0d646e66767d0e0d1ad01aab33b125d162` | 5.00 s, 30 fps | Material of the mobile navigation |
| 4 | layout grid flip | `147d1dc6-e002-4526-94d5-b9ecbdd90210` | 683,264 | `a0d15ad800c43ed97338b23ed14dbbb62cb52578794d7af59095b1923d56f67c` | 2.93 s, 60 fps | New catalog grid-view toggle; none exists today |
| 5 | Willem loading animation | `9289fa93-ca38-453a-9a98-06ef3f9d5dec` | 253,087 | `c032ce40c4f98dce197dd6adb8f5696074f2b7d06e4e81e9dd2409d0e11f21f9` | 4.67 s, 30 fps | Loading animation |
| 6 | footer parallax effect | `e0211533-eb37-48a6-9be9-f925bf7d76ce` | 795,395 | `cbcacf0fe4d871f2f56925a8c3a246b23491587025efbb0c2d94f34d28d87a51` | 5.17 s, 30 fps | Footer, with big type across its full width |
| 7 | logo wall cycle | `a883ff70-394f-4bb1-a407-4994802a8b8d` | 48,796 | `4b2da7f16d715da26ed702386ff44516472535541465d7268fd7fa3d59813547` | 4.00 s, 30 fps | New "Marcas que encuentras" section |
| 8 | change page title on leave | `52a426b9-d21a-410f-a42c-4b547b50da5c` | 172,639 | `f086ef95f371e34753d713eed7a47faf309be1acb89dc31c5c4047303ca6683a` | 4.34 s, 29.97 fps | Tab title while the tab is hidden |

Observed motion, read from 16-frame contact sheets (about ±0.2 s); B0 resamples each motion window at full frame rate:

1. A rounded window rises from the bottom center (0.2 s), becomes a centered card (0.44 s) and fills the screen (0.65–0.88 s), with the next page inside it; the reverse starts at 2.19 s.
2. A bottom-center pill with a logo and a square menu button morphs (0.35–0.53 s) into a tall card with large staggered links and a contact block, and the button becomes an X; on close (2.12–2.48 s) the content fades, then the card shrinks back to the pill.
3. A floating pill nav with frosted blur and tint stays legible over scrolling content.
4. A "Large/Small" toggle switches 3 columns with name and price to 5 columns without price; cards move and scale in about 0.5 s with a slight stagger.
5. A word rises from a mask (0–0.3 s); a gap opens inside it (1.17 s) and cycles images every 0.3 s; the last image grows to full screen (3.2–3.5 s) and the hero appears.
6. The footer appears beneath the content with a slower parallax and a dark-to-light veil; three link columns sit above a giant full-width wordmark.
7. A 4×2 logo grid on black swaps one cell about every 0.75–1 s with a fade or slide.
8. Leaving the tab changes its title to a come-back message; returning restores it.

One motion system (judge default):

- Set-piece duration, easing, corner radius and origin are defined once, as CSS custom properties mirrored by one JS constants object; effect code has no magic numbers.
- The transition window, the mobile pill and the loader image share one radius token and grow from the bottom center, so navigation, menu and entrance read as one system.
- The loader opens the visit and the footer closes it with the same MARTHA SILVA wordmark.
- Every effect degrades to a static, usable page without JS, without GSAP and under reduced motion.

Code architecture (judge default; the critic reviews it):

- `prepare.py` copies exactly three `src/` JS files, so new behavior goes into `src/app.js` as named `init…` functions.
  A new `src/` file needs a judge-approved change to `prepare.py`, `tools/verify_release_snapshot.py` and the path pins.
- All 47 pages carry the footer and the toast, and 46 carry `data-menu-toggle` and `#mobile-menu`; `checkout.html` has no menu and gets no pill.
  42 pages hold a Barba container between `</header>` and the footer; `admin`, `ayuda`, `bolsa`, `checkout` and `pedido` have none and always load in full.
  So the mobile navigation, footer, tab title and loader mount once per full page load.
- Site-wide markup, such as the pill or the footer wordmark, lands through CSS on existing elements, or else through an idempotent `tools/` codemod with `--check` across the HTML inputs, as in A6.
  Never edit the 47 pages by hand, and never inject site-wide markup with JS.
- Every new init feature-detects `gsap`, `ScrollTrigger`, `IntersectionObserver` and `showModal`, because tests such as `tests/desktop-gallery.cjs:108` run `app.js` outside a browser.
- The grid toggle and the brand wall live inside the container; they register listeners on the existing `pageScope` AbortController (`src/app.js:669`) and kill their tweens when it aborts.
- `src/app.js` never calls ScrollTrigger or creates a Lenis instance (0 matches for `ScrollTrigger` and `Lenis`), yet all 47 pages load `ScrollTrigger.min.js` (44,575 B), `lenis.min.js` (18,722 B) and `lenis.css`.
  The footer adds one site-wide ScrollTrigger that refreshes after each Barba navigation; B2 decides whether Lenis stays.
- `styles.css` has two layers: from line 416 ("Jason public frontend, captured 2026-11-05") it repeats and overrides earlier rules, and line 4 equals line 420.
  Verify the computed style, not the source line.
- `tests/desktop-gallery.cjs:108` mocks `barba.init` and reads `transitions[0]`; keep the editorial transition first, or update that test in a judge patch.

Build per element (judge defaults, confirmed at B0):

1. Page transition (B4a, high risk).
   - Barba forward navigations show the next page inside a rounded window that grows from the bottom center to full screen in at most 700 ms.
   - The outgoing page stays still under the window, and the scroll resets only after the window covers the viewport.
   - `mountPage` runs in Barba's `after` hook, which follows `enter`, so the window may show the next page only after it is mounted, translated and rendered.
   - The window may animate `clip-path`, the one exception to transform and opacity, only if the long-frame check passes.
   - Back and forward keep today's 120 ms fade and scroll restoration; reduced motion keeps today's instant swap.
   - Barba runs only between home, catalog and product pages (`prevent` at `src/app.js:802`), so bag, checkout and the other full-load pages get no transition; B0 shows this so Jason can object.
   - Critic failure cases: Spanish or unrendered content inside the window in EN; the outgoing page jumping on `scrollTo(0,0)`; lost focus; a click during the transition; the 4 s Barba timeout.
   - Checks: frames at 25, 50 and 100 % show the window; EN shows only English inside it; no long animation frame over 50 ms (Long Animation Frames API, local, relative only); equal `ScrollTrigger.getAll().length`, GSAP global timeline children and Barba container counts after 1 and 10 navigations; real-click purchase at 390 ES and 1440 EN.
2. Mobile navigation with glass (B4b).
   - Below 1024 px, the current `.menu-toggle` breakpoint (`styles.css` lines 12 and 428), a glass pill fixed at the bottom center replaces the header menu button.
   - The pill holds the wordmark and the menu button, as in the reference.
   - Tapping it morphs the pill into a card with the existing `#mobile-menu` content, and the links stagger in.
   - The card stays the native `<dialog id="mobile-menu">` opened by `openDialog` (`src/app.js:507`), so `showModal`, Esc and focus return keep one source of truth; the close animation runs before `dialog.close()`.
   - The glass uses `backdrop-filter` with the `-webkit-` prefix, and turns solid under `@supports not (backdrop-filter: blur(1px))` and under `prefers-reduced-transparency: reduce`.
   - Targets are at least 44×44 px, the pill respects `env(safe-area-inset-bottom)`, the toast (`.toast`, bottom center) sits above it, and page padding keeps it off the last footer link and any focused element (WCAG 2.4.11).
   - From 1024 px up, the header does not change.
   - For "inspiración para el nav bar", B0 shows Jason one 1440 mockup that carries the glass pill into the desktop header, and he picks yes or no.
   - Checks: axe cannot rate text over `backdrop-filter`, so compute the pill text contrast against its tint over pure black and over pure white (at least 4.5:1 on both); test at 390, 1023 and 1024 px; keyboard pass (open, Tab cycle, Esc, focus return) and an accessibility-tree snapshot (`aria-expanded`, dialog name), with a real screen reader listed as unverified; the toast never overlaps the pill, and no focused element hides behind it at 390; 1440 header pixel diff within noise; real-click purchase at 390 ES.
3. Catalog grid toggle (B4c).
   - `catalogo.html`, the only catalog page, gets a two-option segmented control of native radios, in ES and EN, that sets `data-grid` on the product grid.
   - "Grande" is the default and keeps today's grid: 4 columns from 1024 px and 2 below, with name and price.
   - "Pequeña" shows 6 and 3 columns with images only; name and price stay in each card link's accessible name, and quick-add is hidden and leaves the tab order.
   - The choice persists in `localStorage` key `martha-grid-v1` across Barba navigation and reload, and storage errors are caught.
   - A manual FLIP with GSAP core moves the cards in at most 500 ms with a small stagger; text fades and never scales; the same helper animates filter and sort reflow; there is no Flip plugin.
   - Reduced motion switches instantly.
   - Checks: computed column count per state at 390 and 1440; accessible names; no overflow; quick-add and purchase pass in "Grande".
4. Loader (B4d, high risk).
   - It plays on the home page only, on the session's first home visit, and never on Barba navigations, under reduced motion or without JS.
   - "MARTHA" and "SILVA" rise from a mask, a gap opens between them and cycles 3 or 4 existing catalog images, and the last one, the home hero image, grows to full screen.
   - It hands off to the existing `[data-intro]` fade in `motion()` (`src/app.js`), so the page keeps one entrance.
   - It lasts at most 1.6 s, and any key, click, tap or scroll ends it at once.
   - The first frame of a fresh session is the loader, with no flash of the page.
   - All 10 scripts on `index.html` use `defer` and CSP forbids inline script, so this needs a render-blocking mechanism; the critic review chooses it.
   - A new public file moves the 1,558-path pin through a judge patch.
   - A CSS failsafe hides the loader after 3 s if `app.js` never runs.
   - Checks: fresh-session LCP with the loader playing, median of 3, within noise of the baseline; the first recorded frame shows the loader; a repeat visit, reduced motion and no-JS show none; no new image file.
5. Footer (B4e).
   - The footer reveals with a parallax: its inner part rises from about −25 % to 0 while a dark veil fades out, scrubbed by one site-wide ScrollTrigger.
   - A full-width "MARTHA SILVA" wordmark in Cormorant Garamond sits at its base, `aria-hidden="true"`, sized with CSS container-query units and no JS.
   - The newsletter, text and links keep their content and layout (D-030).
   - Reduced motion shows the static footer with the wordmark.
   - Checks: the wordmark fills 98–100 % of the container width at 320, 390, 768, 1024, 1440 and 1920 px without horizontal overflow; the newsletter form still works; equal `ScrollTrigger.getAll().length` after 1 and 10 navigations.
6. Brand wall "Marcas que encuentras" (B4e, blocked on data).
   - Real brand logos conflict with the hard limit "No real store names, photos, secrets or customer data in Git or the demo".
   - Showing them needs Jason to lift that limit for brands explicitly and to send the brand list and logo files with display rights, imported by allowlist with hashes (AGENTS.md).
   - The `tools/` generator writes the section into `index.html` from a brand list in `site.config.json`, so brand names stay crawlable text.
   - Until then, the brand list ships empty, the generator emits no brand section, and a fictional fixture lives only in `tests/`.
   - Build: a 4×2 grid at 1440 and 3×2 at 390; one cell swaps about every second with a 300 ms fade and slide; it pauses off screen, while the tab is hidden and under reduced motion; a visible pause button meets WCAG 2.2.2.
   - Checks: no brand section with the empty config; with the fixture, swap, pause and reduced-motion behavior pass.
7. Tab title (B4e).
   - When the tab hides, save `document.title` and show a localized away title; when it returns, restore the saved title if the away title is still showing.
   - Copy for Jason to confirm at B0: with items in the bag, "Tu bolsa te espera · MARTHA SILVA" / "Your bag is waiting · MARTHA SILVA"; otherwise "Vuelve pronto · MARTHA SILVA" / "Come back soon · MARTHA SILVA".
   - Add one named handler beside the `visibilitychange` listener at `src/app.js:814`, not inside `videoMotion`.
   - The HTML `<title>` never changes, so SEO is untouched.
   - Checks: emulated hide and show give the away title in the active language and then the exact original; after a Barba navigation, the restored title belongs to the new page.

## Roles and routes

- Judge and orchestrator: you.
  You own slicing, packets, frozen checks, independent acceptance, serial integration, records and the report.
- Builder: Claude Sonnet 5.5 via T3 `delegate_task`, with `isolation:"worktree"` from `frontend-finish`.
- Call `orchestrator_capabilities` once before the first `delegate_task`.
  Use its exact model id and option names, and request high effort explicitly.
- Verify the effective model in each worker return.
  If Sonnet is unavailable, stop and tell Jason; do not switch models or routes.
- Critic, for high-risk slices only: codex `gpt-6-astra` with `{reasoningEffort:'xhigh'}`, read-only, in a fresh session, before any implementation (orchestration.md).
- High-risk here means: bag, checkout, price or order code; Barba navigation; the home page's first paint (loader); `_headers`; `wrangler.jsonc`.
- Optional visual critic: a different vendor on blinded A/B pairs (AGY `gemini-4-argon` high; `gemini-3.8-flash-high` for video, per video.md).
  It is advisory only; skip any route that bills per use.
- One builder at a time; one writer per worktree.

## Owned scope

- Builders may change `src/`, `build-inputs/static/` and `prepare.py`.
- Builders may also add scripts in `tools/` that the packet names, add test cases to existing `tests/*.cjs` files, and change `not_found_handling` in `wrangler.jsonc`.
- `dist/` is tracked (1,560 files) but changes only through `python3 prepare.py`.
  Builder patches exclude it; the judge regenerates it after each integration.
- Pinned expectations belong to the judge: the 47-page count in `tests/check.py`, `tests/structure.py`, `tests/test_check.py`, `tests/frontend-runtime.cjs` and `tests/localization-runtime.cjs`.
- `tools/verify_release_snapshot.py` also pins the 47 page names, 1,558 public paths, and every public byte in `evidence/releases/20261105/responsive-runtime-sha256.json`.
  The `tests/check.py` stage "Reproducible snapshot build" enforces the path pins on the real `dist/` path set, with fixture bytes.
  CI `tony-snapshot.yml` also checks the recorded bytes.
  Read-only run at `0147124` on Windows: PASS, 1,558 public paths, all 1,560 dist files equal to the inputs.
- When a slice legitimately invalidates an existing assertion, the judge updates it in a judge patch and logs the reason.
  Known cases: A6 changes `USD 185.00` in `tests/localization-runtime.cjs:191,197`; A7 and B1 change the page and path pins above; B4a may change `tests/desktop-gallery.cjs:108`; B4d moves the path pin if it adds a file.
  Prefer a design that keeps the count.
- Every slice changes public bytes, so the recorded-bytes check drifts during the loop by design.
  Re-record it with `python tools/verify_release_snapshot.py --record` only at commit time, after Jason approves the re-record.
- Ask Jason before editing `tests/check.py`, because the PR7 thread also changes it.
- Judge-only and frozen: `tests/storefront_scorecard/` with its SHA256 manifest, and `docs/storefront-loop-20261120/`.
- Out of scope: `savia/` and the osmo.supply `fit-text-to-width` resource (the SAVIA thread), CI and the `tests/check.py` stage list (the PR7 thread owns them), `_headers`, and the original Cloudflare site.

## Hard limits

- No commit, push, deploy, merge, SQL beyond the local dev container with fictional data, account change or spending without Jason's explicit approval.
- Builders never commit, because the local hooks sync GitHub.
  If a T3 handoff needs a commit, stop and ask Jason.
- The original Cloudflare site stays intact.
- No real store names, photos, secrets or customer data in Git or the demo.
- Preserve unrelated work.
  Do not edit `savia/db` or `savia/api`.
- No new dependency, CDN, MCP or tool install.
  CSP `script-src 'self'` stays.
- Clean-room rule for Jason's motion picks: rebuild each effect from the observed motion with the existing GSAP core and CSS.
  Copy no Osmo code, CSS, copy text, assets or demo content, and do not open or buy osmo.supply resource code.
  Never commit the videos or frames from them; extract frames to a scratch folder outside the repo.
- Paper file "Martha Silva · Ecommerce": use it only for a screen that needs a design decision; read `get_guide("paper-mcp-instructions")` first; count calls; the weekly cap is 100.
- Caps: 3 builder attempts per slice and 24 builder runs in total.
  The plan has 14 builder packets (5 in Track A, 9 in Track B), which leaves 10 retries; only Jason can raise a cap.
  Stop on uncertain billing or any per-use charge.
- If you run `tests/gallery-browser-contracts.cjs`, set `GALLERY_OUTDIR` to a scratch folder; otherwise it rewrites tracked docs.

## Phase 0: baseline and frozen gates (judge, before any builder run)

1. Run `python C:/Users/Jason/AI-OS/bin/agent-awareness.py --workspace "<repo>"`.
   Confirm SHA `0147124` and a tree that is clean except `docs/storefront-loop-20261120/`.
2. Build with `python3 -B prepare.py --output <scratch>/baseline/dist`.
   Serve it with the `_headers` CSP (reference: `baseline-20261119/csp_server.py`).
3. Write the scorecard harness in `tests/storefront_scorecard/` from the reference scripts.
   Each run prints one compact JSON with:
   - axe violations by impact, on the 9 baseline states plus the checkout steps and the 404, at 390 and 1440 px;
   - Spanish strings in EN mode, on 26 states at 2 widths;
   - console errors and warnings, including CSP violations;
   - price strings that do not match `^−?\$\d{1,3}(,\d{3})*\.\d{2}$` (the bag shows discounts with U+2212), on all 47 pages in ES and EN, plus bag, checkout and order;
   - horizontal overflow, broken images, pages without exactly one h1, and interactive targets under 24×24 px at 390;
   - real-click purchase pass or fail at 390 and 1440, in ES and EN, under CSP;
   - the exit of each `tests/check.py` stage, run one by one, because `check.py` stops at the first failure;
   - byte parity: `dist/` equals `build-inputs/static/` plus the three `src/` JS files, with no CRLF in top-level HTML, JS or CSS;
   - JS, CSS, font and image bytes and the request count for home, catalog and one product page at 390;
   - `agent-browser vitals` LCP, CLS, FCP and TTFB, median of 3.
     The server is local and unthrottled, so these are a relative ratchet only, never a field claim;
   - animations running on load per page, and visible content under reduced-motion emulation.
4. Calibrate: run the harness 3 times on the baseline and record the noise bands.
   It must reproduce the known findings: 5 EN strings; axe color-contrast (serious), region and heading-order; mixed `US$`/`USD` prices; the GSAP warning; the server's own 404; size L → 0 results.
   If one does not reproduce, fix the harness before trusting it.
5. Freeze: write the SHA256 manifest of the harness and recheck it before every evaluation.
   Save the harness as `docs/storefront-loop-20261120/patches/000-scorecard.patch`, the first patch of the series, so every builder worktree has it.
   Builders run it and never change it.
6. Record "before" videos with `agent-browser record` at 390×844 and 1440×900, with the same scripted sequence:
   a fresh-session home load; home scroll to the footer; the mobile menu open and closed at 390; catalog filter, sort and quick-add; a catalog→product navigation; product gallery, zoom and size; bag; checkout to the DEMO order; a missing URL; the EN toggle.
   Never re-record "before" after a change.
7. Create `docs/storefront-loop-20261120/LOOP-LOG.md` and `STATE.md` (objective, base SHA, champion scorecard, accepted patches, next action).
   Update both after every iteration.

## Track A: approved slices (start on Jason's go)

| Slice | Goal | Red→green check | Risk |
| --- | --- | --- | --- |
| A1 | Guard GSAP targets | 0 console warnings under CSP | low |
| A2 | Complete EN | EN scan 0; a new case in `tests/localization-runtime.cjs` | low |
| A3 | Banner landmark and heading order | axe `region` 0 and `heading-order` 0; no pixel change elsewhere | low |
| A4 | Contrast AA | axe serious 0; the `color-system` contrast script exits 0 | low, visual |
| A5 | Size availability in the filter | L disabled and labeled in ES and EN; correct keyboard and screen-reader state; no 0-result dead end | medium |
| A6 | Price format | 0 non-matching price strings; bag, coupon and checkout totals unchanged; integration currency still `USD` | high: critic first |
| A7 | 404 page and wrangler | the local server returns `404.html` with status 404; `wrangler.jsonc` parses; Cloudflare behavior stays unverified until an approved deploy | high: critic first |

A1 to A3 may run as one builder packet; each keeps its own check.
A6 facts: 3,354 `US$` strings sit in the 47 static HTML inputs; no tool in `tools/` or `prepare.py` writes them; they arrived in commit `c4e0e48`.
`src/app.js:9` formats with `currencyDisplay:'code'`, and `locale-en.js` holds one `US$`.
A6 decision: a reviewed, idempotent codemod in `tools/` rewrites the inputs and has a `--check` mode.
A build-time transform would break the byte parity between `dist/` and the inputs.
A7 fact: parity puts `404.html` among the inputs, so it breaks the 47-page pins, the page-name set and the 1,558-path count; choose the pin update in the critic review.
A7 stops before editing the count in `tests/check.py`, unless Jason's go approved that edit.

## Track B: spec first, then Jason's approval, then build

B0 (judge, no product edits):

- Motion intake: verify the bytes, SHA256 and length of Jason's 8 picks against the table.
  Extract each motion window at full frame rate with FFmpeg into a scratch folder outside the repo, and inspect the frames directly.
  Use AGY `gemini-3.8-flash-high --effort high --sandbox --mode plan` for temporal questions.
  Report timestamps and coverage.
  Output: timestamp → effect (its `website-motion.md` catalog number, or "new") → storefront element from the frozen mapping → adaptation.
- Detail checklist: from the NET-A-PORTER research and `commerce-template.md`, for the catalog, product page, bag and checkout.
- `INSPIRATION-MAP.md`: each proposed change → source → purpose → element → acceptance check, per ui.md.
  Label hypotheses.
- Motion specs: fill the `website-motion.md` template for each pick (trigger, motion, timing, replay, mobile, reduced motion, acceptance), starting from the judge defaults in "Jason's motion picks".
- SEO/AIEO/GMB spec, generated from `catalog.js` and a `site.config.json` kept outside `build-inputs/static/` (`siteUrl`, `indexable:false`, empty NAP):
  - canonical, Open Graph and Twitter tags with real product images;
  - JSON-LD: Organization, WebSite, BreadcrumbList, ItemList on the catalog, and Product with one Offer per size and its real availability;
  - `sitemap.xml`, `robots.txt` with the sitemap line, `llms.txt`, and meaningful alt text;
  - an offline SEO linter: required tags present, JSON-LD valid, JSON-LD prices equal to catalog prices, sitemap equal to the indexable pages, no NAP while the config is empty.
  - Baseline: canonical 0/47, Open Graph 0/47, JSON-LD 0/47, meta description 47/47; no sitemap, robots, llms or 404 file.
- Performance budget: JS bytes per page below the baseline after the picks are added (`catalog.js` is 216,694 B; it and the four motion vendors load on the home page, and `src/app.js` uses neither ScrollTrigger nor Lenis); LCP image prioritized; no CLS increase; vitals within noise or better.
- Show Jason one Spanish HTML spec page (`html_preview`, then `html_render`) with the map, the specs and representative 390/1440 mockups for each visual change.
  Mockups include the mobile pill closed and open, both grid densities, loader key frames, the footer, the brand wall with the labeled fictional fixture, and the optional desktop glass header.
- Wait for his approval of the spec.
  Silence is not approval.

After approval, cut the exact slices from the approved spec: B1 SEO/AIEO build, B2 performance, B3 micro-interactions, B4 motion, B5 detail polish.
B4 runs as five packets: B4a transition (high), B4b mobile navigation with glass, B4c grid toggle, B4d loader (high), and B4e footer, brand wall and tab title as one packet with three checks.
Before each Track B packet, the judge adds that slice's checks to the scorecard, updates the manifest and saves them as a judge patch in the series; builders never change them.

## The loop (every slice)

1. Packet: write a PROTOCOL.md packet with all its fields.
   Include the task-completion contract, the KISS contract, the slice's motion specs and the list of accepted patches.
2. Critic first when the slice is high-risk; turn its failure cases into checks.
3. Builder: applies the accepted patches in order with `git apply --index`, implements the slice, and runs the slice checks and the relevant `tests/check.py` stages.
   The packet gives the absolute path of `docs/storefront-loop-20261120/patches/` in this checkout, because new worktrees lack that untracked folder.
   The builder keeps recordings and scratch files outside its worktree, because `git add -N .` would add them to the patch.
   It returns its own increment with `git add -N .` then `git diff --binary -- . ':(exclude)dist' > <path>.patch`, never a commit, plus the PROTOCOL.md worker return YAML.
4. Judge acceptance, independent of the builder's report:
   - the patch touches only owned paths; the harness manifest matches; no secrets, real data or hand-edited `dist/`;
   - read the whole diff for defects and clean code: one source of truth, small named functions, no dead code or duplication, existing patterns, progressive enhancement;
   - in a scratch worktree (`git worktree add --detach <scratch> 0147124`), apply the series plus the patch, run `python3 prepare.py` (check.py compares the JS in `src/` and `dist/`), run the scorecard and compare it with the champion;
   - every `tests/check.py` stage exits 0, except `asset-audit` and `catalog-staging`, which may fail only with WinError 1314;
   - real-click purchase at 390 ES and 1440 EN after any bag, checkout, price, navigation, menu or catalog-grid change;
   - a same-sequence "after" recording; a pixel diff on unaffected pages; your blind A/B on visual slices is advisory only.
5. Verdict:
   - ACCEPT when the slice check goes red→green, at least one metric improves and nothing regresses beyond noise.
     Apply the patch, uncommitted, to this checkout, which is the integration worktree; save it in `docs/storefront-loop-20261120/patches/` with its SHA256; update the champion and the log.
   - REJECT with findings (file:line, failing check, expected value) in a new `delegate_task` (brief, findings, objections).
   - Fix small findings yourself, as a judge patch.
   - After 2 failed attempts, change the diagnosis or split the slice.
     After 3, mark it BLOCKED and continue with independent slices.

## Stop conditions

- VERIFIED: every approved slice is accepted; the final matrix is green (purchase at 390 and 1440 in ES and EN under CSP, scorecard, each check.py stage); before/after recordings are ready.
- BLOCKED: a named external dependency remains, such as the brand data for the brand wall; continue independent work.
- LIMIT: a cap, context or billing uncertainty; save STATE.md and the next safe action first.
- STOPPED: Jason pauses or redirects.

## Final report to Jason

Write it in Spanish, KISS, result first.
Include one HTML page with the champion scorecard before vs after, and playable before/after recordings per flow.
List the slices accepted, rejected or blocked; the builder identity and usage; the Paper calls used; and what remains unverified.
Ask for: (1) visual approval of the recordings; (2) commit and sync approval; (3) re-recording `evidence/releases/20261105/responsive-runtime-sha256.json`, which CI gates on Tony; (4) deploy to `martha-silva-preview`, which stays a separate approval; (5) the brand data for the brand wall, if it is still blocked.
On commit: if (3) is approved, re-record and confirm `python tools/verify_release_snapshot.py` exits 0; without (3), CI `tony-snapshot.yml` fails after the push.
Update the area docs per AGENTS.md, keep the hooks, check `SYNCED` and the remote SHA, and add no agent or model co-author trailer.
Still out of scope: card payment, real orders, customer account, currency (USD today; an old gate draft asked for córdobas), legal pages, admin authentication, publication and indexing, Google Business Profile, EN URLs, and SAVIA's `fit-text-to-width`.

## Amendment: brand wall removed (Jason, 2026-11-20)
Jason: "Quitemos lo de las marcas que vende la tienda." The brand wall (pick 7, B4e) is out of scope: no section, no generator, no fixture, no brand names anywhere. B4e keeps the footer and the tab title only.

## Amendment: Jason's B0 decisions (2026-11-20)
- 2 Grid: yes. Animate the existing "Ver 2·3·4" / "1·2" toggle with a GSAP-core FLIP and persist it in `martha-grid-v1`; no new "Grande/Pequeña" control.
- 3 Glass: no, neither desktop header nor mobile pill ("andate con el negro clásico"). Pick 3 is discarded. The mobile pill (B4b) is solid classic black like the header, with the same morph from pick 2.
- 4 Transition: yes, only between home, catalog and product pages.
- 5 Tab title copy: approved as written.
- 6 Domain: later. B1 SEO builds everything config-driven with `siteUrl` empty and `indexable:false`: JSON-LD, meta and alt text ship; canonical, Open Graph URLs and sitemap entries need the domain and are emitted only once `siteUrl` is set.
Track B is approved. Order: P4 = B4c grid + B4e footer + tab title; P5 = B4b black pill; P6 = B4a transition (critic first); P7 = B4d loader (critic first); P8 = B1 SEO; then B3/B5 polish.

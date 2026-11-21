# Loop state

Objective: finish the storefront per `PROMPT.md` (Track A, A8, B0 spec).
Base SHA: `0147124`, branch `frontend-finish`; integration is this checkout, uncommitted.
Phase: Track A, packet P1 (A1–A5) with the builder.
Champion scorecard: `scorecards/000-baseline.json` (harness SHA256 `549ab76a…d7d1`).
Accepted patches: `000-scorecard.patch` (harness, judge).
Builder runs used: 1 of 24 (P1). Critic runs: 1 (A6/A7, Opus, read-only).
Paper calls used: 0.
Before recordings: 390 ok in `%TEMP%/sf-loop/rec/before/`; 1440 must be re-recorded (ffmpeg pipe closed, sequence lost the bag item).
Next action: judge P1 when it returns; then P2 (A6 price), then P3 (A7 404 + A8 Lenis/ScrollTrigger + pins).

## Update 2026-11-20: P1 accepted
- Judge scorecard (scratch worktree, 000+001): purchase 4/4, enSpanish 171->0, axe serious 6->0, moderate 64->8 (only server 404: region 4, landmark-one-main 4), console warnings 100->0, sizeL disabled + labelled ES/EN, small390 958->950, stages same as baseline.
- Patch `patches/001-P1-A1-A5.patch` SHA256 0bfee757dfc812ee8f19915a3a8932d869a13e7cb27a628abbae6649c03dd786; applied uncommitted to this checkout; champion `scorecards/001-P1.json`.
- Visual check: 'El edit de novias' at 1440 sits on cream, not on the photo; dark text is correct.
- Debt: `tests/responsive_images.py` reversal lines; P3 replaces them.
- Builder runs: 2 of 24 after P2 launch. Next: P2 (A6 price).

## Update 2026-11-20: P2 accepted
- Judge scorecard (000+001+002): priceBad 2946->0, staticPriceBad 3354->0, purchase 4/4, review totals $153.50 (coupon) and $165.00, everything else equal to P1.
- Patch `patches/002-P2-A6.patch` SHA256 8781bf1447cc7343f08bde9c3b2515d2da9874bfcb8a69e578d10a36547382e4; applied uncommitted; champion `scorecards/002-P2.json`.
- Gap: tests/golden-path (SAVIA/POS, other thread) keeps 3 USD display mentions.
- Builder runs: 3 of 24 after P3 launch. Next: P3 (A7 404 + A8 Lenis/ScrollTrigger + pins + page-hash pin).

## Update 2026-11-20: P3 accepted, Track A complete
- Judge scorecard (000..003): axe 0 violations, enSpanish 0, priceBad 0, console 0/0, purchase 4/4, real 404 page (status 404, h1, no axe issues), JS 557,335 B/10 files -> 495,038 B/8, CSS 3 -> 2 files, 48 pages, 1,558 public files, stages as baseline.
- Patch `patches/003-P3-A7-A8.patch` SHA256 c8d1b53ebedc9337249ac988ff64d8cc1b76dac1986cf69b53ea8d26d336013f; applied uncommitted; dist vendor files deleted; champion `scorecards/003-P3.json`.
- Page bytes now pinned by `tests/page-hashes.json` (`tools/pin_page_hashes.py --check`).
- Open for Jason: `wrangler.jsonc` not_found_handling is `none`, so Cloudflare will not serve 404.html until set to `404-page` (deploy config, not touched). `tools/verify_release_snapshot.py` compares with frozen release-20261105 bytes and fails since P1; a new release needs a new snapshot.
- Next: B0 spec page (motion intake of the 8 Osmo videos, SEO, brand list unconfirmed), then stop for Jason's approval.

## Update: B0 shown to Jason; Track B waits for his approval of B0-SPEC.html decisions.

## Update: brand wall removed by Jason. B0 decisions still open: 2 grid toggle, 3 desktop glass header, 4 transition scope, 5 tab-title copy, 6 domain.

## Update: Track B approved by Jason (decisions in PROMPT amendment). Judge writing `tests/storefront_scorecard/slices.py` for P4.

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

- 2026-11-20: judge patch 009 (transition check) saved; P6 builder running. Champion still 008.
- 2026-11-20: P6 accepted as champion 010 (page transition window). Next: P7 loader critic.
- 2026-11-20: judge patch 011 (loader check) saved; P7 builder running. Champion 010.
- 2026-11-20: P7 accepted as champion 012 (home loader). Next: P8 SEO judge patch 013, then builder.
- 2026-11-20: judge patch 013 saved; P8 SEO builder running. Champion 012.
- 2026-11-20: P8 accepted as champion 014 (SEO, config-driven, closed until domain). Next: EN meta follow-up, then B3, then B5.
- 2026-11-20: checkpoint commit of P1–P8 to Tony with snapshot re-record (Jason approved).

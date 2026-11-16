# Gallery contracts: corrected candidate (2026-11-07)

Task `savia-gallery-outcomes-c5ee743-20261107-01`. Test-only candidate over base
`c5ee743242cb2d360ef4c4e94a61548e1180748b`. Product bytes are unchanged.

## What changed

- `tests/desktop-gallery.cjs`: replaced mandatory absent-attribute and
  unhandled-key assertions with user outcomes (reachability, activation,
  selected-slide usability, preserved modified/media keys). The four-slide
  fixture is asserted at boot (`4 slides = 3 photo + 1 video`); last/previous
  derive from `slides.length`, and the remaining literal `2`/`3` are explicit
  scenario positions under that binding.
- `tests/gallery-browser-contracts.cjs`: real installed Chrome, real
  Tab/Shift+Tab/Enter/Space/Home/End, bounded loops, local immutable `dist/`,
  and a responsive-resource contract (rendered width, DPR, `sizes`, `currentSrc`,
  chosen candidate, next smaller candidate, response status/bytes).
- `controls/check-variant.cjs`: inspectable in-memory controls.

## Evidence

| Check | Result |
|---|---|
| jsdom baseline | 14/14, exit 0 (`controls/logs/baseline.log`) |
| `tabindex-zero` | 14/14, exit 0 (harmless equivalence) |
| `valid-measured-sizes` | 14/14, exit 0 (equivalent hint) |
| `bad-sizes` (`sizes=1px`) | 11/14, exit 1; DG04/DG05/DG09 fail |
| `no-activation` | 4/14, exit 1; 10 cases fail |
| Chrome 1280x900 DPR1 | 720w chosen, hint 426.66px, 200 webp 86518 B; resize 1440 keeps 720w, index 0 |
| Chrome 390x844 DPR2 | 1024w chosen, hint 390px / needed 780px, 200 webp 140962 B |
| Real keyboard | photo reachable (33/9 Tab); nav Enter/Space select; Shift+Tab moves back; arrow Enter/Space move; Alt and media ArrowRight unchanged; End/Home native |

Raw browser data: [`browser-contracts.json`](browser-contracts.json).
Screenshots: [`desktop`](browser-contracts-desktop-1280x900.png),
[`mobile`](browser-contracts-mobile-390x844.png). Both were read back and show
the gallery, not the footer.

## Reproduce

```powershell
$env:MARTHA_JSDOM_PATH='C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules/jsdom'
node tests/desktop-gallery.cjs
node docs/gallery-contracts-20261107/controls/check-variant.cjs bad-sizes
node tests/gallery-browser-contracts.cjs
```

The browser script serves `dist/` on `127.0.0.1:18433` and writes
`browser-contracts.json` plus both screenshots here.

## Dispositions

Per-ID reasoning is in [`historical-expectations.json`](historical-expectations.json).
Summary: DG01 covered (selection/focus/scroll/usability), DG03 covered
(focused-photo scroll, focus not stolen, next Tab visible), DG04 covered
(independent hint contract plus resource bounds; `1px` fails), DG06 covered
(real keys, modified/media keys preserved), DG10 covered (arrow outcomes;
native Home/End accepted, no custom handler claimed).

The historical quote in `docs/release-20261106/process-judge.md:19` concerns an
earlier plan and asks for missing observations. It is not approval of this
candidate. Versioning alone is not acceptance.

## Limits

- The zoom result passed in the Chrome run (exit 0) but was not serialized
  because `openAndCloseZoom` returned nothing during that run; the corrected
  script returns it next run.
- `tabindex-zero` and `valid-measured-sizes` were observed 14/14 exit 0 earlier
  without a persisted log; re-run with the command above.
- `naturalWidth`/`naturalHeight` are density-corrected per the `srcset`
  `w`-descriptor spec; raw webp sizes were verified with Pillow
  (360x540, 720x1080, 1024x1536).
- Headless Chrome only; no headed device, mobile hardware, full visual
  regression, accessibility audit, or performance claim.
- NOT RUN: full suite/631 aggregate, backend/.NET, staff UI, SQL, Docker,
  services, CI, issue writes, publication, merge or deployment.
- No product defect is asserted. S-LEGACY closure remains the primary's
  decision; issue #4 disposition evidence remains a primary responsibility.


## Primary proof correction, 2026-11-07

The latest Astra review found two verification gaps. Both are now corrected in tests only.
[Fresh results and remaining acceptance](primary/proof-corrections/README.md): real keyboard at the stated viewport, observed browser image responses, four origin controls and two Chrome journeys. Independent acceptance remains pending.

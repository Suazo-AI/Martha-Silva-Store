# Desktop product carousel candidate

**Source candidate only. The new tests are WRITTEN, NOT RUN on Tony.** No build,
dependency installation, image processing or browser was launched for this task.
The existing `dist/` remains the baseline, not a claimed build of this candidate.

After measuring resources on the authorized cloud host, use its existing
locked jsdom install or install the repository lock there. Run serially:

```
npm ci --prefix tests/frontend-deps --ignore-scripts --no-audit --no-fund
node tests/desktop-gallery.cjs
python prepare.py
python tests/check.py
```

`MARTHA_JSDOM_PATH` can point to an already-installed package. The focused script
loads source app/static HTML directly; the full regression suite uses generated
outputs. Restore authorized baseline media by exact manifest before a full asset
audit; a text-only handoff does not establish media completeness.

Fourteen proposed DOM cases cover desktop control navigation, video wrap, irregular
slide offsets/manual scrolling, resize and resource hints, mobile restoration,
keyboard/focus, zoom, BFCache-style remount/handler cleanup, preserved product
identity/commerce/Share/footer, zero-width recovery, rapid smooth-scroll commands,
user interruption, semantic photo restoration after Back at another width, and
native Back/Forward events without pagehide or an outgoing anchor click.
Geometry, matchMedia,
media playback and dialogs are fixtures. These cases do not prove CSS layout,
native `inert`, network lifecycle, Safari BFCache, or physical-device behavior.
The resized Back case calls the real app's captured transition hooks using a
no-network router fixture; it is not a claim of real Barba network navigation.

The inherited Green static test already has a documented EOF-boundary adaptation
in the combined release evidence. Its whole-tail assumptions must not be silently
called a runtime regression or relaxed to manufacture a pass. Review the actual
header-clearance behavior of this new carousel as well as the preserved baseline.

Required independent browser review of the exact built candidate:

- At genuinely available desktop and short-height viewports, one complete photo
  is visible below the sticky header; thumbnails are complete in the left gutter;
  arrow icons sit below the photo with 44px targets. No stretching, source crop,
  overlay on the garment or unexplained empty stage. Capture real measurements.
- Scroll/thumbnail/arrow/keyboard selection agrees, focus never remains in an
  inactive slide, a playing video stops when left, and its native controls work.
- Image `currentSrc` and actual binary dimensions suit the new stage. Browser
  `naturalWidth` can be density corrected; do not treat it as encoded resolution.
- Mobile/tablet keep their existing layout and behavior, including crossing the
  desktop breakpoint. No new image bytes or catalog entries are introduced.
- Catalog search/filter -> PDP -> Back/Forward preserves context, page scroll and
  gallery position; zoom returns focus; ES/EN, Share, supporting illustrations and
  removed admin footer link remain intact. Report unavailable Safari/iPhone and
  VoiceOver coverage instead of inferring it from jsdom.

Denis authorized publication to the existing preview Worker after tests and an
independent judge accept this exact candidate. Do not publish before that gate.

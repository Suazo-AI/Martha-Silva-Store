# Browser Back restoration — independent acceptance matrix

**Target:** Safari on iPhone. This is separate from the additive AI-illustration candidate. Node/DOM fixtures are not Safari, browser BFCache or physical-device evidence. All real-device results below are **PENDING** until the browser owner supplies observations; no duplicate browser run is authorized here.

Record for each run: source/asset hashes; iPhone model, iOS/Safari version, viewport/orientation; URL including query/hash; history entry identity; selected filters/search/sort/language; top visible card or section and its viewport offset; scroll position before leaving and after settled return; pageshow.persisted and popstate/navigation sequence; load/layout timing; screenshots/event trace. Tolerance should reflect rounding only when layout is unchanged; when images/header geometry settle, the same semantic card/section must remain at its recorded viewport offset without a late jump to top.

| ID | Flow / setup | Required result |
|---|---|---|
| B01 | Catalogue, scroll several rows, open card → native Back button and iPhone edge-swipe separately | Same catalogue URL, same card and approximate viewport offset, not top; no wrong-card focus scroll. |
| B02 | Catalogue filter + search + sort + language → scroll → PDP → Back | Exact query semantics, controls, rendered ordering and selected filters restored before final scroll; no debounce creates a new history entry after Back. |
| B03 | Home editorial section → PDP → Back | Same home section/offset; restoration is not restricted to catalogue URLs. |
| B04 | Entry A and entry B have the **same URL/query**, but different scroll positions; traverse Back/Forward repeatedly | Each history entry has its own position; URL-keyed cache must not conflate them. |
| B05 | Filter/search/sort creates multiple same-document history entries; Back/Forward between them | Correct state and card list for every entry; no extra history pushes during restoration. Preserve existing history.state keys used by Barba/other code. |
| B06 | Repeated catalogue↔PDP and home↔PDP traversal | No accumulated handlers, duplicate restore, stale offset or oscillation; Forward restores its own entry. |
| B07 | Fresh ordinary click/new history navigation to a PDP, catalogue or home | Normal new-navigation-to-top policy retained; do not reuse an unrelated history offset. Intentional hash-anchor navigation remains anchor navigation. |
| B08 | Change ES/EN, traverse Back/Forward with differing language query/state | Language, filters and URL agree; translated layout settles before final position; no stale language callback moves the page. |
| B09 | `pageshow.persisted=true` (BFCache restoration) with remount changing DOM/layout | Capture/restored browser position before remount; preserve/reconcile that entry's position after remount rather than forcing top. No needless jump if native BFCache position is already correct. |
| B10 | `pageshow.persisted=false` + popstate/reload-style traversal, delayed data rendering | Desired history position restored when applicable; fresh load still follows normal top/anchor behavior. Do not treat every pageshow as Back. |
| B11 | Slow images/fonts/header layout and initially short document; target position initially unreachable | Reconcile when content height becomes sufficient; final same card/section offset. Bound reconciliation by outcome (reachable target and settled relevant layout) or user/new-navigation cancellation, not a fixed short timeout; do not clamp once and permanently lose target. |
| B12 | Popstate arrives before/after render completion; rapidly Back then Forward while earlier restore awaits | Latest entry/navigation wins; earlier queued callbacks cannot overwrite the current entry or scroll it. |
| B13 | User touches/wheels/presses a key/pointer-drags or activates a button or hash anchor via VoiceOver without pointer events during pending or delayed-initial restoration | Cancel pending programmatic restoration promptly; no later image/layout callback overwrites the user's scroll or gallery choice. Include detail=0 click activation. |
| B14 | sessionStorage/localStorage denied, unavailable, full or throwing; history.state includes unrelated keys | Navigation and rendering do not throw; preserve entry state and existing keys, use safe in-memory/native fallback as designed. No credential/storage policy changes. |
| B15 | Orientation/address-bar/visual viewport height changes between leave and return | Restore meaningful content position without overflow, huge jump or stuck compensation loop. |
| B16 | Anchor links, Share, gallery navigation and purchase controls after traversal | Existing behavior unaffected; product gallery counts, commercial metadata and authentic images unchanged. |
| B17 | History return or fresh navigation with slow API mount; focus a control/activate with VoiceOver during the await | History must not force focus to main. Fresh untouched navigation may focus main; an intervening interaction/newer navigation must prevent late focus stealing. Real VoiceOver focus identity is not established by a DOM activeElement test. |
| B18 | Repeat Back/Forward under iOS Reduce Motion enabled and disabled | Restoration remains immediate and independent of animation preference; no animated jump or preference-specific lost position. |

## Source/fixture gates

- Baseline exact A704b app SHA `8ee8deb77dd6608023f0d315c2451aafa248f58e77658b881717e9de09470ba8`.
- Test desired failures on exact baseline snippets first; label these source-level observations, not a reproduction on Safari.
- New fix gets separate source hashes and patch scope. Do not merge AI-support or GreenB changes.
- Assert unique per-entry IDs, immutable/copy-safe snapshots, unrelated history.state keys preserved, explicit traversal vs new navigation, persisted resume, delayed geometry reconciliation, latest-navigation/token guard and user-input cancellation.
- Record exactly which lifecycle paths are mocked. Real Back/Forward, BFCache eligibility, scrolling/layout and Safari event order remain pending until device evidence.

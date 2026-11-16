# Navigation worker return

Task `savia-ux-navigation-20261116`. Status: **PARTIAL / primary acceptance pending**.
Host SUAZO-PC, T3 Codex, `gpt-6.1-sol`, high reasoning. Token/cost usage unknown.
Frozen HEAD: `2c96904f49d2df913850bc13cf53b3b03ceebacf`.
Assigned managed worktree: `C:/Users/Jason/.t3/worktrees/github/t3-c34f8833-9c5b016af2421802`.
No stage, commit, push, SQL, Docker, deployment, credentials, dependencies or external services.

## Implemented

Owner navigation: 14 routes remain reachable once, with seven top-level decisions.
Venta, Caja, Inventario and Historial remain direct, subject to existing access.
Native details/summary groups: Mercadería, Consultas and Administración.
Groups contain only permitted links and disappear when empty.
Routing opens the current group and marks its link with aria-current.
All links retain `#nav a[data-route]`.
SCREENS, canAccess, landing and role permissions remain unchanged.
Existing SAVIA theme tokens and 48px navigation targets remain.
History uses the existing SaleDetailResponse.ReceiptNumber (`savia/src/Savia.Contracts/Sales.cs:17`).
Missing/null/blank numbers display “Venta sin número de recibo”.
Date, amount, search, return and receipt actions remain.
UUID appears in collapsed support details.

## Verification

- Focused invocation 1: `node --test savia/web/tests/roles.test.mjs savia/web/tests/navigation-ux.test.mjs`, exit 1, 5/6. Test DOM lacked document event methods.
- Focused invocation 2: same command, exit 1, 5/6. Test DOM lacked input.focus.
- Changed diagnosis to incomplete scanner host fixture; inspected scan.mjs attachment contract and completed the test DOM.
- Focused invocation 3: same command, exit 0, 6/6. See `focused-final.log`.
- Relevant suite: `node --test savia/web/tests/*.test.mjs`, exit 0, 66/66, zero skipped. See `web-suite.log`.
- `git diff --check`, exit 0.
- Tests cover 64 role combinations, exact existing access table, duplicates/empty groups, receipt fallback and original history actions/search.
- T3 preview matrix: four roles at CSS widths 390/1440, 64 route visits. Seven matrix rows passed initially. Manager desktop had eight active-link failures with a fixed 70ms wait.
- Failed-path recheck waited for actual active route, bounded at 3000ms: Manager 11/11, zero overflow, active links visible. Observed waits 34–232ms explain the fixed-delay failure. See `manager-recheck.json`; retain the original failures in `browser-checks.json`.
- Separate mobile nested check: `#/recepcion/revisar` marks Recepción and opens Mercadería.
- Final browser snapshot: console entries empty, no failed network entries in its bounded diagnostics. No full accessibility or performance audit.

## Before/after evidence

Original BEFORE was recorded before product edits. `source-manifest.json` confirms four captured source files match frozen Git bytes after CRLF normalization.
Recordings: `before-1440.mp4`, `after-1440.mp4`, `before-390.mp4`, `after-390.mp4`.
Sequence: Venta → Historial → scroll down/up → Precios → Historial. AFTER additionally opens Mercadería to reach Precios.
T3 preview was used because session instructions prioritize it over the requested agent-browser route.
One invalid about:blank request was corrected by omitting the URL.
One temporary server rooted above the built site caused boot asset 404s; serving the build root corrected it.
Only fictional local demo data was used.
Four ffprobe runs exited 0; four ffmpeg decodes exited 0. Source MP4s contain non-monotonic DTS warnings; see `recordings.json`.
CSS viewport sizes were verified with innerWidth. Capture sizes differ: desktop 1246×1124, mobile 488×1054. Desktop captures do not prove full-width pixel coverage.

## Open blocker and exact next action

Keyboard test FAILED on Historial: focus Consultas summary, press Enter; focus was INPUT and the group remained closed (`keyboard.json`).
Direct cause: scan.mjs shouldReclaimFocus returns true for SUMMARY, and attachScanField reclaims focus after input blur.
The source is unchanged, so a pre-existing scanner interaction is inferred; no BEFORE keyboard test was recorded.
No correction attempted because `savia/web/scan.mjs` and its focus tests are outside this worker's owned paths.
Primary must authorize/own that correction: retain focus on native navigation controls, preserve scanner behavior, then rerun keyboard navigation and scanner regressions.
Completion check: Tab can reach summary; Enter/Space expands it; Tab reaches its links; scanner input and scanner-wedge operation still work.
This candidate is not accepted while that check remains open.

Both own servers were stopped; the own preview tab was closed. Three disposable build directories were removed after containment checks.
Five changed product/test paths and hashes are frozen in `source-manifest.json`; all other writes are under this assigned evidence directory.
Primary owns serial integration, independent acceptance and visual judgment.

# CF2-R1: cleanup warning survives logout and navigation

Status: corrected locally; independent Astra/xhigh acceptance pending.
Base: `ba8ff2ba10935e99fc268ebbe5eae130f72c1cca`, branch `Tony`.
Host: `SUAZO-PC`. Primary: T3 Code/Codex `gpt-6.1-sol/xhigh`.

The previous warning used the private route notice inside `#shell`. Logout hid that shell. The next route cleared the notice.

The correction adds `#approval-cleanup-notice` directly under `body`, outside both authentication screens. Its reporter writes only fixed, non-private text. Ordinary route notices still clear normally. No permission, payment, storage or SQL behavior changed.

## Fresh evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Before correction, actual app login/logout/router | 11 PASS / 4 FAIL | `before.json`, frozen `before-app.mjs`, `before-index.html`, `before-desktop.mp4` |
| Web suite, final source | 118 PASS / 0 FAIL / 0 skipped, exit 0 | `web-tests.txt`; `node --test savia/web/tests/*.test.mjs` |
| Desktop CSS viewport 1280x800, DPR 1.25 | 15 PASS / 0 FAIL | `after-desktop.json`, PNG and MP4 |
| Mobile CSS viewport 390x844, DPR 1.25 | 15 PASS / 0 FAIL | `after-mobile.json`, PNG and MP4 |
| Syntax and whitespace | exit 0 | `node --check` on app and lifecycle test; `git diff --check` |
| Owned resource cleanup | tab closed; owned listener absent | Primary closed its T3 tab and stopped only the verified `node.exe` PID serving port 50532. Listener readback found no listener. |

The first after-correction navigation changed only the hash. It retained the old document and old reporter. `same-document-attempt.json` preserves that 11/4 result. A new query URL forced a full load; both subsequent runs passed. This was an observation of stale loaded code, not another product change.

`server.mjs` serves actual app files and fictional HTTP responses on loopback. For instrumentation only, it appends `export {ctx as __probeCtx};` to `app.mjs`. `probe.mjs` uses the real login form, logout action and router. It invokes the actual approval-cleanup API with a fictional token, holds its HTTP 500 until after logout, then calls the actual reporter. It does not claim to reach that cleanup through a complete return screen. The return lifecycle tests separately exercise the callback and retirement wiring.

The 15 checks cover warning visibility after logout; fixed non-private content and live status; hidden private shell; old actor/notice isolation; logged-out navigation; different-account login; another route; unchanged pending-reference bytes; exact cleanup/logout call counts; no financial POST; and no horizontal overflow.

The pending reference is an intentionally invalid fixture sentinel. Its unchanged bytes prove preservation only. They do not prove financial recovery. The final Seller route is Inventory with its expected permission denial. The warning remains visible above it.

Primary inspected both final screenshots. They show the warning and the new account without the previous private actor or notice. Recordings are retained; no full video timeline analysis is claimed. Actual browser: T3CodeBeta 0.1.9 / Electron 44.10.1 / Chrome 152.0.7977.169 on Windows. The narrow viewport is not touch emulation or a physical device. `browser-environment.json` records the actual values. No console-error instrumentation was installed. Its empty external-resource list applies to the final document.

`served-final.json` records original source RAW hashes before instrumentation. The receipt verifies those files against the final checkout. Text bindings record RAW and CRLF-to-LF hashes separately. PNG and MP4 hashes use RAW bytes.

## Remaining gates

Primary must receive an independent Astra/xhigh verdict on this frozen correction. V029 SQL replay, authorization, concurrency and rollback remain NOT RUN. Real browser-to-API-to-SQL and exact-candidate Linux aggregate/CI remain pending. Previous Windows aggregate failures were symlink fixtures with `WinError 1314`; unchanged failures are not repeated here.

The previous one-shot publication/runtime authority is consumed. No new commit, push, workflow, SQL, merge or deploy occurred. Next: primary freezes the packet, obtains the independent review, and prepares the concrete publication/runtime scope. Production remains NO-GO.

Lesson: a callback test can verify delivery to a notice while missing that logout hides its container. Verify the actual document and route transitions before closing visibility findings.

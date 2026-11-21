# Receipt of goods: worker return

RETURNED WITH LIMITS. Primary acceptance is pending.
Base: `a4bdac69581ac0423a964dea6bc5c74d4e2bad28`.
Host: SUAZO-PC. T3 Code / Codex / gpt-6.1-sol / high, exposed by runtime and agent-awareness.
Provider-level reasoning telemetry, usage and cost are unreported.
No nested agents, commits, pushes, deployments, SQL connections or paid services.
All writes stayed in this T3-managed worktree.

Existing purchase orders now have list/detail, recorded-delivery pagination, receipt quantities and recovery.
Owner, Manager and Inventory may operate the client; backend authorization remains unchanged.
Cashier navigation and supply requests are blocked.
No new-purchase button, supplier editing, guessed costs or calculated stock are added.

The qualified staff action is **Confirmar recepción** for quantities physically received against an existing order.
The existing SAVIA design is retained: `styles.css` canvas `#f5f4ed`, surface `#fffefa`, ink `#192d25`, primary `#31584a`.
No new palette, imagery, animation or external design reference was introduced.
Mobile and desktop use the same receipt form with existing buttons, panels and field styles.
I inspected the mobile screenshot; [layout measurements](layout.json) show no document overflow at 1440x1000 or 390x844.
Human visual acceptance remains pending.

Verification:

| Layer | Result | Evidence |
| --- | --- | --- |
| Focused supply | 21/21, exit 0 | [log](focused-final.log) |
| Full staff, including pagination | 124/124, exit 0 | [log](staff-final.log) |
| Portable runner regression | 7/7, exit 0 | [log](runner-final.log) |
| Actual Chrome, mocked HTTP supply | 8/8, exit 0 | [results](browser-bound/results.json) |
| Existing full Chrome suite, N5 and sales retained | 50/50, exit 0 | [results](existing-final/browser-results.json) |
| Negative controls, disposable local copies | exits `[0,1,0,1,0]`, byte-exact restore | [proof](negative-controls.json) |
| Diff whitespace | exit 0 | `git diff --check` |
| .NET build | blocked before compilation | [failure](dotnet-build.log) |

Supply Chrome cases cover partial/full receipt at both viewports, lost POST response with reload/recovery at both viewports, synchronous double submission, malformed contract, 401 private-data clearing and logout with a late POST response.
The requests retain receipt ID, command key and exact JSON body across transport retries/recovery.
Durable-delivery counts here belong to the in-memory HTTP fixture, not a persisted database.
[Negative-control script](negative-controls.py) breaks duplicate protection and outgoing physical identity in disposable copies.
Each mutation fails its assertion; restoring the exact source bytes returns green.
The actual product source remains unchanged during these controls.

Recordings, same `/internal/` → Abastecimiento path:

| Viewport | Actual before | Actual after |
| --- | --- | --- |
| 1440x1000 | [unavailable screen](before/1440.webm) | [partial/full receipt](browser-bound/videos/partial-full-1440.webm), [lost response/reload](browser-bound/videos/lost-reload-1440.webm) |
| 390x844 | [unavailable screen](before/390.webm) | [partial/full receipt](browser-bound/videos/partial-full-390.webm), [lost response/reload](browser-bound/videos/lost-reload-390.webm) |

[FFprobe metadata](recordings.json) confirms local WebM files, dimensions and durations, approximately 1.1–2.3 seconds.
The recordings were captured locally with Playwright's installed Chrome channel after T3 recording failed.
T3 returned `Preview automation recordingStart timed out after 15000ms.`
Subsequent calls returned `No preview automation host is available` for this environment.
The T3 tab was closed; the owned loopback fixture on port18764 was stopped.
Every acceptance-driver fixture uses its own assigned loopback port and closes its own browser/server.
No full temporal or audio review is claimed.

[Source manifest](source-manifest.json) binds every changed non-evidence path to Git base blobs and final worktree bytes.
RAW means exact bytes; LF converts CRLF to LF and retains BOM.
The historical `base-hashes.json` helper is supplementary; the Git-blob manifest is authoritative for base/source comparison.
Chrome's response-body API strips a UTF-8 BOM.
The final supply driver therefore verifies exact RAW HTTP bytes using Node arrayBuffer and compares ChromeDecoded hashes separately.
Its console errors, safe network call metadata, source hashes and served hashes are retained per scenario.
PowerShell `*>` logs can contain UTF-16 and stderr wrappers; process exits and assertion results are reported separately in RESULT.json.

Corrections and limits:

- The initial existing suite returned49/50 because it explicitly required purchasing to remain unavailable. Its obsolete expectation was replaced with a usable receipt entry check; final50/50.
- Initial supply-browser fixture failures came from automatic HTTP retries, a late fixture fault change and a route glob that did not cover nested receipts. The corrected fixture preserves loss until explicit recovery, waits for initial receipt reads and intercepts the full receipt route.
- An initial source-byte check compared Chrome-decoded bytes to BOM-preserving RAW bytes and failed. The final check separates these representations.
- Initial authoring had a Python Windows decoding error and a JS test arrow-parenthesis error. Base source was restored from Git before reapplying UTF-8 edits; corrected tests parse and pass.
- No existing product security defect is alleged by those harness failures. The original direct-source/browser reproducer was the unavailable supply feature.

The compiled resource/route check is blocked: `global.json` requires .NET SDK10.0.402; the installed SDK is8.0.422.
`dotnet build backend/src/Martha.Store.Api/Martha.Store.Api.csproj --no-restore` returned `-2147450735` before compilation.
The resource and protected route are explicit in source and covered by a static regression.
No SDK installation, global.json change, SQL connection or restore was attempted.
Primary should run the pinned-SDK build and compiled resource/authorization checks on an authorized runner.
Closure requires build exit0, resource presence and authenticated/anonymous route readback.

Full Windows `tests/check.py` was NOT RUN because its known symlink fixture returns WinError1314.
The locked jsdom installation already present in the canonical project was read through process-local NODE_PATH; no dependency installation was needed.
The portable runner now runs staff tests from its locked dependency path before the snapshot-build stage.
The existing SAVIA CI also already consumes `dev/savia-staff-ui/*.test.mjs`.
Integrated Linux CI, real API/SQL persistence, rollback/concurrency, devices, operational acceptance and production remain NOT RUN.

Next owner: primary orchestrator.
Review this worktree independently, integrate serially, run exact-candidate CI and the pinned-SDK resource checks.
A separately authorized API/SQL exercise must verify persisted receipts and stock movements.
No production readiness or SISFAIN feature parity is claimed.
Exact paths, acceptance mapping, commands/exits, blockers and owners: [RESULT.json](RESULT.json).

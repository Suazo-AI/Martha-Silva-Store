# Current correction status after ac0bb9f CI

CI on `9879d5c` (2026-11-17): 15 pass, 3 fail, 6 skipped. Two failures were test defects (T-SQL 172 expectation, .NET snapshot NULL), corrected and passing on local SQL: T-SQL 135/135, .NET 181/181, C# format pass. The golden path failed twice at the same cash close step; cause unknown. This publication adds a harness diagnostic that names the failing wait. [CI on 9879d5c](ci-followup/ci-9879d5c/README.md).

Published Tony SHA: `ac0bb9f47f5a12ffc0626f7737a347dea9b37900`. All seven required checks passed. All 25 check-runs completed; Azure migration and v2 validation still failed.

[Current follow-up](ci-followup/README.md) supersedes the pre-publication snapshot below. Local Biome passes on 68 files; web/scanner passes 134/134. V029 batch-source checks pass 11/11 after a one-GO correction. Real SQL remains pending. The .NET transaction correction is integrated locally. Production build passes with zero warnings/errors; primary focused tests pass 24/24 using a fake connection. Independent Astra review and actual SQL remain pending.

No new publication, SQL runtime, merge or deployment is authorized by these results. Previous one-shot authority is consumed. The integrated repository check stopped at three unchanged symlink fixtures with WinError 1314; preceding groups passed. Primary sends the frozen 12-source candidate to Astra/xhigh. Linux aggregate, SQL runtime and exact-candidate CI remain pending. No push or SQL attempt has occurred.

Update 2026-11-17: Astra/xhigh returned REVISE with one P2 finding, F1: command disposal could replace the original migration error. Primary changed to Claude Code `claude-fable-5-2` after Codex hit its usage limit (back 2026-11-20 14:03). F1 is corrected in `MigrationExecution.cs`: focused tests red 27/3, green 30/30; migrator build 0 warnings/errors; Astra's own adversarial probe 20/20 (was 17/3). [F1 record](ci-followup/command-disposal/README.md). A second gap was found and corrected: the CI C# format gate failed on one line of `ReturnRetrySafetyTests.cs`, already in `ac0bb9f`; `dotnet format --verify-no-changes` now exits 0. The candidate is 13 sources. A fresh independent recheck of F1, real SQL, the Linux aggregate and exact-candidate CI are still NOT RUN. Nothing is published; the Git index is empty. Jason answered at 2026-11-17T03:28:36.880181+00:00: Astra has usage again, so Astra/xhigh rechecks F1; and "Publicar una vez (Recommended)" for one Tony publication of the 13-source candidate with its automatic CI, bounds as in [PUBLICATION-RUNTIME.md](PUBLICATION-RUNTIME.md): maximum 330 cumulative job minutes, no retry, no paid AI, no merge, no deployment. Astra recheck task `savia-pr7-f1-recheck-ac0bb9f-20261117` is running on [the frozen F1 packet](ci-followup/command-disposal/PACKET.json). Astra/xhigh returned **ACCEPT WITH LIMITS**: F1 closed, no new findings, fresh 30/30 tests and 37/37 probe ([recheck](ci-followup/command-disposal/astra-f1-recheck.md)). Primary accepts the local 13-source candidate with limits. Next: one publication from [the allowlist](ci-followup/PUBLICATION.json), then every CI result is read. Real SQL and exact-candidate CI are NOT RUN until that publication.

---

## Historical pre-publication snapshot

# PR7 correction status

Base: `ba8ff2ba10935e99fc268ebbe5eae130f72c1cca`. Branch: `Tony`.
Host: `SUAZO-PC`; primary T3 Code/Codex `gpt-6.1-sol/xhigh`.
Status: **PRIMARY ACCEPTED WITH LIMITS for the local correction source.** Publication, exact-candidate CI and SQL remain pending.

[Primary acceptance](final-combined/PRIMARY-ACCEPTANCE.json) records the final Astra/xhigh report and the verified frozen 18-source overlay. [Final review](final-combined/lifecycle-correction/notice-visibility/review/astra-recheck.md) closes CF2-R1; CF1 and PRIMARY-BROWSER-01 remain closed. A returned review alone does not authorize runtime or merge.

| Item | Verified result | Remaining closure |
| --- | --- | --- |
| Staff CI scheduling race | Actual digest seam reproduced and controlled. Worker cash 58/58, staff 223/223; negative control detected. Cash product unchanged. [Evidence](staff/README.md). | Exact-candidate automatic CI. |
| Golden workflow flags | Automatic PR/main push selects cash, supply and stock-exception scope. Partial manual selection rejects before runtime. Worker 108 offline checks. [Evidence](golden/README.md). | Real browser/API/SQL run with those flags. |
| Seller UUID fallback | API-absence failure reproduced; generator isolated and API export preserved. Architecture rule passed. [Evidence](uuid/README.md). | Included in exact-candidate CI. |
| Return recovery and exchange completion | Durable immutable intent, explicit replay, receipt validation, cancellation recovery and lifecycle fences reviewed. Historical module Chrome 22/22 uses mocked HTTP. [Import](final-combined/browser-IMPORT.json). | SQL authorization, replay, contention and financial conservation. |
| SQL replay safety | V029 registered. Cached restore/build passed with SDK 10.0.402 and zero warnings/errors. Fixtures require observed lock waits, current authorization and line-order equivalence. [Preparation](returns/sql/PRIMARY.json). | Installed V029 and real SQL fixture execution. |
| SQL approver guard | Bracketed-header bypass reproduced and corrected. Primary red exit 1; corrected guards 9/9 and rules 10/10. Astra independently checked the required predicate mutation. [Combined result](final-combined/RESULT.json). | Runtime authorization controls remain separate. |
| CF1 context and PRIMARY-BROWSER-01 stale alert | Closed by independent lifecycle review. Historical source: web 117/117 and module Chrome 22/22. [Evidence](final-combined/lifecycle-correction/README.md). | Preserve those assertions in CI. |
| CF2-R1 logout/navigation notice | Fixed nonprivate notice lives outside hidden login/app shells. Primary fresh web 118/118 and actual-router fictional-HTTP checks 15/15 desktop + 15/15 narrow viewport. Astra fresh web 118/118 and 33 assertions; both regressions detected. [Evidence](final-combined/lifecycle-correction/notice-visibility/README.md). | Same-document scope accepted. Reload persistence and physical devices are not claimed. |

## Blockers and next actions

| Blocker | Evidence, cause and attempted correction | Owner and completion check |
| --- | --- | --- |
| Linux aggregate | Earlier local aggregate hit three symlink fixtures with `WinError 1314`; catalog fixtures have the same Windows permission failure. Eight other groups passed separately. No assertions or security settings weakened. [Receipt](integrated/RESULT.json). | Primary: use the scheduled clean Linux job after authorization; inspect exact-candidate exit and results. Do not repeat unchanged Windows failure. |
| SQL / real combined journey | Previous one-shot automatic PR attempt consumed. V029 and current return fixtures have not run against SQL. No retry attempted. Mocked HTTP cannot prove persisted money or inventory. | Jason authorized option A for the concrete publication/runtime scope; primary inspects actual SQL counts, financial invariants, concurrency and cleanup. |
| Publication | [Publication/runtime scope](PUBLICATION-RUNTIME.md) is prepared: one Tony push, automatic push/PR jobs, maximum 330 cumulative job minutes. [Allowlist](PUBLICATION-FILES.json): 226 owned paths; six ZIPs excluded by the existing hook. Exact allowlist staged; publication pending. | Jason authorized option A: one publication and automatic CI under this packet. Primary uses normal hooks and verifies `SYNCED`, exact remote SHA and applicable CI. No automatic retry, merge or deployment. |
| Merge / production | No merge or deployment authorization. PR #5 seasonal offers remain deferred; PR #6 optional policy remains separate. | Primary reports exact-SHA checks and unresolved review state before any merge decision. Production remains NO-GO. |

## Evidence custody and limits

Primary verified 18 current RAW/LF source bindings, all 58 frozen archive entries, 17 latest browser artifact RAW hashes, and the byte-exact final review import. Frozen historical review packets remain unchanged. Historical counts are not relabeled as current runs.

The six frozen review ZIPs remain local and are excluded from publication by the existing hook. Their hashes are recorded in the allowlist exclusions. Historical archive references retain their local-review meaning; they are not promises of downloadable GitHub ZIPs.

Historical browser failures and corrections are preserved. The notice's first after attempt retained an old document; a full navigation loaded the corrected bytes. Narrow viewport is not touch emulation. The pending-storage sentinel proves byte preservation only. The notice probe invokes the actual approval API/reporter with actual login/logout/router and fictional HTTP; full return-screen wiring is separate offline proof. No full video timeline or console-error audit is claimed.

Browser/server resources are closed. At this pre-publication snapshot, no new SQL, Docker, workflow, commit, push, merge or deployment has occurred. Jason authorized one publication and its automatic CI; execution results remain pending.

Lessons applied: identify the actual bracketed SQL procedure before selecting authorization predicates; use RAW hashes for binary media; verify input encoding and a fresh browser document before attributing a failure to product code.

Publication preparation: removed one trailing ASCII space from `savia/web/tests/return-lifecycle.test.mjs`; all other test bytes are identical. `node --check` passed. Frozen text logs, review Markdown and patch context retain their original whitespace; the full staged whitespace report is kept privately. Current reviewed sources are checked separately.

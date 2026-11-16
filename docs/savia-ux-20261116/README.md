# SAVIA: simpler staff workflows

Status: primary ACCEPT WITH LIMITS for the UX increment. Published on Tony at `63a8b1e9bfe50e9426295cb22097514fc15155e7`. Its SQL CI failed in Spec17. The verification-tool correction is published at `2587712b`: all four workflows passed, including web 98/98 and .NET 145/145 with zero failures or skips. See [current continuation](../savia-completion-20261116/README.md) and [historical local acceptance](ACCEPTANCE.md).
Base: `Tony@2c96904f49d2df913850bc13cf53b3b03ceebacf`.
Primary: SUAZO-PC / T3 Code / Codex / `gpt-6.1-sol/max`.
Executors: three separate tool-managed worktrees, `gpt-6.1-sol/high`.
Jason authorized these UX improvements and parallel execution on 2026-11-16.

## Result

- Owner has seven main navigation choices. All 14 authorized routes remain reachable.
- History uses existing receipt numbers. UUIDs remain available for support; missing numbers are never invented.
- Fictional demo entry offers four roles. Reset requires confirmation; Cancel preserves data and session.
- The primary seller stays visible. Advanced sale options use a native disclosure.
- Seller attribution requires an active, exact GUID match or deliberate selection. No arbitrary first-seller default.
- Before POST, the final sale attempt is durably saved and read back. An uncertain result permits receipt lookup only.
- Pending attempts retain their original account, origin, node, branch, location, till, key and body. GET 404 never proves rejection.
- Scanner focus no longer steals keyboard control from navigation disclosures.

The six frozen outcomes remain unchanged: navigation, readable history, demo entry/reset, secondary advanced options, correct seller attribution and safe sale feedback/recovery.
All ten [sale acceptance checks](sale-preimplementation.md) were adopted before implementation.
This increment preserves server authorization, real login, payments, approval rules, shared sales and stock exceptions.

## Design references

[REFERENCES.md](REFERENCES.md) records the 26 supplied repositories and six deeper source reads.
Applied: clear primary action, native disclosures, keyboard focus, calm actionable errors and progressive diagnostics.
The existing green and neutral visual system remains. No UI framework, motion package or other dependency was added.
Shaders, smooth scrolling and virtualization remain deferred until a measured product need exists.
This is selective inspiration; it is not a full audit of those repositories or their licenses.

## Fresh combined verification

Commands below ran in the canonical checkout. Final web/lint/build and delayed lookup checks include the two residual lifecycle guards.
`corrections/lookup/CHECKS.json` records their exits, timings and private raw-log hashes.
`corrections/lookup/CANDIDATE.json` binds the final 20 product/test paths under explicit RAW and LF policies.
The 19-path `corrections/CANDIDATE.json` and its checks remain historical. Unchanged earlier browser evidence is reused explicitly below.
The original 16-path `primary/CANDIDATE.json` and `primary/CHECKS.json` remain historical.

| Command | Result | Limit |
| --- | --- | --- |
| `node --test savia/web/tests/*.test.mjs savia/web/scanner/scanner.test.mjs` | 98/98; exit 0; zero skips | Final Node tests |
| `node node_modules/@biomejs/biome/bin/biome check web` from `savia` | 65 files; exit 0; no warnings | Final format and static lint |
| `python savia/tools/build_demo.py` | exit 0 | Fictional demo build |
| `python -X utf8 docs/savia-ux-20261116/corrections/lookup/browser.py` | 8/8; exit 0 | Final real Chrome; active lookup and delayed response across navigation/logout/account, two viewports |
| `python -X utf8 docs/savia-ux-20261116/corrections/browser.py` | 30/30; exit 0; reused | Earlier full shell, fictional HTTP/data; before the two lookup guards |
| `python docs/savia-ux-20261116/primary/browser.py` | 41 mounted + 20 keyboard; exit 0; reused | Earlier real Chrome, fictional HTTP/data; before the two lookup guards |
| `node --test savia/demo/site/entry.test.mjs` | 3/3; 71 browser checks; exit 0; reused | Entry/reset source unchanged |
| `python savia/tools/rules.py` | 9/9; exit 0; reused | Architecture unchanged |
| `python tests/check.py` | exit 1: three asset-audit fixture errors, `WinError 1314` | Windows cannot create fixture symlinks |

Earlier mounted/keyboard browser evidence covers Enter/Space disclosures, scan-to-add exactly once, seller selection, cash/change and fictional sale submission. The final lookup-only browser run covers active selection and delayed replies at 1440x900 and 390x844; it sends zero sale POSTs.
The mounted flow includes response loss before/after commit, invalid success, storage failures, stale identity and lookup without retransmission.
Full-shell checks hold or fail till dependencies, delay mounts across route/session changes, and reset a pending fictional sale.
The final Node suite also proves a retired session's delayed 401 cannot invalidate the session that replaced it.
Own browser sessions and HTTP servers were closed. No SQL or real payment was used.

Reused appearance evidence from the earlier primary run: [desktop sale](primary/sale-ready-1440.png), [mobile sale](primary/sale-ready-390.png), [mobile receipt](primary/sale-receipt-390.png).
Worker BEFORE/AFTER media remain attributed in the area reports.
The final demo test overwrites `demo/real-browser.json` and its entry/manager screenshots; these are now primary evidence, not unchanged worker outputs.

## Corrections and historical evidence

- Navigation worker exposed scanner focus theft. The primary reproduced the actual blur-timer failure, corrected `shouldReclaimFocus`, and verified keyboard plus scanner regressions.
- Two initial browser failures came from retained disclosure/draft state in the test setup. Their first-result JSON files remain; explicit initial-state setup fixed the tests.
- The sale worker's 64-test result preceded its last changes. It is historical. The final combined result is the fresh 98/98 above.
- Biome initially rejected formatting. The primary used the existing formatter only on owned modules, removed two unused catch bindings and verified a clean final result.
- The format command itself exited 0. Printing its Unicode diagnostics through CP1252 failed afterward; the saved process receipt and subsequent clean lint distinguish that reporting error.
- Four navigation `.log` files are excluded from publication under repository policy. `primary/EXCLUSIONS.json` records their original hashes and ignored archive paths. Historical manifests retain their original meaning.
- Unrelated changes to `AGENTS.md`, `docs/DECISIONS.md` and other working files remain excluded.

The [first independent review](astra-combined-review.md) returned REVISE with four P2 findings.
The primary reproduced all four and corrected the actual router, demo reset, delayed mounts and approval redraw.
[Correction evidence](corrections/README.md) separates the original red runs from the expanded final green checks.
The additional stale-401 regression failed twice on the old code and passes in the final 98-test suite.
The [second review](corrections/astra-recheck.md) closed those findings except a delayed catalog lookup opening the shared size picker.
That residual case failed 6/7 offline checks before two guards were added. It now passes 7/7 and eight full-shell Chrome scenarios.
[Residual correction and limits](corrections/lookup/README.md) preserve the red run and distinguish final proof from reused evidence.
The [final Astra/xhigh recheck](corrections/lookup/astra-recheck.md) accepts F3b within its tested boundaries: fresh 98/98 tests and 24/24 independent adversarial scenarios, both exit 0. The primary verified all 115 frozen paths and accepted this bounded local increment in [ACCEPTANCE.md](ACCEPTANCE.md). Historical candidate manifests retain their original pending-review labels.

Lesson: test through the router and session/reset boundaries. A directly mounted screen does not establish lifecycle safety.

## Blockers and next actions

| Blocker | Evidence / cause | Attempt / next action | Owner and completion check |
| --- | --- | --- | --- |
| Combined independent acceptance ? CLOSED locally | Final Astra/xhigh verdict: ACCEPT WITH LIMITS; 98/98 tests and 24/24 adversarial scenarios, exit 0 | Primary verified the report hash, 20 source bindings, six artifact bindings and 115 frozen paths; acceptance recorded | Primary: [ACCEPTANCE.md](ACCEPTANCE.md) |
| Required repository gate CLOSED on Linux | The local Windows run failed in symlink fixtures with `WinError 1314`; Linux passed the full gate on `2587712b` | Primary verified the completed Linux snapshot workflow; Windows permissions remain unchanged | [Source-bound readback](../savia-completion-20261116/publication/CI-2587712.json) |
| Publication and corrected-SHA CI CLOSED | The original Spec17 failure is preserved; corrected source at `2587712b` passed all four workflows | Primary verified the remote SHA and completed checks; new SQL runtime retains its gate | [Completed source-bound readback](../savia-completion-20261116/publication/CI-2587712.json) |

The following continuation supersedes the pre-publication checkpoint. No merge or deployment was performed.
NOT RUN for the current UX: combined browser→API→SQL, physical scanner/devices, complete accessibility audit, real-user usability validation or production. Separate real SQL CI results are recorded below.
The result is an accepted local UX increment with explicit test limits. Production readiness is not established.

## Completion continuation — 2026-11-16

The preceding publication and NOT RUN statements describe the pre-publication checkpoint.
The primary subsequently published the accepted UX on `Tony` at `63a8b1e9bfe50e9426295cb22097514fc15155e7` and verified the same remote SHA.
This continuation preserves that accepted UX while closing the remaining technical gaps.

Live readback of [SAVIA v2 CI run 43943782960](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/43943782960), attempt 1:

- Architecture, tool tests, web lint/tests, generated SQL baseline, no-delete guard, build and C# formatting passed.
- Real T-SQL: `SUMMARY PASS=134`.
- Real .NET suite: **144 passed, 1 failed, 0 skipped, 145 total**.
- The failing method is `UsdVerifyTests.Spec17_quick_verification_preserves_pilot`.
- The full-check command exited `1`. The job log alone does not expose the underlying quick-check assertion.
- Cleanup logs explicitly record the disposable container, data volume and network being removed. No separate post-cleanup absence query was recorded.
- Progress digest, progress documentation and Tony source snapshot workflows passed on the same SHA.

| Workstream | Current evidence / cause | Next authorized action | Owner / closure check |
| --- | --- | --- | --- |
| CI failure resolved | Local reproduction confirms a nested working-directory error. The historical inner log remains unavailable | Correction passed 4/4 focused regressions; corrected source at `2587712b` passed web 98/98 and .NET 145/145 in CI | [Source-bound worker evidence](../savia-completion-20261116/ci-worker/README.md); [completed CI](../savia-completion-20261116/publication/CI-2587712.json) |
| Three-branch synchronization | Existing simulator and SQL foundation exist; one untracked historical basic-run log is incomplete | Fresh Astra/xhigh source review of replay, disconnected branches, transfer conservation and stale-backup recovery; freeze minimum acceptance checks | Astra/xhigh advises; primary accepts and assigns isolated implementation/runtime work |
| Current UX with real persistence | Latest UX has synthetic-HTTP Chrome proof; this CI does not execute its real browser journey | Prepare isolated browser→API→SQL sale, receipt lookup, refund and till-close proof, preserving the existing pilot | Primary; exact source, owned resources and database readbacks |
| Production operations | Backup/access/deployment preparation is separate from UX acceptance | Verify existing operational artifacts against current source and identify only material unproved gates | Primary; runnable recovery evidence and explicit external-deployment scope |

No automatic retry of the failed GitHub run was requested. No merge, deployment, native SQL change or real transaction was performed in this continuation.
Lesson applied: diagnose the one failed path before rerunning a broad suite. Successful SQL business tests do not hide a failed verification tool.

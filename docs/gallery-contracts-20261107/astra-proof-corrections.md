# ACCEPT WITH LIMITS — gallery proof corrections

Task `savia-gallery-proof-judge-69d3268-20261107`; mode VALIDATE; status returned. No unresolved F1/F2 finding and no new product defect established. Primary owns integration, final acceptance and ledger changes.

**Identity and scope.** SUAZO-PC / Windows / T3 Code / Codex. Requested `gpt-6-astra`, `reasoningEffort:xhigh`; runtime instructions and agent-awareness expose the same effective settings. Usage, token counts and cost are unexposed. One judge; no delegation. Managed worktree `C:/Users/Jason/.t3/worktrees/github/t3-469d6e00`, branch `t3/review-gallery-proof-corrections`, clean at entry. HEAD/base reviewed: `69d3268c63019d8b8299027789962a1089f91a58`; parent `7bce17f65b6a49b64443349d76f3a98b76e4b347`. Review occurred 2026-11-07, approximately 12:36–12:42 UTC, within 15 minutes. All required global contracts were accessible.

**1. F1 resolved.** `tests/gallery-browser-contracts.cjs:294` restores the promised viewport after the 1440 resize. Lines 300–303 observe/assert actual `innerWidth`, `innerHeight` and DPR before keyboard input, then capture the screenshot. No subsequent viewport change occurs inside the journey. Committed `browser/browser-contracts.json:128,353` records desktop 1280x900/DPR1 and mobile 390x844/DPR2. Independent PNG-header reads give 1280x900 and 780x1688. Direct image inspection confirms both show the green-dress product gallery, including its video slide and navigation; neither is an unrelated screen.

**2. F2 resolved.** `tests/gallery-browser-contracts.cjs:112,119` only reads the observed-response map and requires `source === 'browser.response'`. The sole map writer is `page.on('response')` at lines 270–276. `response.body()` reads that response; it is not another request. No `context.request.get` fallback remains. Controls extract the actual checked-out functions, rather than duplicate their implementation.

Fresh command, executed exactly once:

```powershell
node docs/gallery-contracts-20261107/primary/proof-corrections/resource-origin-controls.cjs
```

Exit **0**; **4 PASS / 0 FAIL**, **0 replacement calls**. Observed response passes; absent, substituted and unattributed responses each reject. No additional distinguishing probe or browser run was needed.

**3. Evidence binding verified.** Two read-only inline `python -` inspections exited **0**. They checked SHA256/CRLF-to-LF bindings, Git blobs, PNG headers, JSON arithmetic, local WebP bytes and parent product trees. All **10/10 manifest artifacts** and **6/6 product bindings** match. Text checkout differences are CRLF conversion, not source changes; binary hashes match raw bytes.

Retained red recounts **1 PASS / 3 FAIL**, one replacement call; `RESULT.json:8–13` records exit **1**. Retained green recounts **4/0**, zero replacement calls; exit **0**, independently reproduced above. Red is historical evidence attributed to the previous judge's baseline hash and reproduced defect (`astra-judge-corrections.md:17,28–33`); that earlier browser-source overlay was not independently re-executed here.

Committed browser evidence recounts **2 runs / 0 failures**; `RESULT.json:24–27` records exit **0**. Desktop: **720w / 86,518 bytes**. Mobile: **1024w / 140,962 bytes**. Both record HTTP200, WebP and `browser.response`; corresponding local files independently match byte counts and WebP signatures. Blocked, failed and HTTP-error lists are empty. These are inspected primary executions, not fresh judge browser executions.

**4. Historical overlay preserved.** `tests/desktop-gallery.cjs` LF SHA256 is exactly `58258777f44e7c48827584129cf5dba3b7537ee307485896962ddc18fcd68c7a`, matching the previously adjudicated overlay. Earlier DOM14/14 controls remain explicitly historical. No new concern warrants their rerun.

**5. Product unchanged.** Git tree IDs for `src/`, `build-inputs/` and `dist/` are identical to parent `7bce17f`. The commit changes only tests and documentation. Jason's layout and Denis's images are preserved.

**6. Remaining gates.** Primary records fresh Windows `python tests/check.py` exit **0**, all recovered-demo checks, and `python tools/export_progress.py --verify` exit **0**, **15 bindings**. These are source/site results; private raw logs were not accessed and neither command was rerun. Exact-SHA CI remains unconfirmed. Physical devices, screen readers, SQL/backend/.NET/Docker, production, network calls, installs and Git mutations were NOT RUN by this judge.

**Disposition and next action.** F1/F2 no longer prevent S-LEGACY's bounded technical closure. Primary must adjudicate this report and confirm applicable CI on the exact candidate SHA before closing S-LEGACY. This is not production readiness. No corrective implementation remains within judge scope; CI is the explicit external gate, owned by primary.

Only owned write: this report. No scratch, source/test/ledger edits, staging, commit, push, PR, merge or deployment. Lesson: require observed provenance and measured viewport; preserve historical evidence without relabeling it fresh.

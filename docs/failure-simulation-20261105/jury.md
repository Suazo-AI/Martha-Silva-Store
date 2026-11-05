# Standing jury review

Verdict: **ACCEPT WITH LIMITS**. Open material findings: **0**. Required corrections: **none** for the bounded claims. No demonstrated product defect or product fix follows.

Reviewer: T3 Code / Codex, gpt-6-astra / high, SUAZO-PC. Verified base: Tony@7d61524e29b4286055d44d145475a0a76195e1ba. Applied the canonical evidence-first playbook. Read-only review except this report; no nested agents, test reruns, hooks, publication or runtime changes. Agent awareness ran at entry and immediately before creation; task ownership reserves this file to the jury and integration to the primary.

## Responses to critic

- **P3 F03 — accepted limitation, still present.** `dev/savia-staff-ui/failure-simulation.test.mjs:96` explicitly deletes stored receipt state between clear/start. `app.mjs:461` clears in-memory/DOM state, while `app.mjs:569` rereads persisted receipts. Thus clear/start alone does not establish reachability. The test checks pending identity and eventual confirmation while an earlier-generation 404 arrives (`test:97–99`). It supports an adversarial invariant, not an ordinary user journey. `README.md:38` and `primary-review.md:14` disclose this. No correction required; retain that wording.
- **P3 F07 — original empty-baseline objection resolved for the revised test.** `failure-simulation.test.mjs:129–138` supplies valid nonempty inventory, asserts visible SYN-2, observes a held POST, delivers 401, then releases the receipt. It checks null verified session, empty/hidden receipt, empty stock, disabled submission, unchanged pending bytes and one POST. `login.mjs:56–58,77` invalidates/rechecks authorization; `app.mjs:527` guards generation. Qualification: `app.mjs:480` clears stock when refresh starts, before 401. This demonstrates the final revoked state and late-response exclusion; it does not isolate stock removal specifically to `clear()`. No material gap for the documented outcome.

## Reachability, oracles and evidence

Actual imports and an exhaustive mock-route boundary appear at `failure-simulation.test.mjs:6–8,29–48`; no network fallback exists. F01/F05 inspect blocked intervals and POST counts. F02 completes a new multiarticle sale after obsolete-reference discard. F04 compares full retry body/key and restores persisted pending state into another DOM/client. F06 checks storage denial prevents POST. F08 exercises a server-shaped rejection, not observed server durability. F09 checks eight corruptions through parser and HTTP-to-DOM paths. F10 checks valid controls before corruption across 32 deterministic parameter samples (`test:168–180`). Its 192 fixed actions are not independent scenarios or exhaustive state exploration.

Independently recomputed hashes: nine original recorded artifacts still match; only the revised test differs, as documented. All five current hashes match both before/after maps in `PRIMARY-RESULT.json`. Product modules have no diff against HEAD. The original test hash is historical; the current test hash is `491a8f3b0f516fefd81fa5cc426c0c002470f3ef183e3d1eeb8dc08deef5d9d8`.

Both primary TAP hashes match. `focused-primary.sanitized.txt:305–310` reports 50/50; `staff-glob-primary.sanitized.txt:617–622` reports 102/102, zero failures/cancellations/skips. PRIMARY-RESULT records direct-process exit 0; the jury did not independently observe those processes. Worker UTF-16 logs match their original hashes and normalized public exports. Counts include two parent tests. Before/after hashes improve binding but are not an atomic snapshot. Historical README/RESULT/critic remain distinct from the F07 revision.

## Public import and handoff

Read all four destination files; independently verified byte equality against the authorized source directory and the published hashes. README, verification.json, bin/agent-awareness.py and tests/test_agent_awareness.py are the only imported files. No snapshots, private configuration, conversations, backups or bytecode are included. These are archival sources, not installers. Originating six-test/hook/review claims remain attributed; actual automatic startup remains NOT RUN (`verification.json:37`).

Primary may integrate these limited claims and the four public files. `.github/workflows/savia.yml:35` includes the test glob; new CI and hook publication remain unobserved. Next: primary publishes reviewed explicit paths, verifies remote SHA and applicable CI. This review proves no real backend, SQL durability, browser/device/layout, payments, production readiness or C2/C9/C10 closure. The next-session coordinator separately verifies automatic startup under normal client trust controls.

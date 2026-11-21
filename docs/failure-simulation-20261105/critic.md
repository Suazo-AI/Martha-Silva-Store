# Independent critic review

Verdict: ACCEPT WITH LIMITS for bounded local failure simulations. No blocking finding and no demonstrated product defect. Primary owns acceptance and integration.

Reviewer: T3 Code / Codex, gpt-6.1-sol / high, SUAZO-PC. Candidate verified locally: Tony@7d61524e29b4286055d44d145475a0a76195e1ba. Review scope: test, six worker evidence files, actual app/client/login modules and CI glob. No nested agents. Only this report was created.

## Findings

**P3, optional — F03 is a constructed cross-generation state, not proof of an ordinary user journey.** `dev/savia-staff-ui/failure-simulation.test.mjs:96` manually removes the saved receipt after `clear()`. Actual `app.mjs:461–465` clears memory/DOM but retains storage; `app.mjs:569–570` reads that receipt again on start. Without the injected removal, the second start would await another receipt lookup. The test meaningfully delivers the old 404 while a new POST is held, checks the exact pending object, then completes the new sale. It therefore proves the stated invariant under that constructed interleaving. It does not establish that clear/start alone reaches it. README:38–42 already discloses the injection. Optional next improvement: identify a supported actor/storage transition that reaches this state, or continue describing it explicitly as adversarial state injection. No product correction follows from this limitation.

**P3, optional — F07's stock-clearing oracle is vacuous.** `dev/savia-staff-ui/failure-simulation.test.mjs:129–136` starts with malformed stock `{}` and later asserts an empty stock table. `client.mjs:51–54` rejects that initial payload; no populated stock table existed to clear. This does not invalidate its late-sale-response oracle: a POST is observed before 401, the real auth client invalidates its session, the callback clears commerce, and the delayed valid receipt cannot appear or replace durable pending state. Actual guards are `login.mjs:56–58,77` and `app.mjs:527`. Optional improvement: use a valid nonempty initial stock response and assert its presence before revocation if claiming populated-stock clearing. The present README explicitly discloses the malformed fixture.

Required corrections: none for the limited claims currently documented. Neither observation warrants a product fix or altered expectations.

## Acceptance evidence

- Actual imports: test:5–8 loads mountCommerce, createStaffClient, readReceipt and StaffRequestError. Fixtures construct receipts independently; transport has no network fallback.
- F01 checks pending identity, disabled recovery and zero POST during held recovery. F02 checks obsolete-reference deletion followed by one complete two-line POST. F03 checks the constructed generation race described above.
- F04 compares complete retry call/body/key despite edited DOM, then restores the exact saved operation into another DOM/client and confirms without another POST. Receipt validation checks expected line quantities, not only sale ID.
- F05 checks one POST during delayed double submit. F06 checks zero POST after storage denial. F07 exercises real simulated-HTTP 401 and delayed receipt rejection.
- F08 retains pending on operation404 and unlocks on a server-shaped rejected outcome. “Durable” here describes the mocked outcome contract, not independently observed persistence.
- F09 exercises eight corruptions through both readReceipt and HTTP-to-DOM handling. F10 supplies 32 deterministic parameter samples, 192 declared fixed actions and eight reused fault classes. Positive valid-receipt controls precede corruption. Counts are honest; this is not randomized state exploration or exhaustive testing.

## Evidence integrity and limits

All ten recorded SHA256 values match current bytes, including sources, test, logs, README and MATRIX. The three product modules have no diff against HEAD. BOM-aware decoding confirms focused.log:53–60 reports 50/50 and staff-glob.log:105–112 reports 102/102, zero failures/skips/cancellations, and matching Node durations. Counts include two parent tests, as disclosed. RESULT.json:13–34 records commands and exit 0; exit codes are worker-recorded metadata, not independently recovered process receipts. Hashes are explicitly post-run, not an atomic execution snapshot.

`.github/workflows/savia.yml:35` includes this filename through the staff test glob once integrated. No new CI run was observed. Passing tests were not rerun. An initial console print hit Windows cp1252 encoding; escaped output resolved log inspection without modifying evidence.

This establishes jsdom/module behavior with HTTP mocks only. It establishes no real backend HTTP, SQL durability/uniqueness, browser/device/layout behavior, payments, production readiness or C9/C10 closure. Worker artifacts remain immutable. Next action: primary accepts these bounded claims and passes the concrete limitations to the standing jury.

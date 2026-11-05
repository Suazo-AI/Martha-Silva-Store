# N5 browser coverage: primary inspection

Date: 2026-11-05 UTC. Host: SUAZO-PC.
Primary: T3 Code / Codex, gpt-6.1-sol, xhigh.
Disposition: limited technical integration accepted; final review PENDING Opus.
Production: NO-GO. This report does not close the ledger item.

## Artifact and direct checks

Worker: Codex gpt-6.1-sol, requested/effective reasoningEffort high.
T3 worktree: `C:/Users/Jason/.t3/worktrees/github/t3-6b804833`.
Base SHA: `1e353d45cd0eb2ad8e79589f410ac191c1368b06`.
Test: `tests/browser-mock-validation.mjs`.
Original worker test SHA256: `020b29f19d8820489ccdb4317141ec3ca2fd83d4733a8244a277bc5ab982862c`.
Corrected integrated test SHA256: `8fdd63efe6a2858b15c54cf589c1b3215d6f70320b946a3151b875b5e86960c8`.

Primary read the actual diff, worker README/RESULT, focused/full browser JSON,
log summaries and affected `app.mjs` generation/receipt/start/submit paths.
The diff adds 94 lines and three cases; existing assertions remain present.
Only the test and owned evidence changed in the worker checkout.
`git diff --check` returned 0. Product Git diff was empty.
All 16 entries in changedFilesSha256 and six source hashes match current files.
Focused/full browser source manifests match those same six source hashes.

Recorded execution: N5 8/8, full browser 50/50, staff 102/102, zero skips; exits 0.
The logs and machine-readable results agree on counts.
Browser runtime arrays and external-request arrays are empty.
Focused aborts: one deliberately lost sale response and one logout navigation.
Full aborts: ten deliberately lost sale responses and three logout navigations.
These are expected test actions, not zero failed HTTP requests.
Logs use UTF-16 BOM; parse using the detected BOM before summarizing.
After the two minor judge findings, primary strengthened the initial inventory
comparison to exact cells and corrected the logout attribution in README.
The integrated test then passed focused N5 8/8, exit 0, on the corrected SHA256.
It recorded zero uncaught page errors, zero external requests and the same two
expected aborts. The 50/50 full and 102/102 staff runs remain the worker's original
evidence; they were not repeated or attributed to the corrected test bytes.
`RESULT.json` stays the original worker record. `worker-test.patch` reproduces its
test from the base and `worker-README.md` preserves its README. The generated
`INTEGRATION.json` records current bytes and checks separately.

## Frozen criteria

1. Held operation GET: disabled native button plus synthetic submit, zero new POSTs,
   byte-identical pending body/key/version, original-key recovery, one setup POST.
2. Discarded receipt 404: complete two-line sale, exact body, one UUID-keyed POST,
   new receipt/reference and inventory read, stock 10/10 to 8/7, reload without repost.
   This fixture has no old pending operation, so it does not claim comparison with
   a prior operation key. Receipt data and inventory remain HTTP fixtures.
3. Held old receipt 404: native logout invalidates the live document before the
   response; its completion changes neither cleared private UI nor stored reference.
   Native login then exercises a fresh session. No manual storage deletion.
   Logout also advances the client's epoch in login.mjs. The old response is
   rejected as 401 before the HTTP 404 is processed; restoreReceipt rethrows it.
   This proves the combined logout protections, not the isolated gone branch or
   restoreReceipt generation guard. Astra identified this attribution correction.
   A concurrent new sale within the original generation is dismissed because
   start awaits restoreReceipt with busy set, lock disables controls and submit
   rejects while busy/pending. Navigation does not create a new commerce instance.
   This is a reasoned dismissal plus a reachable invalidation test, not a claim
   that the impossible newer-pending state was exercised.

All new cases passed unchanged product on their first actual browser execution.
No red product result exists; no product correction is justified by this batch.

## Blockers, owners and completion checks

- Independent judge: [Astra/high](judge.md) returned APTO CON REPAROS, zero material
  findings. Primary verified both minor findings in source and corrected them.
  Focused browser recheck passed with exact initial cells. No new judge run is
  needed for the strengthened assertion and factual documentation correction.
- Opus critic: the previous approved Antigravity route was quota-blocked. A
  read-only quota check at 2026-11-05T13:41:11.946Z returned stale data and
  `Antigravity process discovery unavailable`; effective availability is unknown.
  The cached Claude/GPT window showed 0 and reset 2026-11-05T14:03:19Z, which is
  not a fresh availability guarantee. No retry or paid-credit fallback attempted.
  Fresh quota at 2026-11-05T13:46:34.569Z now confirms effective Claude/GPT 0%,
  exhausted_now, limiting five-hour reset 2026-11-05T14:03:19Z (08:03:19 Managua).
  Owner: primary. Recheck after the indicated reset; only fresh availability plus
  an actual approved Opus/high verdict closes this blocker. No substitution or
  paid-credit fallback. The ledger remains review.
- General portable check: fresh `python tests/check.py` exited 1 at asset-audit
  fixture creation with `[WinError 1314] A required privilege is not held by the
  client`; six asset tests ran with three environment errors. Reproducible build
  and fixture checks passed before that failure. Cause: Windows symlink privilege,
  matching the documented baseline issue. No product assertion failed in this
  error. No security/privilege change or repeated attempt was made.
  Owner: primary. The approved normal Tony push runs the same portable suite on
  Ubuntu through tony-snapshot.yml. Close the verification gap only with that
  exact candidate's Linux CI result; do not claim full local portable PASS.
- Integration/publication: primary imported only the bounded files into Tony and
  preserved foreign untracked paths. Corrected N5 passed 8/8; ledger validation,
  24 ledger tests and 15 preserved evidence hashes passed. Progress tests passed
  exit 0. Supplemental screenshots were inspected and contain synthetic fixtures.
  Remote SHA and exact-SHA CI remain required before remote delivery is claimed.
  Publication of review-stage progress does not close Opus or the ledger item.
- Product dependencies: C2 walkthrough, C9 consumed TLS attempt, C10 operational
  acceptance, payments/closing and hosting remain outside this test-only batch.
  No correction attempted because this packet grants no new operational,
  SQL, certificate, real-data, merge or deployment authority. Owners and next
  actions remain in the current release plan and ledger; none are closed here.

## Limits and lesson

Actual Chrome with mocked HTTP. No fresh real API, SQL, physical-device,
cross-browser, performance, production or operational acceptance proof.
No primary CI or complete local portable-PASS claim yet. Worker token/currency usage is unknown.
Lesson applied: hold real intercepted requests and exercise native user
transitions; do not create unreachable races by deleting storage in the test.

## Public evidence package

The first commit attempt was blocked by the existing `.log` filename policy in
`tools/progress.py`. No commit or push occurred during that attempt.
Primary removed all nine raw logs from the index and archived them outside the
repository at `C:/Users/Jason/MARTHA-SILVA/test-runs/n5-browser-20261105/raw-logs/`.
No filter was weakened and no raw log was renamed to bypass it.
[EXECUTION-SUMMARY.json](EXECUTION-SUMMARY.json) records reviewed totals, log hashes
and archive locations. Browser result JSON, command/exit records and synthetic
screenshots remain in the public evidence package. Frozen `RESULT.json` and
`worker-README.md` refer to the original worker checkout; their log paths are not
included in the public package. Completion check: normal hook accepts this
allowlisted package, remote SHA matches and exact-SHA Linux CI is inspected.
Owner: primary. Independent Opus review remains pending.

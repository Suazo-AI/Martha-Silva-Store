# N5 browser recovery coverage

Date: 2026-11-05. Host: SUAZO-PC. Mode: BUILD (test coverage).
Source: Tony `1e353d45cd0eb2ad8e79589f410ac191c1368b06`.
Status: primary ACCEPT WITH LIMITS after Opus return and Astra/high M1 adjudication.
Negative controls killed 3/3; baseline/restored N5 passed 8/8. N5-COV is done.
Remote delivery requires the publication SHA readback and applicable GitHub CI.
Production remains NO-GO.

## Objective and authorization

Jason: "Go for it and let me know what are you going to build now and why".
This follows the approved mandate to complete reversible work, use isolated workers,
and verify actual results. This packet covers existing N5-COV browser criteria only.
It does not extend SQL, certificate, security, payment, merge or deployment authority.

The business outcome is safe continuation after interrupted sales, without a second
sale or a lost pending attempt. Existing jsdom checks do not close browser coverage.
No product defect has been demonstrated by the source audit.

Sources: `../release-20261105/savia-audit.md` (N5-COV),
`../pipeline/ledger.json` (N5-COV), `../../tests/browser-mock-validation.mjs`,
and the current `dev/savia-staff-ui/app.mjs` and `client.mjs`.

## Frozen acceptance checks

1. Hold the actual browser operation-recovery GET. While held, verify native submit
   stays disabled and a synthetic submit cannot post a sale. Compare stored pending
   key/body before release; recover with the original identity and no duplicate POST.
2. After discarding a confirmed receipt that returns 404, complete a fresh
   multiarticle sale. Verify one new key, exact body, one POST, valid receipt,
   obsolete reference absent and refreshed inventory.
3. Hold an old receipt 404 and exercise a user-reachable invalidation or new-session
   transition. Verify its late response cannot erase newer state or expose old data.
   If the constructed same-generation state is unreachable, document why from source
   and browser evidence. Do not manually delete storage to manufacture reachability.
4. Preserve existing pending-sale, authorization, CSRF, session-invalidation and
   stale-receipt checks. Source product bytes must remain unchanged.
5. Run the new scenarios against unchanged product, then affected existing browser
   and staff checks. Distinguish test-harness failures from product failures.
   All-green coverage may establish no reproduced defect; do not invent a red result.

## Ownership, limits and review

- Executor: Codex `gpt-6.1-sol`, explicit `reasoningEffort: high`.
- Isolation: T3-managed worktree. One writer.
- Owned: `tests/browser-mock-validation.mjs` and this area's new execution evidence.
  Primary alone owns this PLAN and later serial integration/status publication.
- No product edits, commits, pushes, installs, SQL, Docker, certificates, real data,
  external services, credential copies, global instruction edits or recursive workers.
- Existing browser harness may start an ephemeral loopback test server and its own
  headless browser. Both must close. HTTP fixtures are synthetic, not real API/SQL.
- Budget: one delegated run, at most 25 minutes; no new paid route or automatic retry.
  Token/currency usage is unknown unless the runtime reports it.
- Stop on demonstrated product defect: preserve red evidence and return it to primary
  for the smallest authorized correction. Stop on missing dependencies or authority.
- Primary verifies actual diff/results. Opus 5.5/high through Antigravity critic and
  Astra/high judge review the new scope when their approved routes are available.
  Unavailable review remains pending; no silent substitution or READY claim.

## Blockers and next actions

N5-COV: missing browser assertions, not a demonstrated product defect. Correction:
add and exercise the frozen checks. Owner: executor, then primary. Close only after
candidate-bound assertions, explicit late-404 disposition and independent review.

Receiving UI: the release plan conditions business-flow implementation on C2 and a
frozen operational contract. No product correction attempted here because the Martha
walkthrough facts remain missing. Jason supplies the already selected D-029 walkthrough;
primary maps the confirmed receiving task to UI/API checks before implementation.
This work does not close C2, C9, C10, full SISFAIN parity or production readiness.

## Execution return

The Sol/high worker returned from T3 worktree `t3-6b804833` on the frozen base.
Focused N5 8/8, full Chrome/HTTP-mock 50/50, staff 102/102; recorded exits 0.
Primary inspected the three added cases and verified 22 artifact/source hashes.
No product bytes changed and no product defect was reproduced.
See [primary inspection](primary-review.md) for acceptance limits and review blockers.

Public-package correction: the commit hook rejected raw `.log` paths. Primary
archived nine logs outside the repository and published reviewed totals/hashes in
EXECUTION-SUMMARY.json. Controls remain unchanged; normal-hook retry and CI pending.

## Critic follow-up and frozen negative controls

Opus returned ACCEPT WITH LIMITS. The model was claude-opus-5-5 through
Antigravity; requested thinking_level was high, effective reasoning was not
exposed. Do not label the critic runtime high-verified. The reviewer could not
load three global rule files due a workspace pre-tool restriction; primary read
them directly. Those limits remain in [critic.md](critic.md).

Material M1 is accepted: keep N5-COV in review until disposable mutation controls
prove the tests detect the injected regressions. The owner acceptance criterion
is unchanged. No first-green result is being relabeled red/green.

Primary corrected m2 by adding a browser turn after the second synthetic submit.
For m1, the combined late-response mutation below must demonstrate that the
observation window detects the forbidden state change. A surviving mutant or
infrastructure failure is not a PASS; return it for diagnosis.

Frozen control plan, Sol/high in a separate T3-managed worktree:
1. Baseline focused N5: all eight cases pass on the exact approved test bytes.
2. Remove only busy/pending submit guards: held recovery test must fail on a
   semantic invariant, such as original pending bytes changing.
3. Omit obsolete receipt storage removal: complete fresh-sale test must fail.
4. Remove the two request epoch checks and the restoreReceipt generation guard:
   late-404 test must fail on retained-reference/private-state protection.
5. Restore exact product bytes after each injection and after the final run;
   restored N5 must pass 8/8. Product mutations must never enter canonical Git.

Record command, filter, exit, test assertion, raw and normalized source hashes,
mutation patch and restoration proof. Use the installed Playwright and Chrome,
synthetic HTTP only, no API/SQL/Docker/certificates, no external requests.
Primary owns serial evidence integration and asks Astra/high to adjudicate M1
on the returned artifacts. No operational or production acceptance is implied.

## Negative control return

Primary verified baseline8/8, M01/M02/M03 killed and restored8/8 on the frozen
88eaa4 test overlay. Product restored byte for byte; no real defect reproduced.
See mutations/README.md and IMPORT.json. Independent Astra/high adjudication of
M1 remains pending. Keep the acceptance checks and ledger review unchanged.

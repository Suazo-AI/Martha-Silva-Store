# Session-bound antiforgery worker return

Candidate returned with limits. Production remains **NO-GO**. Primary and sole judge Astra/xhigh acceptance are pending.

Host `SUAZO-PC`; T3 Code / Codex `gpt-6.1-sol/high`, requested and exposed settings match.
Usage/cost and internal provider telemetry are unknown.
Base HEAD verified: `70e7549062e6919f36c0f36ba21d7a54999a7d9d`.
No branch/checkout change, staging, commit, push, PR, merge or deployment.

## Implemented

`AddInternalSecurity` replaces the framework additional-data provider after `AddAntiforgery`.
Authenticated tokens carry `s1:<canonical nonempty GUID-D session>` and compare ordinally.
A single session claim must belong to the single authoritative authenticated identity.
Missing, malformed, empty, duplicate and distributed claims fail closed for generation and validation.
Anonymous empty data remains valid. Authenticated legacy empty data fails.
Both existing validators consume the same real framework provider. No filter/product changes outside scope.

## Fresh proof

- Real HTTPS TestServer, real IAntiforgery, ephemeral DataProtection, fixture principal selection, no SQL.
- Original product source: **2 expected failures**. S1 token works in S1 and wrongly returns 204 in S2 on common and Directory paths.
- Final candidate: **55/55 PASS**, comprising 6 new cases and 49 existing InternalSecurity cases. Actual code and prepared N8 compile.
- Fresh/repeated/two independently issued S2 tokens work. Stale T1 returns 400 before the mutation counter.
- Missing/wrong cookie, missing/duplicate header, cross-user, invalid claims, anonymous and legacy token controls pass.
- HTTP is covered by the common production filter. Directory's route-group HTTPS guard was read; its HTTP wrapper was not exercised with this real-antiforgery fixture.
- Captured mutation response bodies/headers and in-memory logs contain no fixture token, cookie value, password or invalid session claim.
- Initial green: 54/55. Directory's existing primary-identity guard correctly returned 401 for the anonymous-first mixed principal.
  The fixture now expects that guard and also directly proves provider validation false and fixed generation failure. Correction: 55/55.
- Final discovery: **637 cases**, separate inventory, not 637 executed tests. Historical A552/C77/E2 evidence remains unchanged.
- Existing auth client regressions: **12/12 PASS**. Every tracked staff-client file matches HEAD after LF normalization.
- `git diff --check`: PASS.

[Machine-readable result, commands/exits, timings, controls, failures and exclusions](RESULT.json).
[Raw/LF source hashes and unchanged client bindings](SOURCE-MANIFEST.json).
[Discovered test inventory](TEST-INVENTORY.txt).

## SQL preparation

N8 retains its original checks and adds real same-account cashier and Owner logout/relogin assertions.
It checks a new persisted session, revocation/version, retained antiforgery cookie, stale-token 400 and full independent 20-table fingerprint equality immediately around rejection.
The same original body/key with a fresh token creates a single intended sale/stock effect or Directory item and explicitly replays the result.
Actor, branch, quantity, price, movement, stock, item and operation assertions are prepared.
SQL is **NOT RUN**. Changed-table historical-row equality beyond the targeted assertions is not proven.

## Runtime and failures

Two nonce-owned non-SQL containers were used. Both exact IDs are in RESULT.json and are absent after cleanup.
The first was stopped before tests completed: the writable output parent exposed a second source path.
It is excluded from sandbox proof. The second uses distinct read-only source/cache mounts and an output-only writable sibling.
Network none, no ports, read-only root, all capabilities dropped, no-new-privileges, UID 1000:1000, 2 CPUs, 4GiB, pids256, tmpfs total 2GiB, --rm and 900-second lifetime.
Actual controls and cleanup were read back. Combined runtime was below 30 minutes; each container was below 15 minutes.
Retained private files are below 200MiB. Raw TRX/logs remain ignored under `private-exports/session-csrf-20261107/`.

Runner failures were diagnosed before retry: empty tmpfs seed copy, lost PowerShell filter quoting, and CRLF shell script.
A direct source copy, locked offline restore and LF runner resolved them. No host security settings, network restore, trust, accounts or SQL were changed.
Lesson applied: separate the writable output mount from source and emit shell scripts as LF bytes.

## Remaining blocker and next action

`python tests/check.py` exits 1: `Missing jsdom: run python tests/check.py --install first.`
The expected local and canonical dependency directories were absent. Downloads/installations are outside this task's offline scope.
Independent auth tests passed without jsdom. Full pending sale/supply/review same-account relogin and DOM regressions remain unexecuted.
Owner: primary. Supply an existing cached jsdom dependency directory in the intended checkout, then run focused client and repository checks.
Closure requires those checks passing with their actual scope recorded; unchanged bytes alone do not prove the full client journey.

NOT RUN: SQL/N8 runtime, C77/D/E, full backend execution, browser, CI, production, primary acceptance and Astra/xhigh judgment.
Next: primary inspects/imports these exact paths serially, completes missing client evidence and sends the frozen candidate to Astra/xhigh.

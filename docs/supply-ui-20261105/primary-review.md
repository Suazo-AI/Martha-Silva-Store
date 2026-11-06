# Supply UI: primary review in progress

2026-11-06 UTC. SUAZO-PC / T3 Code / Codex / gpt-6.1-sol / xhigh.

Status: RETURNED candidate inspected; independent acceptance and integration pending.
Canonical and worker base: `a4bdac69581ac0423a964dea6bc5c74d4e2bad28`.
Worker: `C:/Users/Jason/.t3/worktrees/github/t3-6ec58bbd`.
The frozen checks remain in [PLAN.md](PLAN.md).

## Direct checks

- Verified all 14 changed non-evidence files against the worker's RAW and LF SHA256 manifest.
- Verified each existing base file against its actual Git blob at the stated SHA.
- Read the supply module, auth/client/app/HTML diff, focused tests, pagination test and browser acceptance driver.
- Compared the frontend DTO fields with `InternalSupplyModels.cs`; the supplied order and receipt shapes match.
- Confirmed the new resource has an explicit protected route and explicit embedded-resource entry in source.
- Confirmed narrow supply GET/POST/recovery allowlists and preserved CSRF/session epoch checks in source.
- Read the worker results: staff124/124, supply Chrome8/8, existing Chrome50/50, negative-control exits0/1/0/1/0.
  These are worker executions; the primary did not repeat them in this review.
- No worker product file was edited, staged or imported during this inspection.

The browser fixture stores synthetic deliveries in memory. It does not establish SQL persistence.
Compiled resource routing, integrated Linux CI and real API/SQL receipt persistence remain unverified.
No production or SISFAIN feature-parity acceptance is implied.

## Review questions retained

The supply browser logout case allows navigation to the login document before checking its result.
The unit test checks late completion after `clear()` separately.
The independent critic must assess what the browser case proves about same-document invalidation.
The new focused browser driver is not called by the existing `savia.yml` browser step.
The portable runner does execute the new staff regressions; the critic must assess the frozen CI criterion precisely.

## SDK blocker and chosen route

`global.json` pins SDK `10.0.402`, with roll-forward disabled.
`dotnet --list-sdks` directly reported only `8.0.422` in `C:/Program Files/dotnet/sdk`.
The worker build stopped before compilation with exit `-2147450735`.

Microsoft's release metadata lists the exact Windows x64 archive:
`https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.402/dotnet-sdk-10.0.402-win-x64.zip`.
Its published SHA512 is:
`ae4fd528cb7e9f6af6aaf7de36715a69f761f183744f1bb3025d19f5a92447090ec561410e46266c1d10a63781ed6f3de771760bc76c876d87daabc367b898cd`.

Primary attempted a task-local download under
`C:/Users/Jason/MARTHA-SILVA/test-runs/supply-ui-20261105/`.
The transfer was stopped at 42,854,399 bytes because it was too slow for this bounded check.
The command returned exit1 after interruption. No archive was extracted or executed.
The checksum of the incomplete archive is not a verified SDK checksum.
No global SDK, PATH, `global.json`, certificate or security setting changed.

Chosen correction: use the existing GitHub `backend.yml` build-and-guards job on the integrated Tony SHA.
It installs SDK10.0.402, restores locked packages and runs database-independent tests.
Its SQL job requires `refs/heads/main`; a Tony dispatch must not start that job.
Do not dispatch until the reviewed candidate is integrated and the exact remote SHA is verified.
Primary must inspect the resulting jobs and stop if the workflow scope differs.

Closure: build exit0; embedded `SaviaStaff.supply.mjs` present; anonymous access denied;
authorized resource bytes equal the candidate. Add a bounded no-SQL compiled-route regression if needed.
Owner: primary. This replaces another local download attempt; the SDK blocker remains open until fresh proof.

## Remaining owners and completion checks

| Item | Owner and next action | Completion check |
| --- | --- | --- |
| Independent review | Gemini4Argon/high critic, then Astra/high judge; source and frozen evidence only. | Primary disposition of every material finding. |
| Integration | Primary imports only approved paths serially, preserving unrelated changes. | Integrated hashes, focused checks and exact-SHA Linux CI. |
| Compiled routing | Primary uses the pinned-SDK CI route above. | Build/resource/authorization proof without SQL. |
| API/SQL persistence | Primary prepares a separate authorized test of receipt and stock movements. | Persisted receipt, one stock movement and retry/rollback evidence. Not authorized or run here. |
| Operational release | Existing owners/gates remain in the project ledger. | Their existing evidence; this increment does not close C2/C9/C10 or production. |

Lesson: check the pinned toolchain before choosing a local execution route.
Use the existing pinned CI runner when a local SDK transfer is disproportionate.

Next: bounded independent critic review of the frozen worker candidate.

## Primary correction and review publication (2026-11-06 UTC)

Status: UNACCEPTED REVIEW CANDIDATE. SUPPLY-UI moves from doing to review, not done.
The worker's 14 source paths were imported after base/RAW checks. Product bytes remain unchanged from that return.
The first Gemini report is preserved as `critic-access-blocked.md`; its REJECT was an access/evidence failure.
It did not inspect the actual overlay and does not demonstrate a confirmed product defect.
No hook, allowlist, global policy or trust setting was changed.

A new managed checkout will receive the published source and `REVIEW-PACKET.md` directly.
The packet supplies relevant non-secret policy excerpts. It excludes private configuration, credentials and unrelated data.
Historical worker evidence is unchanged. `IMPORT.json` maps private raw logs and duplicate-recording exclusions.
`worker-log-outcomes.json` contains only curated summary lines, not renamed raw logs.

Primary changes beyond the worker:
- `tests/browser-supply-validation.mjs`: hold valid receipt and logout responses in the same document.
- `tests/fixtures/supply-browser.mjs`: test-owned synthetic HTTP gates; original worker fixture remains frozen.
- `backend/tests/Martha.Store.Api.Tests/InternalSupplyUiTests.cs`: actual embedded resource, anonymous denial,
  authenticated source-byte readback using test-only authentication and no database registration.
- `.github/workflows/savia.yml`: include the new supply browser driver and its separate evidence folder.
- `.github/workflows/staff-ui-candidate.yml`: bounded Tony/Linux workflow, no SQL, for staff, both browser drivers
  and database-independent backend/resource tests. It never deploys. Existing SQL job conditions are unchanged.

Fresh primary results:
- Full staff:124/124, zero skipped, exit0 (`primary/checks.json`).
- Portable runner tests:7/7, exit0. Scoped diff whitespace:exit0.
- Current held-logout browser probe:1/1, exit0 (`primary/logout-execution.json`).
- Current full supply browser suite:8/8, exit0 (`primary/browser-executions.json`, `primary/supply-full/results.json`).
- Disposable broken-guard probe reached the expected pending-reference assertion in the observed window.
  Its process exceeded35s; no successful exit1/restored run is claimed. See `primary/late-window-observation.json`.
- Primary existing-browser rerun exceeded120s; no primary50/50 or clean process exit is claimed.
  Worker50/50 remains historical evidence of the same product source bytes.
- No local .NET build or new SQL execution. Existing interrupted SDK download remains incomplete and unused.

The stale-session guard rejects at response headers without consuming JSON. `Response.finished()` stalled locally.
The corrected test waits for valid200 headers and two frames, with logout still held and `/internal/` unchanged.
It checks all supply private containers empty, original pending bytes retained and synthetic submit adds no POST.
The semantic negative observation supports that bounded window; it does not instrument every callback or scheduler order.
Read `primary/local-blockers.json` for exact failures, attempts, owners and completion checks.
No product defect was inferred from these harness timeouts.

Linux CI must verify this publication's exact SHA; no prior green run certifies it.
The new workflow avoids the existing full SAVIA workflow's manual SQL job entirely.
The compiled-resource test demonstrates route/resource wiring with a test authentication handler, not production cookies.
Real receipt/stock persistence, real API authorization, SQL/TLS and operational acceptance remain separate gates.
No `dist/`, public storefront, backend business rule, certificate or security setting was changed.

Next: publish this clearly unaccepted candidate, read back remote SHA and CI, then new Gemini critic in a managed
checkout containing the actual source. Astra/high follows the critic; primary retains final acceptance.
Lesson: a cold reviewer must receive the actual source inside its permitted checkout. Publishing a review candidate
with honest pending status is useful progress; granting wider filesystem access is unnecessary.

### Registry checks before review publication

All three commands completed with exit `0`: `python -X utf8 tools/delivery_status.py --check`, `python -X utf8 tests/test_progress.py`, and `python -X utf8 tools/export_progress.py --verify`. Exact private-log hashes: [registry-checks.json](primary/registry-checks.json). YAML syntax parsed for both affected workflows. These checks do not imply product acceptance.

Lesson: a reviewer must receive the actual frozen candidate inside its permitted checkout. The next managed review starts from the published candidate commit and uses the self-contained review packet. The previous access rejection remains preserved.

Publication check found one trailing empty line in the frozen historical `worker/before.mjs`. Its exact bytes are preserved in the private archive recorded by `IMPORT.json`; the redundant diagnostic script is excluded from publication. Historical evidence was not rewritten. The staged publication must pass `git diff --cached --check` without exceptions.

# Frozen cash workflow candidate — unaccepted

The staff UI now implements opening, full cash sale/change, authorized quantity refund and counted close.
Local/offline checks pass. Primary acceptance and fresh Astra/xhigh review remain pending.
Production remains **NO-GO**. No SQL or real payment execution occurred.

Task: `savia-cash-ui-continuation-550b104-20261107-02`.
Original task: `savia-cash-ui-550b104-20261107-01`.
The previous partial report and its original receipt remain in [partial-read-slice](partial-read-slice/README.md).
This report supersedes its unfinished-UI status without changing historical evidence.

## Identity and source freeze

- Host: SUAZO-PC. Harness: T3 Code/Codex. Provider exposed as Codex.
- Requested and exposed effective model/effort: `gpt-6.1-sol/high`. Runtime and agent-awareness agree.
- Hidden provider settings, token accounting, reasoning-token accounting and USD cost are unknown.
- Sole writer in tool-managed `C:/Users/Jason/.t3/worktrees/github/t3-ba806449`.
- Branch: `t3/savia-cash-ui-workflow`. HEAD/base unchanged: `550b10456c10a2857da930913b397bd1a96949d2`.
- [RESULT.json](RESULT.json) binds all **13 changed product/test paths** in RAW and normalized LF SHA256.
- The original four read-slice LF bindings remain unchanged and match the archived receipt.
- No nested delegates. No canonical checkout edits. Unrelated paths remain untouched.
- No stage, commit, push, merge, deploy, dispatch, accounts, certificates, services, Docker, SQL or external messages.
- The repository log's “Validated commit pushed” line comes from an automatic-sync unit-test fixture. No publication occurred.
- Cached .NET SDK 10.0.402 and installed frontend/Playwright dependencies only. No network installs or global upgrades.
- No credentials or `.env` files copied. SQL-related environment-variable count was zero in offline execution and final cleanup.

## Product changes

`backend/src/Martha.Store.Api/Internal/Cash/InternalCashReadService.cs` implements the two additive, persisted reads.
`InternalCashEndpoints.cs` registers them with `no-store` and the required sell/manage policies.
Serializable read transactions include persisted session validation, current authorization and monetary provenance.
An inaccessible existing own till denies access instead of reporting false absence.
Paying tills require an open matching location/currency/exponent and an enabled custodian with current branch access.
Paging orders by opening time and ID. Tests cover 103 tills, foreign locations, reassigned/disabled custodians and configuration drift.
The existing four POST handlers, operation scopes and business semantics remain unchanged.

`dev/savia-staff-ui/cash.mjs` implements transport, strict responses, operation intent and the mounted cash panel.
`app.mjs`, `client.mjs`, `login.mjs` and `index.html` connect it to the existing staff design and commerce cart.
Fresh sales use cash. Legacy unpaid pending sales retain `commerce.sale.record`, their original key and their original body.
Supply source remains unchanged. Paid receipt compatibility preserves stock-exception/review reads.

Money parsing uses decimal strings and BigInt, exponent 0–6 and the 9e12 minor-unit bound.
Cash receipts use recorded currency/exponent. An old unpaid receipt without exponent displays explicit minor units.
UUIDs, dates, enums, actors, locations, linked lines, arithmetic, refund credit and close differences are validated.
Requests never send client prices, totals, actor IDs or expected balances.

Before POST, the complete validated envelope is saved and read back: schema, actor/version, scope, key, path, body, raw body and dispatch state.
Storage failure blocks dispatch. The original key/body survive uncertainty, reload and same-account login.
Storage remains intent only. Current server session and permissions remain authoritative.
Unknown 404, 5xx, malformed success, timeout and key conflict retain the reference.
Only an explicit continuation can POST the same key/body. Reload performs GET recovery, never automatic reposting.
Known business rejection recovery uses the original generic operation endpoint and scope/key.
First known predispatch 400/403 unlocks only without earlier uncertainty. A 401 renews protection while retaining intent.
Actor/version/scope isolation and epoch guards cover headers, body, render and cleanup. Cleanup failure retains the reference.
Recovered immutable operations refresh current context and refund reads.

## Verification and exact commands

All commands ran from the assigned worktree. Full command arrays, exits, counters and bindings are in `RESULT.json`.

| Evidence | Result | Freshness / limit |
|---|---|---|
| Locked restore from existing NuGet cache | exit 0 | Original unchanged read slice reused |
| Focused cash/read/security .NET tests | **91 passed, 0 failed, 0 skipped; exit 0** | Offline rules, metadata, query translation and anonymous TestServer HTTP; no SQL |
| Focused cash/commerce/session/failure/stock tests | **167/167; exit 0** | Final restored frontend; includes 56 cash tests |
| Final `python tests/check.py` | **exit 0; staff 221/221** | Entire repository portable check passed |
| Final cash Chrome driver | **2/2; exit 0** | Exact final six UI source hashes match; synthetic HTTP |
| Original unpaid recovery Chrome case | **1/1; exit 0** | Original commerce scope/key retained |
| Supply screen Chrome case | **1/1; exit 0** | Supply entry remains usable |
| Final negative controls | **6/6 detected; each mutant exit 1** | Three backend and three frontend controls; source restored |
| `git diff --check` | **exit 0** | LF conversion warnings only |

```text
C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe restore backend/tests/Martha.Store.Api.Tests/Martha.Store.Api.Tests.csproj --locked-mode --source C:/Users/Jason/.nuget/packages
C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe test backend/tests/Martha.Store.Api.Tests/Martha.Store.Api.Tests.csproj --no-restore --filter FullyQualifiedName~InternalCashReadTests|FullyQualifiedName~InternalCashTests|FullyQualifiedName~InternalSecurityTests --logger trx;LogFileName=final.trx --results-directory docs/cash-register-20261107/ui-worker/test-results
node --test dev/savia-staff-ui/cash.test.mjs dev/savia-staff-ui/commerce.test.mjs dev/savia-staff-ui/session-transition.test.mjs dev/savia-staff-ui/failure-simulation.test.mjs dev/savia-staff-ui/stock-exception.test.mjs
python tests/check.py
node tests/browser-cash-validation.mjs C:/Users/Jason/AppData/Roaming/npm/node_modules/@playwright/cli/node_modules/playwright C:/Users/Jason/AppData/Local/SaviaEvidence/cash-ui-550b104/after-final-candidate
python docs/cash-register-20261107/ui-worker/frontend-negative-controls.py
python docs/cash-register-20261107/ui-worker/finalize-evidence.py
python docs/cash-register-20261107/ui-worker/freeze.py --verify
```

The .NET filter/logger literals above are structured arguments in `RESULT.json`; quote them when using a shell.
Frontend tests use the existing `tests/frontend-deps/node_modules` junction through `NODE_PATH`.
Browser tests set `SAVIA_PILOT_EVIDENCE` to the precreated private root.
The final repository check ran after the last product correction and exact mutant source restoration.
An earlier passing repository log remains as `repository-before-cart-reset.log`.
The final check was required by the confirmed-cart correction; it was not repeated for documentation changes.

Reproduced defects and corrected paths remain in `date-repro.log`, `nested-price-repro.log` and `payment-rejection-repro.log`.
Each failing reproduction exited 1 before correction; the final focused run passes.
`cart-reset-repro.log` also records the confirmed-sale cart-reset regression before correction.
Confirmed sale now clears the cart and received amount only after successful intent cleanup.
The browser also reproduced insufficient tender, then verified durable rejection recovery leaves the form editable.
Two initial browser failures came from a missing mock favicon route; a fixture-only 204 route corrected that diagnosis.
An initial socket-abort fixture allowed Chrome transport retry with the same key, so the driver now deterministically injects malformed success after one effect.
Timeout/network uncertainty remains covered by unit transport tests.

Backend mutants remove enabled-custodian, recorded-exponent and active-branch filters.
Each produces exactly one failed and eight passed assertions, then source restoration is verified.
Final frontend mutants remove the outer recorded exponent, replace the operation key or bypass session-version compatibility.
Each exits 1. The final cash source RAW SHA256 is `6e3bb17e0e0521bb2b969813366bc324ca26e8e4a9e4d43a425b1329b38c6c86`.
The first exponent mutant survived a fixture gap; an explicit outer-exponent assertion fixed the test.
An exploratory single epoch-guard removal survived because remaining guards still prevented cleanup; the final control targets version authorization.
Original exploratory results remain in `frontend-negative-controls.json`; final results are separate.

## Actual browser evidence

Private root: `C:/Users/Jason/AppData/Local/SaviaEvidence/cash-ui-550b104/`.
[browser-evidence.json](browser-evidence.json) records private paths, source hashes, network classifications, readbacks and media hashes/metadata.
No recordings were uploaded or placed in source control.

Before: genuine existing UI at **1440x1000** and **390x844**, multiarticle add/remove/quantity editing, response loss and reload.
Historical baseline **2/2** is compatibility evidence, not cash acceptance.
After: the same cart editing/loss/reload sequence plus opening, received/change, original-quantity refund and counted close.
Final-bound Chrome runs use exact frozen source bytes at both viewports.
Native empty-field and decimal errors, keyboard submission, insufficient tender, double-submit, malformed success, reload recovery and horizontal overflow checks pass.
Page/uncaught errors: **0**. External requests: **0**. One deliberate insufficient-tender HTTP400 console entry per viewport is classified separately.
Each viewport records exactly one opening, one successful sale, one refund and one close effect.
Reload recovers the sale using the original key without a second sale POST.
Synthetic exponent-3 amounts: total **27.500**, received **30.000**, change **2.500**; refund **10.000**; expected **27.500**, counted **27.000**, difference **-0.500**.
These synthetic NIO values do not choose real business currency or represent real transactions.

The integrated browser also exercised desktop/mobile keyboard interactions and captured private MP4 recordings.
A separate late-refund readback verifies a new paying shift leaves the old close immutable.
Integrated v2 recordings precede restoration of the `cash_payment_required` rejection code and confirmed-cart reset.
The separate final-bound Playwright recordings match the complete final product source.
Six before/after recordings have nonzero bytes, SHA256, positive duration and video streams verified with installed ffprobe.
Live browser states and final screenshots were directly inspected. Full video replay and human visual acceptance are NOT RUN.
The final mobile screenshot shows the confirmed close and empty paying-till page without horizontal overflow.

Owned preview tab closed. Owned loopback server stopped with Ctrl-C; expected process exit 1.
Owned ports **61230**, **65040** and final-candidate **49827** reject connections after cleanup.
Automatic drivers close their own Chrome contexts and servers in `finally`.
No unrelated processes were terminated. See [cleanup.json](cleanup.json).

## Frozen eleven-check accounting

| Check | Worker-local evidence |
|---|---|
| 1 | D031–034 and existing POST scopes/semantics preserved. No credit, card or mixed tender. |
| 2 | Authoritative reads and strict recorded money; exponent 0–6 and 9e12 boundary tests. |
| 3 | Own-till isolation and eligible paying-custodian query; 103-till stable paging and adversarial filters. SQL not run. |
| 4 | All four durable intents and same-key/body uncertainty tested; actual sale reload recovery recorded. |
| 5 | Definitive versus uncertain errors, storage/cleanup failure and editable rejections tested. |
| 6 | 401 renewal, actor/version/scope isolation and delayed CSRF/header/body epoch tests across all four actions. |
| 7 | Current Owner/Manager refund, original quantities/prices/reason, current paying till and immutable prior close. |
| 8 | Confirmed total/received/change/expected/count/difference displayed in actual desktop/mobile browser. |
| 9 | Legacy unpaid recovery, paid receipt compatibility, supply and stock-exception/review regressions pass. |
| 10 | Focused tests, six final negative controls, genuine before/after recordings and browser interaction checks. |
| 11 | Mocks/offline evidence explicitly separate from future real browser/API/SQL and independent reconciliation. |

These satisfy the authorized local implementation scope. They do not constitute primary or production acceptance.

## Remaining gates and one next action

| Item | Cause and attempted correction | Owner / completion check |
|---|---|---|
| Real persisted cash behavior | SQL and real API/SQL execution excluded. Prepared lifecycle test compiles; offline query translation and mocked browser pass. | Primary in a later authorized campaign: run lifecycle and real browser/API/SQL journey, then independently reconcile rows. |
| Independent review and integration | A worker cannot accept its own candidate. RAW/LF bindings, tests and private browser readbacks are frozen. | Primary verifies bindings/diff, then fresh Astra/xhigh reviews before serial integration. |
| Full historical browser suite | Most old fresh-sale browser cases target the retired fresh unpaid route. New cash driver covers fresh cash; focused original unpaid recovery and supply pass. | Primary may migrate remaining fixtures if broader historical browser coverage is required. No full-suite claim. |

There is no missing source, installation requirement, exposed business decision or unresolved local implementation blocker.
SQL, Docker, real data/payments, CI, independent Astra review and canonical integration are **NOT RUN**.
No production-readiness claim is made.

**Next action:** primary verifies `python docs/cash-register-20261107/ui-worker/freeze.py --verify`, reviews the actual 13-path candidate, and sends it to fresh Astra/xhigh.

Lesson applied: recover a persisted business rejection with its original scope/key before releasing intent.
The reproduced insufficient-tender and `cash_payment_required` paths now pass without creating a replacement operation.
Historical implementation helper scripts in this directory are evidence only; they are not needed to apply the candidate.

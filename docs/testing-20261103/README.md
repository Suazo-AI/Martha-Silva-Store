# Martha Silva / SAVIA validation — 2026-11-03

**Verdict: not production ready.** The tested local candidate has 590 passing .NET cases, including 67 real SQL cases. Browser testing found one reproducible staff checkout defect. Several legacy UI suites still fail, and two release tests remain unexecuted.

## Exact candidate and independent checks

Base Tony commit: `9befe15ece1cfb34b7376a13d1c5d8dac4a837fe`, plus existing working changes in staff UI/security and tests. This is **not** a green verdict for that Git commit or a production deployment. The validation commit preserves those unrelated changes without staging them.

Host: SUAZO-PC / Windows. Worker: explicitly selected GPT-6.1 Sol, high. SDK 10.0.402; SQL Server Standard Developer 17.0.1000.7; real installed Chrome through Playwright. Root independently parsed all three TRX files, deduplicated by testId, checked all 2377 source hashes against current files, and read the SQL inventory comparison. Evidence includes machine assertions and database readback, beyond either agent's opinion.

Backend: 590 PASS, 0 FAIL, 2 NOT RUN across 592 distinct case IDs. Browser: 31 PASS, 1 FAIL across 32 scenarios. HTTP guards: 4 PASS. These counts use different test units and must not be added into a completion percentage.

## Results by layer

| Layer | Result | What it establishes |
| --- | --- | --- |
| Backend / offline | PASS: 523 / 523 | Unit tests and in-process HTTP; one offline release-script case passed after providing its owned evidence directory. |
| Backend / real SQL | PASS: 67 / 67 | 21 migrated StoreDbContext cases; 46 internal EnsureCreated cases. Transactions, concurrency, stock, authentication, revocation and idempotency. |
| Internal release / recovery | NOT RUN: 2 cases | Internal migration/backup/restore and controlled owned-container restart require their separate isolated environment. |
| Staff frontend / Node | PASS: 42 / 42 | Authentication, session handling, pagination, DOM, branch compatibility and commerce. |
| Demo frontend / Node | PASS: 29 / 29 | Client, model and UI contract tests. |
| Harness client / Node | PASS: 37 / 37 | API client and operation recovery contracts. |
| Public local adapter | PASS: 23 / 23 | Browser-local commerce simulator; no external provider. |
| Public integration adapters | PASS: 19 / 19 | Local/synthetic boundary, payload and mode isolation. |
| Catalog / migration | PASS: 9 / 9 + 9 / 9 | Catalog expansion and current media/catalog assertions. |
| Public DOM simulations | PASS: 29 / 29 + 17 / 17 + 11 / 11 | Runtime, localization and sharing. jsdom is not layout proof. |
| Live HTTP guards | PASS: 4 / 4 | Real loopback .NET process; invalid SQL target; fail-closed storage, authority and client-price guards. |
| Browser / synthetic scenarios | FAIL: 31 pass / 1 fail | Real Chrome. Stale saved receipt 404 leaves staff new-sale, recovery and retry controls locked. |
| Legacy desktop gallery | FAIL: 1 pass / 13 fail | Geometry fixture mismatch is evidenced by source and two passing real browser checks; 13 assertions remain unreconciled. |
| Legacy Green checks | FAIL: 4 pass / 2 fail | Old CSS hash and media-count expectations disagree with current output. Contract drift needs explicit reconciliation. |
| Legacy editorial checks | FAIL: 4 pass / 4 fail | Old source paths/media expectations disagree with current output. Do not silently rewrite expected results. |
| Windows asset/catalog guards | BLOCKED: 3 + 2 errors | WinError1314 while creating symlinks. Asset audit:6 methods, 3 error observations. Catalog staging:10 methods, 2 errors. |
| Deployment contracts | PARTIAL: 13 pass / 1 skip | Symlink test explicitly skipped because local privilege is unavailable. No deployment was performed. |
| Build / structure | PASS: 47 pages ; 1082 dist files | Reproducible build, publication snapshot, asset links, ARIA references and JS syntax. |
| Progress / runner checks | PASS: 13 + 10 + 6 + 16 | Progress hooks, SQL result verifier, portable runner and legacy sync tests. Export verification also passed. |
| Browser to live API to SQL | NOT RUN: No combined session | Browser mocks and SQL TestServer tests are separate layers; no combined staff transaction was exercised. |
| External providers / release | NOT RUN: No production verdict | Payments, SISFAIN, production hosting/TLS, real-device acceptance, load and operational recovery remain unproved. |

All 47 public pages mounted without uncaught JavaScript errors. Staff views were checked at 1440px and 390px. Public checkout approval, decline, cancellation and order reconstruction worked with synthetic customer data. These are simulator behaviors; no payment was processed. Both desktop and mobile gallery control/alignment checks passed after correcting the mobile test assumption.

## Reproduced defect N5: an old receipt blocks all new sales

1. Open the staff UI as a valid cashier with a previous confirmed receipt reference in localStorage and no pending sale.
2. Return 404 for that saved receipt, while session, catalog and location responses remain valid.
3. Open sales. New-sale submission, recovery and retry are all disabled.

Cause: `dev/savia-staff-ui/app.mjs:510` catches a historical receipt lookup error and sets `pending ||= {}`. New sales require no pending object. Recovery/retry require a pending key, which this object lacks. The UI reports an unconfirmed sale even though none is pending.

Evidence: [synthetic screenshot](evidence/stale-receipt.png), [control states](evidence/stale-receipt.json), and the N5 case in [the repeatable browser harness](../../tests/browser-mock-validation.mjs).

No product correction was attempted in this validation batch. The required behavior decision is to distinguish an inaccessible historical receipt from an unknown pending sale, while preserving fail-closed session and pending-operation handling. The next implementation increment owns that correction; the new test already reproduces it.

## Blocker register and shortest path to closure

| Item | Evidence / attempted correction | Next action and owner | Completion check |
| --- | --- | --- | --- |
| N5 product defect | Reproduced in Chrome; no product edit. Current task validates the candidate. | Next implementation agent: separate receipt retrieval failure from actual pending-operation state. | N5 passes; lost-response, rejected-operation, 401/403, malformed receipt and reload cases remain green. |
| Legacy UI suites | Desktop 1/14, Green 4/6, editorial 4/8. Two real-browser gallery geometry cases pass; this does not clear every failed assertion. | Implementation agent: compare each assertion with current accepted source/media records; fix stale fixtures or demonstrated product defects individually. | All 19 failing assertions resolved with unchanged historical evidence and explicit reasons. |
| Windows symlink coverage | WinError1314 in asset audit and catalog staging; deployment suite skips one check. No host privileges changed. | Validation owner: run unchanged suites on a disposable Linux CI runner. A new workflow dispatch or environment change is outside this completed local batch. | Both suites complete without errors and symlink rejection is exercised. |
| Internal release recovery | Two PrivatePilotReleaseTests not run; their Linux paths/owned-container prerequisites are absent from this authorized SQL scope. | Validation owner: prepare a separate disposable compatible release environment; obtain runtime scope approval before migrations/backup/restore or container restart. | Both exact case IDs pass with restore readback and preserved existing pilot data. |
| Combined critical path | Browser used mocked staff API; SQL tests used real engine with TestServer/repositories. No combined browser-to-SQL test was attempted because the approved SQL batch was fixture-only. | Next implementation agent: prepare an isolated fixture host and scope the browser session before runtime execution. | Browser login → sale → persisted receipt → reload → recovery; exactly one sale and one stock decrement. |
| Real services / production | No provider credentials or approved production environment in this batch; no provider calls attempted. | Jason supplies release target and required providers; agent prepares sandbox contract and live acceptance checks. | Provider sandbox results, deployment/readiness, monitoring, recovery and owner acceptance attached to the same release candidate. |

The symlink errors are environment failures, not evidence that symlink rejection works. Legacy UI failures indicate a contract mismatch; they are not automatically product defects or automatically obsolete. No expectations were weakened.

## Test corrections and exclusions

- Staff Node tests initially could not resolve jsdom. Using the existing locked dependency copy through child-only NODE_PATH produced 42/42 PASS; no install or source change.
- The offline release-script test initially lacked SAVIA_PILOT_EVIDENCE. Giving it an owned output directory produced 1/1 PASS without SQL.
- The initial browser checkout test tried a deliberately hidden integration switch. The corrected case exercised the available checkout and passed. The mobile gallery test initially assumed zero scroll offset; clone-aware visible alignment passed. Original results remain private and hashed in the browser evidence.
- The aggregate runner stopped at Windows symlink failures. Later stages were run individually; the aggregate command remains failed.
- Real SQL: 21 cases used StoreDbContext migrations; 46 internal cases used EnsureCreated. This does **not** validate internal release migrations.
- SQL inventory: 52 before, 52 after; every existing name preserved; zero new remaining databases; no manual cleanup. Database names, logs and authorization receipts are excluded from the public repository.
- No production deployment, provider call, service restart, Docker start, certificate change or existing pilot database mutation was performed. The owned HTTP API stopped after testing.
- No exhaustive API/branch coverage, production latency, accessibility audit, Safari/iPhone hardware acceptance or security certification is claimed. The 58 route declarations in [the inventory](endpoint-inventory.json) are source inventory, not 58 executed endpoint tests.

## Highest-leverage next increment

**Finish and prove the cashier sale path.** Fix N5, then exercise the real staff browser against an isolated API and disposable SQL database. Prove login, one sale, server pricing, stock decrement, receipt reload and response-loss recovery. Keep the same idempotency key and verify one persisted sale and one stock movement. Preserve actual pending-sale locks and revoked-session behavior.

This closes the known checkout defect and the gap between the separately passing browser and SQL layers. Release acceptance still requires internal migration/recovery tests, reconciled legacy checks and the declared production integrations. Do not add screens or agent infrastructure before this path works.

## Repeatable local toolkit

From the repository root, use installed Playwright and a new private output directory:

```powershell
node tests/browser-mock-validation.mjs <installed-playwright-directory> <private-output-directory>
# Focus the reproduced defect without repeating passing scenarios:
$env:MARTHA_BROWSER_TEST_MATCH='Stale confirmed receipt'
node tests/browser-mock-validation.mjs <installed-playwright-directory> <new-private-output-directory>
Remove-Item Env:MARTHA_BROWSER_TEST_MATCH
# Real HTTP guards with intentionally unavailable SQL:
node tests/run-http-guards.mjs <dotnet-executable> <built-api-dll> <installed-playwright-directory> <private-output-directory>
```

The browser harness serves current files on an owned loopback port, blocks external origins, uses synthetic records, records outcomes and stops its server/browser. The HTTP wrapper starts and stops only its owned API. Both return nonzero on failure. They do not authorize a future SQL run. [SQL technical scope](SQL-TEST-SCOPE.md) documents this completed isolated run.

Long evidence: [results](evidence/results.json), [590 backend outcomes and 2 not run](evidence/dotnet-cases.json), [32 browser outcomes and correction history](evidence/browser-cases.json), [source hashes](evidence/source-hashes.json), [artifact hashes](evidence/artifact-hashes.json). Private raw evidence is retained under `C:/Users/Jason/MARTHA-SILVA/test-runs/20261103-results` and the sibling browser/HTTP run directories.

Lesson applied: passing layers independently did not prevent a real browser dead end. Preserve the failed N5 regression and require the combined cashier path before accepting the next increment. This report does not alter prior operational acceptance percentages.

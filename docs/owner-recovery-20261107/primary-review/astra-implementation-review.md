# Owner recovery implementation review

**REVISE.** One confirmed test-evidence defect prevents accepting F8's controlled-concurrency preparation. No confirmed recovery-product security defect was found in this bounded source review. This is advisory to the primary, not runtime acceptance or production READY.

Task: `savia-owner-recovery-source-85d5872-astra-20261108-01`. Mode: VALIDATE, source only. Bottleneck: reliable recovery evidence before any authorized runtime.

## Identity and frozen inputs

Host: `SUAZO-PC`. Harness/provider: T3 Code / Codex. Model: `gpt-6-astra`. Requested and runtime-exposed reasoning: `xhigh`; independently measured internal effort is unavailable. Usage, token accounting and provider cost are unknown. No additional provider requests or children.

Managed checkout: `C:/Users/Jason/.t3/worktrees/github/t3-2887214b`, branch `t3/owner-recovery-source-review`.

Verified HEAD: `85d5872ecb379e42e8ed59de346bf60933207c53`.
Overlay base: `9554645846adffd961a8d889bbaa61760785fd19`.
CANDIDATE recorded parent: `39161ef8c5afcac1f7c9502cc5f38439608a8d70`.

The implementation is outside this checkout, under read-only input root `C:/Users/Jason/MARTHA-SILVA/test-runs/owner-recovery-primary-20261108/review-inputs`.

Verified `CANDIDATE.json` RAW SHA256: `699cd91ddec454f7207c4be3d0ae7d4ad07607e9c29416b96e20a6483bd77f3d`.
Verified specification `docs/owner-recovery-20261107/astra-design-review.md` LF SHA256: `5beee5493a2e3bb900c1b9d62968ace5b665b64f729a943150ab04c20e1c47ff`.

All ten overlay files match their declared byte lengths, RAW hashes and LF hashes. `source-hashes.json` repeats exactly those bindings. Each also matches its recorded final compile-input entry.

The following paths are relative to `backend/`. LF hashes:

| File | SHA256 |
| --- | --- |
| `src/Martha.Store.Api/Program.cs` | `74e043cebd6242d9f114fef2cf30f9cf944e5f99dc602b7fd3309b095de14fe4` |
| `src/Martha.Store.Api/Internal/Security/InternalOwnerConsole.cs` | `6c4471cd566bbe4620722e99c9f8a5efc41c71147c19891f4b45ccafc047bdd7` |
| `src/Martha.Store.Api/Internal/Security/InternalOwnerRecoveryConsole.cs` | `bbe457d5247a348c5c9a18026783f7c0f8876c2661127852033c1bf8c437ea69` |
| `src/Martha.Store.Api/Internal/Security/InternalOwnerRecoveryService.cs` | `d13a14717563c4f89dd2da881fe736fdde2f8bee2814a216581bbd3cd85d661c` |
| `tests/Martha.Store.Api.Tests/InternalOwnerRecoveryConsoleTests.cs` | `96a275b89a276653d4d99c1709d6062c32c34236a7438e4f02f920e5b1426cd8` |
| `tests/Martha.Store.Api.Tests/InternalOwnerRecoverySqlTests.cs` | `84d17f0a8e4949468c07e281a7da89cff5ca3073d68ac3fc5006ed6ec62e29c6` |
| `tests/Martha.Store.Api.Tests/InternalSecuritySqlTests.cs` | `ad2674aee310e5e7963e749c1db66c396c46572a4d1aeac05035a7c5aa62bb37` |
| `tests/Martha.Store.Api.Tests/InternalAcceptanceHttpSqlTests.cs` | `339266e8dfce6583b1c1ef0181ba42265b0753895d8e6920d8763305e0572b9e` |
| `tests/Martha.Store.Api.Tests/InternalOwnerRecoveryFixture.cs` | `d2528bec753b5483d28475bb468ba5c3766798212e5cd8fd2e1008aa8daa178f` |
| `tests/Martha.Store.Api.Tests/InternalOwnerRecoveryDatabaseLease.cs` | `c782d60e1ebd0700dbc9db8d061ad51020178048e806298e11c00d6a0ef5b8a0` |

Read-only `git ls-tree` verifies the four existing paths have identical blobs between base and HEAD: Program, OwnerConsole, SecuritySqlTests and AcceptanceHttpSqlTests. The other six are absent at HEAD. Baseline files were not mistaken for the overlay.

## Finding: P2, concurrency evidence can pass without contention

**Location:** overlay `backend/tests/Martha.Store.Api.Tests/InternalOwnerRecoverySqlTests.cs:95-120`, especially `started.Set()` at line 107 and `release.Set()` at line 118.

Actor: the test runner. Input: any of the four competing cases (`recovery`, `reset`, `login`, `demote`). Boundary: the fixture's claimed controlled SQL overlap. Affected evidence: F8's recovery/concurrent-security-operation guarantees.

The contender signals `started` before calling recovery or even constructing the ordinary operation's context. The parent immediately releases recovery after observing that signal. A valid schedule pauses the contender after line 107, lets recovery commit, then runs the entire contender. Every current winner/loser assertion can pass under that fully serial schedule. The barrier therefore does not establish that the second SQL operation contended with the held target lock.

The preservation comparison at line 123 also excludes initially active target-session `RevokedAt` through `InternalOwnerRecoveryFixture.cs:104`. Lines 124-126 do not independently assert revocation. F5 checks revocation separately, but that does not prove it for these concurrency cases.

**Minimum correction:** retain the existing four fixtures, but require bounded, observable contender admission at the SQL boundary while recovery still holds its lock. Release recovery only after that evidence. Add explicit final target-session revocation/version assertions. Preserve task joining and zero retry.

**Closure proof:** demonstrate that a contender deliberately delayed before SQL cannot satisfy the overlap condition; show each actual competing operation reaches the held boundary, completes once, and leaves no invalid target session. This proof requires later authorized execution. No source correction or execution was attempted because this reviewer owns only this report. Primary owns correction and acceptance.

## F1-F13 disposition

References below use overlay filenames unless identified as unchanged dependencies. “Consistent” means source assessment, not runtime PASS.

| Control | Disposition and evidence |
| --- | --- |
| F1 | Consistent. `Program.cs:7-20` dispatches before host construction. `InternalOwnerRecoveryConsole.cs:14-15,95` captures listed malformed variants and rejects anything except the sole exact argument. No recovery endpoint or startup/bootstrap fallback. |
| F2 | Consistent subject to Windows validation. Console lines 23-59,67-84,95-111 enforce environment, protected paths, SID, private terminal and journal acquisition. Service rechecks SQL identity. Actual ACL/file/identity behavior remains untested. |
| F3 | Consistent. Shared `InternalOwnerConsole.cs:163-202` bounds, masks, drains rejection and clears its mutable buffer. Tests cover 14/15/128/129, controls, whitespace-only, mismatch, overflow, backspace and Escape. Managed strings are not securely erased. |
| F4 | Consistent. Service lines 14-24,48-80,94-105 bind instance/catalog/GUID/ID, SQL SID, target/login/version, enabled Owner and different password. Malformed stored hashes refuse. SQL no-write fixtures are prepared only. |
| F5 | Consistent. Service lines 94-119 use one SERIALIZABLE transaction and the inspected connection, locked target recheck, allowed fields and target-only revocation. Rowversion remains enforced; no identity/session creation. |
| F6 | Prepared, not executed. HTTP matrix at `InternalAcceptanceHttpSqlTests.cs:592-664` covers old credentials/cookies, new Owner access, fresh-CSRF mutation, anonymous/role/forged hints and stale updates. Unchanged cookie/session/CSRF dependencies retain their guards. |
| F7 | Consistent. Unchanged `InternalSecurityService.cs:120-133` permits authorized Owner self-reset. New SQL/HTTP cases cover self/second Owner, disabled target preservation and stale PUT refusal. |
| F8 | **REVISE:** finding above. Separate deadlock fixture at SQL tests lines 252-269 does not repair the four competing-operation barriers. No concurrency runtime claim. |
| F9 | Consistent with limits. SQL tests lines 29-69 inject after revocation/SaveChanges and after acknowledged commit. Service lines 118-152 retain UNKNOWN after commit uncertainty or failed cleanup/receipt, without replay. Fresh version and session assertions prepare reconciliation; real acknowledgement loss remains untested. |
| F10 | Consistent with limits. Console journal lines 175-182 flush INTENT; service cleanup precedes terminal receipt. Console lines 120-139 retain an acknowledged result across later handle/output failure. Recorded tests cover that correction and a child crash after INTENT, not a crash during SQL commit. |
| F11 | Consistent. Existing enabled Owner only; unchanged bootstrap stops on any Staff row. Last-Owner protection is retained. SQL tests lines 213-249 distinguish one-owner server safety from two-owner operational readiness. Custodian independence remains external evidence. |
| F12 | Consistent preparation. `InternalOwnerRecoveryFixture.cs:79-118` uses typed independent SQL rows and the explicit 23-table inventory, including audit/unrelated rows and target immutable fields. SQL tests lines 192-210 contain six preservation canaries. Not executed. |
| F13 | Prepared with operational limits. Four migration IDs match HEAD. Database lease requires exact nonce/SID/GUID ownership before deletion and retains unresolved CREATE outcomes. Restore checks owned identity; backup cleanup remains an explicitly recorded SQL-host custodian obligation. No live cleanup or restore accepted. |

## Recorded evidence and limits

All nine declared evidence RAW hashes match. Original TRX metadata, result rows and unique IDs agree:

- `1-red.trx`: 84 PASS / 1 FAIL, 85 unique IDs. Failure: `F10_known_commit_receipt_is_not_overridden_by_cleanup_failure`.
- `2-green.trx`: 89/89, zero failures/skips, 89 unique IDs.
- `4-green.trx`: 38/38, zero failures/skips, 38 unique IDs.

These are separate recorded executions, not a combined total or fresh execution. Recorded compile exits and sandbox/cleanup receipts were inspected as inert metadata; the container's current absence was not queried.

`inputs-4-green.json` contains 130 unique entries. Ten bind the overlay. Of 120 remaining entries, 110 match HEAD bytes or its LF/CRLF representations. Ten differ: API project file, InternalUiHosting, InternalCashEndpoints, InternalCashSqlTests, InternalSupplyUiTests, and staff UI app/client/commerce.test/index/login. Consequently, recorded builds do not qualify the overlay integrated with current HEAD. Their source list also predates new cash files. Primary must preserve this integration-validation gap.

NOT RUN: builds, tests, target parsers/functions, SQL/API/browser, Docker, network, installs, recovery/accounts, migrations, backup/restore, security settings, publication or Git mutations. SQL5 remains D: REVIEW FIRST, DO NOT EXECUTE.

No unresolved input-access denial. The security-audit skill was absent from the managed/global paths and loaded from `C:/Users/Jason/MARTHA-SILVA/github/.agents/skills/security-audit/SKILL.md`. It and juez-de-rama were applied in GUIDANCE mode. Evidence text decoding/output failures were resolved with CP1252 input handling and UTF-8 stdout; hashes used original bytes throughout. Trusted awareness checks succeeded before inspection and report creation. Initial/pre-write Git status was clean.

**Next action:** primary corrects the F8 fixture and freezes the revised source/evidence binding before any runtime request. Lesson: a task-start signal proves scheduling, not SQL contention. Apply that distinction in the existing fixture; add no audit infrastructure.

Only retained change: this report. RAW/LF report hashes and final Git status are returned separately.

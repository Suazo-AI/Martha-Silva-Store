# ACCEPT WITH LIMITS — offline fingerprint correction

Task: `savia-fingerprint-judge-857bea1-20261106`. Mode: `VALIDATE`.
Reviewed SHA: `857bea105fe1dfa045114a5569ba5cb4c31b3391`.
Primary retains acceptance. Production remains **NO-GO**.

No blocking defect found in the three-file correction. It strengthens table coverage without replacing the SQL oracle or weakening existing rejection assertions.
This verdict permits no runtime action and does not resolve the six historical SQL failures.

## Identity and scope

Host: `SUAZO-PC`. Harness: T3 Code / Codex. Model: `gpt-6-astra`.
Requested/effective reasoning: `xhigh` / `xhigh`, corroborated by runtime context and current agent-awareness metadata.
Checkout: `C:/Users/Jason/.t3/worktrees/github/t3-604702b6`; branch: `t3/review-fingerprint-guard`.
Token usage and monetary cost: unknown. No external/paid tool calls, installations or delegates.

Reviewed actual source, committed blobs and named evidence. Only this report was created.
The independently owned Python verifier changes are outside this review.

## Findings against source

- **PASS — exact membership.** `backend/tests/Martha.Store.Api.Tests/InternalAcceptanceFingerprint.cs:8-20` pins 20 names using ordinal sequence equality. Missing, extra, duplicated or substituted names cannot pass merely by preserving the count. The committed relational snapshot independently contains the same 20 unique table names.
- **PASS — exact business subset.** The same file, lines 22-28, validates the full input, copies it, removes only `Staff`, `Sessions`, `BranchAssignmentAudit`, and checks the remaining exact sequence. All 17 business tables retain their captured values, including `StockExceptionReviews`. The input is not mutated.
- **PASS — actual SQL guard, not an alternate oracle.** `InternalAcceptanceHttpSqlTests.cs:619-641` enumerates `sys.tables` through ADO.NET, calls the shared guard, then reads `SELECT *` for every accepted table. Column names, every field, ordinal row sorting, row counts and SHA256 remain unchanged. EF metadata supplies offline test inputs, never the runtime expected table set.
- **PASS — unauthorized-write checks preserved.** The HTTP fixture equals base `0f786c3f2a747115b5cae90957b17a959f357298` plus exactly three replacements: comment, business-helper delegation and table-guard delegation. N1/N3/N4/N5/N8/N9 comparisons remain. See `InternalAcceptanceHttpSqlTests.cs:86,126,182,322,391,406,433`. N5 separately checks permitted authentication/assignment effects at lines 304-308. N4's existing durable-conflict `Operations` exception at lines 214-222 is unchanged; the correction adds no exclusion.
- **PASS — focused adversarial controls.** `InternalAcceptanceFingerprintTests.cs:23-78` checks actual relational metadata, the independently listed 17-table subset, missing/extra/same-count substitutions, changed review fingerprints and each intended exclusion. Duplicate rejection follows directly from sequence equality; it has no dedicated test. These are table-membership checks, not comprehensive schema/type/constraint validation.

Severity: no new blocking finding. Required source fix: none within this frozen correction.
Full-row serialization is preserved; no new live SQL or serializer collision-resistance claim is made.

## Evidence independently checked

All 11 selected LF source hashes match both this checkout and the reviewed Git blobs. Bindings are selected files, not the entire compilation closure.
The three corrected source hashes are:

| File under `backend/tests/Martha.Store.Api.Tests/` | SHA256 after CRLF → LF |
| --- | --- |
| `InternalAcceptanceHttpSqlTests.cs` | `373a5edbefe70c97b17d9f610ddda835688812637529357f98c584d55e3da0ca` |
| `InternalAcceptanceFingerprint.cs` | `d677084da128d7e96695cc9c7fcb72900a92189531a49a2da74347dc577712ce` |
| `InternalAcceptanceFingerprintTests.cs` | `cc60d1076db1e9973f749061bf06ec963f62c6afa7176aa9eb5090e249ec0827` |

Parsed the retained private TRX files, recomputed their SHA256 and compared actual rows with sanitized evidence:

- Correction red: **7 Failed / 2 Passed**. Actual assertions show `19 / 20`, `16 / 17`, and missing-table acceptance where an exception was required.
- Correction green: **9 Passed**, no failures/skips. The red run exercises an extracted historical count-only seam; it is not a replay of the historical SQL failures.
- Correction's separate broader run: **552 Passed / 58 NotExecuted**, 610 rows. This is distinct from partition A.
- Local partition-preparation fingerprint run: **9 Passed**, matching its separate recorded TRX hash.

Sources: `docs/stock-exception-20261106/runtime-campaign/correction/test-results.sanitized.json:3-77`; `docs/local-validation-20261106/fingerprint-results.json:1-16`.
The retained red binding manifest matches the recorded seam hashes; the historical red helper source bytes are not included in the committed three-file candidate.

Private discovery has **631 occurrences / 274 methods**, matching `PARTITIONS.json:8-9` and every recorded method multiplicity.
All 14 backend filters select exactly their assigned inventory methods. A195 methods/552 occurrences, C77 and E2 are disjoint and exhaustive for that frozen inventory.
This proves inventory/filter agreement, not future discovery or executed SQL coverage.

Partition A readback confirms **551 Passed / 1 Failed**, 552 unique test IDs and execution IDs, exact method multiplicities, and no C/E methods.
The failed method is the offline release-script test. Its actual `DirectoryNotFoundException` and `PrivatePilotReleaseTests.cs:98-104` support an environment-directory failure.
The targeted TRX contains only that method, **1 Passed**. Its three generated SQL scripts match recorded hashes and are nonempty.
The reused assembly matches `f34ab91883ab924c751b04b2820f38addbf9597f9af328dc537bd0d2190da1ce`; all 105 tracked backend files match the retest worker's LF bytes.

Therefore accept **551 original passes + one replacement pass**, not a new single `552/552` TRX. Truncated theory labels still limit independent argument identity.
See `PRIMARY-ACCEPTANCE.md:26-45` and `PRIMARY-A-RESULT.json:65-76` in this directory.
Five artifact-manifest hashes match current Windows raw bytes; those CRLF hashes are not Git LF blob hashes. Source LF verification above is separate.

## Checks, limits and remaining blockers

Executed read-only Git inspection, inline Python hash/XML/JSON/filter comparisons, and `git diff --check` (exit 0).
No .NET test was rerun. Existing raw evidence was sufficient. No SQL, Docker, API/service startup, cloud dispatch, certificates, elevation, credentials, Git mutation, merge or deployment occurred.

**Historical SQL cause remains a hypothesis.** The offline stale-count defect is demonstrated. Missing historical assertion diagnostics prevent attributing all six failures to it.
The six current SQL regressions, C77, combined journey D, E2 and current full runtime remain **NOT RUN**. Historical B is not a fresh browser result.

**Runtime blocker — owner: primary/Jason.** Existing evidence records strict TLS rejection and an unavailable Docker engine; Docker launch was previously policy-rejected (`PRIMARY-ACCEPTANCE.md:65-87`). This judge neither reproduced nor corrected host prerequisites because the task forbids those actions.
Next action: primary serially imports this report, then uses the separately authorized runtime route after Jason resolves its prerequisite. Do not bypass trust controls or the prior denial.
Completion requires exact-candidate SQL results, six actual passes with zero skips, retained assertion diagnostics, database preservation/cleanup proof, and separate D/E evidence.

Lesson applied: verify table identities and negative controls, then bind raw outcomes to source bytes. Passing an offline guard does not establish SQL behavior or operational acceptance.

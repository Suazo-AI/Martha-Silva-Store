# Fingerprint correction: returned candidate

Task: `savia-fingerprint-correction-0f786c3-20261106-01`.
Primary integration and independent acceptance remain pending.

Host: `SUAZO-PC`. Provider/model: `codex / gpt-6.1-sol`.
Requested and effective reasoning: `high`, per runtime context and agent-awareness metadata.
Assigned tool-managed checkout: `C:/Users/Jason/.t3/worktrees/github/t3-c0d851dc`.
Branch: `t3/fix-stale-fingerprint-guards`.
Base: `0f786c3f2a747115b5cae90957b17a959f357298`.
No commit was created. Tokens/cost are not exposed.

## Verified offline

The actual fixture now calls a test-only shared coverage guard.
Its explicit oracle requires exactly 20 named `savia_internal` tables.
The business projection keeps exactly 17 tables, including `StockExceptionReviews`.
It excludes only `Staff`, `Sessions`, and `BranchAssignmentAudit`.
Missing, unexpected, and same-count substituted tables fail.

The regression uses EF SQL Server relational metadata without opening a connection.
Synthetic dictionary values demonstrate that a changed review-table fingerprint fails the existing business comparison pattern.
They do not simulate successful database persistence or validate SQL row serialization.

Before correction, the extracted helper preserved the original `19` and `16` assertions.
The same nine tests then produced **7 failures / 2 passes**, exit `1`.
The positive model guard failed with `Expected: 19 / Actual: 20`.
The business projection failed with `Expected: 16 / Actual: 17`.
The missing-table negative control also exposed the count-only guard accepting an incomplete schema.
After correction, **9/9 passed**, exit `0`.

The backend regression ran once after focused green: **552 passed / 58 skipped / 0 failed**, exit `0`.
The `Category!=SqlServer` filter additionally excluded **21 cases**, verified by discovery with the inverse filter.
This is not full SQL acceptance.

SDK `10.0.402` was verified at the existing portable path.
The existing package cache and lockfiles were checked before a successful locked restore.
Release compilation completed during focused testing, with no reported warnings or errors.

## Scope and preservation

Changed: `backend/tests/Martha.Store.Api.Tests/InternalAcceptanceHttpSqlTests.cs`.
Added: `backend/tests/Martha.Store.Api.Tests/InternalAcceptanceFingerprint.cs`.
Added: `backend/tests/Martha.Store.Api.Tests/InternalAcceptanceFingerprintTests.cs`.
Added evidence is confined to this directory.

A complete normalized-file comparison against the base verified only three intended source replacements.
The original six unauthorized-write assertion bodies remain intact.
The ADO.NET enumeration, full-row hashing loop, formatting, and comparison sites remain intact.
No application code, migrations, workflows, lockfiles, ledger, status, instructions, or decisions changed.

`git diff --check` passed, exit `0`.
[Source bindings](source-bindings.json) records SHA256 after CRLF-to-LF normalization for 11 selected files and the initial red seam.
These selected bindings are not a manifest of the entire compilation dependency closure.
[Sanitized results](test-results.sanitized.json) contains parsed case outcomes, red assertion messages, and raw TRX hashes.
Raw TRX files, generated scripts, and build caches stay outside public evidence.
No caches were removed.

## Commands and limits

[RESULT.json](RESULT.json) preserves exact test/restore commands, exits, identity, environment preparation, paths, and blocker ownership.
Raw results directory: `$env:TEMP/savia-fingerprint-correction-20261106`.
Before the broader run, SQL connection and authorization variables were cleared only in the test-launch process.
`SAVIA_PILOT_EVIDENCE` pointed to its `offline-scripts` subdirectory for the existing offline migration-script test.
Generated SQL was not executed.
Existing HTTP regressions use in-process TestServer; no listening API or browser journey was started.

NOT RUN: SQL, Docker, workflow dispatch/rerun, browser journey, certificates, staging, commit, push, merge, deploy, frontend/Chrome suites.

## Historical uncertainty and next action

This proves an offline guard defect and its correction.
It does not prove why each of the six historical SQL cases failed in run `42295568744`, attempt `1`.
The primary supplied the sanitized historical artifact provenance; this worker did not fetch it again.
Historical raw assertion messages were deleted by the existing cleanup.

The runtime blocker remains owned by the primary orchestrator and Jason for authorization.
The attempted local correction passed the checks above.
Primary should independently review and integrate this candidate, then obtain explicit authority for an exact-candidate SQL rerun.
Closure requires fresh SQL results, retained sanitized assertion evidence, and cleanup proof.

Lesson applied: an explicit table-membership guard catches omissions and substitutions that a count-only guard cannot detect.
# Primary acceptance of the offline correction

Primary inspected the three-file diff and its nine focused tests.
The explicit table oracle requires all 20 names, including `StockExceptionReviews`.
Only `Staff`, `Sessions` and `BranchAssignmentAudit` are excluded from the 17-table business projection.
The SQL fixture retains ADO.NET enumeration, complete row hashes and the six unauthorized-write checks.
Schema substitutions and review-hash changes remain rejected by the focused negative cases.

The unchanged candidate is also covered by the accepted local offline partition A.
Evidence: [local primary acceptance](../../../local-validation-20261106/PRIMARY-ACCEPTANCE.md).
The offline correction is accepted. The cause and resolution of the six historical SQL failures remain unconfirmed until C1 executes.
No SQL runtime, production acceptance, merge or deployment is implied.

# N8 successful-write oracle recheck

**ACCEPT WITH LIMITS.** The scoped Astra **P2 is resolved at source/offline-oracle level**. No unresolved material finding in this correction. This does not close N8 SQL or authorize production. Primary owns integration and acceptance.

Task: `savia-n8-oracle-recheck-79d18c4-20261107`. Mode: VALIDATE.
Frozen HEAD: `79d18c407f0de7650a83016093de15efcad10b39`.
Compared base: `6708709b4bda8a2638acb995d9ae1b91fc60d257`.

Host: SUAZO-PC; T3 Code / Codex. Requested and harness-exposed model/effort: `gpt-6-astra/xhigh`. Internal reasoning, token usage and cost telemetry are unavailable.
Requested isolation: new tool-managed worktree. Observed: registered separate checkout `C:/Users/Jason/.t3/worktrees/github/t3-2d71fae0`, branch `t3/savia-n8-oracle-review`; managed provenance comes from the assigned runtime, not an independently inspected creation receipt. No canonical writes.
Agent-awareness ran at entry and before mutation. Only this assigned task was reported in this checkout; other harness activity remains incompletely observable. Initial worktree/index were clean. No delegates.

## P2 disposition and frozen checks

Paths below are relative to `backend/tests/Martha.Store.Api.Tests/`.

1. **Exact permitted effects; existing rows retained.** `InternalAcceptanceHttpSqlTests.cs:408–438` captures the complete pre-write state and a target-only stock projection. Lines 425–427 preserve sale, actor, branch/location, line, price and movement predicates. Lines 429–433 require count increments and identify exactly one line, operation and movement through `Scalar`/`Assert.Single` (:700). `InternalAcceptanceWriteProjection.cs:18–36` excludes only four identified inserts, reverses exactly one OnHand decrement and masks only the target balance's UpdatedAt. Its composite ItemId/LocationId selector matches the balance primary key (`Internal/Commerce/InternalCommerceModel.cs:14`). Every other column remains compared. Reserved and Available (`OnHand-Reserved`) are directly asserted at :437–438.

2. **Adversarial preservation.** `InternalAcceptanceWriteProjectionTests.cs:45–118` has 24 pure cases: intended sale; changed existing Sales/SaleLines/StockMovements/Operations/Items/other balance; wrong target OnHand/Reserved; deleted existing rows; unidentified inserts; Directory preservation; empty inserted identity. Five controls explicitly demonstrate the former exclusion accepting corruption before the new projection rejects it (:60–66). Directory uses only the returned item and unique operation IDs (`InternalAcceptanceHttpSqlTests.cs:465–474`); existing Items/Operations remain hashed. SQL-reader wiring was inspected directly; these synthetic cases do not execute SQL serialization.

3. **Original controls intact.** The base diff preserves same-account logout/login, persisted session replacement/revocation/version/expiry and unchanged antiforgery cookie (:393–405, :443–455). Original bodies/keys survive rejection, fresh-token submission and replay (:406–441, :456–474). Rejection and replay still call unprojected `Fingerprint()` (:413, :441, :460, :474). Receipt/actor/location/line/movement predicates were not removed.

4. **Independent oracle and scope preserved.** `InternalAcceptanceHttpSqlTests.cs:703–740` still opens plain `SqlConnection`, enumerates `sys.tables`, asserts the explicit inventory, reads `SELECT *`, and hashes sorted complete rows. It never derives its inventory from EF or API output. `InternalAcceptanceFingerprint.cs:8–20` retains all 20 names. N8 does not use the 17-table Business subset. Both fingerprint guard files are unchanged from base. The complete diff contains 16 paths: three test C# files and 13 documentation/evidence paths. Product source is unchanged. Cash evidence is outside this judgment.

5. **Source binding and attribution verified.** All 12 RESULT LF hashes match HEAD blobs, this checkout and canonical source. All 12 canonical RAW hashes also match. Seven checkout RAW hashes differ solely through CRLF conversion. Original `CANDIDATE.json` is byte-identical between base and HEAD; blob SHA256: `e1c604f0ec0ea0a3c5d8e70f8e740ca4b6c846bf054218c23a899ebc22c78554`. Original REVISE remains immutable; canonical RAW/HEAD/worktree-LF hash: `f395d69510599cb123b8d94009503f4755a079a0145a41740119b442faaafcf3`.

This is a bounded correction to the same-account sale and Directory creation. The older cross-user positive control (:492–504) remains unchanged, including its whole-table exclusions. This verdict does not certify that separate oracle.

## Recorded tests independently inspected

The primary's fresh correction run is **33/33 PASS**, zero failed/skipped: 24 projection cases and nine fingerprint cases. I read the original private TRX, process receipt and build/test log; hashes and all result counters match [RESULT.json](RESULT.json). Recorded process exit: **0**; elapsed: **262.2727349 s**. These tests were not rerun by this judge.

Exact recorded command:

```powershell
& 'C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe' test backend/tests/Martha.Store.Api.Tests/Martha.Store.Api.Tests.csproj -c Release --no-restore --filter 'FullyQualifiedName~InternalAcceptanceWriteProjectionTests|FullyQualifiedName~InternalAcceptanceFingerprintTests' --logger 'trx;LogFileName=n8-projection.trx' --results-directory private-exports/session-csrf-n8-primary-20261107
```

Private evidence root: `C:/Users/Jason/MARTHA-SILVA/github/private-exports/session-csrf-n8-primary-20261107/`.
TRX RAW SHA256: `3bf6b7e781fbeadc4ccf27d68a0fb7130dd7083f89357dfcef319be61990d6c0`.
`focused.log` RAW SHA256: `56d9b99f9561529f86718b62bb28a63064034573bfe13bbde2b4e4a53393d5f0`.

Historical `python tests/check.py`: recorded exit **0**, **405.609 s**, attributed only to base `6708709`. I verified its original log hash and final PASS: `15f91e6467a787df914fdeacb0148e00eb22e17f47357fc9ddece4862261aa1b`. It is not evidence of a full check on corrected HEAD.

## Executed here, limits and handoff

Executed read-only Git/source inspection, agent-awareness, and two `python -` stdlib evidence audits. Audit 1 exited **1** at its original-report RAW equality assertion. Cause: this checkout has CRLF; the canonical report is LF. Audit 2 separated canonical RAW, Git blob and normalized checkout hashes, completed the remaining TRX/log/scope checks, and exited **0**. No source change was needed. An exploratory `rg` lookup of absent `InternalEntities.cs` returned OS error 2; exact class search located `Internal/Commerce/InternalCommerceModels.cs` and resolved the lookup.

Fresh test/build invocations: **0**. No additional probe was necessary for this small projection after direct inspection and original evidence validation.
NOT RUN: N8 SQL, Docker, browser, network, CI, package installation, full web/backend suites, production, staging, commit or push.

Remaining gate: N8 SQL. Cause: runtime is outside this assignment. Attempt: source and recorded offline checks verified; no connection attempted. Owner: primary/Jason. Next: primary imports this report serially, completes runner/cash prerequisites and obtains the exact runtime scope. Completion check: authorized source-bound N8 readbacks proving intended inserts, unchanged unrelated rows, stale-token rejection and replay equality. No SQL/production waiver.

Lesson applied: exclude identified inserts, then compare the remainder; retain full rejection/replay fingerprints.
Only owned write: this report. RAW/LF report hashes accompany the return.

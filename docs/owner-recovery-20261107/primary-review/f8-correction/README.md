# Owner recovery: F8 contention correction

**Prepared source correction. Not executed or accepted.** Primary verified Astra's P2 against the frozen fixture.

The old `started.Set()` preceded the competing SQL operation. Recovery could commit before that operation reached SQL.
That schedule satisfied the assertions without testing SQL contention. The original input and recorded runs remain unchanged.

## Bounded correction

Only `InternalOwnerRecoverySqlTests.cs` changes in the ten-file overlay. Recovery product code is unchanged.
The revised inputs are bound by [CANDIDATE.json](CANDIDATE.json); [changes.patch](changes.patch) records the exact test delta.

- Recovery pauses before commit, retaining its uncommitted Staff write lock. Its earlier update lock alone admits shared readers.
- The observer identifies the recovery connection and the actual contender connection within the uniquely owned fixture database.
- Each of the four existing races first holds the contender before SQL. That delayed task must not qualify as lock contention.
- Recovery is released only after SQL reports the actual contender waiting on that recovery session's Staff statement.
- The observer uses bounded, read-only DMV queries. Missing visibility fails the check; the fixture grants no permissions.
- Both tasks are joined, including assertion failure. No operation is retried.
- Final assertions bind the new version to the journal, preserve target-session identities, require revocation and reject prior principals.

These are source checks, not SQL results. The delayed-control rejection, four real blocked operations and final session assertions still require authorized execution.
The SQL principal must already have the DMV visibility required by SQL Server 2022. Do not change permissions to satisfy this fixture.

## Evidence and next action

Primary verified the original candidate hash and ten source bindings before copying exact sources into a separate correction directory.
The original nine evidence files remain historical. Their recorded 84/1, 89/89 and 38/38 executions do not exercise this correction.
An integrated build with current Cash files is also pending; earlier worker builds used different inputs.

The [initial Astra report](../astra-implementation-review.md) remains `REVISE`.
Next: one fresh Astra/xhigh source-only recheck of this delta, then integrated compilation and separately scoped runtime validation.
Owner recovery remains open. SQL5 remains **D: REVIEW FIRST, DO NOT EXECUTE**. No SQL, account, ACL, container or recovery action ran.

Lesson: a task-start signal proves scheduling. Require the database to expose the claimed contention before releasing the held transaction.

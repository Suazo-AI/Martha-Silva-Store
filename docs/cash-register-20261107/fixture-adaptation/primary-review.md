# Primary review of cash SQL fixtures

The primary verified and imported the eight source files from the worker.
The worker broad result was 624 Passed, 67 NotExecuted, zero Failed.
A fresh primary run reproduced those counts.

## Verification correction

The imported check-expression normalizer removed grouping and spaces inside SQL string literals.
Two injected changes were wrongly accepted: changed Boolean grouping and `sale` changed to `s ale`.
Two new real regression cases failed with exit 1 before correction.
The corrected bounded parser preserves quoted values and mixed Boolean grouping.
It accepts SQL Server formatting changes and rejects unsupported grammar.
Only the two new test-helper files changed after import. Product sources and migrations did not change.

Final fresh non-SQL run: **627 Passed, 67 NotExecuted, zero Failed**, exit 0, 23.640 seconds.
`python tests/check.py`: exit 0, 143.031 seconds.
The repository check does not execute the C# suite; the C# result is separate.
[Exact commands, private artifact hashes and current source bindings](PRIMARY-REVIEW.json).
The worker manifests remain historical and unchanged.

## Remaining checks

The 67 omitted cases require actual SQL. [Parallel local scope](../../sql-parallel-20261107/README.md) fixes two independent disposable instances.
SQL failures must retain sanitized assertion details before cleanup. No inferred cause closes a historical failure.
Astra/xhigh remains the sole independent judge. Runtime execution and offline passes are not final acceptance.
The custom local runner still has a Windows receipt-lock defect and is excluded from this execution route.
Next: execute the frozen 39-case and 28-case SQL partitions, then inspect actual results.
Production remains **NO-GO**.

The original worker `changes.patch` remains byte-exact in private storage and is excluded from publication.
Its whitespace-only context lines fail Git whitespace validation as a newly added document.
The import map records its hash and location; published source files preserve the actual changes in Git.

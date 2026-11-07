# Cash backend integrated; acceptance pending

Host: SUAZO-PC. Primary: T3 Code / Codex / gpt-6.1-sol/xhigh.
Parent: `754b67eedd70d4234db950f53262d652b83d616c`.
Worker: `gpt-6.1-sol/high`, managed worktree `t3-49ff92f2`, base `030b64f7cba87c6a0d710892deb9a8493ea8bbf4`.

Primary verified 16 RAW/LF source bindings and imported the cash backend, three generated migration artifacts and four public migration records.
Existing destinations matched the worker base. AGENTS.md, DECISIONS.md and the N8 HTTP test remained unchanged.
Exactly three additive tables: CashTills, CashEntries, CashCloses. The explicit fingerprint inventory is 23 total / 20 business tables.
Migration generation did not apply database changes. No real currency or operational payment facts are inferred.

## Fresh primary verification

| Check | Result | Exit |
|---|---|---|
| Cash, migration, fingerprint and N8 projection focused integration | 65/65 passed; zero omissions | 0 |
| Initial non-SQL regression run | 605 passed, 2 failed, 66 NotExecuted | 1 |
| Pinned EF regeneration of idempotent release script | Generated only; 9.469 s | 0 |
| Corrected non-SQL regression run, fresh build | 607 passed, zero failed, 66 NotExecuted; 56.938 s | 0 |
| `python tests/check.py` | Existing recovered-demo checks passed; 251.782 s | 0 |

The two reproduced integration failures were stale migration history and a stale generated release script.
Primary added the fourth explicit migration to the history expectation and regenerated the SQL artifact with EF CLI 10.0.13 through SDK 10.0.402.
The corrected fresh run proves those two failures resolved offline. SQL-attributed omissions are not passes.
Worker 41/41 migration evidence and 30 source guards remain historical and separately attributed.

Documentation checks: `python tests/test_progress.py` passed 23/23; `python tests/test_delivery_status.py` passed 24/24.
`python tools/delivery_status.py --check` validated 40 items; `python tools/export_progress.py --verify` preserved 15 evidence hashes.
All four commands exited 0. They verify documentation and publication controls, not SQL or cash behavior.

[Exact commands, source/log/TRX hashes, outcomes and blocker ownership](RESULT.json).
Raw evidence stays in ignored `private-exports/cash-register-20261107/primary-integration/`.
Generated files were never hand-edited; release-script trailing blank normalization follows MIGRATION-PLAN.

## Remaining work and continuity

1. Adapt existing SQL/N8/security fixtures to cash without weakening authorization, exact-row rollback or legacy-key recovery checks.
2. Extend independent release-schema expectations and discover a current test inventory. Historical A552/C77/E2 remain frozen evidence, not coverage of new cash tests.
3. Implement the staff cash interface and update the real journey; the old client still targets unpaid creation.
4. Obtain source-bound Astra/xhigh acceptance, qualify the runtime prerequisites, then run separately authorized SQL and combined browser/API/SQL proof.

The old fresh-unpaid route is deliberately rejected by this candidate. Existing authorized recorded-key replay remains supported.
Therefore this backend candidate alone is not a working cash-enabled staff product.
SQL cash atomicity, concurrency, refunds, real reconciliation, UI/browser acceptance and production remain unproved.
Production stays NO-GO. No SQL, Docker, merge or deployment ran for this integration.

Lesson: adding a migration also changes the reviewed release artifact and explicit history oracle. Verify both together before a SQL campaign.

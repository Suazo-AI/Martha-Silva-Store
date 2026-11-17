# Return request identity correction

BUILD checkpoint. Full source/SQL acceptance remains pending.
Source: ba8ff2ba10935e99fc268ebbe5eae130f72c1cca, managed isolated worktree.
Requested/exposed: codex / gpt-6.1-sol / high on SUAZO-PC. Tokens and USD unknown.
Current-session allowance; no nested delegation, SQL, Docker, services, installs or external mutations.

V027 is the effective source for usp_PostReturnOutcome and usp_PostCreditReturn.
The task name usp_PostReturnToCredit has no SQL definition; ReturnsStore calls usp_PostCreditReturn.
V028 overrides PostSale/readmodel/conservation, but neither return procedure.
V001-V028 remain immutable. sources-before.json binds raw and normalized LF bytes.

Version 1 hashes typed financial parameters as ordered SQL JSON (UTF-16 bytes, SHA2_256).
NULL is explicit. Omitted optional SQL arguments use existing defaults. Empty TVPs are [].
Text retains exact case/whitespace; NULL and empty string are distinct.
Seller JSON parses into the same typed columns as PostSale, then sorts by line number.
Missing seller JSON remains distinct from an explicit mapping, matching the historical CASHIER contract.
Actor/approver credentials are checked currently but excluded from financial identity.
FX remains forbidden before identity processing.

A transaction-owned application lock serializes both endpoints by reversal ID before existing
NIO-parent/USD-child drawer locks. Existing credit/drawer financial operations retain their order.
Current enabled actor/approver branch permission precedes replay acceptance.
An exact v1 replay exits before open-till, return-window, stock, customer and price policy eligibility.
A NULL/unknown/mismatched digest throws 51538 (existing sale.reversal_id_reused mapping).
Legacy reversals remain readable through unchanged GET; retries cannot backfill identity.

Migration envelope is the existing -- savia:transactional path, including registry commit.
Runtime rollback/reapply, module permissions, deadlocks, concurrency and conservation require real SQL proof.
Procedure catches retain existing full transaction ROLLBACK behavior (including any caller transaction).
Rollback must restore a verified database backup; downgrading procedures would reintroduce unsafe replays.
Do not drop identity columns or backfill them from retries. No operational rollback executed.

Integration gap: MANIFEST.sha256 is outside owned scope. Primary must run the existing
accept-migrations command after serial integration; this worker does not change that file.

Loading corrections: the requested 136 source is actually 136_credit_return_replay_other_lines.sql.
The first guessed path failed; the actual file was located and read. metodo is under .codex/skills,
not .agents/skills; the exact installed SKILL.md was then read. Required rule/docs loading succeeded.
UI rules are not applicable: no UI changes or review. No parser dependency was found in the project.

Prepared fixtures:
- 172_return_retry_safety.sql: six outcomes; field mutations; pool-only; seller-only;
  equal-total tender repartition; FX rejection; typed JSON reorder; current permission;
  closed/expired exact replay; NULL-identity rejection; legacy GET; complete ordered row images
  for all tables in sales/inventory/credits/accounting/sync, including rowversions.
- ReturnRetrySafetyTests.cs: four same-ID races via existing UsdFixture/TestSql, both endpoints,
  equivalent vs pool-mismatched contenders; one winner, one financial effect, USD drawer unchanged.
These are executable fixture sources for existing harnesses, NOT executed SQL evidence.
Some independent mutations intentionally change one cross-constrained field (cash creditId,
received/change, item/price). Pool, seller and equal-total tender-split cases are valid alternatives.
Further valid paired alternatives and multi-return-line reorder coverage require runtime review.
No cross-endpoint concurrent contender case or real close-document close flow was exercised.

Observed checks:
- python -m unittest discover -s savia/tests -p test_return_retry_safety.py -v: exit 0, 5 tests.
- python savia/tools/db/no_physical_delete.py: exit 0, 18 tracked tables, zero physical deletes.
- python -m unittest discover -s savia/tests -p test_usd_change_migration.py -v: exit 0, 1 test.
- python savia/tools/rules.py: exit 1; exactly migration manifest missing, eight other rules pass.
- Final byte binding: all historical migration/source/test paths unchanged raw and LF vs initial;
  normalized bytes also match pinned HEAD. See bindings.json and procedure-bindings.json.

No T-SQL parser was available in the project. These checks are source assertions and a mocked
migration runner, not syntax parsing or SQL compilation. SQL execution, deployment, backup/restore,
rollback fault injection, runtime permissions/lock behavior and real conservation are NOT RUN.
The worktree has no savia/tests/Savia.Tests/obj/project.assets.json; no restore or download attempted.
Canonical checkout has assets but is read-only and was not used to build this candidate.

Blockers and ownership:
1. Manifest guard: observed failure above; cause V029 is new and manifest outside scope.
   Correction: supplied exact raw/LF binding. Primary integrates and runs existing accept-migrations,
   then python savia/tools/rules.py; completion is all nine guards pass on integrated source.
2. SQL proof: prohibited by worker authority; no SQL attempt or retry. Prepared fixture sources.
   Primary obtains fresh authority, freezes integrated SHA, runs migration rollback/reapply,
   136/170/172, four concurrency cases and relevant USD/accounting/conservation suites.
   Completion requires exact error codes plus persisted rows and USD conservation evidence.
3. C# compilation: absent worktree assets. No restore/install authorized. Primary supplies an
   approved cached build environment and compiles the exact integrated candidate before SQL runs.
4. Acceptance: primary serial integration and fresh independent Astra/xhigh review pending.
   Worker source tests do not constitute primary acceptance or merge permission.

Lesson applied: use the current procedure/store names and actual catalog prices before writing
replay fixtures; guessed names and arbitrary new-line prices do not verify real return behavior.

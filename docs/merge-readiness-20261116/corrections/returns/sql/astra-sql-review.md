**REVISE the prepared fixtures.** No concrete new money-write defect was found in V029 during this offline review. The SQL design is supported by source; execution, locking and rollback remain unproved. This advisory return is not primary acceptance.

Task: `savia-pr7-return-sql-astra-ba8ff2b-20261116-01`. Mode: VALIDATE. Host: `SUAZO-PC`; T3 Code/Codex. Requested and exposed model/effort: `gpt-6-astra/xhigh`; harness context and awareness agree. Provider token/cache/reasoning usage, USD charge and remaining subscription allowance are not exposed. No additional provider requests or routing occurred.

Managed worktree: `C:/Users/Jason/.t3/worktrees/github/t3-178ac6b9-3b106bb92de180a3`. Branch: `t3/review-sql-return-contract`. HEAD remains `ba8ff2ba10935e99fc268ebbe5eae130f72c1cca`; initial status was clean. Canonical checkout stayed read-only. The UI executor's scope was excluded.

**Findings**

1. **P2 — An existing SQL regression expects the superseded error.** [134_credit_return_validation.sql:123](C:/Users/Jason/.t3/worktrees/github/t3-178ac6b9-3b106bb92de180a3/savia/db/tests/sales/134_credit_return_validation.sql:123) commits a credit return, then changes CreditId and Reason. Its catch at line 134 accepts only `51526`. [V029:199](C:/Users/Jason/.t3/worktrees/github/t3-178ac6b9-3b106bb92de180a3/savia/db/migrations/V029__return_retry_safety.sql:199) correctly throws the adopted `51538`. Therefore this test will rethrow when it reaches that case. This is a source-established test incompatibility, not an observed SQL run. **Closure:** primary updates this test's error/comment to `51538`, preserving the financial assertions. Later run this affected fixture; no whole-suite rerun is demanded here.

2. **P2 — The race fixture cannot isolate shared reversal-lock protection.** [ReturnRetrySafetyTests.cs:27](C:/Users/Jason/.t3/worktrees/github/t3-178ac6b9-3b106bb92de180a3/savia/tests/Savia.Tests/ReturnRetrySafetyTests.cs:27) releases a client-side barrier, but does not establish overlapping SQL execution. Both calls use the same `f.Till` and the same endpoint. Existing till locks already serialize them before reversal lookup. A broken endpoint-specific application-lock namespace could therefore satisfy these assertions. The offline counterexample below also passes all five source tests after splitting the namespaces. The race checks counts and the USD aggregate, not exact unchanged row images. **Closure:** hold a winner transaction open; establish the contender's wait on the shared application resource before release. Add a mixed-endpoint, different-till case. Require the winner's exact financial/sync row image to survive the contender's `51538`, including USD rows. A sequential schedule must not qualify as the race proof.

3. **P2 — Enabled-staff and refreshed-authorization behavior lack independent controls.** [172_return_retry_safety.sql:161](C:/Users/Jason/.t3/worktrees/github/t3-178ac6b9-3b106bb92de180a3/savia/db/tests/sales/172_return_retry_safety.sql:161) tests `CanApproveReturns=0` only. Removing every `s.IsEnabled=1` predicate still passes all five offline source tests. The prepared cases do not disable staff, revoke branch access, or replay with a different currently authorized supervisor. The SQL predicates are present; this finding concerns their protection against regression. **Closure:** add separate disabled/inactive actor and approver cases expecting `51529` with exact unchanged images. Add equivalent replay by another enabled authorized supervisor, preserving original audit attribution and all financial rows.

4. **P3 — Return-line ordering has no multi-line positive control.** [SQL172:69](C:/Users/Jason/.t3/worktrees/github/t3-178ac6b9-3b106bb92de180a3/savia/db/tests/sales/172_return_retry_safety.sql:69) always returns one original line. Lines 121–123 genuinely reorder exchange lines, sellers and tenders in the dearer exchange, but never return lines. **Closure:** return two original lines, reverse their input order and require success plus identical row images for both endpoints.

**Source assessment against the six frozen checks**

- **Identity:** both procedures persist version `1` plus SHA-256 of SQL UTF-16 JSON atomically. Typed GUID/int/bigint inputs, unique TVP keys, ordered arrays and `INCLUDE_NULL_VALUES` define normalization. All supplied financial fields are represented, including pools, exchange sellers, tender components and credit customer. Text remains exact; it is not trimmed for hashing. API absent/empty new arrays become empty TVPs; omitted discounts default to zero. Missing seller payload remains distinct from an explicit mapping. Actor/approver IDs and credentials are excluded; forbidden FX is rejected.
- **Replay/security:** both use transaction-owned exclusive `savia.return.<ReversalId>` locks before drawer locks. Enabled actor, active branch access and approval checks precede replay. Matching identity returns before till-open, return-window, stock and sale-status eligibility. Mismatch/legacy identity throws `51538`; transactional catch rolls back. These are source properties, not runtime proofs. Existing input/FX validation still precedes identity comparison.
- **Legacy:** no backfill, deletion or receipt replacement exists. NULL identities reject retries. The unchanged explicit receipt projection remains available; SQL172 prepares a receipt-lookup assertion after clearing fixture identities.
- **Preservation/migration:** comparison with both effective V027 procedures found only identity preparation/storage, serialization, authorization and replay changes. Financial processing bodies and signatures remain preserved. V028 does not override these procedures. All 28 historical migration files match HEAD after LF normalization. All 28 existing MANIFEST rows remain identical; all 29 registered hashes verify. The marker selects the existing migration transaction envelope; DDL, procedure batches and registration commit together. The new constraint rejects partially populated identity pairs.
- **Fixtures:** SQL172 prepares six outcomes, individual field mismatches, equal-total tender mutation, exact JSON row images across sales/inventory/credits/accounting/sync, revoked permission, closed/expired replay, forbidden FX and legacy lookup. These are useful controls. Findings above prevent accepting their coverage as complete.
- **API compatibility:** [ReturnsStore.cs:11](C:/Users/Jason/.t3/worktrees/github/t3-178ac6b9-3b106bb92de180a3/savia/src/Savia.Infrastructure/ReturnsStore.cs:11), DTOs and application guards still match procedure parameters. Authentication supplies actor/approver; no credential enters the digest. `51538` already maps to `sale.reversal_id_reused`. No grants or API response changes were introduced. Finding 1 reconciles the obsolete test expectation with that adopted error contract.

**Frozen bindings**

Verified archive RAW SHA256 before extraction and at handback: `70f89bbd047e4e28148f27ce9bbbc092152187d49f80bd66d96488a8710b18a7`. Archive membership was exactly these five files. REVIEW and PRIMARY bindings agreed. Each RAW and LF hash matched before inspection and at handback:

| Path | RAW = LF SHA256 |
| --- | --- |
| `savia/db/migrations/V029__return_retry_safety.sql` | `6041e3880fb4cb02c595504e394701e52408e426767c67c2b575914402b353cc` |
| `savia/db/migrations/MANIFEST.sha256` | `2e878b9e3c3eea5c1135ad0f1c2ac22a24f771aa5e41cba66665be79691eefe0` |
| `savia/db/tests/sales/172_return_retry_safety.sql` | `50dc06558f36da331afe4ddbf45112d7b90c7e08c9983958863b764a78e591b3` |
| `savia/tests/Savia.Tests/ReturnRetrySafetyTests.cs` | `b35dda2fef4a8dc8fc6a3750d213cffce50fbb8827f5c5ba5e43e7e49c390097` |
| `savia/tests/test_return_retry_safety.py` | `d142b60596c5e97e86d88f66a4805bf75116e383d45c6060c71d898200c6c687` |

**Commands, evidence and limits**

`git rev-parse HEAD`, `git branch --show-current`, `git status --short --untracked-files=all`, `git diff --check`, and `git diff --cached --name-only`: exit 0. Index unchanged. Only the five overlay paths and this report differ. Awareness ran at start and before writes, exit 0:

```powershell
python C:/Users/Jason/AI-OS/bin/agent-awareness.py --workspace "C:/Users/Jason/.t3/worktrees/github/t3-178ac6b9-3b106bb92de180a3"
```

Integrity/source-comparison invocations used `python -` with stdlib `zipfile`, `hashlib`, `json`, `pathlib`, `difflib` and read-only Git calls; exit 0. No access denial occurred. Required policies, local AGENTS, DATABASE, REVIEW, PRIMARY, ADOPTION and preimplementation review were accessible. Initial optional-index discovery exited 1 because indexes were absent. Windows wildcard/mislocated-source searches reported errors 123/2; directory-scoped `rg -g` and direct paths resolved them.

One offline probe invocation, `@'<Python source>'@ | python -B -`, exit 0. It compiled the frozen Python test module in memory, blocked `subprocess.run`, and ran its five tests for each mutation:

```python
frozen.replace("N'savia.return.'", "N'savia.return.credit.'", 1)
frozen.replace(' AND s.IsEnabled=1', '')
```

Both returned 5/5, zero failures/errors. The first changes only the first procedure's resource prefix. No SQL was parsed/executed and no frozen file changed. This demonstrates source-test blind spots; it does not demonstrate a database exploit.

Primary's reported 5/5 contracts, 9/9 rules and Release build were not rerun; private logs were not accessed. SQL, Docker, API/browser, network, installation, services, workflows, CI refresh, Git mutations, commits, pushes, merge and deployment: **NOT RUN**.

No correction was attempted because implementation and runtime are excluded. Primary owns fixture corrections and later runtime authorization. Lesson: a same-till race can pass through an unrelated lock; acceptance must observe the lock being claimed.

**Next action:** primary corrects the bounded fixture findings, freezes the revised bindings, and reviews that delta before separately authorized SQL execution.

PR https://github.com/Suazo-AI/Martha-Silva-Store/pull/7, head ba8ff2ba10935e99fc268ebbe5eae130f72c1cca, checks and reviews NOT REFRESHED (network prohibited).

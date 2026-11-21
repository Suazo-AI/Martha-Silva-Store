# V029 preimplementation review

**RETURNED: fix the V029 batch boundary and the production runner's missing transaction envelope. A GO-only change is insufficient for atomic migration acceptance.** This is advisory evidence, not primary acceptance or SQL proof.

Task: `savia-pr7-v029-preflight-ac0bb9f-20261117`. Host: `SUAZO-PC`. Exposed runtime: T3 Code, provider `codex`, model `gpt-6-astra`, reasoning `xhigh`; matches the request. Worktree: `C:/Users/Jason/.t3/worktrees/github/t3-45e9e662-ae3edc461400a173`; branch `t3/v029-preflight-review`. HEAD verified twice as `ac0bb9f47f5a12ffc0626f7737a347dea9b37900`. Managed-worktree metadata agrees. Review used the supplied packet and local source; no prior review files, memory, parent transcript, or canonical checkout were consulted. Tool-level history inheritance is not independently exposed.

**Verified source and diagnosis**

[V029:4](C:/Users/Jason/.t3/worktrees/github/t3-45e9e662-ae3edc461400a173/savia/db/migrations/V029__return_retry_safety.sql:4) adds two columns, then adds a CHECK referencing them before the first GO. The CHECK contains six references: three each to `RequestIdentityVersion` and `RequestIdentityHash`. Neither procedure body shares this batch.

This establishes the problematic same-batch dependency. Compile-time binding against the pre-ALTER schema is the strongly supported explanation for the six SQL207 diagnostics. It was not reproduced here. Run `43996099832`, job `133748432080`, and V001..V028 success are supplied observations, not independently fetched evidence.

[Python:109](C:/Users/Jason/.t3/worktrees/github/t3-45e9e662-ae3edc461400a173/savia/tools/db/saviadb.py:109) sorts V*.sql. It hashes bytes after CRLF-to-LF normalization. Matching ledger hashes skip; differing applied hashes fail. For an exact leading `-- savia:transactional`, it sends one sqlcmd script containing BEGIN TRAN, migration GO batches, transaction-state validation, ledger INSERT, then COMMIT. sqlcmd uses `-b -I`. There is no explicit envelope CATCH; failure terminates the sqlcmd session, leaving rollback dependent on SQL/session behavior. That rollback needs runtime evidence.

[Production:91](C:/Users/Jason/.t3/worktrees/github/t3-45e9e662-ae3edc461400a173/savia/deploy/migrator/Program.cs:91) instead executes each batch separately on one connection, then inserts the ledger row separately. It never recognizes the marker or starts a migration transaction. Procedure-internal transactions are definitions, not migration protection. Later failure can therefore leave committed DDL/procedure changes without V029 registration. This missing envelope is proven source behavior; occurrence in CI is unknown.

Its splitter accepts standalone case-insensitive GO with spaces/tabs and rejects GO counts. Both paths normalize checksums identically and use `dbo.SaviaMigrations`. Production rejects changed hashes before pending work, takes a session application lock, and verifies the final ledger. Python checks files sequentially. Neither runner reads MANIFEST.sha256; [rules.py:56](C:/Users/Jason/.t3/worktrees/github/t3-45e9e662-ae3edc461400a173/savia/tools/rules.py:56) separately enforces that manifest. Its accept command only appends new entries.

**Smallest safe correction to freeze**

1. Insert one standalone GO after V029's column-add statement. Keep the complete CHECK unchanged. This separates binding without dynamic SQL, backfill, or weakened constraints.
2. Add marker-aware production transaction handling around all migration batches **and the ledger insert**. Require XACT_ABORT, a valid single transaction before registration/commit, explicit rollback on failure, and preservation of the original error. Keep unmarked behavior, lock, checksum refusal, plan behavior, and grants unchanged. V028 also carries the marker; include its regression.
3. Preserve both procedure bodies exactly. Preserve V001..V028 Git blobs exactly. Generate only V029's replacement manifest digest after an explicitly documented pre-release correction exception; keep the freeze guard intact.

Recommend correcting V029 for this never-successfully-applied fresh-install candidate. Appending V030 alone cannot repair the ordered chain because V029 fails first. This does **not** establish that V029 was never applied anywhere. Before replacing a distributed checksum, the primary must obtain authorized ledger/schema evidence for every relevant target. Unknown targets or partial application remain a stop for deployment. If an old V029 hash exists, retain installed history and design a separately reviewed compatibility/forward-repair route. Never rewrite a database ledger to force acceptance.

**Frozen acceptance checks**

1. Source checks must reject the original same-batch dependency. Confirm corrected raw batches are four, versus three originally. Both procedure batches must remain byte-identical after LF normalization. Mutation controls must detect deleting the new GO, removing the marker, moving registration outside the transaction, and removing either rollback or state validation.
2. Preserve authorization before replay: enabled actor, active branch access, current approval permission, and the credit approver's independent checks. Preserve shared reversal application locking, parent/child till lock order, deterministic financial identity, exact version/hash matching, and mismatch error 51538. Preserve legacy NULL/NULL lookup-only behavior with no retry backfill.
3. On fresh synthetic databases, run each real migrator through V029. Verify 29 matching ledger entries, nullable column types, enabled/trusted CHECK, both installed definitions, then an unchanged second run. Cross-runner no-op must retain hashes and ledger timestamps.
4. From populated V028 fixtures, verify legacy identities remain NULL/NULL. Accept NULL/NULL and version 1 with 32 bytes; reject half-NULL pairs, other versions, and short hashes. Verify legacy receipt lookup and denied legacy retry.
5. For **each** runner, inject distinct failures after column addition, after the first procedure replacement, and during ledger INSERT. Require nonzero exit, no V029 row, restored schema/procedure definitions, and unchanged financial/sync snapshots. Planned recovery must then succeed once and no-op once. Changed applied checksums must fail without writes.
6. Run [172_return_retry_safety.sql](C:/Users/Jason/.t3/worktrees/github/t3-45e9e662-ae3edc461400a173/savia/db/tests/sales/172_return_retry_safety.sql) and all six [ReturnRetrySafetyTests](C:/Users/Jason/.t3/worktrees/github/t3-45e9e662-ae3edc461400a173/savia/tests/Savia.Tests/ReturnRetrySafetyTests.cs:8) cases. Require exact financial/sync snapshots, conservation, same-request replay, changed-request rejection, current authorization, and mixed-endpoint serialization. Their source exists; execution remains unproven.

**Commands, results, and handoff**

- `git rev-parse HEAD`, `git status --short`: exit 0; matching HEAD and initially clean worktree.
- `python C:/Users/Jason/AI-OS/bin/agent-awareness.py --workspace "C:/Users/Jason/.t3/worktrees/github/t3-45e9e662-ae3edc461400a173"`: exit 0 at start and before writing; own managed worker identified.
- Probe 1: `python -B savia/tests/test_return_retry_safety.py`: exit 0, **9/9**. These mock SQL execution and cannot detect SQL compilation.
- Probe 2: PowerShell here-string piped to `python -B -`: exit 0. Read-only pathlib/hashlib/re audit plus `git show HEAD:<migration>`: **29/29** normalized manifest/HEAD matches; **6** CHECK references; in-memory GO insertion gives **3→4** batches and unchanged procedure suffix.
- V029 normalized SHA256: `6041e3880fb4cb02c595504e394701e52408e426767c67c2b575914402b353cc`.
- Packet path `savia/tools/saviadb.py` was absent; resolved to `savia/tools/db/saviadb.py`. Literal-glob rg lookup failed with OS error 123; directory searches with `-g` resolved discovery. These were source-location errors, not product failures.

Required global instructions were accessible. Exactly two offline probes ran. SQL, Docker, API/browser, installation, network, publication, and implementation: **NOT RUN**.

Primary owns adjudication, serial implementation, target-state evidence, and a new bounded SQL authorization. Proposed smoke scope is disposable synthetic databases only, both migration paths, the checks above, and verified cleanup; no API, deployment, real data, or automatic retries. Existing CI/publication authority remains consumed. Only this report is delivered.


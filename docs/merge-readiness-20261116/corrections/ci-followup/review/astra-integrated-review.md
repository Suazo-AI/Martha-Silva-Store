# Advisory review: REVISE with one P2

Task `savia-pr7-migrator-integrated-review-ac0bb9f-20261117`. Primary retains acceptance. The transaction envelope is materially improved, but original-error preservation has one reproducible gap. No SQL atomicity failure was demonstrated.

Host: **SUAZO-PC**, T3 Code/Codex. Requested and exposed model/effort: **gpt-6-astra/xhigh**. Managed worktree: `C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53`. Base/HEAD: `ac0bb9f47f5a12ffc0626f7737a347dea9b37900`. Required instructions and awareness checks were read/run. No further agents were started.

**F1 ? P2: command disposal can replace the original operation error.**

Affected: [MigrationExecution.cs:83](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/savia/deploy/migrator/MigrationExecution.cs:83), also command scopes at lines 67 and 92. Each helper uses `await using`. If execution throws and `DbCommand.DisposeAsync()` also throws, disposal replaces the execution exception before `ApplyAsync` catches it. Outer cleanup suppression cannot recover the original exception.

An independent fake, compiled with the exact frozen helper, reproduces this for a migration batch, ledger INSERT, and state SELECT. All three return `command-dispose-error` instead of `original-operation-error`. The other **17/17** adversarial scenarios pass. This proves a generic helper error-preservation defect; occurrence with production SqlClient is **not established**. It does not prove lost atomicity or database corruption.

Minimal correction: preserve each command operation's original exception while attempting disposal in `Execute`, `Register`, and `Scalar`. Propagate disposal errors when no earlier failure exists. Add those three double-failure cases to the linked tests. Source remains frozen. Owner: primary/executor; close F1 with exact-source tests showing original exception identity, then fresh advisory review.

**Five packet acceptance checks**

1. **PARTIAL / F1.** One actual `DbTransaction` owns all marked batches, both state queries, and parameterized registration. `XACT_ABORT` is enabled before begin; `@@TRANCOUNT=1` and `XACT_STATE()=1` are checked before/after registration. Rollback, transaction-dispose, and option-restore failures preserve the caught error. Commit acknowledgement loss propagates failure even when the fake already committed. No automatic retry occurs. F1 limits the broader preservation claim.
2. **SATISFIED offline.** [Program.cs:92](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/savia/deploy/migrator/Program.cs:92) invokes this helper in the executable; SDK compilation includes it, and the test project links the same file. Session application lock, plan, applied-hash refusal, grants, and final ledger checks are unchanged. Splitter/normalizer are identical to base. Leading, case-sensitive marker recognition matches Python, including BOM/whitespace rejection and accepted suffixes. GO case/spacing, CRLF, missing final newline, GO-count refusal before commands, and marker removal were exercised. Actual V028 has six batches; V029 has four. Both retain transaction identity through registration in fakes. Unmarked partial-write behavior remains compatible.
3. **SATISFIED source; deployment gate retained.** V029 is exactly base plus one standalone GO after column ADD. Both procedure bodies are byte-identical after LF normalization. V001?V028 match all 28 base blobs. Only V029's manifest digest changes; its guard rejects the missing-GO mutant. The bound preimplementation reference documents the fresh-candidate exception. Unknown target history or partial installation blocks deployment. Never rewrite an installed ledger.
4. **SATISFIED source.** Unchanged procedure bodies retain current authorization before replay, deterministic identity, 51538 mismatch refusal, legacy NULL/NULL lookup-only behavior, lock ordering, and financial/sync logic. Four web files exactly match safe Biome output from HEAD. The fifth, [return-lifecycle.test.mjs](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/savia/web/tests/return-lifecycle.test.mjs:164), has only two equivalent string-to-template expressions and removal of an unused, read-only fake-DOM query beyond that output. No assertion was removed. These residual hunks were inspected directly; this is not five-of-five formatter equality.
5. **SATISFIED as evidence assessment.** Actual linked tests and independent adversarial cases executed. Historical mutation artifacts were hash-verified: missing rollback **13 pass/11 fail**, missing state validation **17/7**, ledger outside transaction **20/4**, each exit **1**. They detect the intended omissions. Historical `final-fixture-correction.trx` is **23/24**, not green; current primary and independent runs each pass **24/24**. Fakes/builds do not prove SQL behavior.

**Commands and observed results**

Reviewer child environments removed SQL/connection-related variables without printing values. One cache-only restore and three focused probe groups ran; no further suite was run.

Exact PowerShell path definitions:

```powershell
$D = 'C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe'
$W = 'C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53'
$S = "$W/private-exports/astra-integrated-review"
$B = 'C:/Users/Jason/MARTHA-SILVA/github/savia/node_modules/@biomejs/biome/bin/biome'
```

- Restore: `& $D restore savia/tests/Savia.Tests/Savia.Tests.csproj --locked-mode --source C:/Users/Jason/.nuget/packages -p:NuGetAudit=false -v minimal` ? **exit 0**, no download/install.
- Probe 1: `& $D test savia/tests/Savia.Tests/Savia.Tests.csproj --no-restore -c Release --filter FullyQualifiedName~MigratorExecutionTests --logger 'trx;LogFileName=review.trx' --results-directory $S -v minimal` ? **exit 0; 24 passed, 0 failed/skipped**. [TRX](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/private-exports/astra-integrated-review/review.trx).
- Probe 2 compile: `& $D C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/sdk/10.0.402/Roslyn/bincore/csc.dll "@$S/compile.rsp"` ? **exit 0**, cached framework references and unchanged helper. Execute: `& $D "$S/adversarial.dll" $W $S` ? **exit 1; 17 pass/3 fail**, all failures F1. [Source](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/private-exports/astra-integrated-review/Adversarial.cs); [log](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/private-exports/astra-integrated-review/adversarial.log).
- Probe 3, cwd `savia`: `node $B check --write --stdin-file-path <web-path>`, with HEAD blob on stdin for each of five web files ? each formatter **exit 0**; comparison wrapper **exit 1**, exact equality **4/5**, explained above. Stdin mode changed no file. [Exact commands/comparisons](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/private-exports/astra-integrated-review/format-comparison.json).

Hash-bound primary evidence was read, not rerun: standalone migrator locked-cache restore/build **exit 0, 0 warnings/errors**; helper **24/24**; `node --test savia/web/tests/*.test.mjs savia/web/scanner/*.test.mjs` **134/134**; `python -B savia/tests/test_return_retry_safety.py` red **10/11, exit 1**, green **11/11, exit 0**; `node node_modules/@biomejs/biome/bin/biome check web` **68 files, exit 0**. Red count is packet-reported; green/build/TRX/log hashes were independently verified.

`python tests/check.py` remains **exit 1**: three unchanged symlink fixtures, `WinError 1314`. Staff **223/223** and preceding groups passed; later groups were not reached. No privilege workaround or broad repeat occurred. Primary needs authorized Linux aggregate evidence on the accepted candidate. No access denial occurred. Read-output encoding/glob errors were resolved using UTF-8 and a directory-scoped glob.

**Frozen bindings and preservation**

Packet RAW SHA256: `cba7b397f4f7b9ebf344cd24ab21d0c760fbc5c984fd33f125c27cf779f31dbd`.
Archive RAW SHA256: `7f253523a696eea97c7fef703dcc12fbfd19940775091117dfd9bd2b344b95dd`.
All 12 unique regular archive entries exactly matched the allowlist; paths/bytes were checked before materialization. All ten existing base blobs matched packet digests; two new files were absent at base. All three reference bindings matched. Final **12/12 RAW and LF** checks passed.

| Source | RAW SHA256 | LF SHA256 |
| --- | --- | --- |
| [savia/db/migrations/MANIFEST.sha256](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/savia/db/migrations/MANIFEST.sha256) | `211faf4029a8214be5ecd945479824a318a4fe368b7fc60c1a73e25b1aba9148` | same |
| [savia/db/migrations/V029__return_retry_safety.sql](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/savia/db/migrations/V029__return_retry_safety.sql) | `68ae40dbbfbc4f14f80dbc5e3896ed153298786765dc8f16e3cd3410d180eb0f` | same |
| [savia/tests/test_return_retry_safety.py](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/savia/tests/test_return_retry_safety.py) | `b14cebde601936f0bd7db2c1a99c47f0872e41bc242b181c39fbbc25d75a98a6` | same |
| [savia/web/api.mjs](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/savia/web/api.mjs) | `247696d41b2e4939c618a88cbfd2fb10d2b9e9bd319cb151201893fac9ae931d` | same |
| [savia/web/screens/return-intent.mjs](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/savia/web/screens/return-intent.mjs) | `930bc9537baa5b5a7dfe095c5df85a504d530fa2e58b091f9d76b617bd8e3207` | same |
| [savia/web/screens/return.mjs](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/savia/web/screens/return.mjs) | `1e5294432c2e10864d7a0e45703ae439d5ea2bc62a8cfe2f8fd5d5d31968d490` | same |
| [savia/web/tests/return-lifecycle.test.mjs](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/savia/web/tests/return-lifecycle.test.mjs) | `edfa5d0623959d908ad2b414936e3507e030672851d00c7a915f1dfa42a88c4f` | same |
| [savia/web/tests/uuid.test.mjs](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/savia/web/tests/uuid.test.mjs) | `63a855ce2651bf215b9dc42bcccbbce478ee9945fe40705aa25bdcfbb41348e2` | same |
| [savia/deploy/migrator/Program.cs](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/savia/deploy/migrator/Program.cs) | `0a89b762ddad718469beed18eb4fa65dfbb79c0be21b36a2bc52ec7389cb1522` | `2552840e40095490ee943192e4b512be7d9293dede77c397da3b7fcc016ed220` |
| [savia/deploy/migrator/MigrationExecution.cs](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/savia/deploy/migrator/MigrationExecution.cs) | `fdffab36bee24327107849bada013ca6218792b8c712b4c6adc9408e40358f72` | `4a1e613d046b9ad745b914b7ee5db8c75973966361208ec0ae52e46ec92cda25` |
| [savia/tests/Savia.Tests/Savia.Tests.csproj](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/savia/tests/Savia.Tests/Savia.Tests.csproj) | `229188de590a454b3cc7c0ee7f231abc5f780cc85462e9edc538d6315bf5bfdc` | `353336eeeb28f9affeda497b9c531c40cbc05c2e0e582e8c37bcff4a330effa8` |
| [savia/tests/Savia.Tests/MigratorExecutionTests.cs](C:/Users/Jason/.t3/worktrees/github/t3-ddbe32a5-6fbb20ac6c90ea53/savia/tests/Savia.Tests/MigratorExecutionTests.cs) | `09030de1d36709235a756c7644ab7c88562a072e12e741a43f8c42625e24e453` | `c8693919acdfb0a64e40d944c9d57a1011688037ed5b3307c07e5ef7a012a5fb` |

HEAD and index are unchanged. Index RAW SHA256: `5c1cac10d5847febd6c97479618b8d497f8486b8665647c0f266577fe2073750`. Only the allowlisted overlay and this report are visible changes; probe artifacts remain ignored. Canonical checkout was not written. No staging, commit, network, workflow, SQL, Docker, browser, account, service, certificate, publication, or deployment action occurred.

**Minimum remaining real-SQL proof and next action**

Primary first resolves F1 and freezes the corrected candidate. Obtain a new bounded authorization; prior gates remain in force. For **both real runners**, use authorized disposable synthetic databases:

- Fresh install through V029: 29 exact ledger hashes, column types, trusted/enabled CHECK, installed procedure definitions, second-run and cross-runner no-op with unchanged timestamps. Include V028 regression.
- Populated V028 upgrade: preserve NULL/NULL legacy rows and financial/sync snapshots; test valid/invalid identity pairs, legacy lookup and refused retry. Run `172_return_retry_safety.sql` and all six `ReturnRetrySafetyTests`, including authorization, replay, conservation, and mixed-endpoint serialization.
- Inject failures after column ADD, after first procedure replacement, and at ledger INSERT. Require failure, no V029 ledger row, restored schema/definitions, unchanged business data, then planned recovery and no-op. Verify changed installed hashes refuse writes, uncertain commits require reconciliation, and owned-resource cleanup.

Corrected SQL, exact-candidate CI, browser/API/SQL, and production acceptance remain **NOT RUN**. This report grants none of those permissions. Lesson: test command disposal as well as transaction cleanup when promising original-error preservation.

PR https://github.com/Suazo-AI/Martha-Silva-Store/pull/7, head ac0bb9f47f5a12ffc0626f7737a347dea9b37900, checks and reviews: historical required 7 green; additional CI failed; local overlay under review; no live refresh.

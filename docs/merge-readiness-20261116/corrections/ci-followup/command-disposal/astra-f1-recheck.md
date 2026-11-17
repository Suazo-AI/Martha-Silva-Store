ACCEPT WITH LIMITS. F1 is closed within the frozen offline scope. No new findings. This report is advisory; the primary retains acceptance.

Task: `savia-pr7-f1-recheck-ac0bb9f-20261117`. Host: SUAZO-PC, T3 Code/Codex. Requested and exposed model/effort: `gpt-6-astra/xhigh`. No further agents were started. Required instructions and both awareness checks were completed. No access denial occurred.

Five acceptance checks:

1. **PASS ? F1, formerly P2.** [MigrationExecution.cs:89](C:/Users/Jason/.t3/worktrees/github/t3-36240a9a-08678ff98f84db59/savia/deploy/migrator/MigrationExecution.cs:89) now preserves the original operation exception while attempting disposal. The prior failure replaced batch, ledger INSERT, or state SELECT errors with disposal errors. The shared `Run` wrapper is the minimal correction. Execute, Register, and Scalar all use it. Fresh tests verify reference identity.
2. **PASS ? disposal after success.** Disposal exceptions propagate. Fake transactions roll back without commit for batch, ledger, and validation failures. This claim concerns operations inside an active transaction.
3. **PASS ? source and fakes.** SQL text, timeout values, parameter names/values, transaction ownership, XACT_ABORT restoration, and unmarked semantics are preserved. Transaction assignment remains first. Register now sets text before timeout; both values remain unchanged. Cancellation preserves exception identity and canceled task state. IL-generated non-Exception throws preserve their wrapped object under the default runtime. Deferred operation/disposal failures, setter failures, and command-creation failure pass. Fatal runtime termination is outside these checks.
4. **PASS ? formatting delta.** [ReturnRetrySafetyTests.cs:58](C:/Users/Jason/.t3/worktrees/github/t3-36240a9a-08678ff98f84db59/savia/tests/Savia.Tests/ReturnRetrySafetyTests.cs:58) differs from HEAD only by the line break and indentation before its initializer. No token changed.
5. **PASS ? frozen bindings.** All 13 unique regular archive entries matched the allowlist and RAW/LF digests before copying. Final worktree verification also passed 13/13. The other 10 files match LF hashes in the independently hash-verified previous packet. Both `.before` files match that packet. Only the three specified content deltas were reviewed.

[Tests:82](C:/Users/Jason/.t3/worktrees/github/t3-36240a9a-08678ff98f84db59/savia/tests/Savia.Tests/MigratorExecutionTests.cs:82) assert original identity, attempted disposal, rollback, no commit, and no persisted effects. The primary red TRX records **27 pass/3 fail**, specifically the three identity assertions against the old helper. The three successful-operation controls already passed. Thus the six cases are not vacuous.

Fresh commands, from this worktree:

```powershell
$D = 'C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe'
$S = 'private-exports/astra-f1-recheck'
& $D restore savia/tests/Savia.Tests/Savia.Tests.csproj --locked-mode --source C:/Users/Jason/.nuget/packages -p:NuGetAudit=false
& $D test savia/tests/Savia.Tests/Savia.Tests.csproj --no-restore -c Release --filter FullyQualifiedName~MigratorExecutionTests --logger 'trx;LogFileName=f1-recheck.trx' --results-directory $S
& $D 'C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/sdk/10.0.402/Roslyn/bincore/csc.dll' '@private-exports/astra-f1-recheck/compile.rsp'
& $D private-exports/astra-f1-recheck/probe.dll $PWD.Path "$($PWD.Path)/private-exports/astra-f1-recheck"
```

Restore: **exit 0**, cache only. Focused test/build: **exit 0; 30 passed, 0 failed/skipped**. Probe compilation: **exit 0**. Extended probe: **exit 0; 37 passed, 0 failed**, including 17 added adversarial cases. SQL/connection environment variables were removed in child processes without printing values. Budget used: one restore, two test/probe invocations.

Evidence: [fresh TRX](C:/Users/Jason/.t3/worktrees/github/t3-36240a9a-08678ff98f84db59/private-exports/astra-f1-recheck/f1-recheck.trx), [probe source](C:/Users/Jason/.t3/worktrees/github/t3-36240a9a-08678ff98f84db59/private-exports/astra-f1-recheck/ExtendedProbe.cs), [compiler arguments](C:/Users/Jason/.t3/worktrees/github/t3-36240a9a-08678ff98f84db59/private-exports/astra-f1-recheck/compile.rsp), [probe log](C:/Users/Jason/.t3/worktrees/github/t3-36240a9a-08678ff98f84db59/private-exports/astra-f1-recheck/probe.log). These are fake-provider results, not SQL proof.

Primary evidence was read and all **20 artifact hashes** matched [RESULT.json](C:/Users/Jason/MARTHA-SILVA/github/docs/merge-readiness-20261116/corrections/ci-followup/command-disposal/RESULT.json). It records red exit 1, green/final **30/30**, and earlier probe **20/20**. Release solution/migrator build logs show **0 warnings/errors**. Format exit 0 is primary-recorded; its log is empty. Rules **9/9** and Python **41 OK** were read. These checks were not independently rerun.

Packet SHA256: `2f286ef7f3ae96da7968c6cd6447a9e736e63e92fc1c3b02c82c0297758defa1`.
Archive SHA256: `244295a95840901859bfd440408d457994c413d2a3f872601230dc75db4974c6`.
HEAD remains `ac0bb9f47f5a12ffc0626f7737a347dea9b37900`. Index SHA256 remains `392ceedc93a98399f5579c41a7a5b9bdb4495669aca3eb3151dd10700fa87e43`; staging is empty. Canonical files were not written. Product source remained unchanged after overlay.

NOT RUN: real SQL, exact-candidate CI, Linux aggregate, broad suites, browser, Docker, network, or deployment. Next action: primary accepts/rejects this correction, then obtains exact-candidate CI and separately authorized SQL evidence. Lesson: test both operation/disposal double failure and disposal after success.

PR https://github.com/Suazo-AI/Martha-Silva-Store/pull/7, head ac0bb9f47f5a12ffc0626f7737a347dea9b37900, checks and reviews: historical required 7 green; additional CI failed; local F1 correction under recheck.

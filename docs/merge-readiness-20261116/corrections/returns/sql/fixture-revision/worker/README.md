# Fixture revision candidate ? SQL NOT RUN

Returned candidate on `ba8ff2ba10935e99fc268ebbe5eae130f72c1cca`.
Host `SUAZO-PC`; Codex `gpt-6.1-sol/high`, requested and exposed.
Managed worktree is the current checkout. Canonical checkout stayed read-only.
Primary acceptance and fresh Astra/xhigh review remain pending.

## Delivered source

Only four source deltas relative to HEAD plus the verified five-file overlay.
See `final-delta.patch`, `hashes.json`, `scope.json`, and `RESULT.json`.
The imported V029 and MANIFEST remain byte-identical to REVIEW.json.
Archive membership, all five RAW/LF hashes and advisory review RAW hash were verified before import.
The final audit verifies the same bindings again.

- SQL134 changes only the obsolete error comment and catch from 51526 to 51538.
- C# prepares six schedules: exact and changed replays for each endpoint, plus mixed endpoints in both directions using different registers/tills.
- Winner executes inside an outer transaction. Its exact ordered financial/sync image is captured before release.
- A separate observer must see contender WAIT and winner GRANT on the same APPLICATION lock identity, exclusive mode, reversal prefix and blocking session.
- Sequential completion, no wait, unrelated drawer/key waits and observation timeout fail before release.
- Observation deadline is six seconds; each observation command has a two-second timeout; send/winner/snapshot commands have twenty-second timeouts.
- Task.Delay controls polling cadence only. It never proves contention.
- Contender inputs use a previously loaded immutable original line ID. Reading that line inside the contender could block before application-lock acquisition.
- Finally cancels, rolls back and drains pending work on failure while retaining the original exception.
- Winner and final images compare all columns of all sales/inventory/credits/accounting/sync tables, ordered by complete primary keys, including USD rows.
- Original duplicate, USD aggregate and conservation assertions remain.
- SQL172 credit actor is distinct from its approver. Six revocation controls cover disabled staff, inactive access and absent branch access for both subjects. Outcome uses its single supervisor actor.
- A different current supervisor replays without changing exact images or attribution. SQL172 images also cover audit tables.
- Two further SQL172 scenarios actually return two original lines, reverse their input order and compare exact images for each endpoint.

## Offline evidence

Three focused offline invocations used PowerShell Python heredocs piped to `python -B -`, each exit 0.
No T-SQL was parsed or executed.

| Invocation | Result | Evidence |
|---|---|---|
| 1: frozen tests, original and two mutations | 5/5 for all three; both mutations incorrectly accepted | baseline.json |
| 2: revised tests, original and two mutations | original 8/8; each mutation produces two failures, zero errors | corrected.json |
| 3: final source guards and existing rules | 8/8 plus 10/10; zero failures/errors | final-offline.json |

The SQL134 source comparison is red on HEAD and green on the correction. This is an expected-error source check, not a reproduced SQL execution.
Mutation controls split the first endpoint namespace with `.replace("N'savia.return.'", "N'savia.return.credit.'", 1)` and remove enabled predicates with `.replace(' AND s.IsEnabled=1', '')` in memory only.
Full failures remain in corrected.json. Cross-control failures include a regex mismatch and a no-op mutation assertion; the direct shared-lock/enabled guard also fails in both mutated suites.

## Cached compilation

Child PowerShell environment only:

```powershell
$env:DOTNET_ROOT='C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402'
$env:DOTNET_HOST_PATH="$env:DOTNET_ROOT/dotnet.exe"
$env:DOTNET_CLI_TELEMETRY_OPTOUT='1'
& $env:DOTNET_HOST_PATH restore savia/tests/Savia.Tests/Savia.Tests.csproj --source C:/Users/Jason/.nuget/packages --locked-mode -p:NuGetAudit=false
& $env:DOTNET_HOST_PATH build savia/tests/Savia.Tests/Savia.Tests.csproj -c Release --no-restore -p:NuGetAudit=false
```

One restore, exit 0. One final Release build, exit 0, zero warnings/errors, 12.39 seconds.
See restore.log and build.log. These PowerShell logs use UTF-16.
C# source did not change after that build. No dotnet test ran.

## Integrity and scope

```powershell
python -B docs/merge-readiness-20261116/corrections/returns/sql/fixture-revision/worker/audit.py
git diff --check
git diff --cached --name-only
git rev-parse HEAD
```

Final audit exit 0. Empty index. HEAD unchanged. Only four owned source deltas, immutable overlay imports and owned evidence are present.
Initial audit exit 1 compared CRLF working bytes to LF Git bytes. audit-initial-failure.txt preserves the failure. The audit now compares normalized LF for the two-line SQL134 delta and records RAW/LF hashes separately. No source correction was needed.
Optional-index discovery found neither CodeGraph nor Graphify indexes. Incorrect direct TestSql.cs lookup was resolved to TestSupport.cs. Windows wildcard-path searches returned error 123; directory-scoped searches resolved them. No install or environment change occurred.

## Boundaries and continuation

SQL race behavior, authorization, rollback, money conservation and ordering behavior remain NOT RUN.
SQL runtime authority was explicitly withheld. No attempt was made through another route.
Observer DMV permissions are a runtime prerequisite, not verified here. A denial must fail visibly.
No services, Docker, browser, network, install, account/certificate change, Git publication or workflow ran.
Provider token/cache/reasoning/USD metrics and whole-session duration are not exposed. No extra provider request or delegate was launched.
Three of eight offline invocations were used. One cached restore and one final build were used. The forty-minute stop was not reached.

Primary owns serial inspection/integration and requests fresh Astra/xhigh review.
Jason owns any later SQL authorization. Completion requires separately authorized execution of SQL134, SQL172 and all six C# cases with observed application waits, exact unchanged images and conservation.

Lesson: observe the named lock and preload contender TVPs before winner writes. A SQL read used to construct the request can introduce an unrelated earlier lock wait.

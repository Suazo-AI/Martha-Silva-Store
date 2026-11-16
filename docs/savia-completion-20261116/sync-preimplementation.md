# CP4 synchronization: REVISE

Advisory review; primary retains acceptance. Current source cannot prove three shops preserve money/stock after replay or restore. A bounded database proof is feasible after corrections; it cannot establish production synchronization.

Task: savia-sync-minimum-proof-63a8b1e-astra-20261116-01.
HEAD: **63a8b1e9bfe50e9426295cb22097514fc15155e7**.
Host SUAZO-PC, T3-managed worktree, branch t3/review-sync-proof. Requested and runtime-exposed: Codex/gpt-6-astra, reasoningEffort=xhigh. Actual token/USD usage unknown.

Required global instructions, project entrypoints, architecture and ownership contract were read. No instruction-read denial. Agent-awareness checked initially and before writing. Source review was fresh; historical S1 evidence and the canonical incomplete log supply no acceptance evidence.

## Source binding

Git blob IDs below bind inspected bytes. Every working file normalized CRLF→LF equaled its HEAD blob; every blob contains zero CR bytes.

| Source alias | Git blob |
|---|---|
| [S: simulator.py](C:/Users/Jason/.t3/worktrees/github/t3-2759772e-28fc4dd8bb0e4d8b/savia/tools/db/simulator.py) | 4c01960d6bc2593f26090c2612dc1257decac38c |
| [D: saviadb.py](C:/Users/Jason/.t3/worktrees/github/t3-2759772e-28fc4dd8bb0e4d8b/savia/tools/db/saviadb.py) | 23cfb2b48260a497892bc54619c0300d908e8135 |
| [R: restore_proof.py](C:/Users/Jason/.t3/worktrees/github/t3-2759772e-28fc4dd8bb0e4d8b/savia/tools/db/restore_proof.py) | 104a507cf8b948ea23cff061d0ee8f8d21d1609f |
| [F: V008](C:/Users/Jason/.t3/worktrees/github/t3-2759772e-28fc4dd8bb0e4d8b/savia/db/migrations/V008__sync_foundation.sql) | 0d1497ce047ff254678c46f8c950eac3d71078d8 |
| [T: V009](C:/Users/Jason/.t3/worktrees/github/t3-2759772e-28fc4dd8bb0e4d8b/savia/db/migrations/V009__credit_transfer_transitions.sql) | 88ddeb0779e65257445a808ec5f05122991af95b |
| [O: V028](C:/Users/Jason/.t3/worktrees/github/t3-2759772e-28fc4dd8bb0e4d8b/savia/db/migrations/V028__usd_change.sql) | 85d7b77370062d5a4128f2d6bc203d22138cab4d |

Git trees: migrations 9b6f7739c28708c35324b113f98de307f922eb2d; sync-tests 2e3916340d3a10f92eebad85120627fe4877d6b6; src d9eb41c4cc9e04814d0bbc3069eece60548a0cd1.

## Material findings and next corrections

1. **P0 implementation: recovery is not enforced.** S:99,283–295 uses an in-memory blocked set; S:503–506 toggles it manually. T:170–256 and O:34–271 do not bind writes to sync.LocalNode or durable recovery state. F:103 classifies recover, but S:210 treats it as an ordinary full upload. F:132 accepts any changed fork. Add persistent quarantine, receiver ownership/epoch validation and controlled recovery completion. Test wrong-owner writes, restarted processes and old-fork replay. S:516 explicitly accepts losing an unsynchronized sale. Reopening afterward can resell physically departed stock; cloud rebuild alone cannot recover that tail.

2. **P1 implementation: current simulator builds invalid DML.** O:5 adds computed SaleTenders.ForeignChangeNioMinor. S:155 excludes only rowversion/timestamp; S:236–245 writes every remaining column. Exclude computed columns from writes and verify resulting values. This is a direct source defect; its SQL error was not executed here.

3. **P1 oracle defect: remote sale does not require a local outbox event.** [ADR:72](C:/Users/Jason/.t3/worktrees/github/t3-2759772e-28fc4dd8bb0e4d8b/savia/docs/adr/ADR-001-arquitectura.md:72) separates state transport from outbox. O:371–384 nevertheless requires one event for every replicated POS sale. Replicating or fabricating events to satisfy this check risks duplicate side effects. Separate local-origin event durability from distributed money/stock checks. Define restored-origin event provenance separately. Missing remote outbox alone is not conservation failure.

4. **P1 implementation/coverage: eighteen tables are insufficient for current operations.** S:44–63 omits ExchangeRates, CashClosures, ReturnSettlements and StockExceptions. [V027:14](C:/Users/Jason/.t3/worktrees/github/t3-2759772e-28fc4dd8bb0e4d8b/savia/db/migrations/V027__usd_cash.sql:14) adds a tender→rate FK; O:440–443 and 486–500 require closure/settlement rows. Extend dependency coverage or explicitly bound the first proof to NIO cash, credits and ordinary stock. T:515–520 lets destination B exhaust an issuer-A credit; S:50,198 filters that change out. Test final exhausted status after A/B consumption; derive status consistently instead of silently losing this write.

R:50–98 checks fork classification on restored till rows when executed; it does not implement financial recovery. No simulator runtime is attributed to this review.

5. **P0 delivery gap: no production sync transport found.** [Endpoints:54](C:/Users/Jason/.t3/worktrees/github/t3-2759772e-28fc4dd8bb0e4d8b/savia/src/Savia.Api/Endpoints.cs:54) and [registration:18](C:/Users/Jason/.t3/worktrees/github/t3-2759772e-28fc4dd8bb0e4d8b/savia/src/Savia.Infrastructure/ServiceRegistration.cs:18) expose no sync endpoint/worker; targeted source searches found only SQL cursor helpers and simulator transport. A simulator PASS cannot close this gap. Primary must scope actual transport and repeat its critical path.

Existing protections are visible: transactional transfer debits, duplicate-leg constraints and atomic row/cursor application (T:91,170–256; S:224–256). Distributed retry, recovery and concurrency evidence remains missing.

## Minimum contract for primary adjudication

Extend existing scenarios, not another runner. Freeze expected operation IDs and opening balances before actions. S:283 swallows business errors; S:420 ignores sale results. Require each expected success/error explicitly. Compare logical records per database; never add four replicas as four businesses.

1. **Offline sales:** hub plus A/B/C; disconnect all branches. Each posts one NIO cash sale, quantity 1, total 120000. Retry identical SaleId; altered payload must reject 51510. Reconnect in differing order, repeat delivery and lose acknowledgement. On each replica require three sales, three lines/tenders/cash entries, total 360000, stock movement −3 and each location opening stock−1. Preserve origin events once; remote events need not exist.

   Create #expected(Id uniqueidentifier PRIMARY KEY) with the three predetermined sale IDs before execution. Missing rows must fail, including NULL aggregates. Execute:
~~~sql
IF (SELECT COUNT(*) FROM sales.Sales s JOIN #expected e ON e.Id=s.Id)<>3
 THROW 59001,'Required sales missing',1;
IF (SELECT COALESCE(SUM(t.AmountMinor),0) FROM sales.SaleTenders t JOIN #expected e ON e.Id=t.SaleId)<>360000
 THROW 59002,'Tender total changed',1;
IF (SELECT COALESCE(SUM(m.OnHandDelta),0) FROM inventory.StockMovements m JOIN #expected e ON e.Id=m.SourceId WHERE m.SourceType='sale')<>-3
 THROW 59003,'Sale stock changed',1;
~~~
   For each ID, require exactly one line, tender, sale movement and cash entry. Assert line/tender/cash totals120000, quantity1, movement−1. Compare three pre-recorded location/item/store balances against opening−1. Run corrected CONS and owner-row equality afterward.

2. **Atomic replay/cursors:** inject failure between row application and cursor advancement; both must roll back. Replay identical captured payload twice. Apply newer then older same-fork payload; require rejection without row/cursor changes. Replay an obsolete fork after recovery; require rejection. Force real CT retention expiry and prove reinitialization preserves owner rows. Literal classifier tests alone do not exercise these paths.

3. **Credit/cancellation:** original120000; dispatch50000 A→B, retry dispatch/receipt. Before receipt: A70000, B0, transit50000; afterward A70000, B50000, transit0. Require exactly one debit and credit leg. Offline dispatch beats cloud cancellation; cancellation already observed by A rejects 51726. Redeem A70000/B50000: redeemed120000, allocations0, transit0, exhausted status. Race two 50000 spends against A70000: exactly one succeeds. Race two sales against one stock unit without exception note: exactly one succeeds, rejected transaction changes nothing. Reject impersonated origin writes on another branch database.

4. **Restore:** backup A before dispatch, then synchronize dispatch/receipt and sales. Restore and restart; block sale/redeem/dispatch and upload before recovery, even without cloud connectivity. Recover authoritative state, repeat recovery, verify A70000 rather than old120000. An unsynchronized tail needs durable recovery or explicit reconciliation before reopening; deliberately lost sale is failure, not PASS.

5. **Independent negative control:** suppress one mandatory sale while retaining internally balanced rows. R1/CONS may agree; assertion59001 must fail. Reuse transfer-leg corruption checks; restore_naive must fail a named amount/stock predicate, not merely crash on computed columns/outbox.

Reuse [SQL tests](C:/Users/Jason/.t3/worktrees/github/t3-2759772e-28fc4dd8bb0e4d8b/savia/db/tests): sync/100–140; audit/010,020; credits/090,110,120,140,150. Reuse [concurrency assertions:34–69](C:/Users/Jason/.t3/worktrees/github/t3-2759772e-28fc4dd8bb0e4d8b/savia/tests/Savia.Tests/ConcurrencyTests.cs:34) through two concurrent SQL operations in the bounded simulator packet. Existing single-database tests do not prove replication.

## Future runtime packet — separate authority required

Owner: primary-assigned runtime worker. Exclusive container **savia-sqlserver-cp4-63a8b1e-20261116-01**, task-ID ownership label; abort on name collision. No published ports, network, mounts or reusable volumes. Use --network none, --restart no, --memory 3g, --cpus 2 and a fresh nonlogged password. Fresh disposable storage only. Express image:
mcr.microsoft.com/mssql/server@sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718.
Python3.11.9, standard library; sqlcmd18 bundled in pinned image. Missing dependencies require a separate decision.

Set SAVIA_SQL_CONTAINER=savia-sqlserver-cp4-63a8b1e-20261116-01 before importing D. Never run D up or existing compose files. Fixed SAVIA_SIM_cloud/a/b/c and /var/opt/mssql/data/SAVIA_SIM_a_old.bak remain inside this exclusive container; D also creates its hash-named template/test databases.

Pin corrected commit/LF hashes. Run focused tests individually with:
~~~text
python savia/tools/db/saviadb.py test <listed-test-prefix> --jobs 1 --json
python savia/tools/db/simulator.py scenario <basic|cancel_vs_dispatch|restore|restore_naive> --seed 1
~~~
Require each positive test PASS, not XFAIL. One attempt per case, 20-minute cap, stop on unexpected failure. Capture terminal RESULT, exit code, semantic SQL rows and cursor/fork readback. Finally use docker rm -f with the captured, label-verified container ID only; confirm container/storage absence and unchanged preexisting resources. Record cleanup failure explicitly.

**NOT RUN:** SQL, Docker, services, APIs, suites, probes (0/2), production transport or deployment. No canonical-log access. Only this report is authorized output.

**Next action:** primary adjudicates findings and freezes these controls before assigning corrections and a separately authorized runtime. Lesson: expected business actions must remain independent of the transport's table list.

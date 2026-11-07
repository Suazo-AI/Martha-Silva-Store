# Parallel local SQL validation

Mode: VALIDATE. Status: prepared for dispatch, not executed. Production: **NO-GO**.
Owner: primary. Executors: temporary authorized Codex `gpt-6.1-sol/high`. Sole judge: `gpt-6-astra/xhigh`.

## Authorization and frozen scope

Jason instructed: ??Por qu? es que no pod?s trabajar en esos casos de SQL en paralelo? Si lo pod?s hacer, hacelo para que avances en eso tambi?n de un solo?.
This authorizes the currently omitted 67 SQL cases in parallel on isolated local fictitious test resources.
The published commit containing this document is frozen in each worker packet before execution.
[Exact disjoint method inventory and source bindings](SQL-PARTITIONS.json).

| Owner | Cases | Scope | Exclusive loopback port |
|---|---:|---|---|
| business worker | 39 | cash, commerce, supply, runner, physical-stock exception | 14338 |
| security worker | 28 | security, branch isolation, HTTP acceptance/N8, judge, release/backup/restore/restart | 14339 |

Each worker uses a tool-managed worktree and its own disposable SQL Server container.
Each test creates fictitious named databases inside that worker's server. No shared mutable databases.
The tests that create deliberate concurrent requests retain those requests together.
Only the security worker stops and restarts its own container after its initial 27 cases pass.

## Verified prerequisites

Host `SUAZO-PC`; Docker Server `29.7.2`, Docker memory 16,550,318,080 bytes.
Cached SQL image: `sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718`.
Native SDK `10.0.402`: `C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe`.
Ports 14338/14339 were available at preflight; each worker must recheck before start.
No SQL image pull, SDK/browser installation or new runner image is needed.

## Execution and ownership limits

- One SQL container per worker, exact cached image, unique `savia-sql-<partition>-<suffix>` name and ownership label, captured container ID.
- Publish SQL only at `127.0.0.1:<owned port>:1433`; no volumes or persistent host mounts. Limit each container to 2 CPUs and 2 GiB RAM.
- SQL Server 2022 Developer uses the existing test EULA convention. Generate one ephemeral password per owned server; keep it and raw connection data private.
- Use encrypted connections with test-only certificate trust for that owned server. Do not change Windows certificates, native SQL or global trust.
- Only child processes receive SQL environment variables and authorization flags. Precreate a private `SAVIA_PILOT_EVIDENCE` directory.
- One locked restore, one Release build, one execution per assigned method. Use exact method filters and retain source bindings. No automatic retry after SQL/test failure.
- Readiness polling is bounded to 120 seconds. Maximum owned-container lifetime: 25 minutes per worker. Maximum worker wall time: 35 minutes.
- Security runs 27 methods first, then reads its own successful release receipt, restarts only its captured container and executes the remaining restart method once.
- Capture and sanitize failing assertions before cleanup; keep raw TRX/logs/passwords only in ignored private exports. No public credentials or full SQL dumps.
- Finally stop/remove only the captured container after confirming its ID and ownership label. Verify absence even after failure. Do not prune or remove unrelated resources.
- Evidence-only worker writes: `docs/sql-parallel-20261107/<partition>/` and ignored private exports. No product/source edits, staging, commit, push or workflow dispatch.

This scope does not authorize native SQL/SAVIATEST, certificate changes, account changes, production data, golden-browser runtime, deployment or merge.
The rejected custom local runner is not used. Direct native `dotnet test` plus owned Docker SQL is the authorized route.
Its remaining Windows reader-lock/receipt defect is independent work owned by primary; it does not block these direct SQL tests.

## Completion checks and handoff

Each partition needs exact assigned method multiplicity, unique result identities after GUID case normalization, zero failures/skips/extras, source SHA, commands/exits and owned-container cleanup readback.
A failed case is evidence, not permission to edit tests or retry. Preserve its exact assertion and return it for diagnosis.
Backup/restore and restart results are separate claims. Browser-to-API-to-SQL and staff cash UI remain unproven by this run.
Primary imports evidence serially and assigns Astra/xhigh independent review. Worker return is not primary acceptance.
Next event: two asynchronous worker returns; the harness wakes this primary.

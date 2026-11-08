# Parallel local SQL validation

Mode: VALIDATE. Status: business 39/39 verified; security 23 passed, 4 failed, 1 not run. Correction under review. Production: **NO-GO**.
Owner: primary. Executors: temporary authorized Codex `gpt-6.1-sol/high`. Sole judge: `gpt-6-astra/xhigh`.

## Authorization and frozen scope

Jason instructed: "¿Por qué es que no podés trabajar en esos casos de SQL en paralelo? Si lo podés hacer, hacelo para que avances en eso también de un solo".
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

## Business return: primary verification

The worker completed one local real-SQL invocation: **39/39 Passed**, zero failures/skips.
Primary mapped the original private TRX definitions to the frozen 39-method inventory and normalized result UUIDs.
There are no duplicates, missing methods, extra methods or multiplicity differences.
Eight LF source bindings, 19 private artifact hashes, public per-method outcomes and restore/build/test exits agree.
Primary independently confirmed the captured owned container is absent. No SQL tests were repeated.
[Worker evidence](business/README.md) and [primary verification/import receipt](PRIMARY-BUSINESS.json).

Security28 is awaiting its existing delegate completion notification; it is not counted as passed.
Next: verify that return, then request one combined Astra/xhigh review.
The rejected custom runner and the real browser/cash journey remain separate unfinished work. Production stays **NO-GO**.

Source-commit CI readback: all four automatic workflows completed successfully on `f9ffa452bae7fc11a4a578ce24b57ecb72add139`: progress digest `42426525692`, staff candidate/no SQL `42426525693`, progress documentation `42426525641`, source snapshot `42426525649`.
The first shell query printed results but exited 1 because a `.cmd` wrapper split `&per_page`; one corrected single-parameter query exited 0.
This is source-commit evidence, not CI for the forthcoming documentation commit.

Integrated documentation check: `python tests/check.py`, exit 0, 212.078 seconds. Private log SHA256 `04d8f822373343e402fba10851d1a6e938250c051a293c68578cfd6e53a7c5d5`.
Lesson: exact method/results mapping and owned-resource readback close this partition; a green worker label alone does not.

Registry update: only CASH-REGISTER prep/review changed; its pending status and production gates remain.
`python tests/test_progress.py`: 23/23, exit0, 113.047s; `python tools/export_progress.py --verify`: 15 preserved hashes; `python tools/delivery_status.py --check`: valid 40 items.
[Next independent source review: staff cash workflow](../cash-register-20261107/ui-preparation/PLAN.md). No UI code was changed.

## Security return and primary correction

Primary verified the original TRX: 27 exact initial methods, 23 passed, four failed, zero skipped or duplicate identities.
All eight frozen source bindings and 27 private artifact hashes match. The owned container is absent.
[Primary verification](PRIMARY-SECURITY.json) and [worker evidence](security/README.md).

Two fixture hosts lacked Cash service registration. Two release tests stopped at the cash-schema oracle before backup.
SQL Server emits integer constants with a trailing decimal point and prefix `NOT ... LIKE`; the limited oracle rejected these forms.
The correction changes tests only. Fresh offline evidence: six failures/28 passes, then 34/34 passes.
The wider offline run passed 641 cases; 67 SQL cases were not executed.
[Correction, source bindings and remaining gates](security-correction/README.md).

Backup, restore, controlled restart and the corrected SQL cases remain unproven.
Primary prepares the frozen candidate for Astra/xhigh review before requesting a new bounded SQL execution.

# Rehearsal baseline 2026-11-21

Result: 5 scenarios PASS and the recovery-lock red test fails as expected (XFAIL); all negative controls fail as designed; the self-test catches a missing sale.
The restricted SQL identity fails, so every scenario ran as `sa`.

Source: worktree at `155ca23bd7d0ed6a9f3f53407312b25f5217f787` plus the uncommitted rehearsal files (final version), run from the repository root.
An earlier full run on a previous harness version gave the same verdicts (5 PASS, 1 XFAIL) with shorter times (96-216 s per scenario); timings vary with host load.
Host: Windows 11, Docker SQL Server Developer (`savia-sqlserver-rehearsal`, pinned digest), .NET 10.0.402, sync interval 5 s.
How to run and what it proves: [REHEARSAL.md](../../sync/REHEARSAL.md).

## Commands

| Command | Exit | Result |
|---|---|---|
| `python savia/tools/rehearsal.py run all --identity auto` | 0 | `offline_sales=PASS replay=PASS credit_transfer=PASS restore_sale_before_rebuild=XFAIL hub_restart=PASS controls=PASS` |
| `python savia/tools/rehearsal.py selftest --identity sa` | 0 | `SELFTEST PASS: run verdict FAIL; failed checks 8` |
| (probe inside `run all`) | - | `restricted FAILS; scenarios run as sa`, with the SQL repro |
| `python savia/tools/rehearsal.py down` | 0 | `rm 0 savia-sqlserver-rehearsal`, `volume rm 0 savia_rehearsal_sql_data` |
| `python -m unittest discover -s tests -p "test_*.py"` (from `savia/`) | 0 | 56 tests OK, 15 of them in `test_rehearsal.py` |

## Scenarios

| Scenario | Verdict | Total s | Checks pass/fail | Key timing | Manifest sha256 |
|---|---|---|---|---|---|
| `offline_sales` | PASS | 203.8 | 61/0 | 6 offline sales; hub held 0; converged 30.8 s after the hub returned | `c73bcb360330` |
| `replay` | PASS | 158.3 | 46/0 | both kill points fired after hub 200; hub held ra1 while A was dead; B held 0 of ra2; converged in 14.9 s | `06936c6d50d2` |
| `credit_transfer` | PASS | 338.5 | 88/0 | t1 round trip 82.4 s (4 hops 8-27 s each); concurrent spend: one 200, the other 409 `credit.insufficient` (sy won this run, sx in the earlier one); offline dispatch after cancel converged in 26.2 s | `b880288d6265` |
| `restore_sale_before_rebuild` | XFAIL | 183.3 | 33/5 | rebuild refused from the first round; not converged after 62.5 s; no failure outside the 5 pinned | `7cbaf0b223ba` |
| `hub_restart` | PASS | 127.2 | 51/0 | hub held h1 committed before the crash; converged 19.4 s after restart | `e2aacdd445ef` |
| `controls` | PASS | 149.5 | 48/0 | see below | `fbcf19f87f79` |

First convergence after start took 25-39 s per scenario in this run.

## Negative controls

| Control | Expected | Actual |
|---|---|---|
| real node secret (positive control) | 200 | 200 |
| wrong secret | 401 `sync.unauthorized` | 401 `sync.unauthorized` |
| A's id with B's secret | 401 `sync.unauthorized` | 401 `sync.unauthorized` |
| no Authorization header | 401 `sync.unauthorized` | 401 `sync.unauthorized` |
| A's push names store B (51851) | 403 `sync.foreign_row` | 403 `sync.foreign_row`; store log `Sync round refused: sync.foreign_row` |
| restored fork pushes without a rebuild token (51854) | 409 `sync.rebuild_required` | 409 `sync.rebuild_required`, then `Sync round: pulled 0, pushed 0, rebuilt True.` |
| self-test: expected sale never made | run FAIL on that sale only | FAIL in 172.9 s; 8 checks, each `selftest_missing` or `store b totals`, on all 4 nodes |

## Findings

1. Recovery lock (red, XFAIL).
   A restored from a backup taken before its till opened accepts sign-in, a new till (204) and a sale (200) before its rebuild.
   When the link returns, every round logs `Sync round refused: db.duplicate El registro ya existe.` and A never converges.
   The hub has till `…A0` open on register `A0000000-…-0000000000A3`; restored A has till `…A1` open on the same register.
   The same rebuild pull in SQL fails with `Msg 2601: Cannot insert duplicate key row in object 'sales.CashTills' with unique index 'UX_OpenTill_Register'`.
   The API maps 2601 to the generic `db.duplicate`, so the store log does not name the index.
   The XFAIL is accepted only when the SQL error names `UX_OpenTill_Register` and no check outside the 5 pinned failures fails.
   The two conservation pins (`sale.outbox_event` for r1/r2 on A) are reported missing because the rebuild never completes.
   This baseline therefore does not evidence the outbox-event finding; it was seen in an earlier development run and is pinned in `tests/Savia.Tests/SyncWorkerTests.cs:173`.
2. Restricted identity.
   The four hosts start and serve HTTP (`http_login_and_open_till` 204) as a login that is only in `savia_api_host`, but every sync round is refused with `db.error`.
   Replaying one pull and one push as that database user (`EXECUTE AS USER`) fails on both sides; the denied INSERT points to `sync.usp_ApplyBatch`, but the repro does not isolate the procedure: `Msg 229 ... The INSERT permission was denied on the object 'CashTills', database 'SAVIA_SIM_R_a', schema 'sales'` (pull) and the same on `SAVIA_SIM_R_hub` (push).
   `sync.usp_GetNodeCredential` succeeds.
   See `identity_probe.json`.
3. A restored store loses sessions: the old token returns 401 `auth.required`, and the cashier signs in again.
   This is recorded as expected behaviour, not a defect.

## Limits

- Localhost only; no load.
- Two full runs; flakiness beyond that is unknown.
- Credit transfers run through the SQL procedures (`sql:no-http-route`).
- Host logs are in `.out/rehearsal/runs/` (gitignored) and were removed with the container.

## Rerun as the restricted identity (2026-11-21, after V035)

`python tools/rehearsal.py run all --identity restricted` on Tony with V035 applied: exit 0.
Every scenario ran as a SQL login that is only in role `savia_api_host`; no fallback to `sa`.
`offline_sales`, `replay`, `credit_transfer`, `hub_restart`, `controls`: PASS. `restore_sale_before_rebuild`: XFAIL (recovery lock, G6).
Transcript: [run-identity-restricted.txt](run-identity-restricted.txt). The scenario JSON files are from this run (`"identity": "restricted"`); the first run as `sa` is in git history. `identity_probe.json` (Msg 229) predates V035.

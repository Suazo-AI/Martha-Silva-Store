# ACCEPT WITH LIMITS — F1–F3 preparation corrections

Task: `savia-real-cash-proof-recheck-9d01fb6-20261108-01`.
Mode: VALIDATE; sole independent judge. Primary retains final acceptance and integration.
The concrete F1–F3 defects are corrected at the frozen candidate. No material unresolved finding within this recheck.
This accepts source preparation and bounded offline proof only. Production remains **NO-GO**.

## Identity, authority and source

Verified HEAD: `9d01fb66caf9f5a94561b909bb34529a954126e0`.
Immediate parent: `3cc608751628264deb6b88aa931d41d4310a105b`.
Original rejected preparation: `990e23a1bac2ef06e40df12ed87a1569586c9b2c`.
Managed worktree: `C:/Users/Jason/.t3/worktrees/github/t3-b20b5bc2`; branch `t3/b20b5bc2`.
Initial state and pre-report state were clean. No other agent's checkout was inspected.
Requested and exposed execution: Codex `gpt-6-astra`, reasoning `xhigh`, T3 Code/Codex harness, host `SUAZO-PC`.
Identity comes from runtime instructions and agent-awareness, not independent provider attestation. Usage/cost unknown.

Read repository instructions, affected sources, original rejection, correction manifests, preparation and review status.
Read canonical orchestration, PROTOCOL, OUTPUT, task-completion, evidence-first and coordination rules.
Agent-awareness ran at entry, before scratch writes and before this report. No denied read occurred.
A console `UnicodeEncodeError` was resolved with `python -X utf8`; a Windows wildcard-path error was resolved with a literal directory search. Neither was an access denial.

Independent byte verification passed:

- **10/10 PRIMARY bindings** match HEAD Git blobs and working files after replacing CRLF with LF only.
- **4/10 RAW hashes** match PRIMARY directly. The other six differ solely through checkout newline conversion; their normalized bytes match exactly.
- **6/6 imported files** match IMPORT's exact RAW Git-blob hashes and LF hashes.
- **8/8 worker candidate/read-only LF bindings** and **7/7 recorded original Git-blob bindings** match. The eighth file is the new regression file.
- Worker README's recorded hash matches. RESULT and README bind through IMPORT; source bindings bind through PRIMARY.
- Relevant source/workflow diffs are identical against the original and immediate parent.
- Product roots `src`, `build-inputs`, `dist`, `dev/savia-staff-ui`, `backend/src`, the SQL helper directory and browser driver have zero diffs against both bases and the working tree.

RAW means exact bytes; LF means CRLF-to-LF replacement only. No whitespace, encoding or content normalization was applied.
Worker private logs were not accessed in another checkout. Their prior verification remains primary evidence, distinct from this review's fresh checks.

## Findings adjudicated

**F1 — closed.** `tests/golden-path/verify_evidence.py:44–62` validates cash discriminators before selecting a publication branch.
Either cash discriminator requires browser mode and `real-cash-v1` on both fields.
Missing mode, smoke downgrade, missing/conflicting protocols and invalid outcomes reject before copying evidence.
Complete cash PASS, historical smoke, partial FAIL and partial STOPPED export exact approved bytes.
An incomplete PASS cannot use the failure-export branch.

**F2 — closed for the frozen checks.** `tests/golden-path/golden_path.py:139–198,425–438` applies shared checkpoint admission during publication.
All 31 ordered checkpoints require their admitted DOM, network and counter fields.
Startup runtime and the complete eight-resource local map are mandatory; the cashier-login served map must match.
`verify_evidence.py:67–81` binds that map and runtime to run metadata and requires typed independent oracle counts.
The unchanged driver emits local hashes at startup and served hashes at login (`browser_path.mjs:233–248`).

Recovery sale identity binds to command index 2 at loss, recovery and repeated reload; loss/recovery keys bind to the same command (`golden_path.py:464–472`).
Repeated reload legitimately emits no key; no new receipt-redisplay requirement was introduced (`browser_path.mjs:327–333`).
Shared admission rejects unauthorized network paths, including successful staff creation.
Cleanup requires a terminal integer API result (`verify_evidence.py:73–76`); absent, null, boolean, float and string results reject.
The independent positive control accepted `api_exit=-15`. Zero exit was not imposed on an intentionally terminated API.

**F3 — closed.** `golden_path.py:306–318` checks returned quantities and derives sale state from every line.
Both refunds correctly leave the original two-line sale `partially_returned` while its other item remains unreturned.
This agrees with the unchanged product contract (`InternalCommerceService.cs:155–158`).
`golden_path.py:348–381` preserves unaffected rows and compares complete immutable projections of affected rows.
Only Sales.State, SaleLines.ReturnedQuantity and closing CashTills.ClosedAt are excluded from their respective projections.
The unchanged helper reads complete persisted rows, including nulls (`GoldenPath.Sql/Program.cs:314–324`).
Both refund pairs rejected immutable-field mutations and incorrect states. Recomputed row hashes prevented stale hashes from becoming the rejection mechanism.
Both close pairs passed; changing the closing till's OpenedAt rejected specifically as `cash_immutable_row_changed`.
Unreturned line, prior close and other-cashier till corruption also rejected.

**CI wiring — accepted as source configuration.** Automatic staff push filtering includes the new evidence test (`.github/workflows/staff-ui-candidate.yml:18`); its offline guard executes it at line 48.
Both cash files run in the golden workflow's offline guard (`.github/workflows/golden-path.yml:61–62`).
The workflow diffs contain only those four added lines. Inputs, permissions, deadlines and runtime commands remain unchanged.
This does not qualify the existing golden workflow's real-runtime path or authorize dispatch.

## Fresh checks

Exactly **two focused offline test/probe invocations**; no passing suite was repeated.

1. `python -m unittest discover -s tests -p 'test_golden_path_*.py' -v`: **102 tests, zero failures/errors/skips**, exit **0**, 4.455 seconds reported by unittest.
2. `python -X utf8 private-exports/astra-cash-recheck-9d01fb6/probe.py`: exit **0**. Four valid exact-byte exports; 53 semantic rejections with empty destinations. Four valid refund/close pairs; 45 row-mutation rejections after recalculating hashes.

The independent probe imports the actual modules and uses synthetic fixture data. It requires specific semantic errors for targeted admission, recovery, state and projection cases.
It supplements, rather than recounts, the 102 test methods.
Git identity/diff checks and the stdin binding verification exited **0**; focused `git diff --check` exited **0**.
Temporary fixtures stayed under ignored `private-exports`; no product/test source was edited.

Private evidence under `private-exports/astra-cash-recheck-9d01fb6/`, SHA256 RAW:

| File | Hash |
| --- | --- |
| `suite.log` | `c42703b1c8b0bc3be4471423d9cebeec4ef767e582f260d9aed1d8140662b453` |
| `probe.py` | `25247975b81350a61933e098936e23ad5d82b7f14030367a4890935deb342571` |
| `probe.log` | `d74934eb1aa6e29bd2b861ad930f94a492a66a08e8967be462fc00a50a8ea49b` |

Lesson applied: positive controls and refreshed row hashes distinguish semantic rejection from incidental fixture failures.

## Limits and next action

Worker final original-code replay remains **21 tests, 29 failing assertions, exit 1**; corrected worker groups remain **21+35+41+5=102** passes.
Earlier failed attempts are separate records, not part of those final totals. This review did not replay the old candidate.
Primary's repository check, exit 0 in 188.875 seconds, was not repeated.
Historical Linux CI on `990e23a` does not qualify corrected HEAD.

Current-SHA CI status is supplied by primary, not independently queried here: docs `42444860573` and digest `42444860536` succeeded; staff `42444860558` and snapshot `42444860537` were **in_progress**.
No pending job is claimed passed. Network/CI queries were prohibited.

REAL-CASH-01–06 retain their prepared source contracts with the corrected evidence/preservation gates; REAL-CASH-07 passes this bounded offline recheck.
None establishes real transactions. Browser/API/SQL execution, C# build, accounts, services, Docker, Owner recovery and populated Cash backup/restore/restart were **NOT RUN**.
No install, host-policy mutation, staging, commit, push, merge, deployment or nested delegation occurred.
SQL5 remains **D: REVIEW FIRST, DO NOT EXECUTE**.

Next owner: **primary**. Read this report, retain the exact candidate binding, and obtain terminal readback of the two pending exact-SHA CI jobs before closing preparation acceptance.
Real runtime remains a separate Jason authorization gate: freeze the execution host, source, deadlines, owned resources and cleanup plan first.
No runtime correction was attempted because this review expressly excludes runtime. Its eventual completion requires authorized browser→API→SQL proof and cleanup readback, not another offline PASS.

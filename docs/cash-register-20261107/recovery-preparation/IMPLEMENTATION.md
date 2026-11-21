# Populated cash recovery: bounded implementation

Primary decision: accept the source-only recommendation in [Astra's review](astra-preimplementation.md).
Source reviewed: `43ce576020100b7d2f9262bfa359f824b86f3b0a`.
Report SHA256: `f725c026120eac1b4e22165cbb1ffaaea9f0f8d5afbb2869cf63b353e802a770`.
Primary independently verified all seven Git/source bindings and inspected the existing recovery assertions.
This accepts the preparation scope. It does not accept an implementation or authorize runtime.
SQL5 remains **D: REVIEW FIRST, DO NOT EXECUTE**. Production remains **NO-GO**.

## Outcome and frozen checks

Extend `PrivatePilotReleaseTests`. Preserve the existing migration, schema and rejection checks.
Do not change product code, money rules, golden-path guards or database cleanup.
The worker must implement A1-A6 from the review, with these primary clarifications:

| Check | Required behavior | Primary decision |
| --- | --- | --- |
| A1 | Two cashier shifts; a cash sale; a Manager refund from the later shift; two counted closes | Accept. Use real cash services and the shared runner in the migrated, owned fixture database. Preserve the four legacy records by explicit identity. |
| A2 | Independent amounts, exact identities and cardinalities | Accept. Shift A: 10000 + 2500 = 12500; counted 12400, difference -100. Shift B: 2000 - 1250 = 750; counted 750, difference 0. The prior close must remain unchanged. |
| A3 | Immutable baseline of all 23 internal tables and schema facts | Accept. Use lossless typed values, explicit nulls and duplicate-preserving row hashes. Include Operations and Sessions. Keep raw sensitive values private. Never rebuild expected rows after restore or restart. |
| A4 | Actual backup, verified restore and real restart of the same owned container | Accept as future runtime criteria. Preparation must reject incomplete or mismatched receipts. No SQL or container action is authorized now. Manual approved orchestration may supply receipts; do not create another runner. |
| A5 | Comparator and admission negative controls | Accept. Reject each named corruption in the review, including a no-op restart. Passing offline controls proves checker behavior only. |
| A6 | Six selected SQL methods, then the deferred restart method | Accept as a proposal. Keep exact names from the existing runtime plan. No full historical rerun without a concrete affected path. Primary must verify equivalence before reusing historical passes. |

Expected cash footprint: two tills, four cash entries, two closes, one sale/line and one reversal/line.
Require six successful cash operations and final fixture stock 2, reserved 0.
Use consistent fixture time for security, runner and cash services.
Keep the original close byte-identical before and after the later refund.

## Execution boundary

One Sol/high worker owns the two existing recovery methods, small C# test helpers and focused offline tests.
The worker may compile and run focused offline tests using existing SDK/cache only.
No downloads, installations, SQL connections, Docker/container actions, accounts, services, certificates or policy changes.
An operating-system denial is a blocker to report, never a reason to bypass the control.
No source changes outside test preparation. No stage, commit, push, workflow dispatch, merge or deploy.
Primary owns serial integration, independent Astra/xhigh review and publication.

Completion for this preparation means reviewed source, focused offline positive/negative evidence and compiled final helpers.
Actual backup/restore/restart and persisted-row equality remain separate, required runtime evidence.
If a local build is blocked, return exact diagnostics and mark compilation NOT VERIFIED.

## Runtime prerequisites checked by primary

Read-only Docker metadata confirms Linux Engine 29.7.2 on SUAZO-PC.
The cached SDK image is `sha256:747cbade5bfd918a175ac32f8f1d931edec2c7d0d5397a3de72eaef1ac1f66d2`.
The cached SQL image is `sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718`.
No cached SAVIA/Playwright/Chrome runner image appeared in the filtered image inventory.
Native Node 24.18.0 and Python 3.11.9 do not qualify the Linux PTY/browser environment.
The historical Dockerfile deliberately stops at `PREPARATION_INCOMPLETE`; it is not an executable fallback.
The SQL fixtures and browser journey can use separate qualified environments. Browser dependencies do not require repeating unaffected SQL cases.
The image/dependency proposal remains pending; no image was built or package installed.

## Store sheet exports (2026-11-11)

Two spreadsheets the store used to keep by hand now come out of the system, from recorded facts only:

| Export | Route | Content |
| --- | --- | --- |
| Reception note | `GET /internal/api/supply/reception-note.csv?from=&to=` | per received line: date, order, barcode, item, quantity, unit cost, total, **pending**, currency, order state, who received, fingerprint |
| Closing report | `GET /internal/api/cash/closing-report.csv?from=&to=` | per till: opening, sales, refunds, expected, counted, difference, state, who closed, who was the cashier; plus a total row per currency |

Both are read-only, both respect the branch scope of the caller, both are semicolon separated with a
byte order mark so a spreadsheet opens them with the locale already set, and neither adds a
dependency. The closing report is restricted to Owner and Manager. The proofs assert quantities,
pending amounts, the receiver and the fingerprint against the real database, and a ten cent shortfall
between expected and counted money. The frozen route inventory was updated to name the new read and
its authorization.

## Verification and continuation

Primary import check: report SHA256 and seven source bindings PASS; exact report bytes preserved.
GitHub readback: three documentation/snapshot workflows succeeded on `43ce576020100b7d2f9262bfa359f824b86f3b0a`.
This documentation-only CI result adds no SQL or browser claim.
Documentation verification: `python tests/test_progress.py`, `python tools/export_progress.py --verify` and `git diff --check` each returned exit 0.
Four local documentation links resolved. No product, test or tool file changed during this import.
Continue with the bounded implementation, then freeze and review its actual bytes.
Before any runtime request, complete the exact resource/dependency/deadline proposal in [the local plan](../real-journey/LOCAL-RUNTIME-PLAN.md).

Lesson applied: a restored schema is insufficient proof that money rows survived. Compare populated, immutable records.

Delivery follow-up 2026-11-10: the bounded implementation arrived and is source-reviewed and built by primary; the final offline filter is blocked by Smart App Control (ON). Read [the delivery report](DELIVERY-20261110.md) for evidence, limits and the pending Jason decision.

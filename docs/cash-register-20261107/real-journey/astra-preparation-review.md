# REVISE — real cash preparation

Task: `savia-real-cash-prep-astra-990e23a-20261108-01`.
Independent source/offline review. Primary retains integration and final acceptance.
The browser journey is substantially prepared. Three evidence gaps require correction before accepting preparation.
Actual browser/API/SQL runtime: **NOT RUN**. SQL5 remains **D: REVIEW FIRST, DO NOT EXECUTE**. Production: **NO-GO**.

## Identity and boundary

Reviewed HEAD: `990e23a1bac2ef06e40df12ed87a1569586c9b2c`.
Managed checkout: `C:/Users/Jason/.t3/worktrees/github/t3-574927d3`.
Branch: `t3/review-real-cash-harness`. Initial tracked state was clean.
Requested execution: Codex `gpt-6-astra`, reasoning `xhigh`.
Actually exposed: T3 Code through Codex, `gpt-6-astra` / `xhigh`; host `SUAZO-PC`.
These settings are runtime metadata, not an independent provider attestation.

Read repository instructions, AGENT-START, project status/map/database guidance, frozen preparation, qualification, and relevant direct source.
Canonical orchestration, PROTOCOL, OUTPUT, task-completion, evidence-first and coordination instructions were accessible and read.
No required-source access gap remained. No nested agents or runtime processes were launched.

## Findings

### F1 — P1: changing the discriminator bypasses all cash verification

Source: `tests/golden-path/verify_evidence.py:44-63`.
The entire semantic gate runs only when `mode == 'browser'` and `outcome == 'PASS'`.
The publisher otherwise copies approved bytes without validating the evidence type.

Offline counterexample: start with the existing cash publication fixture, retain `outcome=PASS`, `cash_protocol=real-cash-v1` and `browser.protocol=real-cash-v1`, remove `mode`, and replace `steps` with `[]`.
Recompute the ordinary exact-byte approval manifest.
`publish()` accepts and copies the artifact with no checkpoints, oracles or cleanup.
Changing `mode` to `smoke` also accepts that contradictory cash artifact.
Control: removing one checkpoint while retaining browser mode raises `HarnessError: cash_checkpoint_order`.

Smallest correction: validate required discriminators before branching.
Cash protocol claims must require the complete cash-browser schema; missing or contradictory mode must reject.
Keep any supported failure-artifact export explicit.
Add both bypass cases as negative publication tests.
The manifest protects byte integrity; it does not establish semantic validity.

### F2 — P1: normal browser PASS accepts missing or contradictory proof

Sources: `verify_evidence.py:49-63`; `golden_path.py:135-195,413-465,1457,1578` under `tests/golden-path/`.
Publication validates command arithmetic and selected request counts, but omits the browser checkpoint admission rules and several proof bindings.

Bounded probes using `tests/test_golden_path_cash.py:220-231` as the publication recipe all accepted:

- A complete checkpoint sequence with no DOM evidence, runtime versions or source hashes.
- `browser.recover_after_reload.sale_id` changed to `00000000-0000-0000-0000-00000000270f`, inconsistent with the original command result.
- An additional successful `POST /internal/api/security/staff`, outside the admitted path set, with unchanged zero error counters.
- Cleanup with `api_exit` absent or null.

Each probe used a matching approval manifest and verified destination bytes.
Control: removing the entire cleanup checkpoint rejects with `missing verified owned-resource cleanup`.
Thus some cleanup checks work, but API termination proof is optional.

The live driver does check recovery identity and served resources (`browser_path.mjs:327-333`; `golden_path.py:1457`).
The publisher does not preserve those guarantees when evidence is incomplete or internally contradictory.
The existing positive publication test explicitly accepts the incomplete synthetic schema (`test_golden_path_cash.py:224-232`).

Smallest correction: apply a shared sanitized-checkpoint schema during publication, require the recorded runtime/source bindings, and compare served hashes to the run's source map.
Bind recovered sale/key fields to the original command and require a recorded terminal API result.
Validate every network entry against the admitted protocol.
Add separate negative controls for each case; retain current passing arithmetic and duplicate-effect controls.

### F3 — P2: a refund exempts whole rows from preservation

Sources: `tests/golden-path/golden_path.py:304-310,344-366`; `GoldenPath.Sql/Program.cs:314-319` in the same directory.
SQL captures complete sale and line rows.
During refunds, Python excludes the returned sale and line from old-row equality, then checks only selected fields.
It never checks persisted sale state or preservation of the returned line's SKU/name.

Independent contract: `backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceService.cs:155-158` changes returned quantities and derives sale state.
The original two-line sale must remain `partially_returned` after these refunds because the second article remains unreturned.

Probe: use consecutive `full_snapshot('browser.cash_later_till')` and `full_snapshot('browser.cash_later_refund')` fixtures.
Populate correct original sale states and stable SKU/name fields; recompute affected row hashes.
The valid pair passes.
Changing only the returned line SKU to `CORRUPTED` still passes.
Changing only the original sale state to `cancelled` also passes.
Control: corrupting the unreturned line SKU rejects with `cash_unrelated_row_changed`.

This demonstrates an oracle gap, not an observed product corruption.
Smallest correction: compare immutable projections of touched rows; allow only intended quantity/state changes and derive state from all line quantities.
Extend fixtures with actual persisted columns and the two mutations.
Current fixtures omit these fields (`tests/test_golden_path_cash.py:104-108`).

## Seven frozen checks

| Check | Source-level disposition |
| --- | --- |
| REAL-CASH-01 | Prepared with F3 limitation. Actual UI selectors/routes match. Two articles total 5900; tender 6000; change 100. Persisted actors/tills/lines/payments/stock are checked independently. |
| REAL-CASH-02 | Driver prepared; evidence gate REVISE under F2. Response-stage loss follows HTTP 200, preserves original key/body, recovers through GET and prohibits another sale POST. |
| REAL-CASH-03 | Prepared with F3 limitation. Real Cashier request expects 403 and unchanged business rows. Manager refund links original quantity, reason, authorizer and paying till. Endpoint and command authorization agree. |
| REAL-CASH-04 | Prepared. Independent entry sum expects 20550; counted 20450; difference -100. The shortage survives validation. |
| REAL-CASH-05 | Prepared. Later open till pays 1250; close expects 8750. Earlier closed till, close/ledger rows and second cashier till remain protected. F3 affects original sale-row preservation. |
| REAL-CASH-06 | Prepared. Supply identity/recovery and stock-exception review remain checked. No inventory balance is fabricated for the exceptional item. |
| REAL-CASH-07 | REVISE: F1/F2 admit incomplete or inconsistent proof; F3 leaves persisted corruption undetected. Existing rejection controls remain useful. |

No selector/route/session-role mismatch was found in the inspected cash journey and current product contracts.
Confirmed-receipt redisplay after another reload was not imposed.
Live network restrictions and database/browser ownership checks remain present.
Their runtime effectiveness is untested here.

## Verified evidence and continuation

`git rev-parse HEAD`, `git branch --show-current`, and `git status --short`: exit 0; identity above.
`python private-exports/astra-cash-review/probe.py`: exit 0; publication counterexamples and controls above.
`python private-exports/astra-cash-review/refund_probe.py`: exit 0; isolated row mutations and rejection control above.
Two offline probe processes were used; no full suite was repeated.
Required agent-awareness checks were administrative checks, separate from probes.

The first probe checked all eight `PRIMARY-QUALIFICATION.json` source entries against `git show <source_sha>:<path>` bytes.
Result: **8/8 SHA256 bindings matched**.
Policy: Git blobs are authoritative LF bytes; worktree comparison replaces CRLF with LF only, with no other normalization.
All eight normalized working files matched their blobs exactly.

Primary's 81/81 tests, repository/progress checks and final helper build remain reported upstream evidence; this review did not rerun them.
CI was not queried. Owner recovery was not audited.
No SQL, API/server/browser launch, compiled helper execution, downloads, host changes or Git publication occurred.

Owner of corrections: primary, through the authorized executor.
Next completion check: reject every listed counterexample, preserve the positive controls, then request bounded re-review of corrected source bindings.
No product or test input was edited because this assignment authorizes a report only.
Temporary probes were removed; the sole final changed path is this report.
Its SHA256 is supplied in the handback, outside the hashed file.

Lesson: correct money and checkpoint counts do not prove complete cash evidence.
Validate required proof structure before accepting its numerical assertions.

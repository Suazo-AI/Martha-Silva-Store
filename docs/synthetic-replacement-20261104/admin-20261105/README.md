# Administrative simulation — RETURNED, NOT ACCEPTED

```powershell
python C:/Users/Jason/.t3/worktrees/github/t3-83ae6eec/docs/synthetic-replacement-20261104/admin-20261105/simulate_admin.py --out C:/Users/Jason/.t3/worktrees/github/t3-83ae6eec/docs/synthetic-replacement-20261104/admin-20261105/run-02
```

Actual command above: exit 0. The output already exists; the runner refuses overwrite.
Primary can use a new directory below this folder for independent acceptance.
Worker consumed both permitted full invocations. No further full run was attempted.

12 bounded families passed their declared checks. 325 transitions received an independent invariant bundle each.
350 driver assertions include those 325 bundles, literal cases and control/process checks.
256 generated actions use eight fixed seeds with 32 actions each, plus 16 fixture setup transitions.
The 53 remaining transitions exercise the twelve fixed families.
Five corrupt-copy controls exited 1 with their expected invariant; baseline and restored verifier exited 0.
[Executed result](run-02/RESULT.json), [frozen matrix](MATRIX.json), [pre-implementation checks](ACCEPTANCE.md).

## Identity and isolation

Host SUAZO-PC. T3 Code / Codex; runtime reports gpt-6.1-sol, effective high reasoning.
Agent-awareness independently reported this task/model/high in this managed checkout.
Independent provider telemetry, tokens and provider cost are unavailable; those remain unknown.
Python 3.11.9. No paid API, network request, dependency installation, recursive delegation or external mutation.
Managed worktree `C:/Users/Jason/.t3/worktrees/github/t3-83ae6eec`, branch `t3/admin-recovery-simulation`.
Initial and final HEAD: `6f304a7571a554bb8968e081a14985829aee3dfb`.
Only new files below this folder; tracked diff and staged diff empty at final inspection.
Agent-awareness ran at start and immediately before first edit. Other process activity was unknown;
this assigned worktree/folder is the independent single-writer boundary. No service or port was used.

## Evidence design

`simulate_admin.py` imports the unchanged historical `Model` without executing its historical `run()`.
It reuses sale, receive, return, collection, audit and operation identity contracts.
Historical 18 scenarios / 51 assertions were read and preserved, not regenerated or counted again.
Historical README findings about single-article UI are dated; current multiarticle product already exists.
This simulation adds no product capability.

`Admin` adds only the bounded proposed administrative contracts required for these fixtures.
`oracle.py` does not import Model or Admin. It independently folds declared fixture/actions into expected
cash, transfer, stock, receivable, event payloads, audit chain, review, incident and close projections.
Expected outcomes are explicit fixture declarations, not extracted from calculated model balances or close output.
The runner checks actual outcome against that declaration and whole state before/after each rejection/replay.
The oracle checks the selected projections after every transition. It is not a complete verifier of every field
or a separately authored business specification; primary review remains required.

Money uses integer NIO centavos. Literal cash equation:
`10000 opening + 70000 cash sale + 10000 credit advance + 5000 collection - 35000 refund - 2000 withdrawal = 58000`.
Counted `57500` leaves `-500`, with original discrepancy retained.
An unauthorized withdrawal is rejected before the authorized withdrawal.

Pending `12345` contributes zero settled money until an explicit synthetic settlement declaration.
Repeated acknowledgement leaves `12345` once. This declaration is not actual bank integration or bank evidence.
The historical Model transfer counter stays zero in this separate pending-transfer fixture.

Each fixed family records rejected actions, exact errors, expected disposition, lost-output status and final state.
Lost output is simulated *after* a committed Model action; recovery repeats the same key and payload.
No process was crashed and no persistent store was used.
Eight deterministic generated journals extend receipt and credit boundaries with independent remaining-amount fixtures.
These are bounded samples, not a probability estimate or exhaustive state exploration.
The generated section also establishes operation identity at setup; it does not generate random crash/replay schedules.

## Controls and recovery

| Corrupt copy | Actual exit | Detecting invariant |
| --- | --- | --- |
| Duplicate cash/collection inflow +5000 | 1 | MONEY_CASH |
| Cashier replaces authorized close actor | 1 | CLOSE_JOURNAL_AUTHORITY |
| Stock replaced by 99 | 1 | STOCK_JOURNAL |
| Sale event omitted | 1 | AUDIT_JOURNAL |
| Shortage silently replaced by zero | 1 | CLOSE_JOURNAL_AUTHORITY |

These are verifier sensitivity checks on offline output copies, not product mutation testing.
Each process command, exit and invariant output appears in RESULT.json.
Recovery discards the altered copy and rechecks the unchanged baseline/journal.
The restored normal state retains the original `-500` shortage. It does not erase or resolve its cause.
The literal fixture and journal are trusted inputs; simultaneous falsification of both lies outside this bounded verifier.

## Selected policy, hypotheses and product gaps

D-022 assigns acceptance to SUAZO-PC; it does not grant this worker acceptance authority.
D-025 selects SUAZO-PC synthetic trial data; no runtime trial occurred here.
D-026/D-027 are fixed selected trial policies: cashier records, another authorized actor reviews at close,
authorized substitute covers absence, and unsupported causes remain open.
A07/A08 use identical fixtures, evidence and counted money; only reviewer identity changes.
Stock, money and original incident compare equal. This is a modeled alternative, not an empirical strategy ranking.

A06 preserves delivery instruction as an incident with fictional item, size, location, quantity, actor, moment,
shift and unposted sale reference. It records `delivered=true`, `financial_posting=false`, `stock_posting=false`.
The unchanged Model rejects the stock-zero sale. No +1/-1 workaround or guard bypass is applied.
The actual SAVIA exception mechanism remains missing; this is not proof a stock-zero product sale succeeds.

Review is distinct from cause resolution. Evidence-free review records the absence and retains an open cause.
No authorized reviewer or no close evidence means no invented authorized close or resolved count.
`MOCK-REVIEW-QUEUE` and `NEXT-CLOSE-ASSUMPTION` are explicit provisional owner/timing choices needing C2 confirmation.
They are not a staffing assignment or an adopted escalation deadline.

A12 rejects wrong-shift review, cashier closure, same-operation replay with another actor and repeated same-shift close.
Shift IDs and actor assignment are fixture assumptions needing C2 confirmation.
A complete second-shift cash lifecycle/handover is UNMODELED; cumulative Model cash cannot prove it.
No actual bank integration, damaged/credit/transfer return disposition, fiscal engine, SQL race, persistence,
operational backup/restore, latency, business-day acceptance or production capability is demonstrated.

## Failure retained and corrected

Full invocation 1, identical command with `--out .../run-01`, exited 1 at the first literal cash assertion.
[Original failed result](run-01/RESULT.json) preserves failure and original executed source hashes.
The fixture writer incorrectly expected `48000`; independent oracle and Model arithmetic both yielded `58000`.
Correction changed the expected literal to `58000` and counted fixture to `57500`, preserving intended `-500` shortage.
This was a harness fixture defect, not a reproduced historical Model or SAVIA defect.
Invocation 2 passed; no third invocation or silent historical fix occurred.
Lesson applied: independently sum the literal accounting equation before fixing the count/shortage fixture.
The corrected literal and separate oracle agree in the actual second run.

## Blockers and concrete handoff

| Gap | Evidence and attempted action | Owner / next action / completion check |
| --- | --- | --- |
| C2 operation and staffing unknown | D-029 guided reconstruction selected; no interview or answers invented. Hypotheses labeled in matrix. | Primary/Jason with Martha: confirm fixture owner, timing, permissions and shift boundaries in guided example; preserve declared/observed/pending evidence. |
| Stock-zero product mechanism missing | A06 records incident and verifies shortage rejection; no product correction authorized. | Primary: specify linked exception/posting acceptance separately; close only with authorized actual product evidence. |
| Money/review/close product workflows unproved | Oracle exercises proposed contracts only; no product runtime authorized. | Primary: map confirmed C2 facts to minimal product work; require exact candidate money/permissions evidence. |
| C9 TLS/recovery remains open | Existing audit reports 0/5; no new connection, certificate, SQL or backup action authorized. | Existing C9 coordinator: use separately authorized certificate/recovery scope; close with actual restore/RTO/RPO/Owner evidence. |
| C10/production unaccepted | Offline sequential Model is not the trial. | SUAZO-PC primary: inspect these artifacts independently, then keep actual C10 acceptance separate. |

No staging, commit, push, PR, deployment, ledger/status update or parent checkout write.
General product tests, browser, SQL and CI: NOT RUN; they are outside this documentation-only simulation scope.
Next action: primary inspects sources, matrix, failed/final results and control inputs before deciding integration.

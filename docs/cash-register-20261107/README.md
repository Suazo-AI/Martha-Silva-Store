# First functional SAVIA cash register

Mode: DISCOVER. Product scope adopted; implementation and runtime acceptance pending.
Owner: primary orchestrator. Host: SUAZO-PC.
Inspected source: `Tony@dab891055072910b5af757d2e36714424b5ee378`.

## Adopted scope

Jason selected **fully paid sales first; credit later** on 2026-11-07.
The question explicitly included cash received, change and till close.
[Decision D-031](../DECISIONS.md#d-031--primera-caja-contado-crédito-después).

Jason also selected **controlled cash refunds by Owner or Manager** on 2026-11-07.
Each refund must reference the original paid sale, include a reason and record a cash outflow.
Till close must include that outflow. [Decision D-032](../DECISIONS.md#d-032--devolución-controlada-de-efectivo).

Jason selected **one till per cashier and shift**, with its own opening and closing, on 2026-11-07.
Each till must identify who received and counted its cash.
[Decision D-033](../DECISIONS.md#d-033--caja-por-cajero-y-turno).

This is a SAVIA product choice, not an observation of Martha's current practice.
Credit balances and later collection are outside this increment.
Card payments remain a production requirement. This decision does not select a payment provider.
Mixed payments, exchange rates and fiscal rules remain undecided; do not invent them.

## Verified gap

- [InternalSaleRequest](../../backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceModels.cs) contains location, customer and lines. It has no tender, cash received or till identity.
- [InternalCommerceService](../../backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceService.cs) returns `not_processed` for sale payment and bank-refund status.
- Its reversal amount is a recorded credit. It is not proof that cash or a bank refund moved.
- [InternalCommandRunner](../../backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs) already handles transactional writes, session checks and idempotency. Preserve those boundaries.

A recorded sale, a successful mock response and an actual cash collection are separate claims.
No existing sale should become "paid" merely because this decision was recorded.

## Proposed checks for preimplementation review

These are technical acceptance proposals. They are not completed tests or additional business decisions.
Use the existing architecture. Do not introduce a separate payment platform for this increment.

| ID | Required result | Direct proof before acceptance |
| --- | --- | --- |
| CASH-01 | The server calculates the sale total. Cash received covers it. Change equals received minus total. | Boundary cases for underpayment, exact payment, excess tender, invalid amounts and overflow. Use integer minor units and an explicit currency. |
| CASH-02 | A successful cash sale persists its sale, stock effect and cash entry together. | Real API/SQL readback plus a forced failure proving no partial business writes. |
| CASH-03 | A retry or lost response cannot collect or decrement stock twice. | Retain the original key and body for uncertain outcomes. Recover the original receipt and prove one cash entry and one stock effect. |
| CASH-04 | Each cashier and shift has its own till, opening and closing. Sales use that cashier's open till in an authorized location. | Reject a sale charged to another cashier's or shift's till. Test simultaneous opening, sale versus close, and repeated close. Persist each accepted cash effect exactly once; reject writes after close. Freeze refund custody rules in review. |
| CASH-05 | Close records the expected cash, actual counted cash and their difference. Historical entries remain auditable. | Independently sum persisted entries. Test both a balanced close and a shortage; preserve the shortage rather than forcing zero. |
| CASH-06 | Only Owner or Manager can refund a paid cash sale. The original sale, reason and cash outflow remain linked and auditable. | Enforce the role on the server. Reject missing reasons, invalid sales and over-refunds without business writes. Prove one refund after response loss or concurrent retries, atomic money/stock effects, and the outflow in till close. A stock reversal alone never proves a refund. |
| CASH-07 | Receipts and till records identify actor, location, sale, currency, amounts and time. Stale sessions cannot mutate them. | API/SQL evidence, authorization failures with no business writes, and affected session/CSRF regressions. |
| CASH-08 | Authorized staff can complete the real journey from the staff screen, with cash attributed to the correct cashier and shift. | Browser -> API -> SQL: open, sell multiple articles, receive cash, show change, recover a lost response, refund as Owner or Manager and close with a counted amount. Read back the cashier, shift and till. Verify the Cashier cannot refund and a second cashier's till remains unchanged. Mocks remain separate. |

Synthetic accounting example, in one test currency's minor units:

- Opening cash: `10000`.
- Sale total: `2500`; received: `3000`; change: `500`.
- Expected till cash: `10000 + 3000 - 500 = 12500`.
- Counted cash: `12400`; difference: `12400 - 12500 = -100`.

Separate controlled-refund fixture:

- Opening cash: `10000`; net cash from the paid sale: `2500`.
- Authorized refund: `1000`, linked to that sale and recorded once.
- Expected till cash: `10000 + 2500 - 1000 = 11500`.
- Counted cash: `11500`; difference: `0`; refundable sale balance: `1500`.

Review must cover a Cashier calling the refund API directly, missing or blank reasons,
two requests attempting to refund the same remaining balance, and a lost response followed by retry.
The balance must come from persisted paid/refunded amounts, not a client-supplied limit.
Review must specify which open till records an Owner or Manager's refund and how a closed original till is handled.
Refund authorization does not itself determine cash custody. No transfer or automatic till reopening is implied.

Isolation fixture: two cashiers open separate tills with `10000` and `20000` minor units.
The first cashier's paid sale of `2500` produces expected balances of `12500` and `20000` respectively.
Closing either till must preserve the other till's balance and history. Reconcile both from persisted entries.

These values are test fixtures, not Martha's prices, opening balance or currency.
The independent check must recompute these amounts from stored entries rather than reuse the write handler's calculation.

## Next action and limits

Prepare one bounded fresh Astra/xhigh preimplementation review against this scope and the actual source.
Resolve its material findings and any product-only questions before an OpenCode/high implementation worker starts.
Two earlier worker assignments have cancellation requested but no terminal notification yet; do not overlap their ownership or exceed the three-agent limit.
Use a managed worktree when the next slot is available. Keep the primary responsible for serial integration and independent acceptance.

No cash implementation, migration, cash browser journey, SQL runtime, payment, merge or deployment was executed for this decision.
Existing runtime approvals are not renewed by the product choice. Production remains NO-GO.

Initial D-031 documentation verification: the primary's read-only `python -` checker reported 16 PASS on 2026-11-07.
It checked four local links and the decision anchor, eight unique criteria, both arithmetic examples,
the actual sale request/status sources, UTF-8 replacement characters, an empty index and `git diff --check`.
The following command lookup found no global `gh-axi` command and made the combined shell invocation exit 1;
that environment lookup is separate from the completed documentation checks. Use the existing cached CLI route for publication readback.
No cash-specific product test was run for that initial scope record.

## Publication evidence

The primary read back completed successful workflows for scope commit `58aa4fac2e61166bf4f493c08f3dcff5d42b1ba4`:
[Progress documentation](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42398605104),
[Progress digest](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42398604925), and
[Tony source snapshot](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42398604965).
Both snapshot jobs succeeded: `Publication integrity and reproducible build` and
`Historical portable regression suite (known gaps retained)`.
These results cover the earlier scope commit. They do not test the new refund policy, cash implementation, SQL or production.

## D-032 verification, 2026-11-07

- Read-only `python -` policy/link/source checker: **33 PASS**, exit `0`.
- `python tests/check.py`: **PASS**, exit `0`; includes the reproducible demo build, staff/DOM regressions, 17/17 localization cases, 47-page structure and syntax for 20 JavaScript files.
- `python tests/test_progress.py`: **23/23 PASS**, exit `0`.
- `python tools/export_progress.py --verify`: **15 preserved evidence hashes**, exit `0`.
- `git diff --check` and explicit staging checks: exit `0`; unrelated D-030 and `AGENTS.md` excluded.

The portable check's local log is ignored: `private-exports/cash-register-20261107/refund-decision/portable-check.log`.
These checks preserve the existing automated baseline. They do not implement or prove cash collection or refunds.
The first partial-staging patch failed without changing the index; passing explicit UTF-8/LF bytes instead of Windows text-mode stdin succeeded.
Lesson applied and checked: stage only D-032 from the shared decisions file; retain the unrelated D-030 working-tree change.
Next: terminal worker handoffs, fresh Astra/xhigh cash review, bounded OpenCode/high implementation and real money/permission reconciliation tests.

## D-033 verification and continuation

The primary read back successful run [42402503913](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42402503913)
for D-032 commit `1ddb022ce8509c8f7a9452109f5c71b2f3a14dc5`.
Both publication/build and historical portable-regression jobs passed. This is prior-commit evidence, not a cash runtime result.
D-033 adds the per-cashier/shift contract and proposed isolation/concurrency checks; no cash code changed.
The prior passing portable check remains attributed to D-032; unchanged product checks were not repeated.
D-033 verification: read-only policy/UTF-8/local-link checks **159 PASS**, `git diff --check` exit `0`,
`python tests/test_progress.py` **23/23 PASS** (76.813 s), and `python tools/export_progress.py --verify` **15 preserved hashes**, exit `0`.
The test fixture's printed commit/SYNCED lines are simulated hook tests, not this checkout's publication receipt.
Both earlier cancellation requests still lack a terminal handoff. Primary owns recovery through T3's completion notification;
no running-child poll, replacement or acceptance is implied. Cash review awaits an available approved slot.

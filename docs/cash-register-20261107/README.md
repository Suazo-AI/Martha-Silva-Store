# First functional SAVIA cash register

Mode: DISCOVER. Product scope adopted; implementation and runtime acceptance pending.
Owner: primary orchestrator. Host: SUAZO-PC.
Inspected source: `Tony@dab891055072910b5af757d2e36714424b5ee378`.

## Adopted scope

Jason selected **fully paid sales first; credit later** on 2026-11-07.
The question explicitly included cash received, change and till close.
[Decision D-031](../DECISIONS.md#d-031--primera-caja-contado-crédito-después).

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
| CASH-04 | Sales use an open till in the actor's authorized location. Closing and simultaneous selling cannot create an unaccounted entry. | Permission and concurrency tests. Freeze till ownership and close rules in review before implementation. |
| CASH-05 | Close records the expected cash, actual counted cash and their difference. Historical entries remain auditable. | Independently sum persisted entries. Test both a balanced close and a shortage; preserve the shortage rather than forcing zero. |
| CASH-06 | A return or cancellation cannot silently claim that cash was refunded. | Review the existing reversal contract before enabling it for paid sales. Define the supported refund path and prove its money/stock effects, or leave that paid-sale action unavailable pending its policy. This document selects neither policy. |
| CASH-07 | Receipts and till records identify actor, location, sale, currency, amounts and time. Stale sessions cannot mutate them. | API/SQL evidence, authorization failures with no business writes, and affected session/CSRF regressions. |
| CASH-08 | A cashier can complete the real journey from the staff screen. | Browser -> API -> SQL: open, sell multiple articles, receive cash, show change, recover a lost response and close with a counted amount. Mocks remain separate. |

Synthetic accounting example, in one test currency's minor units:

- Opening cash: `10000`.
- Sale total: `2500`; received: `3000`; change: `500`.
- Expected till cash: `10000 + 3000 - 500 = 12500`.
- Counted cash: `12400`; difference: `12400 - 12500 = -100`.

These values are test fixtures, not Martha's prices, opening balance or currency.
The independent check must recompute these amounts from stored entries rather than reuse the write handler's calculation.

## Next action and limits

Prepare one bounded fresh Astra/xhigh preimplementation review against this scope and the actual source.
Resolve its material findings and any product-only questions before an OpenCode/high implementation worker starts.
Two earlier worker assignments have cancellation requested but no terminal notification yet; do not overlap their ownership or exceed the three-agent limit.
Use a managed worktree when the next slot is available. Keep the primary responsible for serial integration and independent acceptance.

No cash code, migration, build, browser journey, SQL runtime, payment, merge or deployment was executed for this decision.
Existing runtime approvals are not renewed by the product choice. Production remains NO-GO.

Documentation verification: the primary's read-only `python -` checker reported 16 PASS on 2026-11-07.
It checked four local links and the decision anchor, eight unique criteria, both arithmetic examples,
the actual sale request/status sources, UTF-8 replacement characters, an empty index and `git diff --check`.
The following command lookup found no global `gh-axi` command and made the combined shell invocation exit 1;
that environment lookup is separate from the completed documentation checks. Use the existing cached CLI route for publication readback.
No product test was run for this documentation-only scope record.

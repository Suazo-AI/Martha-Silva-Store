# real-cash-v1 independent oracles (prepared; NOT RUN)

Cash campaign: exactly 31 browser checkpoints, four exact migration names and 23 exact internal tables.
One shift means one persisted till ID. All amounts below are integer USD minor units (exponent 2).
Requests contain original item/line IDs and quantities; prices and refund amounts come from server rows.
The oracle calculates expected values from the frozen fixture, then compares independent SQL readback.

| Successful command | Actor / paying till | Ledger delta | Tender / change | Independent close |
|---|---|---:|---:|---|
| Open original | Cashier / original | 10000 | 0 / 0 | |
| Two-article sale (2 x 1250 + 3400) | Cashier / original | 5900 | 6000 / 100 | |
| Lost response sale (1250 + 3400) | Cashier / original | 4650 | 5000 / 350 | |
| Physical exception sale | Cashier / original | 1250 | 2000 / 750 | |
| Open other cashier | Cashier2 / separate | 20000 | 0 / 0 | |
| Return one original 1250 line | Manager / original | -1250 | 0 / 0 | |
| Close original | Cashier / original | no entry | | expected 20550; counted 20450; difference -100 |
| Open later shift | Cashier / later | 10000 | 0 / 0 | |
| Return remaining original 1250 line | Manager / later | -1250 | 0 / 0 | |
| Close later shift | Cashier / later | no entry | | expected 8750; counted 8750; difference 0 |

Cashier refund rejection is HTTP 403 and changes no business rows or command effects.
The manager is the persisted authorizer; the paying cashier belongs to the selected till.
Both refund lines reference the original first sale line, quantity 1 each, with the fixed synthetic reason.
The later refund uses the current same-location till. The previous close and Cashier2 till stay unchanged.
No reopen or transfer is introduced.

Before refunds: three sales, five lines, four sale movements, two receipt movements,
three opening stock movements, one physical review and 30 recorded units.
Each ordinary refund adds one return movement and one recorded unit, ending at 32.
The physical exception has no stock balance, receipt, purchase cost or stock movement.
Supply still delivers 2 + 3 units against the exact original five-unit order.
Its response-loss recovery keeps the original receipt/key with exactly two receipt POSTs.

Every checkpoint requires `identities`, `amounts`, `unique_effects`, `stock_links`,
`refund_links`, `close_sum`, `preserved_rows`, `operation_requests` and the independent cash-row `money` projection.
SQL operation fingerprints are reconstructed from the original typed requests, with persisted result/effect IDs.
Counts alone never establish these identities.
Excluded tables require identical per-row hashes. Immutable prior rows in affected append-only tables must survive.
Unrelated sale lines, sales, balances and tills are preserved individually during successful commands.
Only session rows are excluded from preservation because real logins/logout alter them.
Public projections contain synthetic IDs and integer cash amounts; private hashes and raw rows stay private.

The offline verifier rejects incomplete/order-swapped checkpoints, missing/false oracles,
changed IDs/amounts, duplicate effects, non-integer amounts, wrong shortage arithmetic,
changed pending body hashes, sale/receipt reposts, missing original-key GETs and missing owned cleanup.
Synthetic offline tests exercise these guards; they do not prove API/SQL/browser operation.

## Historical physical-exception protocol below

The following text is retained as historical preparation. Current execution requires
the combined cash command in [README.md](README.md), not an unpaid browser run.

# Optional physical exception oracles (prepared; NOT RUN)

The existing 17 sale/supply checkpoints and four SQL identity oracles remain.
`--stock-exception` defaults false and adds five checkpoints after them.

| Durable count | Sale + reload | Review + reload | Final logout |
| --- | ---: | ---: | ---: |
| Sales / sale lines | 3 / 5 | 3 / 5 | 3 / 5 |
| Ordinary sale movements / sale command operations | 4 / 3 | 4 / 3 | 4 / 3 |
| All movements / recorded on hand | 9 / 30 | 9 / 30 | 9 / 30 |
| Exceptional sale lines / reviews | 1 / 0 | 1 / 1 | 1 / 1 |
| Exceptional sale movements | 0 | 0 | 0 |
| Active sessions | 1 | 1 | 0 |

Supply retains order quantity 5, delivered 5, two receipts and two receipt movements.
The exceptional article has no opening balance, cost, purchase receipt or compensating movement.
`stock-identity` independently joins sale, exact exceptional line, server actor/location,
size S, quantity 1, reason, price 1250 and idempotency operation/result sale ID.
It requires no sale stock movement and no nonzero balance for that article/location.
It joins the review operation/result ID to its sale line, different reviewer, evidence,
outcome, responsible actor, future date and open cause.
Identity or count mismatch fails before acknowledging the browser checkpoint.
The ordinary line/movement oracle excludes only explicit exceptional lines.
The new zero-exception-movement oracle applies after every schema-ready checkpoint.
Purchase receipt oracles keep their original accounting.

Three `InternalStockExceptionSqlTests` prepare concurrent replay, different-body conflict,
rollback, partial return, cancellation, privileged self-review denial and substitute review.
Exceptional reversal records quantity and original-price credit without creating stock.
A later evidence-based inventory correction is separate, never inferred by a return.
These SQL tests and the combined real journey are NOT RUN here.

Cleanup must stop only owned browser/API process groups, remove the private session file,
and drop only the database acknowledged as created by this run.
Check the final cleanup result and evidence verifier; uncertain retirement is failure.
The durable rows disappear through that verified disposable-database retirement, not unscoped row deletion.

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

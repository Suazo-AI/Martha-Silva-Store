# V029 fixture revision

Base: `ba8ff2ba10935e99fc268ebbe5eae130f72c1cca` plus the frozen five-file SQL overlay in `../REVIEW.json`.
Primary disposition: adopt the three P2 findings and the bounded P3 ordering control from `../astra-sql-review.md`.
V029 and its manifest stay frozen. This task changes tests only.

## Acceptance checks

1. Update the obsolete changed-credit replay expectation in SQL134 to `51538`, preserving financial assertions.
2. A winner holds its transaction-owned reversal lock. A different SQL session must be observed waiting on that shared application resource before release. A sequential schedule must fail the fixture.
3. Cover same-endpoint exact and changed replays, and mixed endpoints with different tills. Compare exact financial/sync row images before and after the contender, including USD rows. A shared till lock cannot substitute for the reversal-lock proof.
4. Independently cover disabled/inactive actor and approver and revoked branch access, expecting `51529` and unchanged financial/sync images. Replay by a different currently authorized supervisor must succeed without rewriting original attribution or any financial row.
5. Both endpoints return two original lines. Reversing input order must be an equivalent zero-write replay.
6. Offline negative controls must reject split endpoint lock namespaces and omitted enabled-staff predicates. Source tests remain source tests; do not label them SQL proof.
7. Compile the final C# fixture with cached SDK 10.0.402 and locked local dependencies. No SQL, Docker, network, installs, services, workflows, commit, push, merge or deployment.

Owned source paths: `savia/db/tests/sales/134_credit_return_validation.sql`, `savia/db/tests/sales/172_return_retry_safety.sql`, `savia/tests/Savia.Tests/ReturnRetrySafetyTests.cs`, `savia/tests/test_return_retry_safety.py`.
Owned evidence: `docs/merge-readiness-20261116/corrections/returns/sql/fixture-revision/`.

## Blockers and ownership

The obsolete error is directly confirmed by SQL134 and V029. The old concurrency fixture releases only a client barrier and shares one till. Authorization and return-line ordering lack the adversarial controls listed above.
Primary owns serial integration and final acceptance. Sol/high owns this bounded test correction. Astra/xhigh reviews the revised delta independently. Actual SQL behavior remains NOT RUN until fresh runtime authorization.

Lesson: observe the lock being claimed; an unrelated shared resource can serialize a weak concurrency test.

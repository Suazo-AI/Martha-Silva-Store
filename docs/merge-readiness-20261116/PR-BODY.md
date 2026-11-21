## Por qué

Integrate the current SAVIA and Martha Silva work from Tony into main through one reviewed product rollup. Tony contains the older PR #2 and later implementation, tests, UX corrections and evidence. Merging only #2 would omit that work.

The storefront preserves Jason's layout and Denis's images. SAVIA changes retain role checks, sales attribution, money handling and pending-operation recovery. This PR requests validation of the combined source; it does not assert operational production acceptance.

## Alternativas

Keep main behind, or merge the old PRs individually. The old seasonal-offers patch conflicts with current editable paths and has unresolved validation gaps. PR #5 remains open and deferred; its feature is not delivered by this rollup. PR #6 proposes an optional pipeline policy and remains separate; it is not a dependency of the existing protected product checks. No pipeline execution is fabricated and no mandatory check is removed.

## Evidencia

See [merge preparation](docs/merge-readiness-20261116/PLAN.md), [independent review](docs/merge-readiness-20261116/astra-merge-route.md), and [exact runtime scope](docs/merge-readiness-20261116/RUNTIME.md).

Historical worker results remain attributed to their tested source. The first-integration bug-proof gate has a reproduced failure and focused correction. Required final-head CI, additional SQL jobs and their evidence must be read back before merge acceptance. Passing mocks is not SQL persistence proof.

## Qué falta

All seven protected contexts must pass for the actual head/base/merge checkout. Inspect v2 and Azure SQL jobs, skipped steps, artifacts and cleanup boundaries. v2/Azure individual container absence is not proven by their best-effort teardown; their disclosed boundary is fresh hosted-runner isolation. Supply/stock manual journeys, a conditional restart not actually observed, live payments and operational production are not claimed.

No automatic merge, deployment, native SQL change or real-data operation is requested. PR #5 and #6 stay visible as separate follow-ups. Main advancement or a failed check requires reconciliation before acceptance.

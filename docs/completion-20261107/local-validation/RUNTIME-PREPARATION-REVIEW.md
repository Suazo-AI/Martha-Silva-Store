# Primary review: offline proof accepted; runtime preparation incomplete

2026-11-07. Host SUAZO-PC. Source `69d3268c63019d8b8299027789962a1089f91a58`.

Primary applied the existing independently reviewed verifier to the actual fresh TRX in memory.
Result: 552/552 Passed, 195/195 methods, 552 unique test IDs and 552 unique execution IDs.
No missing or unexpected method, multiplicity mismatch or changed execution source was found.
The imported worker documents are byte-identical. Raw evidence remains private.
See [primary verification](PRIMARY-VERIFICATION.json) and [sanitized method outcomes](A-sanitized-results.json).

The original runtime plan is retained as returned evidence, not accepted as an executable campaign.
Its commands contain ellipses and unresolved paths. It has no prepared runner-image recipe.
It schedules C1 and then full C, which would duplicate six cases if both TRX files entered one exact verifier.
It does not provide an executable E2 handoff from persisted release metadata to owned-container restart.
The phrase "one failed path may be retried once" is not runtime authority; no automatic SQL retry is permitted.

Cause: the preparation task returned a description instead of the requested complete invocation.
Correction: an OpenCode executor must finish the smallest local campaign entry point using the existing tests and harness.
It must select C1 first and remaining C separately, aggregate exactly C77, retain diagnostics before cleanup,
and reject missing prerequisites before runtime. No product, test, workflow or acceptance change is needed.
Owner: primary for serial integration; OpenCode for bounded execution preparation.
Completion check: offline syntax, plan-only output and fail-closed controls pass; Astra/xhigh reviews the frozen artifact.

Runtime remains NOT RUN. New runtime scope is required by [DATABASE](../../DATABASE.md).
The request must identify the source, local disposable resources, network installs, trust limits,
time limits, no-retry conditions, retained diagnostics, cleanup and absence readback.
No new SQL, container, host certificate, service, GitHub Actions or deployment authority is inferred.

Lesson applied: close the actual offline evidence gap before asking for runtime; do not call an outline executable.

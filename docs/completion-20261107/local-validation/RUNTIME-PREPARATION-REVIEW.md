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

## Official runner dependency metadata, 2026-11-07

The ended worker now has an unaccepted Dockerfile; this does not change the historical outline findings above.
Primary checked four official publisher metadata URLs over HTTPS. All four returned HTTP 200.
The [readback](RUNNER-PREREQUISITES.json) records URLs, extracted fields and response hashes.

- Node `v24.22.2` exists. Its published Linux x64 SHA256 matches the candidate's argument exactly.
- Playwright and playwright-core `1.63.0` exist. Playwright pins that core version; both declare Node `>=20`.
- Google's current amd64 stable package is `157.0.8103.38-1`. This differs from historical Chrome 156 evidence.

The web reader could not retrieve these metadata formats; a direct Python urllib GET succeeded.
No binary archive was downloaded or executed. Publisher signatures were not verified.
No package, image, SQL server or browser was started or installed.
Metadata existence does not prove the recipe builds or Chrome and Playwright work together.

Closed gap: the Node checksum and named npm versions are no longer unsupported assumptions.
Remaining gap: mutable apt resolution, actual downloaded bytes, runner digest and compatibility need build/runtime evidence.
Owner: primary and the next free OpenCode executor after Astra's runner safety review.
Completion check: reviewed recipe, bounded offline controls, authorized build and exact resulting image binding.
This verification grants no install, networked build or SQL runtime scope.

## Runner safety adjudication and correction handoff

Primary inspected [Astra's source-only rejection](astra-runner-safety.md) and accepts F1-F10 as correction requirements.
The reviewed originals are preserved as inert `.txt` inputs under `runner-inputs/`.
[IMPORT.json](runner-inputs/IMPORT.json) binds all four byte-identical copies to the ended worker and review.
They are rejected inputs, not accepted tools. No candidate code was executed during this import.

The next OpenCode executor owns only `tools/run_local_validation.py`, `tools/local-validation/` and correction evidence here.
It must reproduce the offline failures, correct resource ownership, frozen export, deadlines, privacy and cleanup,
then verify every F1-F10 control without SQL or container execution.
Use the dependency metadata above, while retaining actual download/build/compatibility as unproven.
Keep the runner-to-SQL bridge private with no published port in the prepared scope.
Preserve C1 then disjoint C71, aggregate C77, both D flags and all existing journey/SQL oracles.
Fresh A552 evidence remains separate. This handoff grants no runtime or security-configuration changes.

Material lesson: a resource name never proves deletion authority. Require verified creation identity and ownership.
Completion check: primary inspects corrected bytes and offline controls; Astra/xhigh adjudicates the frozen candidate.
Owner recovery's separate execution contract is prepared; its implementation has not started.

Publication verification: `python tests/test_progress.py` passed 23 tests, exit 0.
`python tools/export_progress.py --verify` preserved 15 evidence hashes, exit 0.
Primary verified four imported input hashes, both independent report bindings and local Markdown links, exit 0.
`git diff --check` passed. These checks validate this documentation import, not the rejected runner or recovery implementation.

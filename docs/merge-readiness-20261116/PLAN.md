# Merge preparation: 2026-11-16

Scope: prepare the current increments for merge into `main`. Jason authorized parallel workers and publication of project progress. No merge or deployment is performed by this plan. SQL runtime remains subject to its explicit scope.

## Historical starting point

- Host: `SUAZO-PC`; primary: T3 Code / Codex `gpt-6.1-sol/xhigh`.
- Tony: `51bbea4891cef23129be07cb4bab17e1247db5c5`.
- Main: `3b0049163ece2d9431cee01f1bea624a66d9d8d4`.
- Main is an ancestor of Tony; Tony is 256 commits ahead and zero behind.
- Latest Tony source-snapshot, progress-documentation and digest workflows succeeded. Current product validation remains attributed to its tested source, rather than to a documentation-only publication.

## Independent work and integration

1. Worker 1: assess PR #5's eight-file seasonal-offers increment against current Tony. Preserve pricing, media and the chosen frontend. Keep commercial offers disabled without approved data. Return the minimal necessary delta and direct verification.
2. Worker 2: assess PR #6's five-file verification-gate increment against current Tony. Diagnose the actual failed gate and the installed pipeline. Preserve real checks; never fabricate a pipeline attestation.
3. Primary: integrate accepted deltas serially, preserve unrelated files, freeze the combined source and run affected checks.
4. Astra/xhigh: independently judge the frozen combined candidate. Primary adjudicates findings and owns acceptance.
5. Publish the accepted candidate through normal hooks, verify remote SHA and applicable checks, then prepare the current Tony-to-main PR. Recheck actual protection and deployment conditions before any merge handoff.

## Current blockers and disposition

| Item | Direct evidence | Cause or boundary | Next action and owner | Completion check |
| --- | --- | --- | --- | --- |
| PR #2 is older than Tony | Its head `8744a9699812d62ea5ed31c63781748f833c3def` is contained in Tony | Merging it alone omits later work | Primary prepares one current integration route | PR base/head and source correspondence verified |
| PR #5 is an older draft | Head `cecdbeb05d03ccf01e8ccf74ad83eef4064c0846`; eight changed files | Compatibility with current frontend has not been established | Worker 1 assesses direct source and proposes a bounded disposition | Relevant behavior and regressions pass on accepted bytes |
| PR #6 gate fails | Run `42180834199`: `This PR was not raised through no-mistakes.` | Actual submission gate failed; this is not evidence of a missing Python interpreter | Worker 2 diagnoses authentic pipeline setup and current compatibility | Genuine successful gate or an explicitly adjudicated alternative; no forged attestation |
| Local no-mistakes setup absent | `no-mistakes axi status`: `repo not initialized` | Installed CLI does not establish repository initialization | Worker 2 inspects the supported setup and needed configuration, without starting nested gates | Supported setup and execution path documented and verified |
| Main checks are mandatory | GitHub CLI branch-protection read succeeded | Seven required contexts, strict update requirement and enforced administrators | Primary maps each required context to current PR workflows | Required checks pass for the actual candidate; no protection bypass |
| New SQL execution needs concrete scope | `docs/DATABASE.md` requires runtime scope for each execution | Prior one-shot grants do not authorize arbitrary reruns | Primary prepares exact triggered-workflow scope before any new SQL dispatch | Authorized runtime, exact SHA, result and cleanup evidence |

Required main contexts: `Complete backend suite on disposable SQL Server`; `Staff UI tests and real browser harness`; `Real API + disposable SQL golden path`; `build-and-guards`; `Portable checks (windows-latest)`; `Portable checks (ubuntu-latest)`; `Ledger check and deterministic digest`.

Merge readiness and operational production acceptance remain separate. No current claim covers unexecuted real journeys, live payments or real customer data.

## Primary source assessment: PR #5

The returned review recommends deferring seasonal offers from this rollup. Primary independently verified all 71 extracted-source SHA256 entries against the pinned Git blobs and inspected the recorded outputs. Recorded results: Tony DOM 29/29, PR DOM 16/16, independent predicate/timezone probes 27/27 plus selector/cart assertions. These are historical worker executions, not primary reruns or browser/SQL proof.

The exact patch fails against four current editable-source/test paths. This is patch applicability evidence, not a simulated three-way merge. Stock-input validation and an original checkout-test gap remain. Do not resolve conflicts by taking old frontend files. Primary adopts defer within the independent Astra adjudication below; no PR is closed and no product feature is removed.

Nine explicit files from the worker's owned `pr5` folder were initially imported byte for byte. The publication hook subsequently rejected raw `.log` files under its sensitive-filename policy. Four logs are now retained privately, with original hashes and reviewed counts in [OUTCOMES.json](OUTCOMES.json). Public evidence links are updated under [IMPORT.md](IMPORT.md). No browser profiles, credentials, accounts, databases or screenshots were copied. The source receipt retains its original scratch path as provenance, not a delivered runtime dependency.

## Deployment and runtime boundary

An authenticated GitHub CLI read returned zero repository Actions variables. `CLOUDFLARE_DEPLOY_ENABLED` is absent. The current deployment job requires that variable to equal `true`, and excludes pull-request events. No deployment setting was changed.

Opening a current Tony-to-main PR would trigger SQL-capable workflows in addition to offline checks. The backend workflow's separate SQL job is main-push/manual-only and does not start SQL for this PR. The complete PR SQL list is `savia.yml` (25 minutes), `golden-path.yml` (20 minutes), `savia-v2.yml` (45 minutes), and `savia-azure.yml/build-and-prove` (30 minutes). The fourth job was omitted initially and is now accounted for in [RUNTIME.md](RUNTIME.md). Staff/browser uses 15 minutes. These jobs use disposable runner resources and fictional data; they do not qualify native Windows SQL or an operational installation.

Before opening that PR, primary must finish source adjudication, publish the frozen candidate, and resolve the new runtime scope against `docs/DATABASE.md`. No workflow has been dispatched by this merge-preparation task.

## Primary source assessment: PR #6

The returned review recommends deferring PR #6 as-is. Primary verified all 12 recorded source bindings against Git blobs, and the official verifier against its pinned upstream Git blob and SHA256. Recorded checks: 11 expected rejection controls and 12 workflow/configuration assertions. No authentic positive pipeline was executed. These are worker results, not primary reruns.

The installed Windows CLI is `v1.57.0`; its help does not support the targeting/privacy flags expected by the proposed runbook. The repository is not initialized for that pipeline. This is a tooling compatibility and execution-evidence gap, not a reason to remove required product checks. The PR body declaration is editable and does not independently prove execution.

Seven explicit files from the worker's owned `pr6` folder were imported byte for byte. Original reports and public PR metadata remain attributed to the worker. No pipeline configuration, shared CLI, product code, branch protection, PR or runtime was changed. The first primary audit read a BOM-prefixed JSON file using the platform default encoding and failed before verification completed. Repeating that audit with explicit `utf-8-sig` passed; no source correction was necessary.

Primary adopts separate treatment of PR #5 and PR #6 following Astra/xhigh adjudication. The bounded conclusions are accepted; the runtime preflight findings are addressed below and await a final independent recheck. Neither draft is silently included, closed or labelled complete. The next review must determine the shortest safe Tony-to-main route, whether either draft is a dependency, and the minimum sufficient CI and runtime packet. It must preserve all seven required contexts and distinguish merge acceptance from production acceptance.

Verification commands: a Python standard-library audit of the 12 Git source bindings and pinned verifier returned exit 0; the exact-file import audit returned exit 0 for 7/7 files. PR #5's 71 source hashes and nine imported evidence files passed the preceding audit. No product tests were rerun for this documentation-only import. Independent review and current-candidate PR checks remain pending.

Publication checks: `python tests/test_progress.py` passed 23/23 tests, exit 0. `python tools/export_progress.py --verify` passed 15 preserved evidence hashes, exit 0. The first staged diff check rejected doubled carriage returns in two generated evidence files. Normalizing public line endings resolved that check. The commit hook then rejected raw `.log` publication; excluding those logs and retaining reviewed outcomes resolves its scope without changing the filter. [IMPORT.md](IMPORT.md) accounts for original bytes, public derivatives and private archives. These checks validate progress recording and unchanged exported evidence; they do not validate a new SQL run or qualify the product for production.

## Current primary adjudication and preparation

Source: `670d4a8e6fab650ef1ee2b0fba64d7e810b7dbe3`, plus the two-file bug-proof gate correction. [Astra's report](astra-merge-route.md) was imported byte-identically, with its original limitations preserved. Primary accepts the PR2/PR5/PR6 dispositions, the protected-check mapping and reuse of unchanged source-bound evidence. No primary acceptance of a runtime result is implied.

| Finding or blocker | Direct evidence and action | Status / owner / completion check |
| --- | --- | --- |
| Fourth SQL job omitted | Read the complete Azure workflow, including images, SQL, migration, smoke, teardown and dispatch-only deployment predicate; added its 30-minute job | Source preflight closed; final Astra review accepts the complete four-job packet with runtime conditions |
| Possible narrator billing | Fresh authenticated metadata: public User-owned repo; zero Actions secrets and variables; no organization-secret inheritance | Provider steps inactive at inspection; primary rechecks before PR creation and stops on change |
| v2/Azure cleanup overclaim | Both workflows suppress teardown errors; individual resource absence is not verified | Disclosed hosted-runner isolation boundary proposed in RUNTIME; Jason's runtime decision must include it; no local cleanup waiver |
| New gate cannot bootstrap on old main | Old main has no tools/bugproof scripts; actual workflow command exits 2 in an empty base fixture | Semantic red reproduced; primary 14/14 green; final Astra 3/3 workflow tests and four independent probes passed |
| Local repository check lacks symlink privilege | `python tests/check.py` exited 1 after 131.813 seconds; three asset-audit errors report `WinError 1314` | Environment failure; exact-SHA Linux snapshot passed the full check and 6/6 asset tests at edd2e09; Windows privilege remains unchanged |
| Exact-head integration proof absent | No current rollup PR or new runtime attempt exists | Primary prepares body/source; Jason must approve the concrete runtime scope before PR creation |
| PR5 seasonal feature unfinished | Source incompatibility and stock/checkout gaps preserved in review | Deferred OPEN; later narrow port, not old-file replacement; not silently declared delivered |
| PR6 authentic optional pipeline unproven | Proposed policy is inactive; installed CLI/runbook mismatch preserved | Separate OPEN draft; not a dependency or a fabricated successful gate |

The gate now reads event metadata directly without executing PR-head code. Missing trusted base tooling still fails closed when a bug label or issue-closing reference requires proof. Ordinary integration needs no unavailable base script. The initial test-construction failure was not counted as semantic red; the corrected harness reproduced the old workflow's missing-script failure before the workflow edit.

Commands: `python -m unittest discover -s tests/bugproof -p test_control.py -k bootstrap_ordinary` failed 1/1 before correction, exit 1 (child Python exit 2). After correction, `python -m unittest discover -s tests/bugproof` passed 14/14, exit 0. Three workflow YAML parses and `git diff --check` passed. Fresh `python tests/test_progress.py` passed 23/23, exit 0; `python tools/export_progress.py --verify` passed 15 preserved hashes, exit 0. The prepared PR body contains all four required sections.

The fresh repository check failed at asset-audit symlink fixtures, not at a product assertion. Three errors report `A required privilege is not held by the client`; no test was skipped or weakened. The private log and its SHA256 are recorded in OUTCOMES. The shortest authorized workaround is the existing Linux `historical-regressions` job triggered by ordinary Tony publication. Its result must be verified on the exact published SHA before this check is closed. Linux does not prove Windows symlink permission. No SQL, container, browser, deployment or manual workflow dispatch was executed by this correction.

Lesson applied: the first integration of a new control cannot assume that old main already contains its scripts. Test against an empty base checkout and preserve failure for required proof. This correction changes two verification files only; product bytes remain unchanged.

The ready PR body is [PR-BODY.md](PR-BODY.md). [RUNTIME.md](RUNTIME.md) includes all four SQL jobs, job envelopes, actual metadata, conditional proof/comment behavior, artifact publication, cleanup limits and exclusions. No PR creation, merge or deployment has occurred. Exact-SHA Linux verification and independent source review are accepted below. The fresh runtime grant is the remaining authorization boundary before PR creation.

## Final preflight acceptance at edd2e09

Primary accepts [Astra final preflight](astra-final-preflight.md) for the bounded merge preparation at `edd2e097f6b4f22c9dbbffa897e9ed7f7a063055`. The report is advisory `APTO CON REPAROS`; primary verified its RAW hash and the three source Git/SHA256 bindings. Astra freshly passed three workflow tests and four independent bootstrap probes. The complete runtime packet remains a proposal, not permission or execution evidence. No new material source defect was found within that scope.

Exact-head non-SQL CI completed successfully on attempt 1: snapshot [43965171724](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/43965171724), digest [43965171533](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/43965171533), and documentation [43965171839](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/43965171839). Both snapshot jobs passed. The Linux `python tests/check.py --install` step passed, including six asset-audit tests. Primary inspected the saved run JSON and actual log. Their private location and log hash are recorded in OUTCOMES.

The first display of the saved log tail failed with a CP1252 `UnicodeEncodeError` after evidence collection completed. An ASCII-only audit of the same saved evidence passed. No workflow or test was repeated for that display failure.

This publication imports the report and records acceptance only. Product and workflow bytes remain those reviewed at `edd2e09`; the new documentation SHA still requires its applicable publication checks. SQL runtime, rollup PR creation, merge and deployment remain NOT RUN. Before creating the PR, refresh final Tony/main SHAs, branch protection, and Actions secret/variable names; obtain Jason's concrete approval of RUNTIME, including public synthetic artifacts and hosted-runner cleanup limits. Owner: primary prepares and verifies; Jason supplies that runtime decision. Completion: one authorized PR attempt with exact-head results and cleanup evidence, with no automatic retries.

# Merge preparation: 2026-11-16

Scope: prepare the current increments for merge into `main`. Jason authorized parallel workers and publication of project progress. No merge or deployment is performed by this plan. SQL runtime remains subject to its explicit scope.

## Frozen starting point

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

The exact patch fails against four current editable-source/test paths. This is patch applicability evidence, not a simulated three-way merge. Stock-input validation and an original checkout-test gap remain. Do not resolve conflicts by taking old frontend files. Primary provisionally adopts defer, pending independent Astra adjudication; no PR is closed and no product feature is removed.

Nine explicit files from the worker's owned `pr5` folder were initially imported byte for byte. The publication hook subsequently rejected raw `.log` files under its sensitive-filename policy. Four logs are now retained privately, with original hashes and reviewed counts in [OUTCOMES.json](OUTCOMES.json). Public evidence links are updated under [IMPORT.md](IMPORT.md). No browser profiles, credentials, accounts, databases or screenshots were copied. The source receipt retains its original scratch path as provenance, not a delivered runtime dependency.

## Deployment and runtime boundary

An authenticated GitHub CLI read returned zero repository Actions variables. `CLOUDFLARE_DEPLOY_ENABLED` is absent. The current deployment job requires that variable to equal `true`, and excludes pull-request events. No deployment setting was changed.

Opening a current Tony-to-main PR would trigger SQL-capable workflows in addition to offline checks. The backend workflow's separate SQL job is main-push/manual-only and does not start SQL for this PR. The actual PR SQL jobs are `savia.yml` (25 minutes), `golden-path.yml` (20 minutes), and `savia-v2.yml` (45 minutes). Staff/browser uses 15 minutes. These jobs use disposable runner resources and fictional data; they do not qualify native Windows SQL or an operational installation.

Before opening that PR, primary must finish source adjudication, publish the frozen candidate, and resolve the new runtime scope against `docs/DATABASE.md`. No workflow has been dispatched by this merge-preparation task.

## Primary source assessment: PR #6

The returned review recommends deferring PR #6 as-is. Primary verified all 12 recorded source bindings against Git blobs, and the official verifier against its pinned upstream Git blob and SHA256. Recorded checks: 11 expected rejection controls and 12 workflow/configuration assertions. No authentic positive pipeline was executed. These are worker results, not primary reruns.

The installed Windows CLI is `v1.57.0`; its help does not support the targeting/privacy flags expected by the proposed runbook. The repository is not initialized for that pipeline. This is a tooling compatibility and execution-evidence gap, not a reason to remove required product checks. The PR body declaration is editable and does not independently prove execution.

Seven explicit files from the worker's owned `pr6` folder were imported byte for byte. Original reports and public PR metadata remain attributed to the worker. No pipeline configuration, shared CLI, product code, branch protection, PR or runtime was changed. The first primary audit read a BOM-prefixed JSON file using the platform default encoding and failed before verification completed. Repeating that audit with explicit `utf-8-sig` passed; no source correction was necessary.

Primary provisionally adopts separate treatment of PR #5 and PR #6, pending Astra/xhigh adjudication. Neither draft is silently included, closed or labelled complete. The next review must determine the shortest safe Tony-to-main route, whether either draft is a dependency, and the minimum sufficient CI and runtime packet. It must preserve all seven required contexts and distinguish merge acceptance from production acceptance.

Verification commands: a Python standard-library audit of the 12 Git source bindings and pinned verifier returned exit 0; the exact-file import audit returned exit 0 for 7/7 files. PR #5's 71 source hashes and nine imported evidence files passed the preceding audit. No product tests were rerun for this documentation-only import. Independent review and current-candidate PR checks remain pending.

Publication checks: `python tests/test_progress.py` passed 23/23 tests, exit 0. `python tools/export_progress.py --verify` passed 15 preserved evidence hashes, exit 0. The first staged diff check rejected doubled carriage returns in two generated evidence files. Normalizing public line endings resolved that check. The commit hook then rejected raw `.log` publication; excluding those logs and retaining reviewed outcomes resolves its scope without changing the filter. [IMPORT.md](IMPORT.md) accounts for original bytes, public derivatives and private archives. These checks validate progress recording and unchanged exported evidence; they do not validate a new SQL run or qualify the product for production.

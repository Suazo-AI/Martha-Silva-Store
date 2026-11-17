# Golden workflow correction — worker return

Task: `savia-pr7-golden-correction-ba8ff2b-20261116-01`.
Status: returned for primary integration and Astra/xhigh review; not accepted by this worker.
Source: `ba8ff2ba10935e99fc268ebbe5eae130f72c1cca` (verified before mutation).
Worktree: `C:/Users/Jason/.t3/worktrees/github/t3-ca850f2c-da68c203fe96f38d`.
Branch: `t3/golden-cash-workflow-fix`. No commit or index mutation.

## Result

Automatic PR/main-push acceptance now selects all current cash flags.
Manual dispatch requires both inputs before dependency setup or SQL/container activation.
The original stock-to-supply guard remains; a missing-stock guard rejects the other incomplete combinations.
The focused stdlib regression is wired before runtime in the existing regression step.
No harness, product, SQL oracle, shared ledger or runtime packet changed.

| Event | supply_receipt | stock_exception | Derived supply / stock env | Early guard | C6 parser seam |
| --- | --- | --- | --- | --- | --- |
| pull_request targeting main | absent | absent | true / true | exit 0 | browser + cash + supply + stock-exception |
| push to main | absent | absent | true / true | exit 0 | browser + cash + supply + stock-exception |
| workflow_dispatch | true | true | true / true | exit 0 | same full cash protocol |
| workflow_dispatch | true | false | true / false | exit 1 | not reached by workflow |
| workflow_dispatch | false | true | false / true | exit 1 | not reached by workflow |
| workflow_dispatch | false | false | false / false | exit 1 | not reached by workflow |

Manual defaults remain false. Separate runtime authorization descriptions remain intact.
Existing repository/fork restrictions remain intact.
The event filters and dispatch metadata are bound by an unchanged prefix hash.
Automatic event expressions ignore manual inputs and explicitly enumerate PR and push events.

## Evidence and commands

1. `python tests/test_golden_path_workflow.py -v` against the original workflow: exit 1.
   [Original reproduction](01-original-regression.log) records actual parser exit 2 for both automatic events,
   the two missing early rejections, and absent regression wiring.
   [Original workflow](original-workflow.yml) preserves the actual pre-edit source bytes.
2. Same focused command after the initial correction: exit 0, 5 tests.
   [Initial correction](02-corrected-regression.log).
3. `python -m unittest discover -s tests -p test_golden_path_*.py -v`: exit 1, 108 tests.
   [Intermediate failure](03-affected-suites.log) identified an existing source assertion in
   `tests/test_golden_path_stock_exception.py:22`. Its file remained unchanged.
4. Same discover command after preserving the existing dependency guard and explicit manual expression:
   exit 0, **108 tests, zero failures, zero skips**, including all six final workflow tests.
   [Final focused and affected suites](04-final-affected-suites.log).
5. Installed PyYAML 6.0.3 `BaseLoader` parsed the workflow and confirmed main event filters,
   matching step counts, and Python compilation. Installed Git Bash 5.3.15 `bash --noprofile --norc -n`
   checked all 13 actual run blocks from YAML through stdin. Exit 0.
   [Syntax result](05-syntax.log). No shell runtime blocks were executed by this check.
6. `python tests/check.py`: exit 2 before any tests, missing worktree jsdom.
   [Repository-check limitation](06-repository-check.log).
7. `git diff --check` and index/source readbacks passed. An additional whitespace audit
   incorrectly included captured unittest logs and stopped on their preserved formatting.
   No source defect was found. Raw logs remain intact.
8. Final readback checks source/document whitespace separately from raw logs:
   [Final readback](08-final-readback.log), exit 0.

Verification invocations: 8, including expected red controls and the broader prerequisite failure.
No blind retry. The intermediate suite failure caused a source-informed workflow adjustment.
The remaining broad-check blocker was not retried.

The new test evaluates the actual workflow environment expressions in a closed boolean AST.
It executes the embedded Bash array/invocation with only `python3` intercepted to capture argv.
It compiles the actual harness parser and every guard before optional connection-file loading.
No harness imports, SQL/API/browser processes or connection files execute through that seam.
Negative controls retain exit 2 for original flags and historical unpaid browser acceptance.
A missing connection stops the actual C6 shell before its Python command.
The test fails if Bash is missing; it never skips or installs tooling.

Frozen LF hashes protect all unchanged steps, including smoke, restore, browser-driver setup,
SQL EULA/Developer edition, test-certificate policy, evidence verification and teardown.
The prefix hash protects job timeout, event filters, runtime authorization descriptions and permissions.
The immutable SQL image digest is also checked directly.
Guard/regression/C6 steps must remain unconditional and cannot use continue-on-error.

[Source bindings](source-bindings.json) records RAW and normalized LF SHA256 values for final sources,
original workflow and base Git blobs. Harness/oracle/suite bytes are unchanged after LF normalization.
Only the workflow, new workflow test and this evidence directory are owned changes.

## Identity and limits

Host: `SUAZO-PC`. Provider/harness: Codex through T3 Code.
Session runtime identifies model `gpt-6.1-sol`, reasoning `high`.
Agent-awareness independently reports this task at the assigned tool-managed worktree with `gpt-6.1-sol/high`.
No settings were substituted. Token/cache/reasoning usage and provider cost are unreported/unknown.
Session allowance was used. No additional paid requests or nested delegates were launched.

Actual combined browser -> API -> SQL acceptance remains **NOT RUN**.
SQL, Docker, services, workflow execution, network installation, accounts, staging, commits,
push, merge, deployment and credential copies remain **NOT RUN**.
The historical private job log was not copied or published; the failure was independently reproduced offline.

## Blocker and next action

The broader repository checker requires `tests/frontend-deps/node_modules/jsdom/package.json`
inside this worktree and stopped with `Missing jsdom: run python tests/check.py --install first.`
The canonical read-only dependency metadata reports jsdom 26.1.0 at
`C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules/jsdom/package.json`.
No install or dependency copy was attempted: installation is prohibited and the runner requires a local path.
This is a broader verification prerequisite gap, not a failing golden-path assertion.

Owner: primary. Integrate the exact owned diff serially, obtain Astra/xhigh review,
and run `python tests/check.py` in the canonical checkout with its existing cached dependencies.
Completion check: exit 0 on the integrated artifact, then exact-source CI under a separate authorized packet.
Runtime proof needs a separate primary-owned fresh browser/API/SQL runtime packet.
Rollback: revert only this workflow diff and remove the new focused test; preserve other workers' files.
Worker output does not grant merge or runtime acceptance.

## Material lesson

Cash harness contracts can invalidate older automatic workflow flags while smoke remains green.
Checking YAML substrings alone missed that contradiction.
Execute the real embedded command through the actual parser seam before provisioning runtime.
The original exit-2 controls and final 108/108 checks are the evidence for this correction.

## Primary serial import

The primary verified all nine source bindings against worker bytes, Git base and canonical sources.
Only the workflow and its new test were imported as executable changes.
The eight original logs are archived under ignored `private-exports/merge-readiness-20261116/corrections/golden-logs/`.
`IMPORT.json` maps their exact paths and SHA256; earlier relative `.log` links refer to those archives.
The original workflow remains inert evidence. Independent review and integrated checks remain pending.

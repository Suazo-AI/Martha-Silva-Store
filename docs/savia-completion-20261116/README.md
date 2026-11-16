# SAVIA: current completion record

Updated 2026-11-16 on SUAZO-PC. Primary: T3 Code / Codex / `gpt-6.1-sol/max`.

**The accepted UX is published. A verification-tool correction is integrated locally. Production remains NO-GO.**
This record separates SAVIA v2 in `savia/` from the earlier backend in `backend/` and the public storefront.
The [SAVIA v2 plan](../../savia/docs/PLAN.md) owns its completion criteria. Earlier evidence keeps its original scope.

## Verified work

| Delivery | Direct evidence | Limit |
| --- | --- | --- |
| Simpler staff UX | [Primary acceptance](../savia-ux-20261116/ACCEPTANCE.md); [final Astra review](../savia-ux-20261116/corrections/lookup/astra-recheck.md) | Accepted within tested boundaries |
| UX publication | `Tony@63a8b1e9bfe50e9426295cb22097514fc15155e7`, remote SHA matched; [progress receipt](../progress/20261116T195144037791Z-d00fb77855.json) | Push is separate from deployment |
| Local UX verification | 98/98 Node tests; 24/24 independent adversarial scenarios; final Chrome lookup 8/8 | Chrome uses fictional HTTP responses |
| CI on the published UX | [Run 43943782960](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/43943782960), attempt 1: T-SQL `PASS=134`; .NET 144 PASS, 1 FAIL, zero skips | Overall FAILURE; Spec17 failed |
| Other checks on that SHA | Progress digest, progress documentation and Tony source snapshot succeeded | These do not override the SQL workflow failure |
| Verification-tool correction | [Worker return](ci-worker/README.md), [commands and source hashes](ci-worker/RESULT.json); primary matched 7/7 bindings and inspected the original Spec17 TRX | Worker records remain historical returns; primary accepts the narrow correction below |
| Synchronization review | [Astra/xhigh minimum proof](sync-preimplementation.md); primary matched 6/6 Git/LF source bindings and read the affected simulator and SQL paths | REVISE; source findings and a proposed acceptance contract, no runtime proof |

The UX retains all authorized routes, uses readable receipt numbers and offers four fictional demo roles.
Sales require an explicit valid seller. Uncertain sale attempts preserve their original key and body.
Recovery looks up the receipt without automatically sending the sale again. A lookup 404 does not prove rejection.
Session and navigation guards reject delayed UI updates. [Full UX evidence and limits](../savia-ux-20261116/README.md).

## Verification-tool correction: primary acceptance

The worker reproduced a real local failure: the quick verifier ran web tests from `savia/`.
A lifecycle test then resolved `savia/savia/web/api.mjs` and failed to import it.
The correction runs that web step from the repository root, matching the workflow.
Other step directories, product code, the original C# test and SQL workflow remain unchanged.

Primary checked the two-file code diff, all seven LF source bindings and the original TRX.
Primary imported exactly four worker paths after destination drift checks.
Fresh canonical command: `python -m unittest discover -s savia/tests -p test_verify.py -v`.
Result: **4/4 PASS, exit 0**, including the real web step and full-mode failure/cleanup boundary checks.

Worker evidence remains distinct: real regression 3 PASS / 1 FAIL → 4/4 PASS; unchanged Spec17 1/1 PASS.
Its final quick run included 30/30 Python tests and 98/98 web tests. Formal was explicitly SKIP because tools were absent.
The historical CI omitted the inner quick diagnostic. Its exact original cause is unconfirmed; the local defect and correction are proven.
Primary accepts this narrow local correction. Remote CI of the corrected source is not yet accepted.

Lesson applied: exercise a failing wrapper through its actual command and working directory before repeating the broad suite.

The primary also ran the required repository checker once: `python tests/check.py`, exit 1 after 84.062 seconds.
It stopped in `tests/asset-audit.py`: three fixture errors reported `WinError 1314` while creating symbolic links.
This is a Windows privilege failure; it is not a passing full suite or a reproduced defect in the changed verifier.
Raw log SHA256: `9ae3a42c4e00b34e4c566ba04c8d642d902441084bcce476871b59c2fd779d3b`.
The authorized publication runs the existing Linux snapshot workflow, including `python tests/check.py --install`.
Primary must read that exact-SHA result before closing this check. No Windows privilege or security setting was changed.

## Pull requests: verified routing before merge

GitHub readback on 2026-11-16 found three open PRs. This snapshot is bound to Tony at `63a8b1e`.

| PR | Current route | Verified relationship to Tony | Disposition |
| --- | --- | --- | --- |
| [#2](https://github.com/Suazo-AI/Martha-Silva-Store/pull/2) | `claude/funny-brahmagupta-5e5rj0` → `main` | Head `8744a96` is already included in Tony; Tony has 158 later commits | It does not represent current Tony; prepare the current integration route before a merge decision |
| [#5](https://github.com/Suazo-AI/Martha-Silva-Store/pull/5) | Seasonal discounts → `main`, draft | Seven commits unique to that branch; diverges from Tony | Review its own increment and regressions; no acceptance inferred from the title |
| [#6](https://github.com/Suazo-AI/Martha-Silva-Store/pull/6) | CI gate → the old PR #2 branch, draft | Three unique commits; diverges from Tony | Check whether its five-file change remains necessary and compatible with current verification |

Tony is 254 commits ahead of main and zero behind at this cut. No open PR targets main from Tony.
The GitHub comparison returns at most 300 changed files here; it is not a complete review of the integration diff.
No PR was merged, closed, retargeted or created in this update.

Minimum merge contract: fix the intended source/base pair; inspect the actual delta and secrets;
pass focused and applicable integrated checks on the final combined source; prove affected money/permissions/data paths;
obtain independent review; record remaining inactive work and a rollback path; then obtain merge authority.
Merge readiness and production readiness are separate claims. Avoid repeating unaffected proofs solely to increase test counts.

## Synchronization review: primary disposition

The report content is preserved; the public copy removes one extra blank line at EOF found by the staged whitespace check.
The original bytes remain in private evidence. Primary adopts its five minimum proof scenarios before assigning corrections.
This accepts the review as an actionable work contract. It does not accept the current synchronization implementation.

| Finding | Direct source or declared limit | Required correction and owner |
| --- | --- | --- |
| Computed-column writes | [Simulator metadata and writes](../../savia/tools/db/simulator.py) omit only timestamp/rowversion; [V028](../../savia/db/migrations/V028__usd_change.sql) adds a computed tender column | Executor excludes computed columns and proves valid application without changing derived values |
| Remote outbox assumption | V028 requires an outbox event for every POS sale, including replicated sales | Executor distinguishes origin-event durability from replicated business rows; never fabricates remote events |
| Restore can lose a sale | Simulator uses a process-local blocked set and explicitly accepts losing one unsynchronized sale | Executor enforces durable quarantine, rejects stale ownership/forks and recovers or reconciles the tail before reopening |
| Incomplete dependency coverage | Report identifies omitted financial tables and a credit-status ownership conflict | Primary bounds the first proof explicitly; executor covers dependencies and final exhausted credit status |
| Production transport missing from audited paths | Astra found simulator transport and SQL cursor helpers, without an application synchronization endpoint/worker | Primary scopes a real transport; its critical path needs independent proof |

Frozen proof order: three offline branch sales with independently fixed IDs and totals; atomic replay/cursors;
credit transfer, cancellation and concurrent spending; restore/restart without losing sales; independent negative controls.
Each expected business operation must be asserted. Internally balanced but missing operations must fail.
Existing single-database tests remain useful evidence within their original scope.

The report's runtime packet is proposed only. It labels the pinned SQL image Express, whereas the existing workflow uses Developer.
Resolve that edition label in any future execution packet. No simulator, container or synchronization runtime was executed or authorized here.

## Remaining work

| Item | Evidence, cause or gap | Next action and owner | Completion check |
| --- | --- | --- | --- |
| Corrected-SHA CI | Local regression is green; previous SQL CI failed | Primary publishes under the applicable runtime scope and reads completed checks | Exact remote SHA and successful applicable CI; no automatic retries |
| Three-branch synchronization | A-04, A-05 and A-09 remain pending; the source review found implementation and oracle gaps | Primary adopted the contract above; executor corrects source, then independent judge and separately scoped runtime | Accepted multi-node evidence, real transport and conserved money/stock |
| Current real cash journey | UX Chrome proof uses synthetic HTTP | Primary prepares the isolated browser→API→SQL sale, lookup, refund and close journey | Browser actions match persisted rows and accounting totals |
| Operational readiness | Current-source restore, access, monitoring and deployment qualification are incomplete | Primary verifies existing artifacts and prepares only missing operational checks | Scoped recovery proof, access evidence, release/rollback and authorized target readback |
| Performance and physical devices | A-07 physical printing and A-10 load remain unproved | Run the measured device/load acceptance profile after the critical path | Actual device results and measured performance, not a simulated label |

The prior CI cleanup log records removal of its container, volume and network. It did not retain a separate absence query.
No merge, deployment, native SQL change, real customer data or payment occurred in this repository update.
GitHub publication authority does not by itself authorize another SQL runtime.

## Repository reconciliation

The root README, agent entry, code map and project status now route readers to SAVIA v2 and this dated record.
Historical reports, acceptance receipts and hashes retain their original meaning. The older backend ledger is not repurposed as v2 proof.
The imported worker report remains unedited; this page records primary acceptance separately.

Only explicit reviewed paths enter the commit. Raw logs, private exports, caches, credentials, local review pages and the untracked third-party skill bundle stay outside publication.
Existing `docs/DECISIONS.md` changes concerning an old preview destination remain separate; this update grants no deployment authority.
[Repository update scope and checks](REPOSITORY-UPDATE.md) records the final publication boundary.

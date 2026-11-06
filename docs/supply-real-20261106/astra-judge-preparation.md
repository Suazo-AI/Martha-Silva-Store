# Astra: supply receipt preparation adjudication

**ACCEPT WITH LIMITS — preparation only. Advisory worker delivery; primary retains acceptance. Production remains NO-GO.**

No material preparation blocker found in this bounded source/evidence review. F1 and F2 are resolved in current source. F3 and F4 remain nonblocking. The combined browser → API → SQL receipt journey is **NOT RUN** and requires new explicit runtime authorization from Jason. No C2/C9/C10, payment or production closure follows.

## Identity and scope

Mode: VALIDATE. Host: SUAZO-PC / Windows. Harness/provider: T3 Code / Codex. Requested model/reasoning: `gpt-6-astra/high`. Effective session runtime reports `gpt-6-astra`, high; awareness independently labels this task `gpt-6-astra/high`. Internal reasoning consumption, tokens and cost are unknown.

Managed worktree: `C:/Users/Jason/.t3/worktrees/github/t3-816db411`. Personally verified `git rev-parse HEAD` equals `a77f705a6fd6a2778e4112c21aaa72ab8e478015`. Initial Git status was clean. Awareness ran at entry and immediately before report creation. This reviewer owns only this report; no nested delegation.

Read repository AGENTS, agent entrypoint, SQL instructions, relevant status and test guidance, and all seven requested review inputs. None was absent. Canonical orchestration, PROTOCOL, OUTPUT, coordination and evidence-first playbook were accessible. Gemini's historical policy-access denial does not apply to this session; its denied contents were not inferred. No historical GLM prose was used.

Only changed path: `docs/supply-real-20261106/astra-judge-preparation.md`. Its final whole-file SHA256 is returned with the delivery, outside this file to avoid a self-referential hash.

## Personally verified source and provenance

A read-only Python comparison checked each of the **21/21** `REVIEW-CANDIDATE.json` LF hashes against disk bytes, `git show HEAD:<path>`, `git show 8523523a41d490f7bdcca016bf34cc5fc2c04a37:<path>` and `CI-852.json`. Zero mismatches. Normalization replaced CRLF with LF only, preserving BOM. Historical RAW Windows hashes were not imposed on this checkout.

This demonstrates unchanged bound source between successful CI852's commit and the review HEAD. It does not claim CI852 ran on `a77f705`. Original `CANDIDATE.json`, worker README and original primary review retain their historical scope. The snapshot run `42170897865` was not consulted; primary owns its readback.

No test suite, build, browser, API, SQL, Docker, network probe or CI dispatch ran here. Personally performed checks were Git readback, source inspection, hash comparisons and in-memory Python AST/text assertions. No installs, account/certificate changes, stage, commit, push, PR or deletion occurred.

## Objection adjudication

**F1 MEDIUM — resolved for parent diagnostic propagation.** `tests/golden-path/golden_path.py:1043–1064` now explicitly allows all fourteen `c6_supply_*` literals extracted from the actual driver. Unknown text still maps to `browser_protocol_invalid`. AST inspection confirmed fourteen codes, no missing entries, and exclusion of the private-like sample.

`tests/test_golden_path_browser_safety.py:151–163` extracts driver codes, feeds child JSON errors through `run_child`, checks the exact raised code and recorded failure, and checks browser cleanup. `run_child` at lines 99–110 invokes the actual parent `harness.browser()` with mocked subprocess I/O. It is not a duplicated allowlist-only assertion. The added unknown-text case guards against broadening disclosure. Child-local catches can still coarsen some diagnostics; this correction specifically closes parent loss of permitted codes, not every child's diagnostic granularity.

`CORRECTIONS.json` records browser safety **24/24** and core safety **17/17** as primary results. I did not rerun them. The claimed fourteen pre-fix subtest failures have no retained initial red command/log. That historical reproduction cannot be independently replayed from a retained red artifact; no such artifact is invented. Direct old finding/current source comparison and the actual parser regression support closing the narrow defect without another mutation.

**F2 LOW — resolved.** `tests/golden-path/README.md:165–171` is valid UTF-8. The receipt section restores recepción, añade, pérdida, recuperación and autorización, and uses “de inventario.” A direct text assertion found zero ASCII question marks or replacement characters in that section.

**F3 LOW — nonblocking, with a more precise rationale.** `tests/golden-path/GoldenPath.Sql/Program.cs:235–258` omits a direct `m.ReservedDelta=0` predicate. The aggregate oracle at lines 179–186 requires the matching movement's reserved delta to be zero and validates received quantities. `golden_path.py:469` requires these invariants to be zero before the ACK at line 1104.

The missing direct `l.PurchaseOrderId=@order` is covered by composite foreign keys, not merely purchase counts. `InternalSupplyDbContext.cs:63–82` binds receipt lines to their receipt/order and order-line/item. The actual migration `backend/src/Martha.Store.Api/Internal/Migrations/20261025085402_InitialInternalSavia.cs:477–490` creates those constraints. With the fixture's single order and line, the receipt ID/order filter and constraints preserve the intended relationship. Deployment of those constraints remains runtime evidence to obtain.

Current order status is separately checked by exact open/partial/complete counts. The helper usage text at `Program.cs:25` omits `receipt-identity`, but dispatch at lines 21–22 handles it. No demonstrated false acceptance results in this fixture. Do not mechanically apply Gemini's suggested status equality to arbitrary historical receipts: a partial receipt retains its historical status after the order completes. No C# change is required for this preparation verdict.

**F4 LOW — nonblocking presentation limit.** `golden_path.py:51–54` omits supply columns from the Markdown summary. The complete per-step oracle dictionary is retained at lines 464–465 and serialized through lines 484–496. Acceptance must inspect `evidence.json`, not infer supply correctness from `oracles.md` alone.

## Journey and adversarial boundaries

Source defines **17 browser checkpoints: 11 sale + 6 supply/logout** (`golden_path.py:58–70`). Independent expected arithmetic at lines 74–90 requires five units at 700 cents, receipts of two then three units, stock **25 → 27 → 30**, two receipts totalling **3500 cents**, and unchanged sales.

`browser_path.mjs:339–404` checks the partial receipt, distinct second receipt/key, pending identity across reload, GET recovery and final history. CDP interception uses the **Response** stage, requires HTTP200, reads the actual body, validates receipt identity/amount, then fails delivery at lines 356–372. `InternalCommandRunner.cs:109–116` saves the operation/result and commits before returning the outcome. HTTP200 plus subsequent SQL checks is the prepared proof chain; HTTP200 alone is not executed persistence evidence.

`golden_path.py:1075–1104` checks cumulative receipt POST counts, prohibits additional sale POSTs, requires the lost response's key/status, requires GET200 recovery with that key, and performs four parameterized SQL identity reads. The helper links receipt, line, movement, Inventory actor, order/location/item, quantity/cost and the persisted operation key/result ID. Each must return exactly one match. SQL aggregate checks run before the browser ACK; recovery/reload cannot advance on mismatched counts or identity.

Sanitization remains fail-closed within its stated known-secret scope: `browser_checkpoint` allows only shaped notes/network records; raw bodies and arbitrary error text are excluded. `golden_path.py:503–518` scans privately staged exact bytes before promoting the two approved files and writing the hash manifest. Lines 1266–1275 remove public artifacts on scan failure. `verify_evidence.py:17–48` rejects invalid/symlinked inputs and changed hashes, scans known CI secrets and writes the bytes it checked. This is not proof against every unknown secret or a hostile host.

Cleanup retains ownership gates. `golden_path.py:642–652` requires an acknowledged create before drop authority; uncertain creation requires operator cleanup and fails acceptance. Lines 921–977 check Chrome profile/ancestry and process start identity before group signals and absence readback. Lines 1162–1198 stop processes, verify owned database absence and private-directory removal. Lines 1258–1264 turn incomplete cleanup into FAIL. Source review confirms these branches; actual cleanup remains NOT RUN here.

`.github/workflows/golden-path.yml:13–16,102–113` defaults `supply_receipt=false` and adds `--supply` only for manual dispatch with true input. Existing ordinary golden-path triggers still run their original API/SQL scope; this input is not a technical approval system. Uploads use only verified files, and lines 162–180 require container absence after cleanup. The automatic staff candidate workflow uses `Category!=SqlServer`, not the combined journey.

## Evidence limits and primary action

Read `CI-852.json`: run **42169677581**, commit **8523523a41d490f7bdcca016bf34cc5fc2c04a37**, recorded completed SUCCESS; helper Release build **0 warnings/0 errors**, staff **124/124**, mocked Chrome **50/50 + 8/8**, database-independent .NET **526 passed, 0 failed, 55 skipped, total 581**. The 55 skips remain explicit. I inspected the stored receipt/excerpts and bound source, not the private full log or live GitHub.

Historical SQL run **42163110947** on **708bdbb**, reported **602/602 including 76 SQL cases**, plus backup/restore/restart/cleanup, has independent historical scope. It cannot accept this combined journey. The prior SDK absence claim is superseded by recorded portable **10.0.402** compilation and CI852 build evidence; no installation is needed on that evidence.

Remaining blocker: combined persistence and cleanup have no executed evidence. Cause: new runtime authorization is absent; the earlier isolated authorization is consumed. No runtime correction was attempted because this packet forbids it. Owner: Jason for authorization, primary for execution and acceptance.

Next primary action: independently accept this bounded review and complete snapshot CI readback, then present the exact reviewed SHA and bounded runtime request to Jason. After explicit authorization, require all 17 checkpoints, four identity matches, two POSTs, same-key GET recovery, exact oracle counts, sanitized evidence and same-run cleanup readbacks. No additional source mutation or repeat review is required by the findings above.

# N5 controlled mutation validation — returned, acceptance pending

Task: `savia-n5-mutation-20261105`. Host: `SUAZO-PC`, Windows.
Actual runtime: Codex `gpt-6.1-sol`, reasoning `high`, reported by T3 runtime and agent-awareness.
Worktree: `C:/Users/Jason/.t3/worktrees/github/t3-0dda9f02`.
Base: `5ab44fbb8210f3d6e98f34745700194195c0e1ce`.
No commit, staging, push, PR, branch creation, canonical write, or nested delegation occurred.

The baseline passed 8/8. Three deliberately injected regressions failed on their specified semantic invariants. The restored baseline passed 8/8. These are injected defects, not reproduced defects in the unchanged product.

| Invocation | Filter (`MARTHA_BROWSER_TEST_MATCH`) | PASS / FAIL | Exit | Observation |
| --- | --- | --- | --- | --- |
| baseline | `N5` | 8 / 0 | 0 | Unchanged product plus frozen test overlay |
| M01 | `N5 held operation recovery` | 0 / 1 | 1 | `Original pending bytes changed during held recovery.` |
| M02 | `N5 discarded 404 receipt` | 0 / 1 | 1 | Expected `null`; retained obsolete ID `00000001-0000-0000-0000-000000000005` |
| M03 | `N5 late old receipt 404` | 0 / 1 | 1 | `Old 404 erased reference after generation invalidation.` |
| restored | `N5` | 8 / 0 | 0 | Exact original product bytes restored |

Exactly five browser invocations completed, including harness teardown. Each result is linked to the source hashes captured by the browser harness. [RESULT.json](RESULT.json) records complete assertions, commands, filters, exits, source manifests, restoration checks and private log hashes.

## Frozen source and byte policy

Only the authorized canonical test file was read and copied. Its raw SHA256 was verified before copying:
`88eaa468cc92bdd32ca6b066b512c6a8ebd38969cc7f332dbad9b41122269dea`.
The final worktree test file has the same raw hash. Its only Git change is the approved `await browserTurn(s.page)` after the second synthetic submit in the late-404 case.

Raw hashes cover exact disk bytes. Canonical-LF hashes replace CRLF with LF only. No other normalization occurs.
The initial app has 606 CRLF endings; login has 188. Their canonical-LF bytes equal the base Git blobs.
Mutations preserve those endings. Every controlled run restores the saved original product bytes in `finally`, including assertion failures.

| Source/version | Raw SHA256 |
| --- | --- |
| app baseline and final | `383c40447e91aa465cc945138699151826d7c1ad93f2f1ed041aa3dcda303309` |
| login baseline and final | `ac7714a22eb1e7a383ca41e3e11343472025271dcf21dc862f39cf8c386fc787` |
| M01 app | `c57236b7668b89b592216b04888d80a517553eb75cd490ee33aefbf2386fd26b` |
| M02 app | `3fe413e586f55c2c55d394e3da59acf101e044a859e71bfd5398ebdb994efb86` |
| M03 app | `c30d7193946944dae7c913ac77debc7e7cd9938cf995c757cb1d658296ba80af` |
| M03 login | `88024cfa9e8e7d86d94da3062a2fad8aa5420dc3140668c9c3adb06dc940ba73` |

## Controlled edits and reproduction

Use an authorized isolated checkout at the base SHA and the exact approved overlay. Do not apply these inert patches to the canonical checkout.
To reproduce exact baseline disk bytes from Git on a different newline configuration, read each Git blob as bytes and replace each LF with CRLF. Verify the hashes above before running.

- [M01.patch](M01.patch): remove only `busy || pending || ` from the submit guard. Actor, role, form checks and the resolve guard remain. The existing resolve guard can prevent a new POST while the submitted handler still corrupts the persisted original operation. A new POST is not required for this kill.
- [M02.patch](M02.patch): remove only `storage().removeItem(receiptKey(id));` from `restoreReceipt`'s gone branch. The focused test observes the retained obsolete reference before creating the fresh sale.
- [M03.patch](M03.patch): remove the two `current(generation);` calls within `createAuthClient`'s `request` function and only `restoreReceipt`'s `if (!current(g, id)) return;`. Other generation checks remain. This is a combined boundary control. It does not isolate one guard. The completed old 404 erases a retained reference after logout, which the observation window detects. No unreachable newer-pending sale was simulated.

For each invocation, set the table's filter, use its distinct output directory, and await completion:

```powershell
$env:MARTHA_BROWSER_TEST_MATCH = 'N5' # use exact filter from table
node tests/browser-mock-validation.mjs C:/Users/Jason/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright docs/n5-browser-20261105/mutations/baseline
$LASTEXITCODE
```

Restore exact saved product bytes after each mutant and before the next run. Verify both raw source hashes and zero product diff. Exact commands for all five runs are in RESULT.json. The private execution driver is `C:/Users/Jason/MARTHA-SILVA/test-runs/n5-browser-20261105/t3-0dda9f02-mutation-20261105/run.py`; its hash is recorded there. No installation was needed.

## Errors, aborts and limits

Baseline and restored runs each had zero uncaught page errors and zero external requests. Each recorded one deliberate synthetic sale `net::ERR_FAILED` and one logout/navigation `net::ERR_ABORTED`. M01 recorded one deliberate sale failure. M02 and M03 recorded zero network failures. Expected failures are retained and counted in the JSON.

The first post-run evidence classifier incorrectly rejected the expected baseline logout abort. Direct browser evidence already showed 8/8 PASS, exit 0. The classifier was corrected to recognize that specific expected abort. The same baseline evidence was reused; the browser was not rerun. RESULT.json retains this correction and lesson. Final blockers: none.

Raw logs remain private under `C:/Users/Jason/MARTHA-SILVA/test-runs/n5-browser-20261105/t3-0dda9f02-mutation-20261105/`. Exact paths and SHA256 are recorded per run. No raw log was copied or renamed into public evidence. Public browser artifacts contain synthetic mock data only.

Final source diff: the approved test overlay only. Product diff: empty. Evidence changes stay inside this directory.
Token and currency usage: unknown; runtime did not report them. Runtime used the authorized existing Codex subscription. No paid fallback occurred.

NOT RUN: real API, SQL, Docker, certificates, TLS connections, real data, payments, device testing, full suite, CI and operational acceptance. C9 was untouched.
Next action: primary inspects the actual evidence and hashes, then independent Astra/high adjudicates M1 and the observation-window objection. Worker return is not acceptance or readiness.

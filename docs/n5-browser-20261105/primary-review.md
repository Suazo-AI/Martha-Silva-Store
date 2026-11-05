# N5-COV: primary acceptance with limits

Date: 2026-11-05 UTC. Host: SUAZO-PC.
Primary: T3 Code / Codex, gpt-6.1-sol / xhigh.
Disposition: ACCEPT WITH LIMITS. N5-COV is technically done.
Production remains NO-GO. No product defect was reproduced or fixed in this batch.

## Accepted result

The three frozen browser gaps are covered by actual Chrome tests with HTTP mocks:
held recovery preserves original pending bytes and blocks additional submission;
404 discard permits one complete multiarticle sale with stock refresh; reachable
logout invalidation protects state from a held old 404.

The hypothetical same-generation newer-pending sale is reasonedly dismissed.
start keeps busy while awaiting restoreReceipt, lock disables controls, and the
submit handler rejects busy/pending. The tests did not manufacture that state.
The ledger done_when is unchanged. No owner waiver is used.

| Current-overlay run | PASS / FAIL | Exit | Evidence |
| --- | --- | --- | --- |
| baseline | 8 / 0 | 0 | Original product plus frozen approved test |
| M01 | 0 / 1 | 1 | Original pending bytes changed during held recovery |
| M02 | 0 / 1 | 1 | Obsolete reference retained instead of null |
| M03 | 0 / 1 | 1 | Old 404 erased reference after generation invalidation |
| restored | 8 / 0 | 0 | Exact original product bytes restored |

M01 removes only busy/pending submit guards. Other POST protection remains;
corruption of the stored original key is the correct semantic kill.
M02 omits only obsolete receipt removal. M03 removes two request epoch checks
and restoreReceipt's generation guard together. These are deliberately injected
regressions, not demonstrated defects in the unchanged product.

## Independent review and dispositions

Original Astra/high review: APTO CON REPAROS. Primary corrected exact initial
stock cells and attribution to combined logout protection.
Opus claude-opus-5-5 via Antigravity: ACCEPT WITH LIMITS, material M1.
High was requested; effective reasoning remains unknown. The critic's global-rule
access denials remain disclosed. This acceptance does not verify that setting.

Final Astra/high: ACCEPT WITH LIMITS; actual high reported by runtime metadata.
[M1 adjudication](mutations/judge.md) finds no material blocker for this scope.
Primary accepts that verdict after independently inspecting the actual evidence.

- M1: closed by real negative controls plus restored green, without criterion change.
- m1: closed for the observed scenario/window. M03 detects the forbidden erase
  after the existing response.finished/two-frame wait. No isolated-guard or
  exhaustive scheduler proof is claimed. Future additional waits need new review.
- m2: browserTurn follows the second synthetic submit in the tested overlay.
- m3: PLAN's stale Opus-pending header is corrected before publication.
- m4: explicit byte policy, archived log references and import mappings verified.

The final judge's prose has a 65-character login hash transcription error.
Its exported report preserves that wording and adds a primary erratum with the
actual 64-character value. The actual source manifest is correct. No extra
review was needed for this factual export annotation.

## Source versions and evidence

Original worker: t3-6b804833 at base 1e353d45cd0eb2ad8e79589f410ac191c1368b06.
Original test raw SHA256: 020b29f19d8820489ccdb4317141ec3ca2fd83d4733a8244a277bc5ab982862c.
That worker recorded focused8/8, full browser50/50 and staff102/102, zero skips.
Primary's exact-stock corrected focused8/8 used raw test hash
8fdd63efe6a2858b15c54cf589c1b3215d6f70320b946a3151b875b5e86960c8.
Neither full50/50 nor the earlier focused run is attributed to the current overlay.

Mutation worker: t3-0dda9f02 at base 5ab44fbb8210f3d6e98f34745700194195c0e1ce.
Current approved test raw SHA256:
88eaa468cc92bdd32ca6b066b512c6a8ebd38969cc7f332dbad9b41122269dea.
It includes the second-submit browser turn. Exactly five browser invocations ran.
Current worker and canonical product bytes equal their initial baseline.

Primary verified 13 original evidence hashes, five private log hashes, the private
driver hash, all five source-bound result sets and exact original patch replay.
The independent final judge additionally verified 29 frozen inputs, 53 portable
integration hashes, 14 import entries, nine historical logs and 30 source hashes.
The original patches reconstruct exact observed mutant bytes in memory.
The original M03 patch is privately archived; its public derivative only removes
indentation on two blank added lines. No run is attributed to that derivative.

Frozen REVIEW-PACKET.json describes inputs before acceptance edits. The exact
29 input bytes and packet are archived at
C:/Users/Jason/MARTHA-SILVA/test-runs/n5-browser-20261105/review-inputs-before-acceptance/.
Those historical document hashes are not a current-working-tree manifest.
INTEGRATION.json supplies the current portable artifact manifest.

## Integration checks, limits and publication

python tests/test_progress.py: 23/23 PASS.
python tests/test_delivery_status.py: 24/24 PASS.
python tools/delivery_status.py --check: valid35 items.
python tools/export_progress.py --verify: 15/15 preserved evidence hashes.
git diff --cached --check: exit0 before publication.
Primary did not repeat the worker's browser invocations.

The general Windows portable run failed with WinError 1314 during symlink fixture
creation. No security/privilege change or repeated attempt was made.
Linux portable CI passed on earlier source0a056be and doc-only5ab44fb.
Those earlier results do not prove CI for this publication. Remote delivery
requires normal-hook SYNCED, matching remote SHA and applicable checks on that SHA.
[Publication evidence and criterion](PUBLICATION.md).

Baseline/restored each contain zero page errors and zero external requests.
Each retains one deliberate sale ERR_FAILED and one logout ERR_ABORTED.
M01 retains one deliberate sale failure. M02/M03 record none.
The worker corrected only an expected-abort classifier, reusing baseline evidence.
Primary corrected its assumption that console logs contain semantic errors;
those errors are in browser JSON, while logs contain names/counts. No rerun.
Lesson applied: verify each output schema and require semantic kills plus exact
restoration instead of inferring sensitivity from the first green run.

NOT RUN: real API, SQL, physical devices, cross-browser performance, full browser
suite on this overlay, production or operational acceptance. Usage/cost unknown.
C2 walkthrough, C9 consumed TLS attempt, C10 operational acceptance, payments and
hosting remain separately gated. No correction attempted here because this batch
has no authority to run those paths. Owners and completion checks remain in the
release plan and ledger. Next: normal publication/readback and exact-SHA CI.

# N5 negative controls: accepted with limits

Sol/high ran exactly five Chrome/HTTP-mock invocations at base
`5ab44fbb8210f3d6e98f34745700194195c0e1ce` with the approved test overlay.
Primary independently inspected the artifacts. Astra/high returned ACCEPT WITH LIMITS.
Primary accepts N5-COV as technically done. No existing product defect was reproduced.

| Run | PASS / FAIL | Exit | Result |
| --- | --- | --- | --- |
| baseline | 8 / 0 | 0 | Original product plus approved test |
| M01 | 0 / 1 | 1 | Original pending bytes changed during held recovery |
| M02 | 0 / 1 | 1 | Obsolete receipt reference retained instead of null |
| M03 | 0 / 1 | 1 | Old 404 erased reference after generation invalidation |
| restored | 8 / 0 | 0 | Exact original product bytes restored |

M01 removes only busy/pending submit checks. M02 omits obsolete receipt removal.
M03 removes the two request epoch checks and restoreReceipt generation guard.
M03 proves sensitivity to the combined boundary regression. It does not isolate
one guard. The existing observation window detects the forbidden reference erase.

[RESULT.json](RESULT.json) is the frozen worker record. Its raw evidence hashes
refer to original worker files, not to renamed or derived public copies.
[worker-README.md](worker-README.md) preserves the original worker report.
[IMPORT.json](IMPORT.json) maps source bytes to public artifacts and documents
line-ending semantics and the portable M03 patch correction.

Primary verified 13 original evidence hashes, five private log hashes and the
private driver hash. All five browser results bind to the captured product
sources. Console logs confirm counts and test names; semantic assertion errors
are in browser-results.json. Every recorded restoration equals baseline.
Both current checkouts match baseline product bytes and base Git blobs after
CRLF-to-LF normalization. No browser run was repeated by primary.

The three original patches reconstruct the exact recorded mutant bytes.
The public M03 patch removes spaces on two blank added lines, so Git whitespace
checks stay clean. Its only difference from the executed mutant is blank-line
indentation. Exact original patch bytes remain in the private archive named by
IMPORT.json. Public M01/M02 patches retain original content. Never apply these
inert mutation patches to Tony or production.

Baseline/restored each record zero page errors and zero external requests.
Each retains one deliberate sale ERR_FAILED and one logout ERR_ABORTED.
M01 records one deliberate sale failure; M02/M03 record none.
The classifier correction is preserved in RESULT.json; it did not rerun Chrome.
The two screenshots contain synthetic fixtures, directly inspected by primary.

NOT RUN: real API, SQL, physical devices, full suite on this overlay, CI on this
overlay, production or operational acceptance. Original 50/50 browser and 102/102
staff runs remain historical evidence on their recorded source version.
Opus requested high but its effective reasoning remains unknown.

Owner: primary for serial integration and publication. [Astra adjudication](judge.md)
satisfies M1 and the observed-window objection. Primary accepts with the documented
limits. Next: normal publication and exact-SHA CI. No criterion waiver is used.

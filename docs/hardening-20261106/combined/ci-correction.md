# Snapshot portability correction

The original publication synchronized as `8523523a41d490f7bdcca016bf34cc5fc2c04a37`.
Its Linux snapshot [run 42169677749](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42169677749) failed before historical regressions ran.
The failed assertion was `Publication bytes differ from the recorded snapshot`.

The primary compared the three changed manifest entries with actual Git blobs.
The Windows working files used CRLF. The committed `app.js`, `index.html` and `locale-en.js` already use LF under `.gitattributes`.
All three committed blobs equal the previous working files after CRLF-to-LF conversion only.
No frontend logic, layout, images, styles or committed frontend source bytes changed in this correction.

The primary normalized those local inputs, regenerated dist and explicitly recorded the snapshot again.
Only those three manifest entries changed. Each now matches the exact existing Git blob hash and byte count.
The recorder now rejects CRLF in top-level HTML/JS/CSS before writing evidence.
Captured resources in nested directories keep their original bytes.
The test verifies all three publication file types and confirms rejected recording leaves evidence untouched.
The new test failed before the guard and passed after it. Header tamper and missing/extra path controls remain.
[Commands, exits, normalization and private log hashes](CI-LF-FIX.json) preserve this red/green result.

Fresh `prepare.py`, explicit snapshot recording, snapshot regression, reproducible build and original snapshot verification all exit 0.
The comparison still uses exact RAW bytes; no assertion was removed or hash normalization substituted for deployment integrity.
The earlier browser recordings describe the same LF-normalized frontend code, with different Windows transport line endings.
They are not a new browser execution on this correction commit. No new visual behavior requires a browser rerun.
[CANDIDATE.json](CANDIDATE.json) is historical. [REVIEW-CANDIDATE.json](REVIEW-CANDIDATE.json) binds the current 27 source paths.

| Blocker | Resolution and completion check |
| --- | --- |
| Windows-only snapshot | Directly reproduced; CRLF guard and regression added; local checks green. Primary must read Linux CI on the corrected commit before closing this gate. |
| Independent review | Paused while the snapshot failed. Primary sends the corrected manifest and both the original and correction evidence to Gemini. Astra follows the critic. |

Lesson: enforce the repository's checkout line endings before recording RAW release hashes. Local source/dist parity alone does not prove portable publication.

## Linux readback and the next exposed layout guard

Run [42170897865](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42170897865) completed on exact `a77f705a6fd6a2778e4112c21aaa72ab8e478015`.
Publication integrity and reproducible build passed. This closes the original snapshot portability failure.
The historical aggregate then failed at `ResponsiveImages.test_originals_dimensions_hashes_and_fallback`.
Its index layout constant described the CRLF version; actual index bytes and the Git blob are LF.
The primary proved both hashes and reproduced the same local failure before editing.

The correction changes only that exact hash and its comment in `tests/responsive_images.py`.
It does not change application source, layout, original images, derivatives or the exact-byte assertion.
The focused test now exits 0. An in-memory substituted index input exits 1; restored input exits 0.
[CI-IMAGE-LF-FIX.json](CI-IMAGE-LF-FIX.json) records commands, output hashes, the disposable driver and unchanged input hash.
The new Linux aggregate remains pending. A successful integrity job is not a successful aggregate.

The active Gemini storefront review remains attributed to its frozen a77f705 candidate.
The primary must adjudicate this narrow test-only delta explicitly when accepting that review.
The refreshed 27-path REVIEW-CANDIDATE describes current paths; historical manifests remain unchanged.
## Gemini rejection, M1 readback and M2 checkout correction

The independent [Gemini report](gemini-critic.md) rejects frozen a77f705 for M1 and M2.
The primary imported its exact 15,044 bytes; SHA256 `dd59769667a5010ac4b7d4c7e27a6b572f0fa18e9d8249bed5f6866c1f74db1b`.
This rejection is retained unchanged. The following is the primary disposition, not a replacement critic verdict.

**M1 is resolved on 8e38d98.** Both publication integrity/build and historical portable regressions passed in
[Linux run 42173233401](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42173233401).
That green result predates the M2 fix; it is not CI evidence for the new changes.

**M2 is reproduced and corrected locally.** The primary ran the original verifier in the critic's clean Windows checkout.
It exited 1 with `Publication bytes differ from the recorded snapshot`.
Git's Windows checkout filter returned 495-byte CRLF headers instead of the committed 486-byte LF headers.
The primary expanded the existing recorder regression to include `_headers`.
It failed before the fix because the recorder accepted the CRLF control file.

The fix adds explicit LF checkout rules for both `_headers` paths.
The recorder now applies its pre-write CRLF guard to control files too.
The same regression passes, including proof that refused recording preserves the manifest.
The direct canonical snapshot verifier and both static-header tests pass.
The Windows checkout filter now returns the exact existing 486-byte LF headers for both paths.
[Commands, logs, hashes and limits](CI-HEADERS-LF-FIX.json).

No app, header response, dist, media or recorded snapshot bytes changed.
The updated REVIEW-CANDIDATE binds 28 source paths, including `.gitattributes`.
New Linux CI and bounded Astra adjudication must still confirm the corrected commit.
The historical local/browser/runtime limits remain. No new production gate is closed.

Lesson: a RAW-byte release needs checkout rules and recorder refusal for every publication control file.
Correcting one file type without checking the other recorded types caused avoidable repair work.

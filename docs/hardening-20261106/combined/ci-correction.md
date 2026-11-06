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

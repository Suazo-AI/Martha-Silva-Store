# Gallery proof corrections ? primary return

Mode: VALIDATE. Host: SUAZO-PC. Base: `7bce17f65b6a49b64443349d76f3a98b76e4b347` plus the declared test overlay.
Primary: T3 Code / Codex, `gpt-6.1-sol/xhigh`. Usage and cost: unknown.

The two findings in [Astra's review](../../astra-judge-corrections.md) are corrected in tests only.
The desktop runner returns to 1280x900 before keyboard input and asserts the actual dimensions and DPR.
The mobile journey asserts 390x844 at DPR2. PNG dimensions independently read as 1280x900 and 780x1688.
The image gate requires `source: browser.response`. It makes no substitute HTTP request.

The resource controls reproduce the original gap: 1 PASS / 3 FAIL, exit 1, one replacement request.
After correction: 4 PASS / 0 FAIL, exit 0, zero replacement requests.
The focused Chrome driver: 2 runs / 0 failures, exit 0. Zoom, focus return, video and real keyboard paths are serialized.
Observed WebP responses: desktop 720w / HTTP 200 / 86,518 bytes; mobile 1024w / HTTP 200 / 140,962 bytes.
Both screenshots were visually inspected as gallery evidence. Historical 1440x900 evidence remains historical.
Raw stdout logs remain local. Portable JSON readbacks are included. No claim is made that a physical phone was tested.

[RESULT.json](RESULT.json) binds current tests, controls, results and screenshots.
Earlier passing DOM controls were unchanged and were not rerun.
Product source, static inputs and generated output were not changed.

Independent Astra/xhigh acceptance is pending. S-LEGACY remains open until adjudication.
No physical device, screen reader, SQL, combined browser/API/SQL, production, merge or deployment was tested here.

Lesson: bind a proof to its observed viewport and response origin; a successful replacement fetch is not browser-delivery evidence.

Repository check: `python tests/check.py` passed, exit 0, including asset-audit fixtures.
`python tools/export_progress.py --verify` passed with 15 preserved evidence hashes.
The older Windows symlink error was not reproduced by this run. This does not test backend SQL.

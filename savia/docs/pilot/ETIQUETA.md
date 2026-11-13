# Foto de etiqueta: registrar prendas desde el teléfono

Result: a phone photo of a hanging tag fills the new-product form; the clerk checks it and registers it.
The photo goes only to the branch PC. The OCR runs on that PC's CPU. No paid API and no cloud call.

## Phone use

1. On the PC: `python savia/tools/pilot.py up --lan`. It prints `phone (same Wi-Fi): http://<lan-ip>:5080/etiqueta/`.
2. On the phone, on the shop Wi-Fi, open that address and sign in with the work login.
3. Choose the open reception. "Sin recepción (solo registrar)" only registers.
4. Tap **Tomar foto de la etiqueta**. The phone camera opens (`capture="environment"`).
5. Check the form. A field marked **Revisar** had low OCR confidence (below 0.7). Every field stays editable.
6. **Sí, registrar** (MANAGER/OWNER) creates the product and item with the existing catalog endpoints, then adds 1 to the reception.
7. CASHIER/INVENTORY see **Sumar a la recepción**: the reading stays pending until a manager registers it in Recepción.
8. When the barcode or SKU already exists, the page shows the item and offers **Sumar 1 a la recepción**.
9. **Otra talla del mismo modelo** keeps name, brand, color and composition. Photograph one tag per model.

Recepción (start screen) links to the page as "Foto de etiqueta (teléfono)". The page lives at `savia/web/etiqueta/`.

## What happens to the photo

- The phone reduces the photo to 1600 px on the long side (JPEG 0.85) before sending.
- The phone reads the barcode first: `BarcodeDetector` when present, otherwise the vendored ZXing-js file (offline).
- When that barcode matches one item, the PC returns it and skips OCR.
- Otherwise the API sends the image bytes to the OCR sidecar over stdin. The image stays in memory and is not written.
- The API keeps no copy. `Savia:Tags:KeepPhotos=true` saves copies to `Savia:Tags:PhotoFolder` (default `savia/.out/tags`). Default: off.
- If OCR fails or takes more than 12 s (`Savia:Tags:OcrTimeoutSeconds`), the answer still arrives with a warning.
- The form stays editable and the clerk types the data. The phone gives up after 15 s.

## No network during extraction: how it was checked

- `tools/ocr/tag_ocr_sidecar.py` replaces `socket.connect`, `connect_ex`, `create_connection` and `getaddrinfo` before importing OCR code.
- Any outbound call fails. `python savia/.ocr/venv/Scripts/python.exe -I savia/tools/ocr/tag_ocr_sidecar.py --self-test-network` prints `network: blocked`.
- The models ship inside the pinned wheel; the sidecar never downloads.
- The proof run below polled `Get-NetTCPConnection` and `Get-NetUDPEndpoint` every 200 ms for both sidecar processes.
- Result: 144 polls, 0 sockets (2026-11-12). The API talks to the sidecar only through stdin/stdout.

## Engine chosen: RapidOCR (ONNX Runtime) as a Python sidecar

| | RapidOCR sidecar | Sdcb.PaddleOCR (.NET) |
| --- | --- | --- |
| Version tried | `rapidocr-onnxruntime` 1.4.4, onnxruntime 1.31.1 | `Sdcb.PaddleOCR` 3.3.1, `Models.LocalV5` 3.3.1 (LatinV5), Paddle Inference win64 MKL 3.3.1.70 |
| Barcode / SKU exact | 6/6 and 6/6 | 0/6 and 0/6 |
| All fields | 47/48 | 1/48 (one expected-empty price) |
| Seconds per photo | 1.58 to 2.55 (run 1) | 2.63 to 5.15 (run 1) |
| Disk | 15.4 MB models, 278 MB venv | 245 MB models package, 359 MB native runtime, 131 MB OpenCvSharp |
| License | Apache-2.0 (models: PaddleOCR PP-OCRv4, Apache-2.0) | Apache-2.0 |

Paddle with `AllowRotateDetection=true` and no 180° classifier read the tag text upside down (`∃68∠9920Z`, `%Z upo|∀`).
With the 180° classifier, the MKLDNN device failed (`OneDnnContext does not have the input Filter`) and the ONNX device failed.
The ONNX error was `invalid dimensions ... Expected: 32`. A different Paddle configuration may work; it was not pursued.
RapidOCR runs the PaddleOCR PP-OCRv4 models through ONNX Runtime. It met the target with fewer native parts.
Paddle evaluation code stayed in scratch and is not committed; its scored output is `etiqueta-proof/result-paddleocr-sdcb-3.3.1.json`.

### Pinned OCR dependency set (the only new dependency besides ZXing-js)

Installed by `python savia/tools/ocr/setup_ocr.py` into `savia/.ocr/venv` (git-ignored, never committed).
The setup needs internet once (PyPI). After that it is offline.

| Package | Version | License |
| --- | --- | --- |
| rapidocr-onnxruntime (bundles det/rec/cls ONNX models, 15.4 MB) | 1.4.4 | Apache-2.0 |
| onnxruntime | 1.31.1 | MIT |
| opencv-python | 5.0.0.93 | Apache-2.0 |
| numpy | 2.4.6 | BSD-3-Clause and others |
| pyclipper / shapely / pillow | 1.4.0 / 2.2.0 / 13.0.0 | MIT / BSD-3-Clause / MIT-CMU |
| PyYAML, six, tqdm, colorama, flatbuffers, packaging, protobuf | pinned in `tools/ocr/requirements-ocr.txt` | permissive |

Phone side: `@zxing/library` 0.21.3 UMD (`web/vendor/zxing/zxing-library-0.21.3.min.js`, Apache-2.0, `LICENSE` beside it).
SHA-256 `d7cc8f69dd70bdcf3ac00c9ae572bf2acb9f4132ba379c72df842e4db918652d`. Loaded only when the phone lacks `BarcodeDetector`.

## Proof: six synthetic tags

Source: `etiqueta-proof/tags.html?tag=1..6`, rendered to `tag1.png`..`tag6.png` (900×1200) with agent-browser.
Expected values: `etiqueta-proof/expected.json`. These tags are synthetic; real tags are not tested.
Command (real sidecar plus parser, warm-up excluded): `dotnet run -c Release --project savia/tools/ocr/TagProof -- savia/docs/pilot/etiqueta-proof`.
Barcode, SKU, size and price must match exactly. Name, brand, color and composition ignore case and accents.

| Tag | Kind | Barcode | SKU | Name | Brand | Size | Color | Price | Composition | s (run 1) | s (run 2) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | clear, vertical | ok | ok | ok | ok | ok | ok | ok | ok | 1.58 | 3.04 |
| 2 | clear, horizontal, no price | ok | ok | ok | ok | ok | ok | ok (none) | ok | 2.07 | 4.59 |
| 3 | clear, dark, English labels | ok | ok | ok | ok | ok | ok | ok | ok | 2.31 | 4.86 |
| 4 | blurred | ok | ok | **no**: "Camisaoxford" | ok | ok | ok | ok | ok | 1.79 | 4.90 |
| 5 | tilted 7° | ok | ok | ok | ok | ok | ok | ok | ok | 2.06 | 4.32 |
| 6 | photo-like, perspective and shadow | ok | ok | ok | ok | ok | ok | ok | ok | 2.55 | 5.14 |

RapidOCR per field: barcode 6/6, SKU 6/6, name 5/6, brand 6/6, size 6/6, color 6/6, price 6/6, composition 6/6.
Run 1: mean 2.06 s, max 2.55 s, while Blender used about 6 of the 8 CPU cores.
Run 2: mean 4.47 s, max 5.14 s, with total CPU at 100% (Blender, Defender, WSL and another agent's test host).
Under 3 s per photo held only in run 1. On a loaded PC the 3 s target fails; the 12 s timeout still leaves the form usable.
Sidecar start plus first photo: 7.5 s (run 1), 25 s (run 2). It happens once per API process, on the first photo.
`etiqueta-proof/result-rapidocr.json` holds the latest run (run 2).

### Through the real API (2026-11-12, after the merge into `Tony`)

Red: the first live run gave 0 of 6 tags.
Cause 1: the 12 s photo timeout also covered the reader start (11-14 s on this PC), so every photo restarted it.
Cause 2: a start cut by that timeout left the `ready` line unread; the next photo took it as an empty OCR answer.
Fix: the start has its own 90 s limit and is not cut by a photo; an answer without the request `id` is rejected.
`pilot.py up` sets `Savia:Tags:WarmUp=true`, so the reader starts with the API instead of on the first photo.
Test: `TagExtractTests.Sidecar_json_maps_to_lines_with_boxes` failed before the fix and passes after it.
Green: right after `pilot.py up`, then again, 6 of 6 tags gave barcode, SKU, size, color and price equal to `expected.json`; a seller got 403.

### Page check in a browser (2026-11-12)

agent-browser (desktop Chromium, 390×844) opened `/etiqueta/` from a scratch static server that faked the API on port 5199.
The fake API returned fixed fields; it was not committed. Desktop Chromium has no `BarcodeDetector`, so the vendored ZXing ran.
ZXing read `7501234567893` from `tag1.png` and `7460012345675` from `tag6.png`. The page sent JPEGs of 48 KB and 56 KB.
"Sí, registrar" sent `catalog/products`, `catalog/items` and one reception scan with the expected bodies. The page showed no errors.
Not covered: the real API behind the page, a real phone camera, iOS Safari, Android Chrome.

## Rules the PC applies (Savia.Application `TagParser`)

- Barcode: 8, 12 or 13 digits with a valid check digit; the phone reading wins.
- SKU: value beside or below `SKU`, `REF`, `ESTILO`, `STYLE`, `ART`, `MODELO`; else a code with letters, digits and hyphens.
- Size: XXS to XXXL (2XL→XXL, 3XL→XXXL) or 1 to 2 digits (`32`, `10/12`).
- Price: `C$ 1,250.00`, `1.250,00`, `890` → minor units (125000, 125000, 89000).
- Color: Spanish or English names, answered in Spanish. Composition: `NN% material`, accents restored.
- Brand and name: the first lines with words when no label is printed; confidence ×0.7, so the form marks them "Revisar".

## Limits

- Tested only with six synthetic tags rendered in a browser. No real garment tag, real phone camera or real Wi-Fi was tested.
- The PC does not decode barcode bars itself. It uses the phone reading, or the printed digits read by OCR.
- ZXing-js and `BarcodeDetector` were not exercised on a real phone. The headless browser check used ZXing on desktop Chromium.
- OCR drops accents ("Pantalon", "Sueter"). The form shows what was read; the clerk corrects it.
- The catalog has no brand, size, color or composition column for local registration.
- The brand goes into the product name, size and color into the variant name. Composition is not stored.
- Speed depends on free CPU. On a busy PC expect 3 to 5 s per photo.
- `pilot.py up --lan` exposes the pilot API on the shop LAN. Sample data only. HTTP without TLS.
- The bearer token travels in clear text on that Wi-Fi. Use it only on a private network the shop controls.

## Windows Firewall

The first `up --lan` may show "Windows Defender Firewall has blocked some features of dotnet".
Allow **Private networks** only. Leave **Public networks** unchecked. Without `--lan` the API listens only on 127.0.0.1.
To undo: Windows Security → Firewall → Allow an app → remove `dotnet` from Private.
`--lan` refuses any address outside 10/8, 172.16/12 and 192.168/16; `SAVIA_PILOT_LAN_IP` picks one interface.

## Fallback

- OCR not installed: the endpoint answers 503 `tag.ocr_missing` with the setup command. The page keeps the form editable.
- OCR fails or times out: the answer keeps the phone barcode and a warning. The clerk types the rest.
- No phone: Recepción on the PC keeps the scanner and the "Registrar producto" dialog.

## Files

- API: `src/Savia.Api/TagEndpoints.cs`. Rules: `src/Savia.Application/TagExtraction.cs`. Contract: `src/Savia.Contracts/TagExtract.cs`.
- Sidecar client: `src/Savia.Infrastructure/TagOcr.cs`. Sidecar: `tools/ocr/tag_ocr_sidecar.py`. Setup: `tools/ocr/setup_ocr.py`.
- Phone page: `web/etiqueta/`. Proof harness: `tools/ocr/TagProof/`.
- Tests: `tests/Savia.Tests/TagExtractTests.cs`, `web/tests/etiqueta.test.mjs`, `tests/test_pilot_lan.py`.

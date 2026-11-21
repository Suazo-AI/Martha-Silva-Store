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

### Generated phone photos (2026-11-13)

Two photos made with ChatGPT Images, with text chosen in advance: `etiqueta-proof/generated/tag1.png`, `tag2.png` (1086×1448).
tag1: hand-held, warm light, small angle. tag2: 20°, dim cool light, glare, creased tag, cluttered rack.
Before use, the printed text of both was checked by eye against `generated/expected.json`; it matched character for character.
They are closer to a phone photo than the rendered tags, but they are still generated images, not real tags.

Red: `TagProof` gave 14 of 16 fields. The color "Caqui" came back empty: a labeled color was kept only if the list knew it.
Fix: after a `COLOR` label any short word is kept, with heuristic weight, so the phone marks it "Revisar"; `CAQUI` added to the list.
Test: `TagExtractTests.A_labeled_color_keeps_a_word_the_list_does_not_know`: 3 cases failed before the fix, 34 of 34 pass after it.
Green through the real API (`tools/tag_live.py`, now also reads `generated/`): 9 of 9, the six rendered tags, both photos and the seller 403.
Still wrong, left to the clerk: tag1 brand "ESTRELLADELSUR" (OCR drops the spaces of wide bold capitals); tag2 color "Caaui" (the crease).
Seconds per photo: 2.66 mean in `TagProof` with the CPU at 32%; 5.1 and 9.0 s through the API with other agents running.

### Real tags from the store (2026-11-13)

Jason sent two real photos of one garment (crop top, style LT1558, pink, size M).
They stay out of Git: real store material. Local copy for re-runs: `savia/.ocr/real-tags/` (ignored), with `expected.json`.
- Store sticker, upright: internal code + short name, `MSILVA C$ 2,161 (59)`, `TALLA: M`, `ROSADO`, `LA ROS`, thin barcode, `LT1558ROSM`.
- Supplier tag, photographed turned 90°: `Style No: LT1558`, `Size: M`, `Color: PINK`, `Made In China`.

The store code `LT1558ROSM` is the supplier style + 3 letters of color + size.

Red, before the fixes:
- Supplier tag: size empty. RapidOCR turns tall crops but not the square "M", and read it as "W". Brand "Made In China".
- Store sticker: color empty. OCR read `ROSADO` as `ROSADD`.
- A generated tag turned left (`generated/tag1-ccw.png`) gave 0 of 8 fields; turned right (`tag1-cw.png`) gave 8 of 8.

Fixes:
- Sidecar: when most text boxes are tall, the photo is sideways. Every box is cut out, turned upright and recognized again.
  Detection, the slow half, runs once. Boxes move to the upright frame so the parser's layout rules still hold.
- Parser: a word one letter off a single known color is that color, marked "Revisar" (`ROSADD`→Rosado, `Caaui`→Caqui).
- Parser: lines starting `MADE IN`, `HECHO EN` or `FABRICADO EN` are never brand or name.

Tests: `A_color_one_letter_off_a_known_color_is_that_color_marked_for_review` and `Made_in_lines_are_neither_brand_nor_name`.
Both failed before the fix (2 of 36); 36 of 36 pass after it.

Green in `TagProof`:
- Supplier tag: SKU `LT1558`, size `M`, color Rosado, no brand, no name.
- Generated, 4 photos (2 upright, 2 sideways): 31 of 32 fields; only the old "ESTRELLADELSUR" brand.
- Six rendered tags: unchanged, 47 of 48 (name "Camisaoxford" as before).

Still wrong on the store sticker, left to the clerk:
- SKU `LT155880SM` instead of `LT1558ROSM` (R read as 8, O as 0).
- The code+name line read as `HUTINESI CROP TOPLA` and went to brand; name got `CROS`.
- The barcode is too thin and blurred for the phone reader in this photo.
A store sticker means the garment is already in the catalog; scanning its barcode is the right path, not a photo.

Time: one OCR pass took 4.4 to 4.8 s on this PC today (2.7 s earlier, other agents were running).
The sideways re-read added 0.3 to 2 s. Sideways photos through the API may near the 12 s timeout on a busy PC.
Through the real API (`tools/tag_live.py`): 11 of 11; `tag1-cw` 4.7 s, `tag1-ccw` 2.7 s (`verify.py` 13 of 13).

### First real phone: iPhone on home Wi-Fi (2026-11-13)

Red: the page loaded over `http://192.168.1.40:5080/etiqueta/` and the login worked. After each photo the page went back to the start.
The API log showed no request after the photo. Cause: `api.uuid()` called `crypto.randomUUID()`.
Browsers omit it outside a secure context (HTTPS or localhost). The error was thrown before the form appeared and was not shown.
Fix: `uuid()` falls back to `crypto.getRandomValues` (RFC 4122 v4); a failed photo now shows its error.
Test: `web/tests/uuid.test.mjs` failed with `TypeError: crypto.randomUUID is not a function`, passes after the fix; web 80/80, Biome clean.
Browser check: agent-browser on `http://192.168.1.40:5080/etiqueta/` (`isSecureContext` false, no `randomUUID`) as `bodega.muestra`.
`generated/tag1.png` uploaded: tag-extract 200 in 2.8 s; barcode, SKU, name, size, color, price and composition filled.
Not yet: the same photo flow on the iPhone after the fix. `screens/sale-logic.mjs` still calls `crypto.randomUUID`; the PC screens run on localhost.

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
- Color: Spanish or English names, answered in Spanish; after a `COLOR` label an unknown word is kept and marked "Revisar".
- Color: a word one letter off a single known color becomes that color, marked "Revisar".
- Sideways photo: the sidecar turns each text box upright and reads it again.
- Composition: `NN% material`, accents restored.
- Brand and name: the first lines with words when no label is printed; confidence ×0.7, so the form marks them "Revisar".
- `Made in ...` lines are never brand or name.

## Limits

- Tested with six rendered tags, four generated photos and two real photos of one garment (sent by Jason).
- No real phone camera, upload over real Wi-Fi or upside-down photo was tested.
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

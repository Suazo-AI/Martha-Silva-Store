#!/usr/bin/env python3
"""Local OCR sidecar for /api/v1/inventory/tag-extract. Runs only on this PC, on the CPU.

Protocol: one JSON object per line on stdin, one JSON object per line on stdout.
  start  -> {"ready": true, "engine": "rapidocr-onnxruntime 1.4.4"}
  request  {"id": "...", "image": "<base64 jpeg/png/webp>"}
  answer   {"id": "...", "lines": [{"text": "...", "score": 0.97, "box": [[x,y],...]}], "ms": 812}
  failure  {"id": "...", "error": "..."}
The image lives only in memory; nothing is written to disk.

No network: every socket connect is refused before the OCR library is imported, so a model download or any
other outbound call fails loudly instead of leaving this PC. The models ship inside the pinned wheel
(requirements-ocr.txt) installed in savia/.ocr/venv by setup_ocr.py.
"""
import base64
import json
import socket
import sys
import time


class NetworkBlocked(OSError):
    pass


def _refuse(*_args, **_kwargs):
    raise NetworkBlocked("network disabled in the SAVIA OCR sidecar")


# Block before any third-party import.
socket.socket.connect = _refuse
socket.socket.connect_ex = _refuse
socket.create_connection = _refuse
socket.getaddrinfo = _refuse

import cv2  # noqa: E402
import numpy as np  # noqa: E402
from rapidocr_onnxruntime import RapidOCR  # noqa: E402

MAX_SIDE = 1600


def decode(data: bytes):
    image = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)
    if image is None:
        raise ValueError("imagen ilegible")
    h, w = image.shape[:2]
    scale = MAX_SIDE / max(h, w)
    if scale < 1:
        image = cv2.resize(image, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
    return image


def main():
    out = sys.stdout
    # Tags are printed upright: the 180-degree classifier is skipped; 960 px detection keeps a photo under 3 s.
    engine = RapidOCR(det_limit_side_len=960)
    engine(np.full((64, 256, 3), 255, np.uint8), use_cls=False)   # warm-up so the first photo is not slower
    out.write(json.dumps({"ready": True, "engine": "rapidocr-onnxruntime 1.4.4"}) + "\n")
    out.flush()
    for raw in sys.stdin:
        raw = raw.strip()
        if not raw:
            continue
        rid = None
        try:
            request = json.loads(raw)
            rid = request.get("id")
            started = time.perf_counter()
            result, _ = engine(decode(base64.b64decode(request["image"])), use_cls=False)
            lines = [{"text": text, "score": round(float(score), 4), "box": [[round(float(x)), round(float(y))] for x, y in box]}
                     for box, text, score in (result or [])]
            answer = {"id": rid, "lines": lines, "ms": round((time.perf_counter() - started) * 1000)}
        except Exception as error:  # one bad photo must not stop the sidecar
            answer = {"id": rid, "error": f"{type(error).__name__}: {error}"}
        out.write(json.dumps(answer, ensure_ascii=False) + "\n")
        out.flush()


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test-network":
        try:
            socket.create_connection(("example.org", 80), timeout=2)
            print("network: OPEN")
            sys.exit(1)
        except NetworkBlocked:
            print("network: blocked")
            sys.exit(0)
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stdin.reconfigure(encoding="utf-8")
    main()

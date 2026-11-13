#!/usr/bin/env python3
"""Live check of the tag photo: the six proof tags through the running pilot API and the real local OCR.

  python savia/tools/tag_live.py     # needs: pilot.py up, savia/.ocr installed, SAVIA_PILOT_PASSWORD_BODEGA and _VENDEDOR1

Pass: every tag returns the barcode, SKU, size, color and price of docs/pilot/etiqueta-proof/expected.json,
and a seller gets 403. Unit tests use a fake reader, so only this check proves the real one answers.
"""
import json
import os
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROOF = ROOT / "docs" / "pilot" / "etiqueta-proof"
API = os.environ.get("SAVIA_PILOT_URL", "http://127.0.0.1:5080").rstrip("/") + "/api/v1"
FIELDS = ("barcode", "sku", "size", "color", "priceMinor")


def post(path, data, headers):
    request = urllib.request.Request(API + path, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read() or b"{}")


def login(name, variable):
    status, body = post("/auth/login", json.dumps({"loginName": name, "password": os.environ[variable]}).encode(),
                        {"Content-Type": "application/json"})
    if status != 200:
        raise SystemExit(f"tag live: {name} could not sign in ({status})")
    return body["token"]


def extract(token, file):
    boundary = uuid.uuid4().hex
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{file}"\r\n'
            "Content-Type: image/png\r\n\r\n").encode() + (PROOF / file).read_bytes() + f"\r\n--{boundary}--\r\n".encode()
    return post("/inventory/tag-extract", body,
                {"Content-Type": f"multipart/form-data; boundary={boundary}", "Authorization": f"Bearer {token}"})


def main():
    expected = json.loads((PROOF / "expected.json").read_text(encoding="utf-8"))
    stock_worker = login("bodega.muestra", "SAVIA_PILOT_PASSWORD_BODEGA")
    failed = 0
    for tag in expected:
        status, body = extract(stock_worker, tag["file"])
        wrong = [f for f in FIELDS if body.get(f) != tag[f]] if status == 200 else ["http " + str(status)]
        failed += bool(wrong)
        print(f"{'ok  ' if not wrong else 'FAIL'} {tag['file']} source={body.get('source')} {body.get('elapsedMs')} ms"
              + (f" wrong: {', '.join(wrong)} warning: {body.get('warning')}" if wrong else ""))
    status, _ = extract(login("vendedor1.muestra", "SAVIA_PILOT_PASSWORD_VENDEDOR1"), expected[0]["file"])
    failed += status != 403
    print(f"{'ok  ' if status == 403 else 'FAIL'} a seller gets 403 (got {status})")
    print(f"TAG LIVE {'PASS' if not failed else 'FAIL'}: {len(expected) + 1 - failed} of {len(expected) + 1}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

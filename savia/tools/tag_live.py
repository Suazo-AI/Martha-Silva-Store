#!/usr/bin/env python3
"""Live check of the tag photo: the proof tags through the running pilot API and the real local OCR.

  python savia/tools/tag_live.py     # needs: pilot.py up, savia/.ocr installed, SAVIA_PILOT_PASSWORD_BODEGA and _VENDEDOR1

Pass: every tag returns the barcode, SKU, size, color and price of its expected.json, and a seller gets 403.
Photos: the six rendered tags in docs/pilot/etiqueta-proof/ and the generated phone photos in its generated/ folder.
A field listed in a tag's "knownMisreads" is reported but does not fail the check. Unit tests use a fake reader, so only this check proves the real one answers.
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
FOLDERS = (PROOF, PROOF / "generated")
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


def extract(token, path):
    boundary = uuid.uuid4().hex
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="image"; filename="{path.name}"\r\n'
            "Content-Type: image/png\r\n\r\n").encode() + path.read_bytes() + f"\r\n--{boundary}--\r\n".encode()
    return post("/inventory/tag-extract", body,
                {"Content-Type": f"multipart/form-data; boundary={boundary}", "Authorization": f"Bearer {token}"})


def main():
    expected = [dict(tag, path=folder / tag["file"]) for folder in FOLDERS
                for tag in json.loads((folder / "expected.json").read_text(encoding="utf-8"))]
    stock_worker = login("bodega.muestra", "SAVIA_PILOT_PASSWORD_BODEGA")
    failed = 0
    for tag in expected:
        status, body = extract(stock_worker, tag["path"])
        wrong = [f for f in FIELDS if body.get(f) != tag[f]] if status == 200 else ["http " + str(status)]
        known = [f for f in wrong if f in tag.get("knownMisreads", {})]
        wrong = [f for f in wrong if f not in known]
        failed += bool(wrong)
        print(f"{'ok  ' if not wrong else 'FAIL'} {tag['path'].relative_to(PROOF)} source={body.get('source')} {body.get('elapsedMs')} ms"
              + (f" wrong: {', '.join(wrong)} warning: {body.get('warning')}" if wrong else "")
              + "".join(f" known misread {f}: {body.get(f)!r}" for f in known))
    status, _ = extract(login("vendedor1.muestra", "SAVIA_PILOT_PASSWORD_VENDEDOR1"), expected[0]["path"])
    failed += status != 403
    print(f"{'ok  ' if status == 403 else 'FAIL'} a seller gets 403 (got {status})")
    print(f"TAG LIVE {'PASS' if not failed else 'FAIL'}: {len(expected) + 1 - failed} of {len(expected) + 1}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

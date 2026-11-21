#!/usr/bin/env python3
"""One-time install of the local tag OCR: python savia/tools/ocr/setup_ocr.py

Creates savia/.ocr/venv (git-ignored) and installs the pinned set in requirements-ocr.txt from PyPI.
This is the only step that uses the network. Extraction itself never does (see tag_ocr_sidecar.py).
Then it checks that the sidecar starts, reports its engine and refuses outbound sockets.
"""
import json
import subprocess
import sys
import venv
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]                       # .../savia
VENV = ROOT / ".ocr" / "venv"
PY = VENV / ("Scripts/python.exe" if sys.platform == "win32" else "bin/python")


def main():
    if not PY.exists():
        print(f"ocr: creating {VENV.relative_to(ROOT)}")
        venv.create(VENV, with_pip=True)
    subprocess.run([str(PY), "-m", "pip", "install", "--disable-pip-version-check", "-q",
                    "-r", str(HERE / "requirements-ocr.txt")], check=True)
    blocked = subprocess.run([str(PY), str(HERE / "tag_ocr_sidecar.py"), "--self-test-network"], capture_output=True, text=True)
    print(f"ocr: {blocked.stdout.strip()}")
    if blocked.returncode != 0:
        raise SystemExit("ocr: the sidecar can open network sockets; refusing.")
    proc = subprocess.Popen([str(PY), str(HERE / "tag_ocr_sidecar.py")], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            text=True, encoding="utf-8")
    ready = json.loads(proc.stdout.readline())
    proc.stdin.close()
    proc.wait(timeout=30)
    print(f"ocr: ready={ready.get('ready')} engine={ready.get('engine')}")
    return 0 if ready.get("ready") else 1


if __name__ == "__main__":
    sys.exit(main())

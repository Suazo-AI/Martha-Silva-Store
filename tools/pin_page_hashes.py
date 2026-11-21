"""Pin the SHA-256 of every static page in tests/page-hashes.json.

Usage: python tools/pin_page_hashes.py [--check]
Run it after a deliberate page change. With --check it writes nothing and exits 1 when the pin is stale.
"""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATIC = ROOT / 'build-inputs' / 'static'
PIN = ROOT / 'tests' / 'page-hashes.json'


def main(argv):
    current = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(STATIC.glob('*.html'))}
    pinned = json.loads(PIN.read_text(encoding='utf-8')) if PIN.is_file() else {}
    stale = sorted(name for name in current.keys() | pinned.keys() if current.get(name) != pinned.get(name))
    if '--check' in argv:
        for name in stale:
            print('stale ' + name)
        print(f'{len(stale)} stale page hash(es)')
        return 1 if stale else 0
    PIN.write_text(json.dumps(current, indent=2, sort_keys=True) + '\n', encoding='utf-8', newline='\n')
    print(f'pinned {len(current)} page hash(es); {len(stale)} changed')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

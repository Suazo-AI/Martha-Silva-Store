"""One displayed price format: `US$5.00` becomes `$5.00` in static inputs (idempotent).

Usage: python tools/price_format.py [--check]
Rewrites build-inputs/static/*.html and locale-en.js (the shipping sentence key and value
change together with the HTML). With --check it only lists pending files and exits 1 when any.
Bytes are preserved otherwise (LF, no BOM).
"""
import re
import sys
from pathlib import Path

STATIC = Path(__file__).resolve().parents[1] / 'build-inputs' / 'static'
PATTERN = re.compile(rb'US\$(?=\d)')


def main(argv):
    check = '--check' in argv
    pending = []
    total = 0
    for path in sorted([*STATIC.glob('*.html'), STATIC / 'locale-en.js']):
        data = path.read_bytes()
        new, count = PATTERN.subn(b'$', data)
        if not count:
            continue
        pending.append(path.name)
        total += count
        if not check:
            path.write_bytes(new)
    for name in pending:
        print(('pending ' if check else 'updated ') + name)
    print(f'{len(pending)} file(s), {total} replacement(s) {"pending" if check else "applied"}')
    return 1 if check and pending else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

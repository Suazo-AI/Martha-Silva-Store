"""Site-wide static markup fixes for the storefront pages (idempotent).

Usage: python tools/storefront_markup_codemod.py [--check]
The product reference code is wrapped in translate="no" (it is an identifier, not copy).
Without --check it rewrites build-inputs/static/*.html; with --check it only lists the
pages that still need a change and exits 1 when any are pending.
"""
import re
import sys
from pathlib import Path

STATIC = Path(__file__).resolve().parents[1] / 'build-inputs' / 'static'
CODE = re.compile(r'(<p class="product-code">Referencia: )(?!<span translate="no">)([^<]+)(</p>)')


def transform(text):
    return CODE.sub(r'\1<span translate="no">\2</span>\3', text)


def main(argv):
    check = '--check' in argv
    pending = []
    for page in sorted(STATIC.glob('*.html')):
        text = page.read_bytes().decode('utf-8')
        new = transform(text)
        if new == text:
            continue
        pending.append(page.name)
        if not check:
            page.write_bytes(new.encode('utf-8'))
    for name in pending:
        print(('pending ' if check else 'updated ') + name)
    print(f'{len(pending)} page(s) {"pending" if check else "updated"}')
    return 1 if check and pending else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

"""Add the full-width MARTHA SILVA wordmark as the last child of footer.site-footer (idempotent).

Usage: python tools/footer_wordmark_codemod.py [--check]
Without --check it rewrites build-inputs/static/*.html; with --check it only lists the
pages that still need the wordmark and exits 1 when any are pending.
"""
import re
import sys
from pathlib import Path

STATIC = Path(__file__).resolve().parents[1] / 'build-inputs' / 'static'
WORDMARK = '<p class="footer-wordmark" aria-hidden="true">MARTHA SILVA</p>'
FOOTER = re.compile(r'(<footer class="site-footer"[^>]*>)(.*?)(</footer>)', re.S)


def transform(text):
    def add(match):
        if 'footer-wordmark' in match.group(2):
            return match.group(0)
        return match.group(1) + match.group(2) + WORDMARK + match.group(3)
    return FOOTER.sub(add, text, count=1)


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

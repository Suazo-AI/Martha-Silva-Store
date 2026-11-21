"""Move the mobile menu button into a bottom black pill and give the menu card its own bar (idempotent).

Usage: python tools/menu_pill_codemod.py [--check]
Per page that has [data-menu-toggle]:
  1. removes the toggle button from the header masthead;
  2. adds <div class="menu-pill"> with the wordmark and the toggle, just before <dialog id="mobile-menu">;
  3. in the dialog, replaces the heading close button with a bottom bar (wordmark and close button).
With --check it only lists the pages that still need the change and exits 1 when any are pending.
"""
import re
import sys
from pathlib import Path

STATIC = Path(__file__).resolve().parents[1] / 'build-inputs' / 'static'
BURGER = '<path class="menu-icon-open" d="M3 7h18M3 12h18M3 17h18"></path>'
CROSS = '<path class="menu-icon-close" d="m6 6 12 12M18 6 6 18"></path>'
SVG = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.3" aria-hidden="true">%s</svg>'
TOGGLE = ('<button class="icon-button menu-toggle" type="button" data-menu-toggle="" aria-label="Abrir menú" '
          'aria-expanded="false" aria-controls="mobile-menu">' + SVG % (BURGER + CROSS) + '</button>')
MARK = '<span class="menu-mark" aria-hidden="true">MARTHA SILVA</span>'
PILL = '<div class="menu-pill">' + MARK + TOGGLE + '</div>'
BAR = ('<div class="menu-card-bar">' + MARK + '<button class="icon-button" type="button" data-close-dialog="" '
       'aria-label="Cerrar menú">' + SVG % '<path d="m6 6 12 12M18 6 6 18"></path>' + '</button></div>')

OLD_TOGGLE = re.compile(r'<button class="icon-button menu-toggle" type="button" data-menu-toggle=""[^>]*>.*?</button>', re.S)
HEADING_CLOSE = re.compile(r'(<div class="drawer-heading"><h2>[^<]*</h2>)<button class="icon-button" type="button" data-close-dialog=""[^>]*>.*?</button>(</div>)', re.S)
DIALOG = re.compile(r'(<dialog id="mobile-menu"[^>]*>)(<div class="mobile-menu-inner">.*?</div>)(</dialog>)', re.S)


def transform(text):
    if 'data-menu-toggle' not in text or 'menu-pill' in text:
        return text
    text = OLD_TOGGLE.sub('', text, count=1)
    text = text.replace('<dialog id="mobile-menu"', PILL + '<dialog id="mobile-menu"', 1)
    text = DIALOG.sub(lambda m: m.group(1) + HEADING_CLOSE.sub(r'\1\2', m.group(2)) + BAR + m.group(3), text, count=1)
    return text


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

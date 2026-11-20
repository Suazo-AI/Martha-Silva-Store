"""Remove the dead Lenis and ScrollTrigger vendor tags and `data-lenis-prevent` attributes (idempotent).

Usage: python tools/remove_dead_vendor.py [--check]
Edits build-inputs/static/*.html only. With --check it lists pending files and exits 1 when any.
Bytes are preserved otherwise (LF, no BOM).
"""
import sys
from pathlib import Path

STATIC = Path(__file__).resolve().parents[1] / 'build-inputs' / 'static'
TAGS = (
    b'<link rel="stylesheet" href="/prototypes/vendor/lenis.css">',
    b'<script defer="" src="/prototypes/vendor/ScrollTrigger.min.js"></script>',
    b'<script defer="" src="/prototypes/vendor/lenis.min.js"></script>',
)
ATTR = b' data-lenis-prevent=""'


def main(argv):
    check = '--check' in argv
    pending = []
    tags = attrs = 0
    for path in sorted(STATIC.glob('*.html')):
        data = new = path.read_bytes()
        for tag in TAGS:
            n = new.count(tag)
            tags += n
            new = new.replace(tag, b'')
        n = new.count(ATTR)
        attrs += n
        new = new.replace(ATTR, b'')
        if new == data:
            continue
        pending.append(path.name)
        if not check:
            path.write_bytes(new)
    for name in pending:
        print(('pending ' if check else 'updated ') + name)
    print(f'{len(pending)} file(s), {tags} tag(s), {attrs} attribute(s) {"pending" if check else "removed"}')
    return 1 if check and pending else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

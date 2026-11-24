"""Published output must read as the final store: no build-provenance or test wording,
and every root-relative asset reference must resolve inside the output.

Usage: python tests/public_names.py [dist-dir]   (default: repository dist/)
"""
from pathlib import Path
from urllib.parse import unquote
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
TEXT = {'.html', '.js', '.css', '.json', '.txt', '.xml', '.svg', '.webmanifest'}
# Case-insensitive tokens that reveal a demo, test, generated or research origin.
WORDS = re.compile(r'demo|prototip|prototype|generad[oa]s?\b|generated|sample|muestra|sint[eé]tic|synthetic|'
                   r'simulad|simulaci|simulated|prueba|research|parity|local_test|mock|placeholder|fixture|'
                   r'stand-?in\b|staging', re.I)
ACRONYM = re.compile(r'\b(?:AI|IA)\b')  # case-sensitive: "ai"/"ia" occur inside ordinary words
# Allowed hits, each with the reason it is not a provenance claim.
ALLOW = [
    (re.compile(r'\b(?:se|que|la fotografía|la foto)\s+muestran?\b', re.I), 'Spanish verb "mostrar" in product copy'),
    (re.compile(r'placeholder', re.I), 'HTML placeholder attribute and ::placeholder selector'),
    (re.compile(r'resample', re.I), 'image resampling term'),
    (re.compile(r'Object\.prototype(?![\w$])'), 'JavaScript Object.prototype API'),
]
# Third-party code: the JavaScript prototype API is not wording.
VENDOR = ('lib/vendor/',)
VENDOR_ALLOW = re.compile(r'prototype', re.I)
WINDOW = 30


def allowed(text, start, end):
    lo = max(0, start - WINDOW)
    window = text[lo:end + WINDOW]
    return any(m.start() + lo <= start and end <= m.end() + lo
               for rx, _ in ALLOW for m in rx.finditer(window))


def scan(dist):
    problems = []
    for p in sorted(dist.rglob('*')):
        if not p.is_file():
            continue
        rel = p.relative_to(dist).as_posix()
        if WORDS.search(rel) or ACRONYM.search(rel):
            problems.append(f'path: {rel}')
        if p.suffix not in TEXT and p.name != '_headers':
            continue
        text = p.read_text(encoding='utf-8', errors='replace')
        for m in [*WORDS.finditer(text), *ACRONYM.finditer(text)]:
            if allowed(text, m.start(), m.end()):
                continue
            if rel.startswith(VENDOR) and VENDOR_ALLOW.fullmatch(m.group(0)):
                continue
            problems.append(f'text: {rel}: {text[max(0, m.start() - WINDOW):m.end() + WINDOW]!r}')
    return problems


def resolve(dist):
    # Include the source folder names so a reference that escaped the build remap is reported.
    dirs = sorted({p.name for p in dist.iterdir() if p.is_dir()} | {'generated-luxury', 'generated-illustrations', 'prototypes', 'research'})
    stop = '"\'\\s)<>,;?#\\\\'
    ref = re.compile(r'(?<![\w.:/])/((?:' + '|'.join(map(re.escape, dirs)) + r')/[^' + stop + r']+)')
    missing = set()
    for p in dist.rglob('*'):
        rel = p.relative_to(dist).as_posix()
        if p.is_file() and (p.suffix in TEXT or p.name == '_headers') and not rel.startswith(VENDOR):
            for m in ref.finditer(p.read_text(encoding='utf-8', errors='replace')):
                target = unquote(m.group(1))
                if not (dist / target).is_file():
                    missing.add(f'{rel} -> /{target}')
    return sorted(missing)


if __name__ == '__main__':
    dist = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'dist'
    problems, missing = scan(dist), resolve(dist)
    for line in problems[:80] + [f'missing: {m}' for m in missing[:40]]:
        print(line)
    assert not problems and not missing, f'{len(problems)} wording/path hits, {len(missing)} unresolved references'
    count = sum(1 for p in dist.rglob('*') if p.is_file())
    print(f'PASS: no provenance wording in {count} published files; all asset references resolve')

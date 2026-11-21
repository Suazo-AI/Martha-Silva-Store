"""Add the home loader to index.html and pin its inline gate in _headers (idempotent).

Usage: python tools/loader_codemod.py [--check]
Changes only build-inputs/static/index.html and the script-src of build-inputs/static/_headers:
  1. one inline gate script in <head>, right after the styles.css link;
  2. the .ms-loader node right after <body>;
  3. data-intro on the first hero slide's .ho-copy;
  4. the exact 'sha256-...' of the gate in the _headers script-src.
With --check nothing is written; the exit code is 1 when a change is pending.
"""
import base64
import hashlib
import re
import sys
from pathlib import Path

STATIC = Path(__file__).resolve().parents[1] / 'build-inputs' / 'static'
PAGE = STATIC / 'index.html'
HEADERS = STATIC / '_headers'

# Runs before first paint. Shows the loader only on the first home visit of a browser session.
GATE = ("try{var d=document.documentElement,k='martha-loader-v1',n=performance.getEntriesByType('navigation')[0];"
        "if(!sessionStorage.getItem(k)&&!matchMedia('(prefers-reduced-motion:reduce)').matches"
        "&&!(n&&(n.type==='reload'||n.type==='back_forward'))){sessionStorage.setItem(k,'1');"
        "d.classList.add('ms-loading');performance.mark('ms-loader-start')}}catch(e){}")
GATE_TAG = '<script>' + GATE + '</script>'
GATE_RE = re.compile(r'<script>try\{var d=document\.documentElement,k=\'martha-loader-v1\'.*?</script>', re.S)
STYLES_LINK = '<link rel="stylesheet" href="/styles.css">'
BODY = re.compile(r'(<body[^>]*>)')
LOADER_RE = re.compile(r'<div class="ms-loader"[^>]*>.*?</div>', re.S)
HERO_SOURCE = re.compile(r'<source type="image/webp"[^>]*?srcset="([^"]+)"[^>]*?sizes="([^"]+)"')
FIRST_COPY = re.compile(r'(<article class="ho-slide" data-active=""[^>]*>.*?)<div class="ho-copy"( data-intro="")?>', re.S)
SCRIPT_SRC = re.compile(r"script-src 'self'(?: 'sha256-[A-Za-z0-9+/=]+')?")
CYCLE = ('champagne', 'rosa-empolvado-pedreria', 'gris-perla-hombros')


def digest():
    return "'sha256-" + base64.b64encode(hashlib.sha256(GATE.encode('utf-8')).digest()).decode() + "'"


def hero_images(text):
    """srcset and sizes of the two pictures of the first home slide, copied so the browser reuses the same files."""
    start = text.index('<section class="hero-oh"')
    found = [(m.group(1), m.group(2)) for m in HERO_SOURCE.finditer(text, start)][:2]
    if len(found) != 2:
        raise SystemExit('hero webp <source> not found')
    return found


def loader(text):
    art = ''.join(
        f'<span><img src="{srcset.split(",")[-1].split()[0]}" srcset="{srcset}" sizes="{sizes}" alt="" width="1086" height="1448" '
        'loading="lazy" decoding="async" draggable="false"></span>' for srcset, sizes in hero_images(text))
    pics = ''.join(
        f'<img src="/responsive-images/{pid}/01-front-v1-360.webp" alt="" width="360" height="480" '
        f'loading="lazy" decoding="async" fetchpriority="low" draggable="false">' for pid in CYCLE)
    return ('<div class="ms-loader" aria-hidden="true"><span class="ms-loader-row">'
            '<span class="ms-loader-word"><span>MARTHA</span></span>'
            '<span class="ms-loader-word"><span>SILVA</span></span>'
            f'<span class="ms-loader-gap">{pics}</span></span>'
            f'<span class="ms-loader-hero">{art}</span></div>')


def transform(text):
    text = GATE_RE.sub('', text)
    if STYLES_LINK not in text:
        raise SystemExit('styles.css link not found in index.html')
    text = text.replace(STYLES_LINK, STYLES_LINK + GATE_TAG, 1)
    text = LOADER_RE.sub('', text)
    text = BODY.sub(lambda m: m.group(1) + loader(text), text, count=1)
    text = FIRST_COPY.sub(lambda m: m.group(1) + '<div class="ho-copy" data-intro="">', text, count=1)
    return text


def headers(text):
    new, count = SCRIPT_SRC.subn("script-src 'self' " + digest(), text, count=1)
    if not count:
        raise SystemExit("script-src 'self' not found in _headers")
    return new


def main(argv):
    check = '--check' in argv
    pending = []
    for path, change in ((PAGE, transform), (HEADERS, headers)):
        text = path.read_bytes().decode('utf-8')
        new = change(text)
        if new == text:
            continue
        pending.append(path.name)
        if not check:
            path.write_bytes(new.encode('utf-8'))
    for name in pending:
        print(('pending ' if check else 'updated ') + name)
    print(f'{len(pending)} file(s) {"pending" if check else "updated"}; gate {len(GATE)} B {digest()}')
    return 1 if check and pending else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

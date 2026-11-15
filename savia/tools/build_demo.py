"""Build the offline staff demo without changing the staff application."""
import argparse
from pathlib import Path
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
CSP = ("default-src 'none'; script-src 'self'; style-src 'self' 'unsafe-inline'; "
       "img-src 'self' data: blob:; font-src 'self'; connect-src 'self'; "
       "media-src 'self' blob:; worker-src 'self' blob:; "
       "object-src 'none'; base-uri 'none'; form-action 'self'")


def excluded(directory, names):
    return [n for n in names if n == 'tests' or '.test.' in n or n.startswith('.')
            or n in {'evidence', '__pycache__', 'node_modules', 'test-double.mjs', 'verify.py'}]


def build(api, out):
    api = api.resolve()
    if not api.is_relative_to(ROOT / 'demo'):
        raise ValueError('Fake API must live under savia/demo')
    entry = api / 'index.mjs' if api.is_dir() else api
    if not entry.is_file():
        raise ValueError(f'Fake API entry does not exist: {entry}')
    out = out.resolve()
    # Never remove source trees or silently reuse arbitrary nonempty directories.
    if out == ROOT or out in ROOT.parents or any(out.is_relative_to(ROOT / p) for p in ('web', 'demo', 'tools')):
        raise ValueError('Output must be separate from source trees')
    if out.exists() and any(out.iterdir()):
        if out != ROOT / '.out' / 'demo-site':
            raise ValueError('Custom output must be empty')
        shutil.rmtree(out)
    shutil.copytree(ROOT / 'web', out, ignore=excluded, dirs_exist_ok=True)
    shutil.copytree(ROOT / 'demo', out / 'demo', ignore=excluded, dirs_exist_ok=True)
    target = out / 'demo' / 'api'
    if target.exists():
        shutil.rmtree(target)
    if api.is_dir():
        shutil.copytree(api, target, ignore=excluded)
    else:
        target.mkdir(parents=True)
        shutil.copy2(api, target / 'index.mjs')
    for page, module in [('index.html', '/app.mjs'), ('etiqueta/index.html', '/etiqueta/etiqueta.mjs')]:
        path = out / page
        html = path.read_text(encoding='utf-8')
        html, count = re.subn(r'<script\s+type="module"\s+src="[^"]+"\s*></script>',
                             f'<link rel="stylesheet" href="/demo/site/banner.css">\n'
                             f'<script type="module" src="/demo/site/boot.mjs" data-app="{module}"></script>', html)
        if count != 1:
            raise ValueError(f'Expected one application entry: {page}, found {count}')
        # Enforce the same CSP during a plain Python localhost preview.
        html = html.replace('<meta charset="utf-8">', '<meta charset="utf-8">\n'
                            f'<meta http-equiv="Content-Security-Policy" content="{CSP}">')
        if page.startswith('etiqueta/'):
            html = html.replace('<link rel="stylesheet" href="../app.css">', '<link rel="stylesheet" href="/app.css">')
        path.write_text(html, encoding='utf-8')
    (out / '_headers').write_text('/*\n  Content-Security-Policy: ' + CSP + "; frame-ancestors 'none'\n"
        '  X-Robots-Tag: noindex\n  Referrer-Policy: no-referrer\n'
        '  Permissions-Policy: camera=(self), microphone=(), geolocation=()\n', encoding='utf-8')
    print(f'Built {out}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--api', type=Path, default=ROOT / 'demo' / 'api')
    parser.add_argument('--out', type=Path, default=ROOT / '.out' / 'demo-site')
    args = parser.parse_args()
    build(args.api, args.out)

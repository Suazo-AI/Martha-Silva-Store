"""Verify the recorded public snapshot and canonical inputs without decoding media.

This is integrity/structure verification, not visual or runtime acceptance.
"""
import hashlib
import json
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SNAPSHOT = ROOT / 'evidence/releases/20261105/responsive-runtime-sha256.json'


def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(256 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def verify(record=False):
    actual = {p.relative_to(ROOT / 'dist').as_posix(): p for p in (ROOT / 'dist').rglob('*') if p.is_file()}
    public = set(actual) - {'README.txt'}
    assert len(public) == 1558, 'Responsive candidate public path count changed'
    js = {'app.js', 'demo-api.js', 'integration-adapters.js'}
    static = {p.relative_to(ROOT / 'build-inputs/static').as_posix(): p for p in (ROOT / 'build-inputs/static').rglob('*') if p.is_file()}
    assert set(actual) == set(static) | js, 'Canonical input paths differ from dist'
    for rel, path in actual.items():
        assert not path.is_symlink(), rel
        source = ROOT / 'src' / rel if rel in js else static[rel]
        assert not source.is_symlink(), rel
        result = digest(path)
        assert result == digest(source), 'Canonical/dist drift: ' + rel
    text = (ROOT / 'dist/catalog.js').read_text(encoding='utf-8')
    prefix = 'window.DEMO_CATALOG='
    assert text.startswith(prefix)
    catalog, _ = json.JSONDecoder().raw_decode(text[len(prefix):])
    products = catalog['products']
    ids = {p['id'] for p in products}
    assert len(products) == len(ids) == 40
    assert sum(len(p['variants']) for p in products) == 120
    pages = {p.name for p in (ROOT / 'dist').glob('*.html')}
    assert pages == {f'producto-{pid}.html' for pid in ids} | {'index.html', 'catalogo.html', 'bolsa.html', 'checkout.html', 'pedido.html', 'ayuda.html', 'admin.html'}
    assert not any(p.startswith(('savia/', 'internal/', 'backend/', 'dev/')) for p in public)
    observed = {rel: {'sha256': digest(actual[rel]), 'bytes': actual[rel].stat().st_size}
                for rel in sorted(public)}
    if record:
        # Record only after input parity and the structural gates pass.
        # The October snapshot remains immutable historical evidence.
        SNAPSHOT.parent.mkdir(parents=True, exist_ok=True)
        SNAPSHOT.write_text(json.dumps(observed, indent=2) + '\n', encoding='utf-8')
    manifest = json.loads(SNAPSHOT.read_text(encoding='utf-8'))
    assert public == set(manifest), 'Public paths differ from recorded publication'
    assert observed == manifest, 'Publication bytes differ from the recorded snapshot'
    print('PASS: 1558 public paths match publication bytes; all 1559 dist files match canonical inputs; 47 pages / 40 products / 120 variants; no staff runtime paths')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record', action='store_true', help='Explicitly record the current responsive candidate after all structure/input checks pass')
    verify(record=parser.parse_args().record)

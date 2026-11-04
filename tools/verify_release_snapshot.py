"""Verify the recorded public snapshot and canonical inputs without decoding media.

This is integrity/structure verification, not visual or runtime acceptance.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(256 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def verify():
    manifest = json.loads((ROOT / 'evidence/releases/20261030/current-runtime-sha256.json').read_text(encoding='utf-8'))
    actual = {p.relative_to(ROOT / 'dist').as_posix(): p for p in (ROOT / 'dist').rglob('*') if p.is_file()}
    public = set(actual) - {'README.txt'}
    assert public == set(manifest), 'Public paths differ from recorded publication'
    assert len(public) == 1081
    js = {'app.js', 'demo-api.js', 'integration-adapters.js'}
    static = {p.relative_to(ROOT / 'build-inputs/static').as_posix(): p for p in (ROOT / 'build-inputs/static').rglob('*') if p.is_file()}
    assert set(actual) == set(static) | js, 'Canonical input paths differ from dist'
    for rel, path in actual.items():
        assert not path.is_symlink(), rel
        source = ROOT / 'src' / rel if rel in js else static[rel]
        assert not source.is_symlink(), rel
        result = digest(path)
        assert result == digest(source), 'Canonical/dist drift: ' + rel
        if rel in manifest:
            expected = manifest[rel]
            assert result == expected['sha256'] and path.stat().st_size == expected['bytes'], rel
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
    print('PASS: 1081 public paths match publication bytes; all 1082 dist files match canonical inputs; 47 pages / 40 products / 120 variants; no staff runtime paths')


if __name__ == '__main__':
    verify()

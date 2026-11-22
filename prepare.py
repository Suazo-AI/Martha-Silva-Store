"""Assemble the 40-product storefront using only local inputs.

This deliberately preserves the recovered pages; it is not the legacy editorial
page generator. See build-inputs/README.md for the editing and recovery boundary.
"""
from pathlib import Path
import argparse
import json
import re

ROOT = Path(__file__).resolve().parent
PUBLIC_PATHS = json.loads((ROOT / 'build-inputs' / 'public-paths.json').read_text(encoding='utf-8'))
PREFIXES = sorted(((old, new) for old, new in PUBLIC_PATHS['prefixes']), key=lambda pair: -len(pair[0]))
TEXT_SUFFIXES = {'.html', '.js', '.css', '.json', '.txt', '.xml', '.svg', '.webmanifest'}
_REFERENCE = re.compile(('/(' + '|'.join(re.escape(old) for old, _ in PREFIXES) + ')').encode())
_TARGETS = {old.encode(): b'/' + new.encode() for old, new in PREFIXES}


def public_path(relative: str) -> str:
    """Map a source path (relative to build-inputs/static) to its published path."""
    for old, new in PREFIXES:
        if relative.startswith(old):
            return new + relative[len(old):]
    return relative


def is_published(relative: str) -> bool:
    return relative not in PUBLIC_PATHS['unpublished']


def public_bytes(relative: str, data: bytes) -> bytes:
    """Rewrite root-relative references to source folders in a published text file."""
    if not (Path(relative).suffix in TEXT_SUFFIXES or Path(relative).name == '_headers'):
        return data
    result = _REFERENCE.sub(lambda match: _TARGETS[match.group(1)], data)
    if result != data and relative.startswith(tuple(PUBLIC_PATHS['verbatim'])):
        raise ValueError(f'Third-party file must stay byte-identical: {relative}')
    return result



def build(output: Path) -> None:
    static = ROOT / 'build-inputs' / 'static'
    pages = list(static.glob('*.html'))
    catalog_text = (static / 'catalog.js').read_text(encoding='utf-8')
    prefix = 'window.STORE_CATALOG='
    if not catalog_text.startswith(prefix):
        raise ValueError('Unsupported catalog.js format')
    catalog, _ = json.JSONDecoder().raw_decode(catalog_text[len(prefix):])
    products = catalog['products']
    product_ids = {product['id'] for product in products}
    expected_pages = set(json.loads((ROOT / 'tests' / 'site-pages.json').read_text(encoding='utf-8')))
    if {p for p in expected_pages if p.startswith('producto-')} != {f'producto-{product_id}.html' for product_id in product_ids}:
        raise ValueError('tests/site-pages.json product pages differ from the catalog')
    if len(products) != 40 or len(product_ids) != 40 or {p.name for p in pages} != expected_pages:
        raise ValueError('Expected 40 products and their recovered templates in tests/site-pages.json')
    sources = [(p, Path(public_path(p.relative_to(static).as_posix()))) for p in sorted(static.rglob('*'))
               if p.is_file() and is_published(p.relative_to(static).as_posix())]
    sources += [(ROOT / 'src' / name, Path(name)) for name in ('app.js', 'store-api.js', 'integration-adapters.js')]
    for source, _ in sources:
        if not source.is_file() or source.is_symlink():
            raise ValueError(f'Missing or unsupported build input: {source}')
    # Public names must stay one-to-one with their sources.
    expected = {relative for _, relative in sources}
    if len(expected) != len(sources):
        raise ValueError('Two build inputs map to the same published path')
    # Refuse stale output rather than silently leaving artifacts from another build.
    extras = [p for p in output.rglob('*') if p.is_file() and p.relative_to(output) not in expected]
    if extras:
        raise ValueError(f'Unexpected output files; use a fresh output directory: {extras}')
    for source, relative in sources:
        destination = output / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(public_bytes(relative.as_posix(), source.read_bytes()))
    print(f'Prepared {len(pages)} pages / {len(products)} products / {len(sources)} files: {output}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'dist',
                        help='Output directory (default: repository dist/)')
    args = parser.parse_args()
    output = args.output.resolve()
    # Outputs must never overwrite source inputs or the repository itself.
    protected = (ROOT, ROOT / 'src', ROOT / 'build-inputs', ROOT / 'tests')
    if any(output == p or p in output.parents for p in protected[1:]) or output == ROOT or output in ROOT.parents:
        parser.error('Output must not overwrite the repository or source directories')
    build(output)

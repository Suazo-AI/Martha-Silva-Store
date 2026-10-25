"""Assemble the 40-product sample storefront using only local inputs.

This deliberately preserves the recovered pages; it is not the legacy editorial
page generator. See build-inputs/README.md for the editing and recovery boundary.
"""
from pathlib import Path
import argparse
import json
import shutil

ROOT = Path(__file__).resolve().parent


def build(output: Path) -> None:
    static = ROOT / 'build-inputs' / 'static'
    pages = list(static.glob('*.html'))
    catalog_text = (static / 'catalog.js').read_text(encoding='utf-8')
    prefix = 'window.DEMO_CATALOG='
    if not catalog_text.startswith(prefix):
        raise ValueError('Unsupported catalog.js format')
    catalog, _ = json.JSONDecoder().raw_decode(catalog_text[len(prefix):])
    products = catalog['products']
    product_ids = {product['id'] for product in products}
    expected_pages = {'index.html', 'catalogo.html', 'bolsa.html', 'checkout.html',
                      'pedido.html', 'ayuda.html', 'admin.html'}
    expected_pages.update(f'producto-{product_id}.html' for product_id in product_ids)
    if len(products) != 40 or len(product_ids) != 40 or {p.name for p in pages} != expected_pages:
        raise ValueError('Expected 40 sample products and their 47 recovered templates')
    sources = [(p, p.relative_to(static)) for p in sorted(static.rglob('*')) if p.is_file()]
    sources += [(ROOT / 'src' / name, Path(name)) for name in ('app.js', 'demo-api.js', 'integration-adapters.js')]
    for source, _ in sources:
        if not source.is_file() or source.is_symlink():
            raise ValueError(f'Missing or unsupported build input: {source}')
    # Refuse stale output rather than silently leaving artifacts from another build.
    expected = {relative for _, relative in sources}
    extras = [p for p in output.rglob('*') if p.is_file() and p.relative_to(output) not in expected]
    if extras:
        raise ValueError(f'Unexpected output files; use a fresh output directory: {extras}')
    for source, relative in sources:
        destination = output / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
    print(f'Prepared {len(pages)} pages / {len(products)} sample products / {len(sources)} files: {output}')


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

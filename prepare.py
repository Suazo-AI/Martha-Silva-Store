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


# The storefront settings reach the browser through existing files, so the published path set stays fixed.
CONFIG_PATH = ROOT / 'site.config.json'
CONFIG_MARKER = b'const CONFIG = {"apiBase":"","turnstileSiteKey":"","skus":{}};'
TURNSTILE = 'https://challenges.cloudflare.com'
_LOOPBACK = re.compile(r'http://(127\.0\.0\.1|localhost)(:\d{1,5})?')
_HTTPS_ORIGIN = re.compile(r'https://[a-z0-9.-]+(:\d{1,5})?')
_SITE_KEY = re.compile(r'[0-9A-Za-z_-]{0,100}')
_SKU = re.compile(r'[^\x00-\x1f]{1,64}')
_STATIC_PRICE = re.compile(rb'(<p class="(?:detail-price )?product-price">)[^<]*(</p>)')
_LD_JSON = re.compile(rb'(<script type="application/ld\+json">)(.*?)(</script>)', re.S)


def _without_offers(match: re.Match) -> bytes:
    data = json.loads(match.group(2))
    for node in data.get('@graph', []):
        node.pop('offers', None)
    text = json.dumps(data, ensure_ascii=False, separators=(',', ':')).replace('<', '\\u003c')
    return match.group(1) + text.encode('utf-8') + match.group(3)


def storefront_config(path: Path | None = None) -> dict:
    """Read and check the storefront section; an empty apiBase keeps the demo store."""
    section = json.loads((path or CONFIG_PATH).read_text(encoding='utf-8')).get('storefront', {})
    config = {'apiBase': section.get('apiBase', ''), 'turnstileSiteKey': section.get('turnstileSiteKey', ''),
              'skus': section.get('skus', {})}
    base = config['apiBase']
    # Only an origin: the CSP allows exactly it, and plain http is for a local test hub only.
    if not isinstance(base, str) or (base and not (_HTTPS_ORIGIN.fullmatch(base) or _LOOPBACK.fullmatch(base))):
        raise ValueError('storefront.apiBase must be empty, an https origin, or an http loopback origin')
    if not isinstance(config['turnstileSiteKey'], str) or not _SITE_KEY.fullmatch(config['turnstileSiteKey']):
        raise ValueError('storefront.turnstileSiteKey must be empty or a Turnstile site key')
    skus = config['skus']
    if not isinstance(skus, dict) or not all(isinstance(k, str) and isinstance(v, str) and _SKU.fullmatch(v) for k, v in skus.items()):
        raise ValueError('storefront.skus must map storefront variant ids to hub SKUs')
    if len(set(skus.values())) != len(skus):
        raise ValueError('storefront.skus maps two variants to one hub SKU')
    return config


def configured_bytes(relative: str, data: bytes, config: dict) -> bytes:
    """Write the storefront settings into the adapter and widen the CSP only for the hub and Turnstile."""
    if relative == 'integration-adapters.js':
        if data.count(CONFIG_MARKER) != 1:
            # Only a live build depends on the line; fixtures without it stay byte-identical.
            if config['apiBase']:
                raise ValueError('integration-adapters.js lost its CONFIG line')
            return data
        value = json.dumps(config, ensure_ascii=False, separators=(',', ':'))
        return data.replace(CONFIG_MARKER, b'const CONFIG = ' + value.encode() + b';')
    if relative.endswith('.html') and config['apiBase']:
        # A live store must not show the recovered demo prices; the hub catalog fills these in.
        data = _STATIC_PRICE.sub(rb'\1&#160;\2', data)
        # Structured data must not advertise them either.
        data = _LD_JSON.sub(_without_offers, data)
        # Every live page reads the hub catalog with credentials omitted, so open that anonymous connection early.
        preconnect = f'<link rel="preconnect" href="{config["apiBase"]}" crossorigin>'.encode()
        return data.replace(b'<link rel="stylesheet"', preconnect + b'<link rel="stylesheet"', 1)
    if relative == '_headers':
        text = data.decode('utf-8')
        if config['apiBase']:
            text = text.replace("connect-src 'self';", f"connect-src 'self' {config['apiBase']};", 1)
        if config['turnstileSiteKey']:
            script = re.search(r"script-src [^;]+", text).group(0)
            text = text.replace(script, f'{script} {TURNSTILE}', 1).replace("object-src 'none';", f"frame-src {TURNSTILE}; object-src 'none';", 1)
        return text.encode('utf-8')
    return data


def public_bytes(relative: str, data: bytes, config: dict | None = None) -> bytes:
    """Rewrite root-relative references to source folders in a published text file."""
    if not (Path(relative).suffix in TEXT_SUFFIXES or Path(relative).name == '_headers'):
        return data
    result = _REFERENCE.sub(lambda match: _TARGETS[match.group(1)], data)
    if result != data and relative.startswith(tuple(PUBLIC_PATHS['verbatim'])):
        raise ValueError(f'Third-party file must stay byte-identical: {relative}')
    return configured_bytes(relative, result, config or storefront_config())



def build(output: Path, config: dict | None = None) -> None:
    config = config or storefront_config()
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
    unknown = set(config['skus']) - {variant['id'] for product in products for variant in product['variants']}
    if unknown:
        raise ValueError(f'storefront.skus names variants that are not in the catalog: {sorted(unknown)}')
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
        destination.write_bytes(public_bytes(relative.as_posix(), source.read_bytes(), config))
    print(f'Prepared {len(pages)} pages / {len(products)} products / {len(sources)} files: {output}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'dist',
                        help='Output directory (default: repository dist/)')
    parser.add_argument('--config', type=Path, default=CONFIG_PATH,
                        help='Site configuration (default: site.config.json); a local test build passes its own')
    args = parser.parse_args()
    output = args.output.resolve()
    # Outputs must never overwrite source inputs or the repository itself.
    protected = (ROOT, ROOT / 'src', ROOT / 'build-inputs', ROOT / 'tests')
    if any(output == p or p in output.parents for p in protected[1:]) or output == ROOT or output in ROOT.parents:
        parser.error('Output must not overwrite the repository or source directories')
    build(output, storefront_config(args.config))

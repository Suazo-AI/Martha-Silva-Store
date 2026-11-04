#!/usr/bin/env python3
"""Compare recovered sample catalog with local demo/media; emit inert JSON to stdout.

No network, database, runtime-stock access, publication or file writes. See
 tests/catalog-staging-README.md for provenance and manual activation gates.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
MEDIA = re.compile(r'/(?:research/assets/|assets/research/assets/|hero/)[A-Za-z0-9_./-]+\.(?:jpg|jpeg|png|webp|mp4|webm)')


def safe_media(value):
    return isinstance(value, str) and bool(MEDIA.fullmatch(value)) and '..' not in value.split('/')


def local_status(root, relative):
    path = root / relative
    if any(p.is_symlink() for p in [path, *path.parents]):
        return 'symlink_rejected'
    if not path.is_file():
        return 'missing'
    return 'present' if path.stat().st_size > 0 else 'empty'


def original_status(root, reference):
    direct = local_status(root, reference.lstrip('/'))
    return local_status(root, 'assets' + reference) if direct == 'missing' else direct


def products_by_id(catalog):
    result = {}
    for product in catalog['products']:
        key = product['id']
        if not isinstance(key, str) or not key or key in result:
            raise ValueError('Product IDs must be unique non-empty strings')
        result[key] = product
    return result


def read_demo(path):
    raw = path.read_text(encoding='utf-8')
    prefix = 'window.DEMO_CATALOG='
    if not raw.startswith(prefix):
        raise ValueError('Unsupported demo catalog format (JavaScript is never executed)')
    return json.JSONDecoder().raw_decode(raw[len(prefix):])[0]


def compare(recovered, demo, manifest, dist, asset_root=None):
    original = products_by_id(recovered)
    current = products_by_id(demo)
    known = {ref for source in manifest['sources'] for ref in source['media_paths']}
    if any(not safe_media(ref) for ref in known):
        raise ValueError('Unsafe manifest media path')
    rows = []
    for key, product in original.items():
        refs = product.get('images', [])
        if any(not safe_media(ref) or not ref.startswith('/research/assets/') for ref in refs):
            raise ValueError('Unsafe recovered media path')
        coverage = []
        for ref in refs:
            item = {'reference': ref, 'in_manifest': ref in known,
                    'demo_original_path': original_status(dist, ref)}
            if asset_root is not None:
                item['offline_import_path'] = local_status(asset_root, ref.lstrip('/'))
            item['original_available'] = item['demo_original_path'] == 'present' or item.get('offline_import_path') == 'present'
            coverage.append(item)
        selected = []
        for ref in current.get(key, {}).get('images', []):
            if not safe_media(ref):
                raise ValueError('Unsafe current demo media path')
            selected.append({'reference': ref, 'status': local_status(dist, ref.lstrip('/'))})
        complete = bool(coverage) and all(c['original_available'] and c['in_manifest'] for c in coverage)
        blockers = ['verify_price_currency_and_variant_stock_with_owner', 'explicit_activation_review_required']
        if not complete:
            blockers.insert(0, 'recover_and_review_complete_original_gallery')
        rows.append({
            'id': key, 'name': product.get('name'),
            'state': 'existing_demo_preserved' if key in current else 'staged_not_published',
            'publish_allowed': False,
            'commercial_evidence': {'classification': 'recovered_sample_not_live_inventory',
                                    'source_commercial_status': product.get('commercial_status'),
                                    'sample_price_minor': product.get('price_minor'),
                                    'sample_currency': product.get('currency'),
                                    'sample_variants': [{'id': v['id'], 'size': v.get('size'),
                                                         'sample_stock': v.get('stock')}
                                                        for v in product.get('variants', [])]},
            'original_gallery': coverage, 'original_gallery_complete': complete,
            'current_demo_images': selected, 'activation_blockers': blockers})
    return {
        'schema': 1, 'kind': 'inert_catalog_staging_report',
        'scope': 'Offline file observations only; not live stock, full recovery, or publication.',
        'inventory_policy': 'All recovered price/stock values are sample evidence. Runtime inventory is neither read nor changed.',
        'activation_policy': 'Recover and review original media, verify commercial data with owner, then separately authorize activation. This tool never activates.',
        'summary': {'recovered_products': len(original),
                    'recovered_variants': sum(len(p.get('variants', [])) for p in original.values()),
                    'original_gallery_references': sum(len(p.get('images', [])) for p in original.values()),
                    'current_demo_products': len(current),
                    'new_staged_products': len(original.keys() - current.keys()),
                    'original_galleries_complete': sum(r['original_gallery_complete'] for r in rows),
                    'publish_allowed': 0},
        'current_demo_only_ids': sorted(current.keys() - original.keys()),
        'records': rows}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--original', type=Path, default=ROOT / 'originals/cloudflare/catalog-extracted.json')
    parser.add_argument('--demo', type=Path, default=ROOT / 'dist/catalog.js')
    parser.add_argument('--manifest', type=Path, default=ROOT / 'evidence/asset-source-manifest.json')
    parser.add_argument('--dist', type=Path, default=ROOT / 'dist')
    parser.add_argument('--asset-root', type=Path, help='Optional local directory containing research/assets/...')
    args = parser.parse_args()
    result = compare(json.loads(args.original.read_text(encoding='utf-8')), read_demo(args.demo),
                     json.loads(args.manifest.read_text(encoding='utf-8')), args.dist, args.asset_root)
    result['input_sha256'] = {name: hashlib.sha256(path.read_bytes()).hexdigest()
                              for name, path in [('original', args.original), ('demo', args.demo), ('manifest', args.manifest)]}
    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()

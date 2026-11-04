#!/usr/bin/env python3
"""Offline, read-only asset inventory. Never fetch URLs or read databases."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ['martha-editorial/parity-v2/catalog-fixture.json',
           'sisfain-research/observed-catalog.json',
           'martha-editorial/reference/media.json',
           'martha-editorial/reference/body.txt',
           'martha-editorial/reference/head.txt',
           'martha-editorial/reference/css.txt']
# Only public media paths, not URLs, query strings, credentials or arbitrary files.
MEDIA = re.compile(r'/research/assets/[A-Za-z0-9_./-]+\.(?:webp|jpg|jpeg|png|mp4|webm)(?![A-Za-z0-9])')
ALLOWED = {'.jpg', '.jpeg', '.png', '.webp', '.mp4', '.webm'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def safe(path):
    return (isinstance(path, str) and MEDIA.fullmatch(path) is not None
            and '..' not in path.split('/'))


def collect(base):
    evidence = {'schema': 1, 'sources': [], 'catalogs': [], 'media': []}
    for name in SOURCES:
        p = base / name
        raw = p.read_text(encoding='utf-8')
        refs = sorted({x for x in MEDIA.findall(raw) if safe(x)})
        evidence['sources'].append({'path': name, 'bytes': p.stat().st_size,
                                    'sha256': sha(p), 'media_paths': refs})
        if name.endswith(('catalog-fixture.json', 'observed-catalog.json')):
            products = json.loads(raw)['products']
            evidence['catalogs'].append({'source': name, 'products': [
                {'id': v['id'], 'variants': len(v['variants']),
                 'images': [x for x in v['images'] if safe(x)]} for v in products]})
        elif name.endswith('/media.json'):
            evidence['media'] = [{'id': key, 'primary_images': value['images'],
                                 'paths': sorted(set(MEDIA.findall(json.dumps(value))))}
                                for key, value in json.loads(raw).items()]
    return evidence


def record(root, relative):
    p = root / relative
    # Reject symlinks anywhere along the path, including the selected root.
    if any(part.is_symlink() for part in [p, *p.parents]):
        return {'path': relative, 'status': 'symlink_rejected'}
    if not p.is_file():
        return {'path': relative, 'status': 'missing'}
    if p.stat().st_size == 0:
        return {'path': relative, 'status': 'empty', 'bytes': 0}
    return {'path': relative, 'status': 'present', 'bytes': p.stat().st_size,
            'sha256': sha(p)}


def original_record(root, reference):
    """Observe original public paths, retaining the earlier /assets mirror fallback."""
    direct = record(root, reference.lstrip('/'))
    # An explicit unsafe/empty original path must not be hidden by a legacy copy.
    return record(root, 'assets' + reference) if direct['status'] == 'missing' else direct


def audit(evidence, dist, staging=None):
    text = (dist / 'catalog.js').read_text(encoding='utf-8')
    prefix = 'window.DEMO_CATALOG='
    assert text.startswith(prefix), 'Unsupported catalog.js format'
    published, _ = json.JSONDecoder().raw_decode(text[len(prefix):])
    products = published['products']
    original = evidence['catalogs'][0]['products']
    counts = lambda items: {'products': len(items),
                           'variants': sum(p['variants'] if isinstance(p['variants'], int)
                                           else len(p['variants']) for p in items),
                           'gallery_references': sum(len(p['images']) for p in items)}
    refs = sorted({path for item in evidence['sources'] for path in item['media_paths']})
    assets = []
    for ref in refs:
        row = {'reference': ref, 'demo': original_record(dist, ref)}
        if staging is not None:
            row['staging'] = record(staging, ref.lstrip('/'))
        assets.append(row)
    selected = []
    for p in products:
        for path in p['images']:
            rel = path.lstrip('/')
            if '..' in Path(rel).parts or Path(rel).suffix.lower() not in ALLOWED:
                raise ValueError('Unsafe published media path')
            selected.append({'product': p['id'], **record(dist, rel)})
    original_primary = {ref for p in original for ref in p['images']}
    inventory = [record(dist, str(p.relative_to(dist)))
                 for folder in ['assets', 'hero', 'research/assets'] for p in sorted((dist / folder).rglob('*'))
                 if p.suffix.lower() in ALLOWED and p.is_file()]
    return {'schema': 1, 'scope': 'Offline local snapshot; not live deployment or original PC verification',
            'catalog_evidence': [{'source': c['source'], **counts(c['products'])} for c in evidence['catalogs']],
            'media_primary_references': sum(len(m['primary_images']) for m in evidence['media']),
            'published_fixture': counts(products),
            'published_product_ids': sorted(p['id'] for p in products),
            'unpublished_product_ids': sorted(set(p['id'] for p in original) - set(p['id'] for p in products)),
            'unique_original_media_paths': len(refs),
            'original_primary_paths_present_in_demo': sum(a['reference'] in original_primary and a['demo']['status'] == 'present' for a in assets),
            'original_media_paths_present_in_demo': sum(a['demo']['status'] == 'present' for a in assets),
            'selected_demo_images': selected, 'local_media_inventory': inventory,
            'original_media': assets,
            'exclusions': ['SQLite/databases', 'orders', 'customer data', 'secrets', 'URLs/query strings', 'missing.svg placeholder']}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source-root', type=Path, help='Read only six allowlisted evidence inputs and refresh sanitized snapshot')
    ap.add_argument('--evidence', type=Path, default=ROOT / 'evidence/asset-source-manifest.json')
    ap.add_argument('--output', type=Path, default=ROOT / 'evidence/asset-completeness.json')
    ap.add_argument('--dist', type=Path, default=ROOT / 'dist')
    ap.add_argument('--staging', type=Path, help='Optional offline import root with research/assets/... layout')
    ap.add_argument('--require-complete', action='store_true', help='Fail unless all original media exist in staging (or demo if no staging)')
    args = ap.parse_args()
    if args.source_root:
        evidence = collect(args.source_root)
        args.evidence.write_text(json.dumps(evidence, indent=2) + '\n')
    else:
        evidence = json.loads(args.evidence.read_text(encoding='utf-8'))
    # Snapshot paths must satisfy the same allowlist before any filesystem access.
    assert all(safe(ref) for s in evidence['sources'] for ref in s['media_paths'])
    result = audit(evidence, args.dist, args.staging)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: v for k, v in result.items() if k not in ['original_media', 'local_media_inventory', 'unpublished_product_ids']}, indent=2))
    if any(x['status'] != 'present' for x in result['selected_demo_images']):
        return 1
    if args.require_complete:
        key = 'staging' if args.staging else 'demo'
        return int(any(a[key]['status'] != 'present' for a in result['original_media']))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

#!/usr/bin/env python3
"""Export an explicit public-safe SAVIA snapshot, or verify its preserved hashes.

Export reads frozen local evidence; it does not execute SAVIA, Docker or SQL.
The default is portable verification. Use --export only on the owning Windows host.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'evidence/savia/20261030'
SOURCE = ROOT.parent / 'validation/private-pilot-20261028'
BASE = 'harness-diagnostic-preparation-20261030/'
PACKAGE = BASE + 'r7-diagnostic-package-offline/'
DIAGNOSTIC = BASE + 'r7-anonymous-diagnostic-offline/'
TESTS = ['InternalCommerceCommandSqlTests.cs', 'InternalJudgeTests.cs',
         'InternalMigrationTests.cs', 'InternalSecuritySqlTests.cs', 'PrivatePilotReleaseTests.cs']
ALLOW = {
    'package-acceptance.json': PACKAGE + 'PRIMARY-ACCEPTANCE.json',
    'package-vm.json': PACKAGE + 'INTEGRATION-VM-RESULT.json',
    'diagnostic-offline.json': DIAGNOSTIC + 'OFFLINE-RESULT.json',
    'diagnostic/browser.diff': DIAGNOSTIC + 'browser.diff',
    'diagnostic/offline-checks.cjs': DIAGNOSTIC + 'offline-checks.cjs',
    'diagnostic/candidate-browser.cjs': DIAGNOSTIC + 'candidate/browser.cjs',
    'diagnostic/baseline-browser.cjs': BASE + 'runtime-proposal-revision7/package/manual/browser.cjs',
    'diagnostic/error-policy.cjs': BASE + 'runtime-proposal-revision7/package/manual/error-policy.cjs',
    'anonymous-failure.json': BASE + 'runtime-proposal-revision7/runtime-output/'
        'evidence-20261031T005138242Z-1dd0f218/browser-result.json',
}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def export():
    from progress import scan
    entries = []
    for name in TESTS:
        ALLOW['source-deltas/' + name] = 'worker/candidate/backend/tests/Martha.Store.Api.Tests/' + name
    for public, source in sorted(ALLOW.items()):
        payload = (SOURCE / source).read_bytes()
        scan(public, payload)
        target = DEST / public
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(payload)
        entries.append({'path': target.relative_to(ROOT).as_posix(),
                        'sha256': sha(payload), 'source': 'validation/private-pilot-20261028/' + source,
                        'source_sha256': sha(payload)})
    # Export counters only; raw TRX/results can contain paths and connection details.
    original = (SOURCE / 'worker/full-results.json').read_bytes()
    counts = dict(Counter(item['outcome'] for item in json.loads(original)))
    report = {'historical_date': '2026-10-28', 'outcomes': counts,
              'source_sha256': sha(original), 'rerun_for_this_publication': False,
              'limit': 'Historical source-specific backend result; not current runtime acceptance.'}
    target = DEST / 'historical-backend.json'
    write_json(target, report)
    entries.append({'path': target.relative_to(ROOT).as_posix(), 'sha256': sha(target.read_bytes()),
                    'source': 'validation/private-pilot-20261028/worker/full-results.json',
                    'source_sha256': sha(original), 'transformation': 'Outcome counters only'})
    write_json(DEST / 'manifest.json', {'schema': 1, 'scope': 'Allowlisted frozen evidence and test-source deltas',
               'files': entries, 'excludes': ['credentials', 'certificates', 'execution authorizations',
               'raw TRX and logs', 'customer/order/database exports', 'machine/browser profiles',
               'bulk frozen runtime copies', 'bulk machine inventory']})
    print(f'Exported {len(entries)} allowlisted files; raw evidence remains local.')


def verify():
    from progress import scan
    manifest = json.loads((DEST / 'manifest.json').read_text(encoding='utf-8'))
    scan('manifest.json', (DEST / 'manifest.json').read_bytes())
    for item in manifest['files']:
        path = item['path']
        scan(path, b'')
        target = (ROOT / path).resolve()
        if not target.is_relative_to(DEST.resolve()):
            raise ValueError('Manifest path escapes frozen evidence.')
        payload = target.read_bytes()
        scan(path, payload)
        if sha(payload) != item['sha256']:
            raise ValueError(f'Evidence hash mismatch: {path}')
    print(f"PASS: {len(manifest['files'])} preserved evidence hashes; no runtime executed.")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--export', action='store_true')
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    try:
        if args.export:
            export()
        verify()
    except (ValueError, OSError) as error:
        print(f'Export BLOCKED: {error}', file=sys.stderr)
        sys.exit(1)

#!/usr/bin/env python3
"""Portable offline QA: python tests/check.py [--install].

Requires Python 3 and Node.js on PATH. --install explicitly runs npm ci using
locked DOM dependencies; otherwise no dependency download is attempted.
Frontend coverage is DOM simulation, not a real browser test.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent


def check_fixture(root):
    pages = sorted((root / 'dist').glob('*.html'))
    if len(pages) != 9:
        raise ValueError(f'Expected 9 recovered pages, found {len(pages)}')
    for name in ('app.js', 'demo-api.js', 'integration-adapters.js'):
        if (root / 'src' / name).read_bytes() != (root / 'dist' / name).read_bytes():
            raise ValueError(f'src/dist drift: {name}')
    print('PASS: 9 pages; src/dist app.js, demo-api.js and integration-adapters.js match', flush=True)


def clean_environment():
    env = os.environ.copy()
    # Never mislabel a baseline override as recovered-demo QA.
    env.pop('FRONTEND_APP', None)
    env.pop('FRONTEND_API', None)
    return env


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', action='store_true', help='install locked DOM dependencies')
    args = parser.parse_args(argv)
    env = clean_environment()

    def run(command):
        subprocess.run(command, cwd=ROOT, env=env, check=True)

    def stage(title):
        print(f'\n== {title} ==', flush=True)

    try:
        node = shutil.which('node')
        if not node:
            raise ValueError('Missing Node.js: install Node.js and add it to PATH.')
        if args.install:
            # Resolve npm.cmd on Windows instead of assuming a Unix executable.
            npm = shutil.which('npm.cmd' if os.name == 'nt' else 'npm')
            if not npm:
                raise ValueError('Missing npm: install npm and add it to PATH.')
            run([npm, 'ci', '--prefix', 'tests/frontend-deps',
                 '--registry=https://registry.npmjs.org', '--ignore-scripts', '--no-audit', '--no-fund'])
        if not (ROOT / 'tests/frontend-deps/node_modules/jsdom/package.json').is_file():
            raise ValueError('Missing jsdom: run python tests/check.py --install first.')
        run([node, '--version'])
        run([sys.executable, '--version'])
        stage('Reproducible snapshot build')
        run([sys.executable, 'tests/build.py'])
        stage('Recovered fixture')
        check_fixture(ROOT)
        stage('Backend simulation')
        run([node, '--test', 'tests/backend.cjs'])
        stage('Dual integration adapters (local/synthetic only)')
        run([node, '--test', 'tests/integration-adapters.test.js'])
        stage('Catalog expansion regression')
        run([node, '--test', 'tests/catalog-migration.cjs'])
        stage('Asset audit regression (not full catalog completion)')
        run([sys.executable, 'tests/asset-audit.py'])
        stage('Portable runner regression')
        run([sys.executable, 'tests/test_check.py'])
        stage('Automatic sync guard regression')
        run([sys.executable, 'tests/test_sync_progress.py'])
        stage('Recovered catalog staging regression')
        run([sys.executable, 'tests/catalog-staging.py'])
        stage('Frontend DOM simulation (not a browser)')
        run([node, 'tests/frontend-runtime.cjs'])
        stage('Local HTML structure')
        run([sys.executable, 'tests/structure.py'])
        stage('JavaScript syntax')
        files = sorted(path for pattern in ('src/*.js', 'dist/*.js', 'tests/*.cjs', 'tests/*.test.js')
                       for path in ROOT.glob(pattern))
        for path in files:
            run([node, '--check', str(path.relative_to(ROOT))])
        print(f'PASS: syntax ({len(files)} JavaScript files)', flush=True)
        print('\nPASS: all recovered-demo automated checks', flush=True)
        return 0
    except subprocess.CalledProcessError as error:
        print(f'FAIL: command exited with status {error.returncode}', file=sys.stderr)
        return error.returncode if error.returncode > 0 else 1
    except (OSError, ValueError) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""Offline maintenance checks. No installs, restore, SQL, Docker or publication.

The tests/check.py stages are expanded so a missing dependency does not hide
unrelated results. Quick mode skips build, media and .NET checks explicitly.
Only reviewed offline test locations are discovered; runtime harnesses are not.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def check(name, command, read_next, requires=(), slow=False, reason=None):
    return dict(name=name, command=command, read_next=read_next,
                requires=requires, slow=slow, reason=reason)


def environment(evidence):
    env = os.environ.copy()
    # Never inherit runtime credentials or explicit runtime opt-ins.
    for key in list(env):
        if key.upper().startswith(('SAVIA_', 'INTERNALSAVIA', 'CONNECTIONSTRINGS',
                                   'SYNTHETIC', 'FRONTEND_', 'MARTHA_', 'GIT_')) or any(
                word in key.upper() for word in ('TOKEN', 'SECRET', 'PASSWORD', 'API_KEY')):
            env.pop(key)
    env.update(PYTHONDONTWRITEBYTECODE='1', PYTHONUTF8='1',
               NODE_PATH=str(ROOT / 'tests/frontend-deps/node_modules'),
               DOTNET_CLI_TELEMETRY_OPTOUT='1', DOTNET_SKIP_FIRST_TIME_EXPERIENCE='1',
               DOTNET_CLI_WORKLOAD_UPDATE_NOTIFY_DISABLE='true',
               SAVIA_PILOT_EVIDENCE=evidence)
    return env


def checks(root=ROOT):
    py = sys.executable
    result = [check('git-state', ['git', 'status', '--short'], 'docs/AGENT-START.md', ('git',))]
    # Every stage in tests/check.py, without its fail-fast dependency gate.
    fixture = "import runpy; m=runpy.run_path('tests/check.py'); m['check_fixture'](m['ROOT'])"
    result.append(check('recovered-fixture', [py, '-c', fixture], 'tests/check.py'))
    standalone = ['build.py', 'static_headers.py', 'responsive_images.py',
                  'responsive_fonts.py', 'asset-audit.py', 'catalog-staging.py', 'structure.py']
    for name in standalone:
        media = name in ('responsive_images.py', 'responsive_fonts.py')
        requires = ('media',) if media else ()
        result.append(check('tests/' + name, [py, 'tests/' + name], 'tests/' + name,
                            requires, name == 'build.py' or media))
    for directory in ('tests', 'tests/bugproof', 'backend/tests', 'tools/local-validation'):
        for path in sorted((root / directory).glob('test_*.py')):
            rel = path.relative_to(root).as_posix()
            result.append(check(rel, [py, rel], rel, ('git',) if directory == 'tests/bugproof' else ()))
    for pattern in ('tests/*.cjs', 'tests/*.test.js', 'tests/*.test.mjs',
                    'dev/savia-staff-ui/*.test.mjs'):
        for path in sorted(root.glob(pattern)):
            rel = path.relative_to(root).as_posix()
            if path.name == 'gallery-browser-contracts.cjs':
                result.append(check(rel, ['node', rel], rel,
                                    reason='browser runtime writes evidence; run separately with explicit scope'))
                continue
            # Only DOM runners need jsdom; pure Node tests remain runnable.
            if path.name == 'integration-adapters.test.js':
                result.append(check(rel, ['node', '--test', rel], rel,
                                    reason='includes loopback HTTP; excluded by no-network contract'))
                continue
            dom = 'jsdom' in path.read_text(encoding='utf-8')
            command = ['node', rel] if path.name in ('frontend-runtime.cjs', 'localization-runtime.cjs') else ['node', '--test', rel]
            result.append(check(rel, command, rel, ('node', 'jsdom') if dom else ('node',)))
    for pattern in ('src/*.js', 'dist/*.js', 'tests/*.cjs', 'tests/*.test.js'):
        for path in sorted(root.glob(pattern)):
            rel = path.relative_to(root).as_posix()
            result.append(check('syntax:' + rel, ['node', '--check', rel], rel, ('node',)))
    for path, args in [('tools/verify_release_snapshot.py', []),
                       ('tools/export_progress.py', ['--verify']),
                       ('tools/delivery_status.py', ['--check'])]:
        result.append(check(path, [py, path, *args], path))
    for project in ('backend/tests/Martha.Store.Api.Tests', 'tests/golden-path/GoldenPath.Sql'):
        assets = root / project / 'obj/project.assets.json'
        reason = None if assets.is_file() else 'restore assets absent; with network approval run dotnet restore ' + project + ' --locked-mode'
        result.append(check('dotnet-build:' + project,
                            ['dotnet', 'build', project, '--no-restore', '--configuration', 'Release'],
                            project + '/' + Path(project).name + '.csproj', ('dotnet',), True, reason))
        if project.startswith('backend/'):
            result.append(check('dotnet-non-SQL', ['dotnet', 'test', project, '--no-restore',
                                '--no-build', '--configuration', 'Release', '--filter', 'Category!=SqlServer'],
                                '.github/workflows/backend.yml', ('dotnet',), True, reason))
    return result


def missing(requirement, root):
    if requirement == 'jsdom':
        if not (root / 'tests/frontend-deps/node_modules/jsdom/package.json').is_file():
            return 'jsdom absent; with network approval run python tests/check.py --install'
    elif requirement == 'media':
        if any(importlib.util.find_spec(name) is None for name in ('PIL', 'fontTools', 'brotli')):
            return 'media modules absent; with network approval run python -m pip install -r tests/media-requirements.txt'
    elif not shutil.which(requirement):
        return requirement + ' absent; install ' + {'dotnet': '.NET SDK 10.0.402', 'node': 'Node.js 24', 'git': 'Git'}.get(requirement, requirement) + ' and add it to PATH'
    return None


def execute(item, quick=False, root=ROOT, env=None):
    result = dict(name=item['name'], status='SKIPPED', reason='', read_next=None,
                  command=item['command'], exit_code=None)
    reason = next((message for req in item['requires'] if (message := missing(req, root))), None)
    reason = reason or item['reason'] or ('quick mode' if quick and item['slow'] else None)
    if reason:
        result['reason'] = reason
        return result
    try:
        process = subprocess.run(item['command'], cwd=root, env=env, capture_output=True,
                                 text=True, encoding='utf-8', errors='replace', timeout=900)
        result['exit_code'] = process.returncode
        result['status'] = 'PASS' if process.returncode == 0 else 'FAIL'
        # Do not echo child logs, which can contain local paths or runtime values.
        result['reason'] = ('local changes present (informational)' if process.stdout.strip() else 'clean') if item['name'] == 'git-state' else 'exit ' + str(process.returncode)
    except (OSError, subprocess.TimeoutExpired) as error:
        result.update(status='FAIL', reason=type(error).__name__)
    if result['status'] == 'FAIL':
        result['read_next'] = item['read_next']
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--quick', action='store_true')
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args(argv)
    results = []
    with tempfile.TemporaryDirectory(prefix='savia-doctor-') as evidence:
        env = environment(evidence)
        backend_build_failed = False
        for item in checks():
            if item['name'] == 'dotnet-non-SQL' and backend_build_failed:
                item['reason'] = 'backend build failed; read .github/workflows/backend.yml'
            result = execute(item, args.quick, env=env)
            if item['name'] == 'dotnet-build:backend/tests/Martha.Store.Api.Tests':
                backend_build_failed = result['status'] == 'FAIL'
            results.append(result)
            if not args.json:
                pointer = ' -> read ' + result['read_next'] if result['read_next'] else ''
                print(f"{result['status']} {result['name']} ({result['reason']}){pointer}", flush=True)
    counts = {status: sum(r['status'] == status for r in results) for status in ('PASS', 'FAIL', 'SKIPPED')}
    code = int(counts['FAIL'] > 0)
    if args.json:
        print(json.dumps(dict(schema_version=1, quick=args.quick, checks=results, summary=counts, exit_code=code), indent=2))
    return code


if __name__ == '__main__':
    sys.exit(main())

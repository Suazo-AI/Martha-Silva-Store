"""Differential regression proof. Stdlib only; never executes SQL tests."""
import argparse
import html
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile


def run(args, cwd, env=None):
    try:
        p = subprocess.run(args, cwd=cwd, env=env, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=180, encoding='utf-8', errors='replace')
        return p.returncode, p.stdout[-16000:]
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 125, str(exc)


def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args])


def snapshot(repo, sha, dest):
    with zipfile.ZipFile(io.BytesIO(git(repo, 'archive', '--format=zip', sha))) as archive:
        for entry in archive.infolist():
            target = dest / entry.filename
            if not target.resolve().is_relative_to(dest.resolve()) or (entry.external_attr >> 16) & 0o170000 == 0o120000:
                raise ValueError('Unsafe archive path: ' + entry.filename)
        archive.extractall(dest)


def kind(path):
    p = Path(path)
    if path.startswith(('tests/', 'dev/savia-staff-ui/')) and p.name.endswith('.test.mjs'):
        return 'node'
    if ('tests' in p.parts) and p.suffix == '.py' and (p.name.startswith('test_') or p.name.endswith('_test.py')):
        return 'python'
    if path.startswith('backend/tests/') and p.name.endswith('Tests.cs'):
        return 'dotnet'
    return None


def sql_test(path, source):
    return bool(re.search(r'sql', path, re.I) or re.search(
        r'SqlFact|SqlTheory|SqlServer|MARTHA_TEST_SQL|SAVIA_TEST_SQL|Microsoft\.Data\.SqlClient', source, re.I))


def execute(root, path, test_kind):
    env = {k: v for k, v in os.environ.items() if not any(s in k.upper() for s in ('TOKEN', 'SECRET', 'SQL', 'CONNECTION'))}
    env['PYTHONPATH'] = str(root)
    if test_kind == 'node':
        deps = root / 'tests/frontend-deps'
        if (deps / 'package-lock.json').exists():
            code, log = run(['npm' + ('.cmd' if os.name == 'nt' else ''), 'ci', '--prefix', str(deps),
                             '--ignore-scripts', '--no-audit', '--no-fund'], root, env)
            if code:
                return 'ERROR', log
            env['NODE_PATH'] = str(deps / 'node_modules')
        code, log = run(['node', '--test', '--test-reporter=tap', path], root, env)
        infra = re.search(r'ERR_MODULE_NOT_FOUND|MODULE_NOT_FOUND|SyntaxError|ReferenceError', log)
        passed = re.search(r'# pass ([1-9]\d*)', log)
        failed = re.search(r'# fail ([1-9]\d*)', log)
        return ('ERROR' if infra or code == 125 else 'PASS' if code == 0 and passed else
                'FAIL' if code != 0 and failed else 'ERROR'), log
    if test_kind == 'python':
        code, log = run([sys.executable, path, '-v'], root, env)
        count = re.search(r'Ran ([1-9]\d*) tests?', log)
        assertion = re.search(r'FAILED \(failures=[1-9]', log)
        return ('PASS' if code == 0 and count and '\nOK' in log and not re.search(r'skipped=|expected failures=', log)
                else 'FAIL' if code and count and assertion and not re.search(r'errors=[1-9]', log) else 'ERROR'), log
    source = (root / path).read_text(encoding='utf-8-sig')
    classes = re.findall(r'\bclass\s+(\w+Tests)\b', source)
    projects = []
    for parent in (root / path).parents:
        projects = list(parent.glob('*.csproj'))
        if projects or parent == root:
            break
    if len(projects) != 1 or not classes:
        return 'ERROR', 'Cannot determine test project/classes.'
    results = Path(tempfile.mkdtemp(prefix='.bugproof-trx-', dir=root))
    code, log = run(['dotnet', 'test', str(projects[0]), '--filter',
                     '|'.join('FullyQualifiedName~.' + c + '.' for c in classes),
                     '--logger', 'trx', '--results-directory', str(results)], root, env)
    outcomes = []
    for trx in results.glob('*.trx'):
        outcomes += [e.attrib.get('outcome') for e in ET.parse(trx).iter() if e.tag.endswith('}UnitTestResult')]
    if not outcomes or any(o not in ('Passed', 'Failed') for o in outcomes):
        return 'ERROR', log
    return ('PASS' if code == 0 and all(o == 'Passed' for o in outcomes) else
            'FAIL' if code != 125 and 'Failed' in outcomes else 'ERROR'), log


def prove(repo, base, head):
    base = git(repo, 'rev-parse', '--verify', base + '^{commit}').decode().strip()
    head = git(repo, 'rev-parse', '--verify', head + '^{commit}').decode().strip()
    paths = git(repo, 'diff', '--name-only', '--diff-filter=AM', '--no-renames', base, head).decode().splitlines()
    tests = [(p, kind(p)) for p in paths if kind(p)]
    rows = []
    with tempfile.TemporaryDirectory(prefix='bugproof-') as tmp:
        roots = {s: Path(tmp) / s for s in ('base', 'head')}
        for side, sha in [('base', base), ('head', head)]:
            roots[side].mkdir()
            snapshot(repo, sha, roots[side])
        for path, test_kind in tests:
            content = (roots['head'] / path).read_bytes()
            row = {'test': path, 'base': 'SKIPPED', 'head': 'SKIPPED', 'verdict': 'SKIPPED', 'logs': {}}
            if sql_test(path, content.decode('utf-8-sig')):
                row['logs']['reason'] = 'SQL/env-gated test excluded; not proof.'
            else:
                target = roots['base'] / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)
                for side in roots:
                    row[side], row['logs'][side] = execute(roots[side], path, test_kind)
                row['verdict'] = 'PASS' if (row['base'], row['head']) == ('FAIL', 'PASS') else 'FAIL'
            rows.append(row)
    passed = bool(rows) and any(r['verdict'] == 'PASS' for r in rows) and all(r['verdict'] in ('PASS', 'SKIPPED') for r in rows)
    return {'base': base, 'head': head, 'verdict': 'PASS' if passed else 'FAIL', 'tests': rows}


def report(result, output):
    output.mkdir(parents=True, exist_ok=True)
    lines = ['<!-- bugproof:report -->', '# Bug proof: ' + result['verdict'], '',
             'Base: `' + result['base'] + '`; head: `' + result['head'] + '`.', '',
             '| Test | Base | Head | Verdict |', '| --- | --- | --- | --- |']
    for row in result['tests']:
        name = html.escape(row['test']).replace('|', '&#124;').replace('`', '&#96;')
        lines.append('| ' + ' | '.join([name, row['base'], row['head'], row['verdict']]) + ' |')
    if not result['tests']:
        lines.append('| No added/changed supported test | — | — | FAIL |')
    markdown = '\n'.join(lines) + '\n'
    (output / 'report.md').write_text(markdown, encoding='utf-8')
    (output / 'report.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    table = '<table><thead><tr><th>Test</th><th>Base</th><th>Head</th><th>Verdict</th></tr></thead><tbody>'
    for row in result['tests']:
        table += '<tr>' + ''.join('<td>' + html.escape(row[k]) + '</td>' for k in ('test', 'base', 'head', 'verdict')) + '</tr>'
    logs = ''.join('<h2>' + html.escape(r['test']) + '</h2><pre>' + html.escape(json.dumps(r['logs'], indent=2)) + '</pre>' for r in result['tests'])
    (output / 'report.html').write_text('<!doctype html><html lang="en"><meta charset="utf-8"><title>Bug proof</title><style>body{font:16px system-ui;margin:2rem}td,th{padding:.6rem;border:1px solid #aaa}pre{white-space:pre-wrap;overflow-wrap:anywhere}</style><h1>Bug proof: ' + result['verdict'] + '</h1><pre>' + html.escape(result['base'] + '\n' + result['head']) + '</pre>' + table + '</tbody></table>' + logs + '</html>', encoding='utf-8')
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as summary:
            summary.write(markdown)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--base', required=True)
    parser.add_argument('--head', required=True)
    parser.add_argument('--repo', type=Path, default=Path.cwd())
    parser.add_argument('--output', type=Path, default=Path('bugproof-report'))
    args = parser.parse_args()
    try:
        result = prove(args.repo, args.base, args.head)
    except (ValueError, subprocess.CalledProcessError, OSError) as exc:
        result = {'base': args.base, 'head': args.head, 'verdict': 'FAIL', 'tests': [], 'error': str(exc)}
    report(result, args.output)
    print('Bug proof:', result['verdict'])
    return 0 if result['verdict'] == 'PASS' else 1


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""Document each staged checkpoint and publish it to the approved Tony branch."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = 'Suazo-AI/Martha-Silva-Store'
BRANCH = 'Tony'
ORIGINS = {f'https://github.com/{REPOSITORY}.git',
           f'https://github.com/{REPOSITORY}', f'git@github.com:{REPOSITORY}.git'}
RECEIPTS = 'docs/progress/'
SECRET = re.compile(
    rb'-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----|'
    rb'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|'
    rb'AKIA[A-Z0-9]{16}|sk-(?:proj-)?[A-Za-z0-9_-]{24,})\b|'
    rb'(?i:Bearer\s+eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)')
SENSITIVE_PARTS = {'.local', '.wrangler', 'node_modules', '__pycache__',
                   'private-exports', 'customer-exports', 'order-exports',
                   'database-backups', 'runtime-output', '.auth'}
SENSITIVE_NAMES = {'credentials.json', 'cookies.json', 'cookies.txt',
                   'id_rsa', 'id_ed25519', 'execution-authorization.json'}
SENSITIVE_SUFFIXES = {'.pem', '.key', '.pfx', '.p12', '.cer', '.der', '.db',
                      '.sqlite', '.sqlite3', '.bak', '.log', '.trx', '.zip'}


class Blocked(Exception):
    pass


def run(args, *, cwd=None, timeout=90):
    env = os.environ.copy()
    env.update(GIT_TERMINAL_PROMPT='0', GCM_INTERACTIVE='Never',
               GH_PROMPT_DISABLED='1', GH_HOST='github.com')
    try:
        result = subprocess.run(args, cwd=cwd or ROOT, env=env,
                                capture_output=True, timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired):
        raise Blocked(f'{args[0]} unavailable or timed out; no automatic retry.') from None
    if result.returncode:
        raise Blocked(f'{args[0]} failed (exit {result.returncode}); inspect locally; output withheld.')
    return result.stdout


def git(*args):
    return run(['git', *args])


def guard():
    actual = Path(git('rev-parse', '--show-toplevel').decode().strip()).resolve()
    if actual != ROOT.resolve():
        raise Blocked('Unexpected repository root.')
    if git('symbolic-ref', '--quiet', '--short', 'HEAD').decode().strip() != BRANCH:
        raise Blocked('This hook only publishes Tony; select the approved branch.')
    for direction in ([], ['--push']):
        urls = git('remote', 'get-url', *direction, '--all', 'origin').decode().splitlines()
        if len(urls) != 1 or urls[0] not in ORIGINS:
            raise Blocked('Origin differs from the exact approved repository.')


def scan(path, data):
    parsed = PurePosixPath(path)
    parts = {part.lower() for part in parsed.parts}
    name = parsed.name.lower()
    if parsed.is_absolute() or '..' in parsed.parts or '\\' in path or any(ord(c) < 32 for c in path):
        raise Blocked('Unsafe path; no file content printed.')
    if (parts & SENSITIVE_PARTS or name in SENSITIVE_NAMES or name.startswith('.env')
            or name.startswith('.dev.vars') or parsed.suffix.lower() in SENSITIVE_SUFFIXES
            or name.endswith(('-credentials.json', '.dump.sql', '.backup.sql'))):
        raise Blocked('Sensitive filename; keep it outside the public repository.')
    if len(data) > 8 * 1024 * 1024:
        raise Blocked('File exceeds the automatic publication limit of 8 MiB.')
    if SECRET.search(data):
        raise Blocked('Potential credential detected; value withheld.')


def changes(commit=None):
    if commit:
        raw = git('diff-tree', '--no-commit-id', '--name-status', '-r', '-z',
                  '--no-renames', f'{commit}^', commit)
    else:
        raw = git('diff', '--cached', '--name-status', '-z', '--no-renames')
    values = raw.split(b'\0')
    result = []
    for index in range(0, len(values) - 1, 2):
        status = values[index].decode('ascii')
        path = values[index + 1].decode('utf-8')
        if status not in {'A', 'M', 'D', 'T'}:
            raise Blocked('Unsupported index change.')
        result.append((status, path))
    return result


def describe(rows, commit=None):
    result = []
    for status, path in rows:
        if path.startswith(RECEIPTS):
            continue
        scan(path, b'')
        oid = None
        if status != 'D':
            ref = f'{commit}:{path}' if commit else f':{path}'
            if commit:
                entry = git('ls-tree', commit, '--', path).split(b'\t', 1)[0]
            else:
                entry = git('ls-files', '--stage', '--', path).split(b'\t', 1)[0]
            if entry.split()[0] not in {b'100644', b'100755'}:
                raise Blocked('Symlink, submodule or unsupported file mode.')
            oid = git('rev-parse', ref).decode().strip()
            scan(path, git('cat-file', 'blob', oid))
        result.append({'path': path, 'change': status, 'git_blob': oid})
    return sorted(result, key=lambda item: item['path'])


def pre_commit():
    guard()
    before = git('write-tree').strip()
    rows = changes()
    files = describe(rows)
    if not files:
        raise Blocked('No ordinary file changes to document.')
    existing = [path for status, path in rows if path.startswith(RECEIPTS)]
    if existing:
        if len(existing) != 1 or ('A', existing[0]) not in rows:
            raise Blocked('Expected one generated progress receipt.')
        validate_receipt(existing[0], git('show', f':{existing[0]}'), files)
        print('Progress receipt already matches staged bytes.')
        return
    now = datetime.now(timezone.utc)
    event = {'schema': 1, 'recorded_at_utc': now.isoformat(), 'event': 'git-checkpoint',
             'branch': BRANCH, 'validation': 'NOT_RUN_BY_HOOK', 'files': files,
             'meaning': 'Recorded bytes, not product acceptance. See status and attached evidence.'}
    payload = (json.dumps(event, ensure_ascii=False, indent=2) + '\n').encode()
    suffix = hashlib.sha256(payload).hexdigest()[:10]
    relative = f'{RECEIPTS}{now:%Y%m%dT%H%M%S%fZ}-{suffix}.json'
    target = ROOT / relative
    if git('write-tree').strip() != before:
        raise Blocked('Index changed during scanning; nothing generated.')
    target.parent.mkdir(parents=True, exist_ok=True)
    with target.open('xb') as handle:
        handle.write(payload)
    git('add', '--', relative)
    print(f'Progress documented: {len(files)} staged files; checks are not implied.')


def validate_receipt(path, payload, files):
    scan(path, payload)
    event = json.loads(payload)
    if (set(event) != {'schema', 'recorded_at_utc', 'event', 'branch', 'validation', 'files', 'meaning'}
            or event.get('schema') != 1 or event.get('branch') != BRANCH
            or event.get('event') != 'git-checkpoint'
            or event.get('validation') != 'NOT_RUN_BY_HOOK' or event.get('files') != files):
        raise Blocked('Progress receipt does not match the recorded files.')
    timestamp = datetime.fromisoformat(event['recorded_at_utc'])
    if timestamp.utcoffset() is None:
        raise Blocked('Progress timestamp needs a timezone.')
    suffix = hashlib.sha256(payload).hexdigest()[:10]
    expected = f'{RECEIPTS}{timestamp:%Y%m%dT%H%M%S%fZ}-{suffix}.json'
    if path != expected:
        raise Blocked('Progress receipt filename does not match its bytes.')


def verify(commit='HEAD'):
    commit = git('rev-parse', '--verify', f'{commit}^{{commit}}').decode().strip()
    rows = changes(commit)
    receipts = [(status, path) for status, path in rows if path.startswith(RECEIPTS)]
    if len(receipts) != 1 or receipts[0][0] != 'A':
        raise Blocked('Each new commit must add exactly one progress receipt.')
    path = receipts[0][1]
    validate_receipt(path, git('show', f'{commit}:{path}'), describe(rows, commit))
    print(f'PASS: progress receipt and publication scan for {commit[:12]}.')


def publish():
    guard()
    if git('config', '--local', '--get', 'progress.autopush').strip() != b'true':
        raise Blocked('Automatic push has not been enabled locally.')
    info = json.loads(run(['gh', 'api', f'repos/{REPOSITORY}', '--jq',
                          '{full_name,private,archived}']))
    if info != {'full_name': REPOSITORY, 'private': False, 'archived': False}:
        raise Blocked('Expected active PUBLIC repository could not be confirmed.')
    expected = git('rev-parse', 'HEAD').decode().strip()
    outgoing = git('rev-list', '--reverse', f'origin/{BRANCH}..HEAD').decode().splitlines()
    for commit in outgoing:
        verify(commit)
        scan('commit-message.txt', git('show', '-s', '--format=%B', commit))
    if git('rev-parse', 'HEAD').decode().strip() != expected:
        raise Blocked('HEAD changed during scanning; publication stopped.')
    guard()
    # The authenticated helper is scoped to this one command. No token is printed.
    git('-c', 'credential.helper=', '-c', 'credential.helper=!gh auth git-credential',
        'push', '--no-force', '--no-follow-tags', '--no-mirror', 'origin', f'{expected}:refs/heads/{BRANCH}')
    remote = git('ls-remote', '--exit-code', 'origin', f'refs/heads/{BRANCH}').decode().split()[0]
    if remote != expected:
        raise Blocked('Remote readback differs from the published SHA.')
    git('update-ref', f'refs/remotes/origin/{BRANCH}', expected)
    state = {'status': 'SYNCED', 'commit': expected, 'branch': BRANCH,
             'verified_at_utc': datetime.now(timezone.utc).isoformat()}
    state_path = Path(git('rev-parse', '--git-path', 'progress-sync.json').decode().strip())
    if not state_path.is_absolute():
        state_path = ROOT / state_path
    state_path.write_text(json.dumps(state, indent=2) + '\n', encoding='utf-8')
    print(f'SYNCED: https://github.com/{REPOSITORY}/commit/{expected}')


def install():
    guard()
    previous = subprocess.run(['git', 'config', '--local', '--get', 'core.hooksPath'],
                              cwd=ROOT, capture_output=True, check=False)
    if previous.returncode not in {0, 1} or previous.stdout.strip() not in {b'', b'.githooks'}:
        raise Blocked('Existing local hooks path requires a deliberate integration.')
    git('config', '--local', 'core.hooksPath', '.githooks')
    git('config', '--local', 'progress.autopush', 'true')
    print('Installed repository-local pre-commit and post-commit hooks for Tony.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['pre-commit', 'publish', 'verify', 'install'])
    parser.add_argument('--commit', default='HEAD')
    args = parser.parse_args()
    try:
        if args.command == 'verify':
            verify(args.commit)
        else:
            {'pre-commit': pre_commit, 'publish': publish, 'install': install}[args.command]()
        return 0
    except (Blocked, ValueError, UnicodeError, OSError, TypeError, KeyError) as error:
        # Exception messages from parsers might contain input; only Blocked is safe.
        reason = str(error) if isinstance(error, Blocked) else 'Invalid structured input.'
        print(f'Progress sync BLOCKED: {reason} Local work is preserved.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())

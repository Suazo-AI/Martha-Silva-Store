#!/usr/bin/env python3
"""Opt-in, fail-closed validated publication to the private Martha Silva repo."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = 'Suazo-AI/Martha-Silva-Store'
ORIGINS = {f'https://github.com/{REPOSITORY}.git',
           f'https://github.com/{REPOSITORY}',
           f'git@github.com:{REPOSITORY}.git'}
SECRET = re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|'
                    rb'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|'
                    rb'AKIA[A-Z0-9]{16}|sk-(?:proj-)?[A-Za-z0-9_-]{24,})\b')


class Blocked(Exception):
    pass


def run(args):
    env = os.environ.copy()
    env.update(GIT_TERMINAL_PROMPT='0', GCM_INTERACTIVE='Never',
               GIT_SSH_COMMAND='ssh -oBatchMode=yes -oStrictHostKeyChecking=yes',
               GH_PROMPT_DISABLED='1', GH_HOST='github.com')
    try:
        result = subprocess.run(args, cwd=ROOT, env=env, capture_output=True,
                                timeout=300, check=False)
    except (OSError, subprocess.TimeoutExpired):
        raise Blocked('Required command unavailable or timed out; no automatic retry.') from None
    if result.returncode:
        # Do not print commands, filenames, diffs, URLs, stderr or credential output.
        raise Blocked('Command failed; check local QA/authentication/network manually.')
    return result.stdout


def git(*args):
    return run(['git', *args])


def guard_repository():
    if git('rev-parse', '--show-toplevel').decode().strip() != str(ROOT):
        raise Blocked('Unexpected repository root.')
    if git('symbolic-ref', '--quiet', '--short', 'HEAD').strip() != b'main':
        raise Blocked('Only the main branch may synchronize.')
    for direction in ([], ['--push']):
        urls = git('remote', 'get-url', *direction, '--all', 'origin').decode().splitlines()
        if len(urls) != 1 or urls[0] not in ORIGINS:
            raise Blocked('Origin must point only to the expected GitHub repository.')
    # Verify actual visibility, not an assumption derived from the repository name.
    try:
        info = json.loads(run(['gh', 'repo', 'view', REPOSITORY,
                               '--json', 'nameWithOwner,visibility']))
    except (ValueError, TypeError):
        raise Blocked('Cannot verify repository visibility.') from None
    if info.get('nameWithOwner') != REPOSITORY or info.get('visibility') != 'PRIVATE':
        raise Blocked('Expected private repository could not be verified.')


def clean():
    if git('status', '--porcelain=v1', '--untracked-files=all'):
        raise Blocked('Working tree/index must be clean, including untracked files.')


def scan(data):
    if SECRET.search(data):
        raise Blocked('Potential secret detected; publication blocked without printing it.')


def inspect_commit():
    # Scan tracked content plus outgoing patches (including removed secret text).
    for record in git('ls-tree', '-r', '-z', 'HEAD').split(b'\0'):
        if not record:
            continue
        meta, path = record.split(b'\t', 1)
        mode, kind, oid = meta.split()
        if kind != b'blob':
            raise Blocked('Submodules are not supported by this secret check.')
        name = path.decode('utf-8', errors='replace').lower().rsplit('/', 1)[-1]
        if name in ('.env', 'id_rsa', 'id_ed25519') or name.endswith(('.p12', '.pfx')):
            raise Blocked('Sensitive filename detected; publication blocked.')
        scan(git('cat-file', 'blob', oid.decode()))
    # Missing tracking ref fails closed; initialize it with a manual fetch after auth.
    scan(git('log', '--format=', '--no-ext-diff', '-p', 'origin/main..HEAD'))


def validate():
    run([sys.executable, 'tests/check.py'])


def synchronize():
    guard_repository()
    clean()
    expected = git('rev-parse', 'HEAD').strip()
    inspect_commit()
    validate()
    clean()  # QA builds may modify tracked output; never stage those implicitly.
    guard_repository()
    if git('rev-parse', 'HEAD').strip() != expected:
        raise Blocked('HEAD changed during validation.')
    git('push', '--no-force', '--no-follow-tags', '--no-mirror', 'origin', 'HEAD:main')
    print('Validated commit pushed to private origin/main.')


def progress(message, paths):
    guard_repository()
    # Do not absorb any existing staged work or unrelated modifications.
    if git('diff', '--cached', '--name-only', '-z'):
        raise Blocked('Existing staged changes must be handled separately.')
    if not paths or any(p.startswith('-') or Path(p).is_absolute() or '..' in Path(p).parts for p in paths):
        raise Blocked('Supply explicit repository-relative tracked file paths.')
    requested = set(paths)
    tracked = {p.decode() for p in git('ls-files', '-z').split(b'\0') if p}
    if not requested <= tracked:
        raise Blocked('Only exact tracked file paths are accepted; no directories or globs.')
    changed = {p.decode() for p in git('diff', '--name-only', '-z').split(b'\0') if p}
    if not changed or not changed <= requested or git('ls-files', '--others', '--exclude-standard', '-z'):
        raise Blocked('Resolve unrelated or untracked changes before committing progress.')
    for path in requested:
        file = ROOT / path
        if file.is_symlink():
            scan(os.readlink(file).encode())
        elif file.is_file():
            scan(file.read_bytes())
    scan(git('diff', '--no-ext-diff'))
    validate()
    after = {p.decode() for p in git('diff', '--name-only', '-z').split(b'\0') if p}
    if not after <= requested:
        raise Blocked('QA changed files outside the explicit selection; review manually.')
    scan(git('diff', '--no-ext-diff'))
    git('add', '--', *sorted(requested))
    git('-c', 'core.hooksPath=/dev/null', 'commit', '-m', message)
    synchronize()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--commit', metavar='MESSAGE', help='validate and commit explicit tracked paths first')
    parser.add_argument('paths', nargs='*')
    args = parser.parse_args(argv)
    try:
        if args.commit:
            progress(args.commit, args.paths)
        elif args.paths:
            raise Blocked('Paths require --commit.')
        else:
            synchronize()
        return 0
    except Blocked as error:
        print(f'Auto-sync blocked: {error} Any existing commit is preserved.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())

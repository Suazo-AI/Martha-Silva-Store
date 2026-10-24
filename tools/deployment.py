#!/usr/bin/env python3
"""Stamp/verify a same-run artifact; read-only HTTP smoke checks of that release."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import time
from urllib.error import HTTPError
from urllib.parse import urlparse
from urllib.request import urlopen

MARKER = 'deployment.json'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def inventory(root):
    return {p.relative_to(root).as_posix(): digest(p.read_bytes())
            for p in sorted(root.rglob('*')) if p.is_file() and p.name != MARKER}


def verify(root, sha):
    data = json.loads((root / MARKER).read_text())
    if data != {'sha': sha, 'files': inventory(root)}:
        raise ValueError('Artifact SHA or file inventory mismatch')
    return data


def smoke(root, sha, base):
    parsed = urlparse(base)
    if (parsed.scheme != 'https' or parsed.port is not None or parsed.username or
            not re.fullmatch(r'martha-silva-preview\.[a-z0-9-]+\.workers\.dev', parsed.hostname or '') or
            parsed.path not in ('', '/') or parsed.query or parsed.fragment):
        raise ValueError('Expected the new martha-silva-preview workers.dev URL only')
    data = verify(root, sha)
    base = base.rstrip('/')
    for attempt in range(6):
        try:
            with urlopen(base + '/' + MARKER, timeout=20) as response:
                if json.load(response) != data:
                    raise ValueError('Remote release marker differs')
            for name in ('', 'index.html', 'catalogo.html', 'styles.css', 'app.js', 'demo-api.js'):
                with urlopen(base + '/' + name, timeout=20) as response:
                    if digest(response.read()) != data['files'][name or 'index.html']:
                        raise ValueError('Remote bytes differ: ' + name)
            try:
                urlopen(base + '/__missing_release_check__', timeout=20)
            except HTTPError as error:
                if error.code != 404:
                    raise
            else:
                raise ValueError('Missing asset did not return 404')
            print('PASS: remote release SHA, home page, 5 asset hashes and missing-path 404')
            return
        except HTTPError as error:
            if error.code in (401, 403) or attempt == 5:
                raise
            time.sleep(10)
        except (OSError, ValueError):
            if attempt == 5:
                raise
            time.sleep(10)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['stamp', 'verify', 'smoke'])
    parser.add_argument('--directory', type=Path, required=True)
    parser.add_argument('--sha', required=True)
    parser.add_argument('--url')
    args = parser.parse_args()
    if not re.fullmatch('[0-9a-f]{40}', args.sha):
        raise ValueError('Expected full Git SHA')
    if args.mode == 'stamp':
        (args.directory / MARKER).write_text(json.dumps(
            {'sha': args.sha, 'files': inventory(args.directory)}, sort_keys=True) + '\n')
    elif args.mode == 'verify':
        verify(args.directory, args.sha)
    else:
        smoke(args.directory, args.sha, args.url or '')


if __name__ == '__main__':
    main()

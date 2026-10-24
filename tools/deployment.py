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
from urllib.request import HTTPRedirectHandler, build_opener

MARKER = 'deployment.json'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def inventory(root):
    if root.is_symlink() or not root.is_dir():
        raise ValueError('Expected a real artifact directory')
    files = {}
    for path in sorted(root.rglob('*')):
        name = path.relative_to(root).as_posix()
        if (path.is_symlink() or '\\' in name or
                any(ord(character) < 32 or ord(character) == 127 for character in name)):
            raise ValueError('Unsafe artifact path: ' + repr(name))
        if path.is_dir():
            continue
        if not path.is_file():
            raise ValueError('Non-regular artifact path: ' + repr(name))
        if name != MARKER:
            files[name] = digest(path.read_bytes())
    return files


def verify(root, sha):
    files = inventory(root)  # Reject symlinks, including the marker, before reading it.
    data = json.loads((root / MARKER).read_text())
    if data != {'sha': sha, 'files': files}:
        raise ValueError('Artifact SHA or file inventory mismatch')
    return data


def validate_preview_url(base):
    # Full-string validation rejects credentials, ports, whitespace/control bytes,
    # paths, queries and fragments before urllib can normalize them away.
    if not re.fullmatch(r'https://martha-silva-preview\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.workers\.dev/?', base):
        raise ValueError('Expected the new martha-silva-preview workers.dev URL only')
    return base.rstrip('/')


class UnsafeRedirect(ValueError):
    """A redirect outside the approved HTTPS origin must never be requested."""


class SameOriginRedirectHandler(HTTPRedirectHandler):
    def __init__(self, base):
        self.hostname = urlparse(base).hostname

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        try:
            parsed = urlparse(newurl)
            safe = (parsed.scheme == 'https' and parsed.hostname == self.hostname and
                    parsed.port in (None, 443) and parsed.username is None and
                    parsed.password is None and not any(ord(c) < 32 or ord(c) == 127 for c in newurl))
        except ValueError:
            safe = False
        if not safe:
            raise UnsafeRedirect('Refusing redirect outside the approved preview origin')
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def smoke(root, sha, base):
    base = validate_preview_url(base)
    data = verify(root, sha)
    opener = build_opener(SameOriginRedirectHandler(base))
    for attempt in range(6):
        try:
            with opener.open(base + '/' + MARKER, timeout=20) as response:
                if json.load(response) != data:
                    raise ValueError('Remote release marker differs')
            for name in ('', 'index.html', 'catalogo.html', 'styles.css', 'app.js', 'demo-api.js'):
                with opener.open(base + '/' + name, timeout=20) as response:
                    if digest(response.read()) != data['files'][name or 'index.html']:
                        raise ValueError('Remote bytes differ: ' + name)
            try:
                opener.open(base + '/__missing_release_check__', timeout=20)
            except HTTPError as error:
                if error.code != 404:
                    raise
            else:
                raise ValueError('Missing asset did not return 404')
            print('PASS: remote release SHA, home page, 5 asset hashes and missing-path 404')
            return
        except UnsafeRedirect:
            raise
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
    parser.add_argument('mode', choices=['stamp', 'verify', 'smoke', 'validate-url'])
    parser.add_argument('--directory', type=Path)
    parser.add_argument('--sha')
    parser.add_argument('--url')
    args = parser.parse_args()
    if args.mode == 'validate-url':
        validate_preview_url(args.url or '')
        return
    if args.directory is None:
        parser.error('--directory is required for artifact operations')
    if not re.fullmatch('[0-9a-f]{40}', args.sha or ''):
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

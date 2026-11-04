#!/usr/bin/env python3
"""Copy only hash-bound, previously scanned evidence to a fresh publication directory.

This is a publication guard, not proof that unknown secrets cannot exist. The harness
must first scan its runtime passwords, cookies and CSRF values before writing its marker.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path

FILES = ('evidence.json', 'oracles.md')


def publish(source, destination):
    source, destination = Path(source), Path(destination)
    if source.resolve() == destination.resolve():
        raise ValueError('publication directory must be separate')
    # An old publication must not survive a failed verification. Only our two files.
    destination.mkdir(parents=True, exist_ok=True)
    for name in FILES:
        (destination / name).unlink(missing_ok=True)
    marker = source / 'evidence-approved'
    if marker.is_symlink():
        raise ValueError('invalid approval marker')
    manifest = json.loads(marker.read_text(encoding='utf-8'))
    if manifest.get('schema') != 1 or set(manifest.get('files', {})) != set(FILES):
        raise ValueError('invalid approval manifest')
    approved = {}
    known = [os.environ.get(k, '') for k in
             ('MARTHA_TEST_SQL_CONNECTION', 'SQLCMDPASSWORD', 'MSSQL_SA_PASSWORD')]
    for name in FILES:
        path = source / name
        if path.is_symlink():
            raise ValueError('invalid evidence file')
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != manifest['files'][name]:
            raise ValueError('evidence changed after scan')
        text = data.decode('utf-8')
        if any(secret and secret in text for secret in known):
            raise ValueError('known secret in evidence')
        approved[name] = data
    # Write the bytes actually checked, never re-read the source after validation.
    for name, data in approved.items():
        (destination / name).write_bytes(data)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--destination', required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        publish(args.source, args.destination)
    except Exception:
        # Exception strings, paths and file contents may contain values: never echo them.
        print('Evidence publication refused: approval or content verification failed.')
        return 1
    print('Evidence publication verified (known-secret scan and exact-byte manifest).')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())

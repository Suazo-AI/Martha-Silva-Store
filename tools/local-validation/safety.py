"""Fail-closed primitives for the disposable runner. No implicit external calls."""
import hashlib
import io
import json
import os
import re
import stat
import tarfile
import time
from pathlib import Path, PurePosixPath


class SafetyError(Exception):
    pass


class Deadline:
    def __init__(self, seconds, clock=time.monotonic):
        self.clock = clock
        self.end = clock() + seconds

    def left(self, cap=None):
        value = self.end - self.clock()
        if value <= 0:
            raise SafetyError('absolute deadline exhausted')
        return min(value, cap) if cap is not None else value

    def call(self, transport, args, **kwargs):
        cap = kwargs.pop('timeout', None)
        result = transport.call(args, timeout=self.left(cap), **kwargs)
        self.left()
        return result


def linked(path):
    s = path.lstat()
    return stat.S_ISLNK(s.st_mode) or bool(getattr(s, 'st_file_attributes', 0) & 0x400)


def private_directory(path, acl_reader=None, windows=None):
    """Check existing directory identity and confidentiality; never change its ACL."""
    path = Path(os.path.abspath(path))
    for item in (path, *path.parents):
        if linked(item):
            raise SafetyError('private directory has link/reparse ancestor')
    s = path.stat()
    if not stat.S_ISDIR(s.st_mode):
        raise SafetyError('private destination is not a directory')
    if windows if windows is not None else os.name == 'nt':
        if acl_reader is None:
            raise SafetyError('Windows protected DACL/identity inspection unavailable')
        acl = acl_reader(path)
        # Reader must resolve current token SID and effective rules, not display names.
        allowed = {acl['currentSid'], 'S-1-5-18', 'S-1-5-32-544'}
        if acl['ownerSid'] not in allowed or not acl['protected'] or not acl['rules']:
            raise SafetyError('private directory owner/DACL not protected')
        if any(r['inherited'] or r['sid'] not in allowed for r in acl['rules']):
            raise SafetyError('private directory has insecure/inherited ACE')
    elif s.st_uid != os.getuid() or stat.S_IMODE(s.st_mode) & 0o077:
        raise SafetyError('private directory owner/mode is insecure')
    return (s.st_dev, s.st_ino)


def safe_name(name):
    p = PurePosixPath(name)
    if (not name or '\\' in name or ':' in name or p.is_absolute()
            or '..' in p.parts or name.startswith('//') or '.git' in p.parts):
        raise SafetyError('unsafe public path')
    if p.parts and (p.parts[0] in ('private-exports', 'customer-exports', 'order-exports', 'database-backups')
                    or any(part == '.env' or part.startswith('.env.') and not part.endswith('.example') for part in p.parts)):
        raise SafetyError('private path in public export')
    return p


def extract(archive, destination, files):
    """Only explicit regular/directory members into a newly created, non-link root."""
    if not hasattr(tarfile, 'data_filter'):
        raise SafetyError('safe tar extraction unavailable')
    if destination.exists() or destination.is_symlink():
        raise SafetyError('export destination must be fresh')
    for p in (destination.parent, *destination.parent.parents):
        if linked(p):
            raise SafetyError('export ancestor is link/reparse')
    seen = set()
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:') as tar:
        members = tar.getmembers()
        for m in members:
            p = safe_name(m.name)
            if (m.type not in (tarfile.REGTYPE, tarfile.AREGTYPE, tarfile.DIRTYPE)
                    or m.sparse is not None or any('sparse' in k.lower() for k in m.pax_headers)):
                raise SafetyError('archive link/special/sparse member')
            if m.name in seen:
                raise SafetyError('duplicate archive member')
            seen.add(m.name)
            if m.isfile():
                if m.name not in files:
                    raise SafetyError('archive file outside public allowlist')
                if hashlib.sha256(tar.extractfile(m).read()).hexdigest() != files[m.name]:
                    raise SafetyError('archive hash mismatch')
            elif not any(PurePosixPath(f).is_relative_to(p) for f in files):
                raise SafetyError('archive directory outside allowlist')
        if {m.name for m in members if m.isfile()} != set(files):
            raise SafetyError('public file missing')
        destination.mkdir(mode=0o700)
        tar.extractall(destination, members=members, filter='data')
    return destination


class Ownership:
    def __init__(self, transport, nonce, scope):
        self.transport, self.nonce, self.scope = transport, nonce, scope
        self.receipts = []
        self.ambiguous = []

    @property
    def labels(self):
        return ['--label', 'savia.run=' + self.nonce, '--label', 'savia.scope=' + self.scope]

    def inspect(self, kind, ident, deadline):
        r = deadline.call(self.transport, [kind, 'inspect', ident], check=False)
        if r.returncode:
            return None
        rows = json.loads(r.stdout)
        if len(rows) != 1:
            raise SafetyError('ambiguous resource inspection')
        return rows[0]

    def verify(self, kind, ident, name, deadline):
        row = self.inspect(kind, ident, deadline)
        if row is None:
            raise SafetyError('resource identity unknown')
        actual = row.get('Id', row.get('Name'))
        labels = row.get('Config', {}).get('Labels', row.get('Labels', {})) or {}
        if (actual != ident or row.get('Name', '').lstrip('/') != name
                or labels.get('savia.run') != self.nonce or labels.get('savia.scope') != self.scope):
            raise SafetyError('resource ownership mismatch')
        # Name replacement cannot redirect an ID operation. Check it too before dispatch.
        byname = self.inspect(kind, name, deadline)
        if byname is None or byname.get('Id', byname.get('Name')) != ident:
            raise SafetyError('resource name replaced')
        return ident

    def create(self, kind, name, args, deadline):
        # Atomic creates must reject an existing name. Docker volume create is adoptive:
        # use a freshly random name and record ambiguity; never delete without receipt.
        if self.inspect(kind, name, deadline) is not None:
            raise SafetyError('resource collision')
        try:
            r = deadline.call(self.transport, args)
            ident = r.stdout.strip()
            if not ident:
                raise SafetyError('creation receipt missing')
            self.verify(kind, ident, name, deadline)
            self.receipts.append((kind, ident, name))
            return ident
        except Exception:
            self.ambiguous.append((kind, name))
            raise

    def cleanup(self, clock=time.monotonic):
        outcomes = []
        # Each resource gets an independent slice; one transport failure cannot skip others.
        for kind, ident, name in reversed(self.receipts):
            d = Deadline(20, clock)
            state = 'unknown'
            try:
                self.verify(kind, ident, name, d)
                args = [kind, 'rm'] + (['--force', '--volumes'] if kind == 'container' else []) + [ident]
                d.call(self.transport, args, check=False)
                args = [kind, 'ls'] + (['--all'] if kind == 'container' else []) + ['--format', '{{json .}}']
                r = d.call(self.transport, args, check=False)
                if r.returncode == 0:
                    rows = [json.loads(line) for line in r.stdout.splitlines() if line.strip()]
                    state = 'present' if any(x.get('ID') == ident or x.get('Name', x.get('Names')) == name for x in rows) else 'absent'
            except Exception:
                pass
            outcomes.append({'kind': kind, 'id': ident, 'name': name, 'state': state})
        for kind, name in self.ambiguous:
            outcomes.append({'kind': kind, 'name': name, 'state': 'unknown', 'reason': 'ambiguous creation; no deletion authority'})
        return outcomes

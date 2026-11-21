#!/usr/bin/env python3
"""Fail-closed, source-bound SAVIA local runner. Default is offline preparation report.
No image build/pull is performed. A separately approved immutable image receipt is required.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
import os
import re
import secrets
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

HELPERS = Path(__file__).parent / 'local-validation'
sys.path.insert(0, str(HELPERS))
from safety import Deadline, Ownership, SafetyError, extract, private_directory, safe_name

SDK_IMAGE = 'mcr.microsoft.com/dotnet/sdk@sha256:747cbade5bfd918a175ac32f8f1d931edec2c7d0d5397a3de72eaef1ac1f66d2'
SQL_IMAGE = 'mcr.microsoft.com/mssql/server@sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718'
PLATFORM = 'linux/amd64'
PREP_BUDGET, C_BUDGET, D_BUDGET, E_BUDGET = 900, 1500, 1200, 900
REQUIRED = ('tools/run_local_validation.py', 'tools/local-validation/safety.py',
 'tools/local-validation/evidence_gate.py', 'tools/local-validation/Dockerfile',
 'tools/local-validation/run-stage.sh', 'docs/local-validation-20261106/PARTITIONS.json',
 'backend/tests/verify_full_suite.py', 'tests/golden-path/golden_path.py',
 'tests/golden-path/verify_evidence.py', 'backend/tests/Martha.Store.Api.Tests/PrivatePilotReleaseTests.cs')
RuntimeFailure = SafetyError

@dataclass(frozen=True)
class Config:
    repo: Path
    source_sha: str
    scope: str
    private: Path
    binding: Path
    image_receipt: Path

class Transport:
    """Only explicit execution reaches this adapter; tests replace it before any call."""
    def call(self, args, timeout, check=True, env=None):
        try:
            r = subprocess.run(['docker', *args], capture_output=True, text=True,
                               timeout=timeout, env=env)
        except subprocess.TimeoutExpired as e:
            # Preserve output for protected retention without putting it in messages.
            raise TransportFailure('transport timeout', e.stdout, e.stderr) from e
        if check and r.returncode:
            raise TransportFailure('transport nonzero exit', r.stdout, r.stderr)
        return r

class TransportFailure(SafetyError):
    def __init__(self, message, stdout=None, stderr=None):
        super().__init__(message)
        self.stdout, self.stderr = stdout, stderr

def expected_scope(sha):
    return 'savia-local-runtime-' + sha[:12]

def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()

def git(config, args, deadline):
    r = subprocess.run(['git', '-C', str(config.repo), *args], capture_output=True,
                       timeout=deadline.left())
    deadline.left()
    if r.returncode:
        raise SafetyError('Git source verification failed')
    return r.stdout

def preparation(config, deadline, git_read=git):
    """No Docker or secret writes. Binding and receipt are explicit reviewed inputs."""
    if not re.fullmatch('[a-f0-9]{40}', config.source_sha or ''):
        raise SafetyError('explicit reviewed integrated 40-hex SHA required')
    if config.scope != expected_scope(config.source_sha):
        raise SafetyError('scope does not match source')
    if git_read(config, ['rev-parse', 'HEAD'], deadline).decode().strip() != config.source_sha:
        raise SafetyError('HEAD differs from reviewed integrated SHA')
    if git_read(config, ['status', '--porcelain', '--untracked-files=all'], deadline).strip():
        raise SafetyError('uncommitted candidate refused')
    binding = json.loads(config.binding.read_text(encoding='utf-8'))
    files = binding.get('files', {})
    if binding.get('sourceSha') != config.source_sha or not set(REQUIRED) <= set(files):
        raise SafetyError('reviewed public-file allowlist incomplete or wrong source')
    for name, sha in files.items():
        safe_name(name)
        if not re.fullmatch('[a-f0-9]{64}', sha):
            raise SafetyError('malformed public-file hash')
        blob = git_read(config, ['show', config.source_sha + ':' + name], deadline)
        if hashlib.sha256(blob).hexdigest() != sha:
            raise SafetyError('public-file binding mismatch')
    for relative, actual in (('tools/run_local_validation.py', Path(__file__)),
                             ('tools/local-validation/safety.py', HELPERS / 'safety.py')):
        if hashlib.sha256(actual.read_bytes().replace(b'\r\n', b'\n')).hexdigest() != files[relative]:
            raise SafetyError('executing runner/helper differs from reviewed source')
    receipt = json.loads(config.image_receipt.read_text(encoding='utf-8'))
    if (receipt.get('sourceSha') != config.source_sha or receipt.get('filesDigest') != digest(files)
            or receipt.get('sdkImage') != SDK_IMAGE or receipt.get('sqlImage') != SQL_IMAGE
            or receipt.get('qualification') != 'passed' or not receipt.get('qualificationEvidenceSha256')
            or receipt.get('unresolved') != [] or not receipt.get('approvedBy')
            or not re.fullmatch('sha256:[a-f0-9]{64}', receipt.get('imageId', ''))):
        raise SafetyError('approved source-bound image qualification receipt missing/incomplete')
    deps = receipt.get('dependencies', {})
    if not all(deps.get(k) for k in ('packages', 'checksums', 'provenance', 'integrity', 'licenses', 'trust', 'network')):
        raise SafetyError('dependency/provenance preparation incomplete')
    safe_name(receipt['qualificationEvidenceFile'])
    proof_path = config.image_receipt.parent / receipt['qualificationEvidenceFile']
    proof_bytes = proof_path.read_bytes()
    if hashlib.sha256(proof_bytes).hexdigest() != receipt['qualificationEvidenceSha256']:
        raise SafetyError('image qualification evidence hash mismatch')
    proof = json.loads(proof_bytes)
    if (proof.get('imageId') != receipt['imageId'] or proof.get('sourceSha') != config.source_sha
            or proof.get('filesDigest') != digest(files) or proof.get('status') != 'passed'
            or not all(proof.get('checks', {}).get(k) is True for k in
                       ('downloadIntegrity', 'dependencyClosure', 'publisherTrust', 'licenses',
                        'chromePlaywright', 'sdk', 'python', 'node', 'nonroot', 'sourceBuild'))):
        raise SafetyError('image qualification evidence incomplete')
    # Never build from the working tree. A future authorized build uses the same export.
    return files, receipt

def windows_acl(path, timeout=10):
    # Literal path passes through an environment variable; no shell interpolation.
    script = '''$a=Get-Acl -LiteralPath $env:SAVIA_ACL_TARGET -ErrorAction Stop;
$s=[System.Security.Principal.SecurityIdentifier];
@{currentSid=[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value;
ownerSid=$a.GetOwner($s).Value; protected=$a.AreAccessRulesProtected;
rules=@($a.GetAccessRules($true,$true,$s)|ForEach-Object {@{sid=$_.IdentityReference.Value;inherited=$_.IsInherited}})}|ConvertTo-Json -Depth 4 -Compress'''
    env = os.environ.copy(); env['SAVIA_ACL_TARGET'] = str(path)
    r = subprocess.run(['powershell', '-NoProfile', '-NonInteractive', '-Command', script],
                       capture_output=True, text=True, timeout=timeout, env=env)
    if r.returncode:
        raise SafetyError('Windows ACL read failed')
    return json.loads(r.stdout)

class PrivateStore:
    def __init__(self, root, checker=None, deadline=None):
        self.root = root
        self.deadline = deadline or Deadline(20)
        self.checker = checker or (lambda p: private_directory(p, lambda item: windows_acl(item, self.deadline.left(10))))
        self.identity = self.checker(root)
        if any(root.iterdir()):
            raise SafetyError('private directory must already exist, protected and empty')
    def check(self):
        self.deadline.left()
        if self.checker(self.root) != self.identity:
            raise SafetyError('private directory identity changed')
    def directory(self, relative):
        self.check()
        if relative != '.': safe_name(relative)
        p = self.root
        for component in Path(relative).parts:
            p = p / component
            from safety import linked
            if p.exists() or p.is_symlink():
                if linked(p) or not p.is_dir():
                    raise SafetyError('private destination link/reparse')
            else:
                p.mkdir(mode=0o700)
            if linked(p):
                raise SafetyError('private destination link/reparse')
        return p
    def write(self, relative, content):
        self.check()
        p = self.directory(str(Path(relative).parent)) / Path(relative).name
        # Exclusive creation prevents following a preexisting destination link.
        with p.open('xb') as out:
            out.write(content.encode() if isinstance(content, str) else content)
        self.deadline.left()

    def publish_result(self, result):
        """Only result.json is authoritative; a pending file is never acceptance."""
        self.check()
        pending = self.root / 'result.pending.json'
        target = self.root / 'result.json'
        content = (json.dumps(result, indent=2) + '\n').encode()
        with pending.open('xb') as out:
            info = os.fstat(out.fileno())
            identity = (info.st_dev, info.st_ino)
            if out.write(content) != len(content):
                raise SafetyError('short result write')
        # Closing/flushing and the budget/privacy checks all precede publication.
        self.check()
        from safety import linked
        info = pending.lstat()
        if linked(pending) or (info.st_dev, info.st_ino) != identity:
            raise SafetyError('pending result identity changed')
        try:
            # A hard link publishes the closed file atomically without overwriting
            # an existing destination. Unsupported filesystems fail closed.
            os.link(pending, target)
            self.deadline.left()
        except BaseException:
            # The commit operation itself can complete before raising/expiring.
            # Invalidate only our exact inode in the still-protected directory.
            self.deadline = Deadline(5, self.deadline.clock)
            self.check()
            try:
                info = target.lstat()
            except FileNotFoundError:
                pass
            else:
                if not linked(target) and (info.st_dev, info.st_ino) == identity:
                    target.unlink()
            raise

def load_gate(source):
    spec = importlib.util.spec_from_file_location('savia_evidence_gate', source / 'tools/local-validation/evidence_gate.py')
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m

def execute(config, transport, *, clock=time.monotonic, git_read=git, privacy=None):
    owned = Ownership(transport, secrets.token_hex(16), config.scope)
    store = None; failure = None; outcomes = []; retained = []
    interruption = None; interrupted_error = None
    stage = 'preparation'
    prep = Deadline(PREP_BUDGET, clock)
    runner = sql = None
    image_id = None
    try:
        files, receipt = preparation(config, prep, git_read)
        store = PrivateStore(config.private, privacy, prep)
        archive = git_read(config, ['archive', '--format=tar', config.source_sha, '--', *files], prep)
        source = extract(archive, config.private / 'source', files)
        prep.left()
        image_id = receipt['imageId']
        image = prep.call(transport, ['image', 'inspect', image_id])
        obj = json.loads(image.stdout)[0]
        if obj['Id'] != image_id or obj.get('Os') != 'linux' or obj.get('Architecture') != 'amd64':
            raise SafetyError('immutable runner image mismatch')
        # Cached SQL presence is insufficient; explicitly bind immutable SQL and SDK too.
        for ref in (SQL_IMAGE, SDK_IMAGE):
            prep.call(transport, ['image', 'inspect', ref])
        nonce = owned.nonce
        netname = 'savia-net-' + nonce
        sqlname, runname = 'savia-sql-' + nonce, 'savia-runner-' + nonce
        network = owned.create('network', netname, ['network', 'create', '--driver', 'bridge', *owned.labels, netname], prep)
        password = 'Aa1!' + secrets.token_hex(24)
        connection = 'Server=sql,1433;Database=master;User ID=sa;Password=' + password + ';Encrypt=true;TrustServerCertificate=true;Connect Timeout=5;Pooling=false'
        # Secrets go only in child environment, never host env files or argv values.
        env = {'MSSQL_SA_PASSWORD': password}
        def create_container(name, args, variables):
            # Same ownership contract; environment is supplied only for this child.
            class EnvTransport:
                def call(self, argv, **kw):
                    if argv[0] == 'run': kw['env'] = {**os.environ, **variables}
                    return transport.call(argv, **kw)
            original = owned.transport; owned.transport = EnvTransport()
            try: return owned.create('container', name, args, prep)
            finally: owned.transport = original
        sql = create_container(sqlname, ['run', '-d', '--name', sqlname, *owned.labels, '--platform', PLATFORM,
            '--network', network, '--network-alias', 'sql', '--memory', '4g', '--cpus', '2',
            '--env', 'ACCEPT_EULA=Y', '--env', 'MSSQL_PID=Developer', '--env', 'MSSQL_SA_PASSWORD', SQL_IMAGE], env)
        ready(transport, sql, password, prep)
        variables = {k: connection for k in ('MARTHA_TEST_SQL_CONNECTION', 'MARTHA_INTERNAL_TEST_SQL_CONNECTION', 'SAVIA_INTERNAL_TEST_SQL_CONNECTION')}
        variables.update(SAVIA_INTERNAL_SQL_TESTS_AUTHORIZED='1', SAVIA_INTERNAL_HTTP_SQL_TESTS_AUTHORIZED='1',
                         SAVIA_PILOT_EVIDENCE='/work/evidence/e/pilot', HOME='/home/savia',
                         SAVIA_SOURCE_SHA=config.source_sha, SAVIA_RUN_NONCE=nonce)
        runner = create_container(runname, ['run', '-d', '--name', runname, *owned.labels, '--platform', PLATFORM,
            '--network', network, '--memory', '4g', '--cpus', '2',
            '--mount', f'type=bind,source={source},target=/source,readonly',
            *[arg for k in variables for arg in ('--env', k)], image_id], variables)
        run_stage(transport, store, runner, 'build', prep)
        prep.left()
        stage = 'C'; c = Deadline(C_BUDGET, clock)
        store.deadline = c
        run_stage(transport, store, runner, 'c1', c)
        run_stage(transport, store, runner, 'crest', c)
        c.left()
        stage = 'D'; store.deadline = Deadline(D_BUDGET, clock)
        run_stage(transport, store, runner, 'd', store.deadline)
        store.deadline.left()
        stage = 'E'; e = Deadline(E_BUDGET, clock)
        store.deadline = e
        run_stage(transport, store, runner, 'e-release', e)
        target = store.directory('evidence/e')
        e.call(transport, ['cp', runner + ':/work/evidence/e/.', str(target)])
        database = load_gate(source).release(target, source, config.source_sha, nonce)
        e.left()
        owned.verify('container', sql, sqlname, e)
        e.call(transport, ['stop', '--time', '10', sql])
        owned.verify('container', sql, sqlname, e)
        e.call(transport, ['start', sql])
        ready(transport, sql, password, e)
        run_stage(transport, store, runner, 'e-restart', e, {'SAVIA_PILOT_PERSIST_DATABASE': database})
    except BaseException as error:
        failure = {'stage': stage, 'type': type(error).__name__}
        if not isinstance(error, Exception):
            interruption = failure.copy(); interrupted_error = error
        # Do not expose exception strings: arbitrary transport/filesystem data can contain secrets.
        if store:
            store.deadline = Deadline(20, clock)
            try:
                def dec(v): return v.decode(errors='replace') if isinstance(v, bytes) else (v or '')
                store.write('logs/failure-output.log', dec(getattr(error, 'stdout', None)) + dec(getattr(error, 'stderr', None)))
            except BaseException as error:
                if not isinstance(error, Exception) and interrupted_error is None:
                    interruption = {'stage': 'failure-retention', 'type': type(error).__name__}; interrupted_error = error
    finally:
        # Independent bounded retention attempts, then independent cleanup slices (<=80 seconds).
        if store:
            store.deadline = Deadline(60, clock)
            jobs = []
            if runner: jobs.append(('evidence', ['cp', runner + ':/work/evidence/.', str(config.private / 'retained')]))
            for ident, label in ((runner, 'runner'), (sql, 'sql')):
                if ident: jobs.append((label, ['logs', ident]))
            for label, args in jobs:
                try:
                    store.check()
                    if label == 'evidence': store.directory('retained')
                    r = Deadline(20, clock).call(transport, args, check=False)
                    if label != 'evidence': store.write('logs/' + label + '.log', (r.stdout or '') + (r.stderr or ''))
                    retained.append({'item': label, 'ok': r.returncode == 0})
                except BaseException as error:
                    retained.append({'item': label, 'ok': False})
                    if not isinstance(error, Exception) and interrupted_error is None:
                        interruption = {'stage': 'retention', 'type': type(error).__name__}; interrupted_error = error
        try:
            outcomes = owned.cleanup(clock)
        except BaseException as error:
            outcomes = owned.cleanup_outcomes
            if failure is None: failure = {'stage': 'cleanup', 'type': type(error).__name__}
            if not isinstance(error, Exception) and interrupted_error is None:
                interruption = {'stage': 'cleanup', 'type': type(error).__name__}; interrupted_error = error
        if interruption is not None and failure is None: failure = interruption.copy()
        result = {'status': 'FAILED' if failure or any(x['state'] != 'absent' for x in outcomes) or any(not x['ok'] for x in retained) else 'PASS',
                  'failure': failure, 'interruption': interruption, 'cleanup': outcomes, 'retention': retained,
                  'image': {'id': image_id, 'action': 'retained prequalified shared image; no owned tag/build'}, 'nonce': owned.nonce}
        if store:
            store.deadline = Deadline(20, clock)
            try: store.publish_result(result)
            except BaseException as error:
                result['status'] = 'FAILED'
                if result['failure'] is None:
                    result['failure'] = {'stage': 'receipt', 'type': type(error).__name__}
                if not isinstance(error, Exception) and interrupted_error is None:
                    result['interruption'] = {'stage': 'receipt', 'type': type(error).__name__}
                    interrupted_error = error
    if interrupted_error is not None: raise interrupted_error
    return result

def ready(transport, sql, password, deadline):
    env = {**os.environ, 'SQLCMDPASSWORD': password}
    query = "IF CONVERT(int,SERVERPROPERTY('ProductMajorVersion')) <> 16 THROW 51000,'Expected SQL2022',1; IF CONVERT(nvarchar(128),SERVERPROPERTY('Edition')) NOT LIKE 'Developer%' THROW 51001,'Expected Developer',1;"
    while True:
        r = deadline.call(transport, ['exec', '--env', 'SQLCMDPASSWORD', sql, '/opt/mssql-tools18/bin/sqlcmd', '-S', 'localhost', '-U', 'sa', '-C', '-l', '2', '-t', '3', '-b', '-Q', query], timeout=10, check=False, env=env)
        if r.returncode == 0: return
        # No campaign retry; only bounded readiness polling.
        time.sleep(min(1, deadline.left()))

def run_stage(transport, store, runner, stage, deadline, extra=None):
    args = ['exec']
    for k, v in (extra or {}).items(): args += ['--env', k + '=' + v]
    args += [runner, 'timeout', '--signal=TERM', str(deadline.left()), 'bash', '/source/tools/local-validation/run-stage.sh', stage]
    r = deadline.call(transport, args, check=False)
    store.write('logs/stage-' + stage + '.log', (r.stdout or '') + (r.stderr or ''))
    deadline.left()
    if r.returncode: raise SafetyError('stage failed')

def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--execute', action='store_true')
    p.add_argument('--source-sha', required=True)
    p.add_argument('--scope')
    p.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[1])
    p.add_argument('--private-dir', type=Path, required=True)
    p.add_argument('--binding', type=Path, required=True)
    p.add_argument('--image-receipt', type=Path, required=True)
    a = p.parse_args(argv)
    c = Config(a.repo, a.source_sha, a.scope or expected_scope(a.source_sha), a.private_dir, a.binding, a.image_receipt)
    if not a.execute:
        try:
            preparation(c, Deadline(PREP_BUDGET))
            print('PREPARED_INPUTS_ONLY: no engine/image/runtime qualification readback performed')
        except Exception as e: print('PREPARATION_INCOMPLETE: ' + type(e).__name__)
        return 1
    if not a.scope: return 2
    r = execute(c, Transport())
    print(r['status'])
    return 0 if r['status'] == 'PASS' else 1

if __name__ == '__main__':
    raise SystemExit(main())

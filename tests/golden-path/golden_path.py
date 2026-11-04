#!/usr/bin/env python3
"""Arnés del camino dorado (C5): API real + SQL Server desechable + oráculos SQL.

Uso:  python3 tests/golden-path/golden_path.py --out DIR [--mode smoke|serve] [--no-build]
Requiere MARTHA_TEST_SQL_CONNECTION (servidor desechable; la base indicada se ignora).
Solo biblioteca estándar de Python y el SDK .NET fijado en global.json. Linux/macOS (usa pty).

Nunca escribe en la salida ni en la evidencia: contraseñas, cookies, tokens CSRF ni la conexión.
Ver tests/golden-path/README.md.
"""
import argparse
import fcntl
import http.client
import json
import os
import pty
import re
import secrets
import select
import shutil
import signal
import socket
import ssl
import subprocess
import sys
import tempfile
import termios
import time
import tty
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
API_PROJECT = ROOT / 'backend/src/Martha.Store.Api'
HELPER_PROJECT = ROOT / 'tests/golden-path/GoldenPath.Sql'
DATABASE_PATTERN = re.compile(r'\ASaviaInternalTest_Golden_[a-f0-9]{32}\Z')
EXPECTED_MIGRATIONS = 2  # 20261025085402_InitialInternalSavia, 20261027224500_InternalBranchScope
SEED_STOCK = 10
SALE_QUANTITY = 2
ITEMS = [('SINTETICO-GOLDEN-01', 'SINTETICO Golden artículo 1', 1250),
         ('SINTETICO-GOLDEN-02', 'SINTETICO Golden artículo 2', 3400),
         ('SINTETICO-GOLDEN-03', 'SINTETICO Golden artículo 3', 990)]
ROLES = ['Owner', 'Manager', 'Cashier', 'Inventory', 'Unassigned']
# Invariants that must hold after EVERY step once the schema exists.
ALWAYS_ZERO = ['lines_without_exactly_one_movement', 'sale_movements_not_matching_a_line',
               'balance_vs_movement_sum_mismatch', 'balance_vs_last_movement_mismatch',
               'negative_or_invalid_stock', 'negative_movement_after', 'duplicate_idempotency_keys',
               'items_without_synthetic_marker']
TABLE_COLUMNS = [('sales', 'ventas'), ('sale_operations', 'ops_venta'), ('movements', 'movs'),
                 ('sale_movements', 'movs_venta'), ('on_hand_total', 'existencia'),
                 ('balance_vs_movement_sum_mismatch', 'Σmov≠saldo'), ('negative_or_invalid_stock', 'negativos'),
                 ('duplicate_idempotency_keys', 'claves_dup'), ('active_sessions', 'sesiones')]


class HarnessError(Exception):
    """A failed expectation. Messages are fixed text plus counts or status codes, never secrets."""


class Stop(Exception):
    """SIGTERM/SIGINT received: tear down and exit."""


def _stop(signum, frame):
    raise Stop(signal.Signals(signum).name)


# ---------------------------------------------------------------------------------------------
# Process helpers
# ---------------------------------------------------------------------------------------------

def dotnet_path():
    found = shutil.which('dotnet')
    if not found:
        raise HarnessError('dotnet no está en PATH (SDK fijado en global.json)')
    return found


def child_env(extra=None):
    """Child environment without the raw server connection or sqlcmd password, unless re-added explicitly."""
    env = {k: v for k, v in os.environ.items()
           if k not in ('MARTHA_TEST_SQL_CONNECTION', 'SQLCMDPASSWORD', 'MSSQL_SA_PASSWORD')
           and not k.startswith('ConnectionStrings__')}
    env.update(extra or {})
    return env


class Helper:
    """GoldenPath.Sql: real EF migrator, branch insert, SQL oracles, TLS certificate and drop."""

    def __init__(self, dotnet, dll, connection):
        self.dotnet, self.dll, self.connection = dotnet, dll, connection

    def __call__(self, *args, allow_fail=False):
        env = child_env({'MARTHA_TEST_SQL_CONNECTION': self.connection})
        done = subprocess.run([self.dotnet, str(self.dll), *args], env=env, capture_output=True, text=True, timeout=300)
        lines = [line for line in done.stdout.splitlines() if line.startswith('{')]
        result = json.loads(lines[-1]) if lines else {'ok': False, 'error': 'no_output', 'detail': f'exit_{done.returncode}'}
        if (done.returncode != 0 or not result.get('ok')) and not allow_fail:
            raise HarnessError(f"herramienta SQL '{args[0]}' falló: {result.get('error')} / {result.get('detail')}")
        return result


def free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(('127.0.0.1', 0))
        return probe.getsockname()[1]


def database_connection(server_connection, database):
    # SqlConnectionStringBuilder keeps the LAST occurrence of a keyword, so appending overrides any
    # database/MARS value in the supplied server connection without parsing or echoing it.
    return server_connection.strip().rstrip(';') + f';Initial Catalog={database};MultipleActiveResultSets=False'


def product_status(transcript):
    """Return only the console's fixed refusal/outcome sentences (they never contain typed values)."""
    lines = ''.join(transcript).replace('\r', '\n').split('\n')
    keep = [line.strip() for line in lines if line.strip().startswith(
        ('Refused', 'Cancelled', 'Owner creation outcome', 'Initial owner creation'))]
    return ' | '.join(line[:240] for line in keep)


def bootstrap_owner(dotnet, api_dll, env, login, display, password, timeout=120):
    """Drive the product's interactive Owner console (--internal-bootstrap-owner) through a private pty.

    Nothing read from the console is stored or printed: passwords are only typed, never echoed in clear.
    """
    fd, slave = pty.openpty()
    # Raw mode BEFORE the child starts: otherwise bytes typed before .NET configures the terminal are
    # translated by the line discipline (CR -> LF), which the console correctly rejects as Ctrl+Enter.
    tty.setraw(slave)
    pid = os.fork()
    if pid == 0:  # child: new session whose controlling terminal is the private pty
        try:
            os.close(fd)
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
            for target in (0, 1, 2):
                os.dup2(slave, target)
            if slave > 2:
                os.close(slave)
            os.chdir(api_dll.parent)
            os.execve(dotnet, [dotnet, str(api_dll), '--internal-bootstrap-owner'], env)
        finally:
            os._exit(127)
    os.close(slave)
    buffer = ''
    transcript = []  # in memory only; just fixed product status lines may be reported
    deadline = time.monotonic() + timeout

    def wait_for(marker):
        nonlocal buffer
        while marker not in buffer:
            if time.monotonic() > deadline:
                raise HarnessError(f'consola Owner: no apareció el aviso esperado ({marker[:24]}…)')
            ready, _, _ = select.select([fd], [], [], 1.0)
            if ready:
                try:
                    chunk = os.read(fd, 4096)
                except OSError:
                    chunk = b''
                if not chunk:
                    raise HarnessError('consola Owner terminó antes de completar el diálogo: '
                                       + (product_status(transcript) or 'sin mensaje de estado'))
                text = chunk.decode('utf-8', 'replace')
                buffer += text
                transcript.append(text)
        index = buffer.index(marker) + len(marker)
        consumed, buffer = buffer[:index], buffer[index:]
        return consumed

    def answer(text):
        os.write(fd, text.encode('ascii') + b'\r')

    try:
        wait_for('Type PRIVATE in uppercase'); wait_for('\n'); answer('PRIVATE')
        wait_for('New owner login'); wait_for('\n'); answer(login)
        wait_for('New owner display name'); wait_for('\n'); answer(display)
        wait_for('New password ('); wait_for('\n'); answer(password)
        wait_for('Repeat new password'); wait_for('\n'); answer(password)
        wait_for('Final authorization: type exactly ')
        phrase = wait_for('\n').strip()
        if not phrase.startswith('CREATE OWNER IN ') or not phrase.endswith('/' + env['GOLDEN_DATABASE']):
            raise HarnessError('consola Owner: frase de autorización inesperada')
        answer(phrase)
        wait_for('Initial owner creation committed')
    finally:
        status = None
        for _ in range(100):
            done, status = os.waitpid(pid, os.WNOHANG)
            if done:
                break
            time.sleep(0.1)
        else:
            os.kill(pid, signal.SIGKILL)
            os.waitpid(pid, 0)
        os.close(fd)
    code = os.waitstatus_to_exitcode(status) if status is not None else None
    if code != 0:
        raise HarnessError(f'consola Owner terminó con código {code} (0 = creado)')


# ---------------------------------------------------------------------------------------------
# HTTP actor (mirrors dev/savia-staff-ui/login.mjs + client.mjs: CSRF, login, renew, me, logout)
# ---------------------------------------------------------------------------------------------

class Actor:
    def __init__(self, port, cafile, secrets_seen):
        self.port = port
        self.context = ssl.create_default_context(cafile=str(cafile))  # verify the ephemeral cert, no bypass
        self.cookies = {}
        self.csrf = None
        self.secrets_seen = secrets_seen
        self.statuses = []

    def request(self, method, path, body=None, csrf=False, key=None):
        headers = {'Accept': 'application/json'}
        payload = None
        if body is not None:
            payload = json.dumps(body).encode('utf-8')
            headers['Content-Type'] = 'application/json'
        if csrf:
            headers['X-CSRF-TOKEN'] = self.csrf
        if key:
            headers['Idempotency-Key'] = key
        if self.cookies:
            headers['Cookie'] = '; '.join(f'{k}={v}' for k, v in self.cookies.items())
        connection = http.client.HTTPSConnection('127.0.0.1', self.port, context=self.context, timeout=60)
        try:
            connection.request(method, path, body=payload, headers=headers)
            response = connection.getresponse()
            raw = response.read()
            for header, value in response.getheaders():
                if header.lower() == 'set-cookie':
                    self._cookie(value)
            content_type = (response.getheader('Content-Type') or '').split(';')[0].strip().lower()
            data = json.loads(raw) if raw and content_type in ('application/json', 'application/problem+json') else None
            self.statuses.append(response.status)
            return response.status, data
        finally:
            connection.close()

    def _cookie(self, header):
        name, _, rest = header.partition('=')
        value = rest.split(';', 1)[0]
        expired = 'expires=thu, 01 jan 1970' in header.lower() or 'max-age=0' in header.lower()
        if expired or not value:
            self.cookies.pop(name.strip(), None)
        else:
            self.cookies[name.strip()] = value
            self.secrets_seen.add(value)

    def renew_csrf(self):
        status, data = self.request('GET', '/internal/api/security/csrf')
        expect(status == 200 and data and data.get('headerName') == 'X-CSRF-TOKEN', f'csrf HTTP {status}')
        self.csrf = data['token']
        self.secrets_seen.add(self.csrf)

    def login(self, login, password):
        self.renew_csrf()
        status, data = self.request('POST', '/internal/api/security/login',
                                    {'loginName': login, 'password': password}, csrf=True)
        if status != 200:
            return status, None
        self.renew_csrf()  # identity transition: a new authenticated token is required
        me_status, me = self.request('GET', '/internal/api/security/me')
        expect(me_status == 200 and me and me['id'] == data['staff']['id'], f'me tras login HTTP {me_status}')
        return status, me

    def post(self, path, body, key):
        self.renew_csrf()
        return self.request('POST', path, body, csrf=True, key=key)

    def logout(self):
        self.renew_csrf()
        status, _ = self.request('POST', '/internal/api/security/logout', csrf=True)
        self.csrf = None
        return status


def expect(condition, message):
    if not condition:
        raise HarnessError(message)


def new_key():
    return str(uuid.uuid4())


# ---------------------------------------------------------------------------------------------
# Harness
# ---------------------------------------------------------------------------------------------

class GoldenPath:
    def __init__(self, args):
        self.args = args
        self.out = Path(args.out).resolve()
        self.out.mkdir(parents=True, exist_ok=True)
        self.private = Path(tempfile.mkdtemp(prefix='savia-golden-private-'))  # outside the evidence dir
        os.chmod(self.private, 0o700)
        self.server_connection = os.environ.get('MARTHA_TEST_SQL_CONNECTION', '')
        self.database = args.database or 'SaviaInternalTest_Golden_' + secrets.token_hex(16)
        self.run_id = secrets.token_hex(3)
        self.steps = []
        self.secrets_seen = set()
        self.api = None
        self.api_log = None
        self.database_created = False
        self.drop_needed = False
        self.started = time.monotonic()
        self.ids = {}
        self.users = {}
        self.port = None
        self.previous = None

    # -- evidence ---------------------------------------------------------------------------
    def oracles(self):
        return self.helper('oracles', self.database)['counts']

    def step(self, name, action, expected=None, same_as_previous=()):
        """Run one step, then evaluate SQL oracles. expected: {count_name: value}."""
        began = time.monotonic()
        record = {'step': name, 'status': 'FAIL'}
        self.steps.append(record)
        try:
            notes = action() or {}
        finally:
            record['ms'] = round((time.monotonic() - began) * 1000)
        record.update(notes)
        if self.database_created:
            counts = self.oracles()
            record['oracles'] = counts
            failures = []
            if counts.get('migrations_applied') != EXPECTED_MIGRATIONS:
                failures.append('migrations_applied')
            failures += [k for k in ALWAYS_ZERO if counts.get(k) != 0]
            for key, value in (expected or {}).items():
                if counts.get(key) != value:
                    failures.append(f'{key}={counts.get(key)}≠{value}')
            for key in same_as_previous:
                if self.previous is None or counts.get(key) != self.previous.get(key):
                    failures.append(f'{key} cambió')
            record['oracle_failures'] = failures
            self.previous = counts
            if failures:
                raise HarnessError(f'oráculo SQL falló en {name}: {", ".join(failures)}')
        record['status'] = 'PASS'
        print(f'PASS {name} ({record["ms"]} ms)', flush=True)

    def write_evidence(self, outcome, error=None):
        evidence = {
            'harness': 'tests/golden-path/golden_path.py', 'card': 'C5', 'mode': self.args.mode,
            'outcome': outcome, 'error': error,
            'database_name': self.database,  # random disposable name; not a credential
            'migration_method': 'EF IMigrator.MigrateAsync (release migrator; not EnsureCreated)',
            'owner_method': 'product console --internal-bootstrap-owner driven through a private pty',
            'branch_method': 'EF insert of InternalBranch by the harness (no HTTP endpoint creates branches)',
            'directory_stock_staff_method': 'HTTP as Owner: directory/locations, directory/items, commerce/adjustments, security/staff',
            'api': {'binding': '127.0.0.1 (https, ephemeral self-signed certificate)', 'process': 'dotnet Martha.Store.Api.dll'},
            'roles': ROLES,
            'total_ms': round((time.monotonic() - self.started) * 1000),
            'steps': self.steps,
            'not_proven': ['real browser/UI (C6)', 'Windows/SUAZO-PC', 'production TLS/proxy', 'payments',
                           'concurrency/load', 'backup/restore', 'idempotent release SQL script'],
        }
        (self.out / 'evidence.json').write_text(json.dumps(evidence, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
        table = self.table()
        (self.out / 'oracles.md').write_text(table + '\n', encoding='utf-8')
        return table

    def table(self):
        header = ['paso', 'estado', 'ms'] + [label for _, label in TABLE_COLUMNS]
        lines = ['| ' + ' | '.join(header) + ' |', '|' + '---|' * len(header)]
        for record in self.steps:
            counts = record.get('oracles', {})
            cells = [record['step'], record['status'], str(record.get('ms', ''))]
            cells += [str(counts.get(key, '–')) for key, _ in TABLE_COLUMNS]
            lines.append('| ' + ' | '.join(cells) + ' |')
        return '\n'.join(lines)

    def scan_for_secrets(self, skip=()):
        """Fail if any password, cookie, CSRF token or the connection leaked into the evidence directory."""
        needles = {s for s in self.secrets_seen if len(s) >= 8}
        if self.server_connection:
            needles.add(self.server_connection)
            for part in self.server_connection.split(';'):
                k, _, v = part.partition('=')
                if k.strip().lower() in ('password', 'pwd') and len(v.strip()) >= 4:
                    needles.add(v.strip())
        for path in self.out.rglob('*'):
            if path.is_file() and path.name not in skip:
                text = path.read_text(encoding='utf-8', errors='replace')
                for needle in needles:
                    if needle in text:
                        raise HarnessError(f'secreto detectado en la evidencia: {path.name}')
        return len(needles)

    # -- lifecycle ----------------------------------------------------------------------------
    def build(self):
        dotnet = dotnet_path()
        if not self.args.no_build:
            subprocess.run([dotnet, 'restore', str(HELPER_PROJECT), '--locked-mode'], check=True, cwd=ROOT)
            subprocess.run([dotnet, 'build', str(HELPER_PROJECT), '--no-restore', '-c', 'Release'], check=True, cwd=ROOT)
        self.api_dll = API_PROJECT / 'bin/Release/net10.0/Martha.Store.Api.dll'
        helper_dll = HELPER_PROJECT / 'bin/Release/net10.0/GoldenPath.Sql.dll'
        expect(self.api_dll.is_file() and helper_dll.is_file(), 'faltan binarios Release: compilar o quitar --no-build')
        self.dotnet = dotnet
        self.helper = Helper(dotnet, helper_dll, self.server_connection)

    def api_env(self):
        connection = database_connection(self.server_connection, self.database)
        self.secrets_seen.add(connection)
        return child_env({
            'ASPNETCORE_ENVIRONMENT': 'Development', 'DOTNET_ENVIRONMENT': 'Development',
            'InternalSavia__Enabled': 'true', 'Synthetic__Enabled': 'false',
            'ConnectionStrings__InternalSavia': connection,
            # Legacy Store context is not used by /internal; an invalid guarded name keeps it closed.
            'ConnectionStrings__Store': 'Database=Forbidden_GoldenPath_NoStore',
            'Kestrel__Certificates__Default__Path': str(self.out / 'cert.pem'),
            'Kestrel__Certificates__Default__KeyPath': str(self.private / 'tls' / 'key.pem'),
            'Logging__LogLevel__Default': 'Warning', 'Logging__LogLevel__Microsoft.Hosting.Lifetime': 'Information',
            'DOTNET_NOLOGO': '1', 'TERM': os.environ.get('TERM') or 'xterm',
            'GOLDEN_DATABASE': self.database,
        })

    def start_api(self):
        self.port = free_port()
        self.base_url = f'https://127.0.0.1:{self.port}'
        self.api_log = open(self.private / 'api.log', 'wb')
        self.api = subprocess.Popen([self.dotnet, str(self.api_dll), '--urls', self.base_url],
                                    cwd=self.api_dll.parent, env=self.api_env(), stdin=subprocess.DEVNULL,
                                    stdout=self.api_log, stderr=subprocess.STDOUT)
        probe = Actor(self.port, self.out / 'cert.pem', self.secrets_seen)
        deadline = time.monotonic() + 90
        while time.monotonic() < deadline:
            if self.api.poll() is not None:
                raise HarnessError(f'la API terminó al iniciar (código {self.api.returncode})')
            try:
                status, data = probe.request('GET', '/internal/api/readiness')
                # Anonymous readiness must be refused; any response proves the real process listens with TLS.
                expect(status == 401, f'readiness anónimo devolvió HTTP {status}, se esperaba 401')
                return {'http': [status], 'port_kind': 'loopback-free-port'}
            except (ConnectionError, OSError, http.client.HTTPException):
                time.sleep(0.5)
        raise HarnessError('la API no respondió en 90 s')

    def stop_api(self):
        if self.api and self.api.poll() is None:
            self.api.send_signal(signal.SIGTERM)
            try:
                self.api.wait(timeout=20)
            except subprocess.TimeoutExpired:
                self.api.kill()
                self.api.wait(timeout=10)
        if self.api_log:
            self.api_log.close()
        return self.api.returncode if self.api else None

    # -- scenario -----------------------------------------------------------------------------
    def setup(self):
        expect(self.server_connection, 'falta MARTHA_TEST_SQL_CONNECTION (SQL Server desechable)')
        expect(DATABASE_PATTERN.match(self.database), 'nombre de base rechazado: debe ser SaviaInternalTest_Golden_<32 hex>')
        self.build()
        self.helper('cert', str(self.private / 'tls'))
        shutil.move(str(self.private / 'tls' / 'cert.pem'), str(self.out / 'cert.pem'))

        def migrate():
            result = self.helper('create', self.database, allow_fail=True)
            if result.get('detail') in ('database_already_exists', 'database_name_not_golden_disposable'):
                raise HarnessError(f"herramienta SQL rechazó la base: {result['detail']}")  # never drop it
            self.drop_needed = True  # created (possibly partially) by this run
            expect(result.get('ok'), f"migración falló: {result.get('error')} / {result.get('detail')}")
            self.database_created = True
            expect(result['pending'] == 0 and len(result['applied']) == EXPECTED_MIGRATIONS, 'migraciones incompletas')
            return {'applied_migrations': result['applied'], 'method': result['method']}
        self.step('sql.migrate_release', migrate, {'staff': 0, 'migrations_applied': EXPECTED_MIGRATIONS})

        for role in ROLES:
            self.users[role] = {'loginName': f'golden.{role.lower()}.{self.run_id}',
                                'displayName': f'SINTETICO Golden {role}',
                                'password': 'Golden-' + secrets.token_urlsafe(24)}
            self.secrets_seen.add(self.users[role]['password'])

        def owner():
            u = self.users['Owner']
            bootstrap_owner(self.dotnet, self.api_dll, self.api_env(), u['loginName'], u['displayName'], u['password'])
            return {'console_exit': 0}
        self.step('owner.bootstrap_console', owner, {'staff': 1})

        self.ids['branch'] = str(uuid.uuid4())
        def branch():
            self.helper('branch', self.database, self.ids['branch'])
            return {'note': 'sin endpoint HTTP de sucursales en este candidato'}
        self.step('sql.branch_seed', branch, {'branches': 1})
        self.step('api.start_readiness_anonymous', self.start_api)

        self.owner = Actor(self.port, self.out / 'cert.pem', self.secrets_seen)

        def owner_login():
            status, me = self.owner.login(self.users['Owner']['loginName'], self.users['Owner']['password'])
            expect(status == 200 and me['role'] == 'Owner', f'login Owner HTTP {status}')
            ready_status, ready = self.owner.request('GET', '/internal/api/readiness')
            expect(ready_status == 200 and ready.get('status') == 'ready', f'readiness autenticado HTTP {ready_status}')
            return {'http': [status, ready_status], 'readiness': ready.get('status')}
        self.step('owner.login_readiness', owner_login, {'active_sessions': 1})

        def directory():
            codes = []
            status, location = self.owner.post('/internal/api/directory/locations',
                                               {'name': 'SINTETICO Golden bodega', 'active': True,
                                                'branchId': self.ids['branch']}, new_key())
            expect(status == 201 and location['branchId'] == self.ids['branch'], f'crear ubicación HTTP {status}')
            codes.append(status)
            self.ids['location'] = location['id']
            self.ids['items'] = []
            for sku, name, price in ITEMS:
                status, item = self.owner.post('/internal/api/directory/items',
                                               {'sku': sku, 'name': name, 'unitPriceMinor': price,
                                                'currency': 'USD', 'active': True}, new_key())
                expect(status == 201, f'crear artículo HTTP {status}')
                codes.append(status)
                self.ids['items'].append(item['id'])
            return {'http': codes}
        self.step('owner.seed_directory', directory, {'locations': 1, 'items': len(ITEMS), 'sales': 0})

        def stock():
            codes = []
            for item_id in self.ids['items']:
                status, _ = self.owner.post('/internal/api/commerce/adjustments',
                                            {'itemId': item_id, 'locationId': self.ids['location'],
                                             'onHandDelta': SEED_STOCK, 'reason': 'SINTETICO carga inicial golden'},
                                            new_key())
                expect(status == 200, f'ajuste de stock HTTP {status}')
                codes.append(status)
            return {'http': codes}
        self.step('owner.seed_stock_adjustments', stock,
                  {'movements': len(ITEMS), 'adjustments': len(ITEMS), 'on_hand_total': SEED_STOCK * len(ITEMS)})

        def staff():
            codes = []
            for role in ROLES[1:]:
                u = self.users[role]
                body = {'loginName': u['loginName'], 'displayName': u['displayName'],
                        'role': 'Cashier' if role == 'Unassigned' else role, 'password': u['password'],
                        'branchId': None if role == 'Unassigned' else self.ids['branch']}
                status, created = self.owner.post('/internal/api/security/staff', body, None)
                expect(status == 200 and created['branchId'] == body['branchId'], f'crear personal {role} HTTP {status}')
                codes.append(status)
            return {'http': codes}
        self.step('owner.seed_staff', staff, {'staff': len(ROLES), 'unassigned_staff': 1})

        def owner_scope():
            codes = []
            status, locations = self.owner.request('GET', '/internal/api/directory/locations')
            codes.append(status)
            expect(status == 200 and locations['total'] == 1, f'ubicaciones Owner HTTP {status}')
            status, inventory = self.owner.request('GET', f"/internal/api/commerce/inventory?locationId={self.ids['location']}&skip=0&take=100")
            codes.append(status)
            expect(status == 200 and inventory['total'] == len(ITEMS), f'inventario Owner HTTP {status}')
            status, staff_list = self.owner.request('GET', '/internal/api/security/staff')
            codes.append(status)
            expect(status == 200 and len(staff_list['items']) == len(ROLES), f'personal Owner HTTP {status}')
            codes.append(self.owner.logout())
            expect(codes[-1] == 204, f'logout Owner HTTP {codes[-1]}')
            status, _ = self.owner.request('GET', '/internal/api/security/me')
            codes.append(status)
            expect(status == 401, f'me tras logout Owner HTTP {status}')
            return {'http': codes, 'visible_locations': locations['total'], 'visible_stock_rows': inventory['total']}
        self.step('owner.scope_and_logout', owner_scope, {'active_sessions': 0})

    def role_scope(self, role, sale_expected_status=None):
        actor = Actor(self.port, self.out / 'cert.pem', self.secrets_seen)
        codes = []
        status, me = actor.login(self.users[role]['loginName'], self.users[role]['password'])
        codes.append(status)
        expected_role = 'Cashier' if role == 'Unassigned' else role
        expect(status == 200 and me['role'] == expected_role, f'login {role} HTTP {status}')
        status, locations = actor.request('GET', '/internal/api/directory/locations')
        codes.append(status)
        status2, inventory = actor.request('GET', f"/internal/api/commerce/inventory?locationId={self.ids['location']}&skip=0&take=100")
        codes.append(status2)
        visible = (locations or {}).get('total'), (inventory or {}).get('total')
        if role == 'Unassigned':
            expect(status == 200 and status2 == 200 and visible == (0, 0), f'sin asignación ve ubicaciones/stock: {visible}')
        else:
            expect(status == 200 and status2 == 200 and visible == (1, len(ITEMS)), f'{role} no ve su sucursal: {visible}')
        notes = {'visible_locations': visible[0], 'visible_stock_rows': visible[1]}
        if sale_expected_status is not None:
            status, problem = actor.post('/internal/api/commerce/sales', self.sale_body(), new_key())
            codes.append(status)
            expect(status == sale_expected_status, f'venta de {role}: HTTP {status}, se esperaba {sale_expected_status}')
            notes['sale_attempt'] = {'http': status, 'code': (problem or {}).get('code')}
        return actor, codes, notes

    def sale_body(self):
        return {'locationId': self.ids['location'], 'customerId': None,
                'lines': [{'itemId': self.ids['items'][0], 'quantity': SALE_QUANTITY}]}

    def smoke(self):
        def manager():
            actor, codes, notes = self.role_scope('Manager')
            codes.append(actor.logout())
            expect(codes[-1] == 204, 'logout Manager')
            return {'http': codes, **notes}
        self.step('manager.login_scope_logout', manager, {'sales': 0, 'active_sessions': 0})

        def inventory():
            actor, codes, notes = self.role_scope('Inventory', sale_expected_status=403)
            codes.append(actor.logout())
            expect(codes[-1] == 204, 'logout Inventory')
            return {'http': codes, **notes}
        self.step('inventory.login_scope_sale_denied', inventory, {'sales': 0, 'sale_operations': 0, 'active_sessions': 0},
                  same_as_previous=('movements', 'operations'))

        def unassigned():
            actor, codes, notes = self.role_scope('Unassigned', sale_expected_status=403)
            codes.append(actor.logout())
            expect(codes[-1] == 204, 'logout sin asignación')
            return {'http': codes, **notes}
        self.step('unassigned.denied_scope_and_sale', unassigned, {'sales': 0, 'sale_operations': 0, 'active_sessions': 0},
                  same_as_previous=('movements', 'operations', 'on_hand_total'))

        self.cashier = None

        def cashier_login():
            self.cashier, codes, notes = self.role_scope('Cashier')
            return {'http': codes, **notes}
        self.step('cashier.login_scope', cashier_login, {'sales': 0, 'cashier_active_sessions': 1})

        self.sale_key = new_key()

        def sale():
            status, receipt = self.cashier.post('/internal/api/commerce/sales', self.sale_body(), self.sale_key)
            expect(status == 200, f'venta HTTP {status}')
            expect(receipt['paymentStatus'] == 'not_processed' and receipt['totalMinor'] == ITEMS[0][2] * SALE_QUANTITY,
                   'recibo inesperado')
            self.sale_id = receipt['saleId']
            return {'http': [status], 'total_minor': receipt['totalMinor'], 'lines': len(receipt['lines'])}
        self.step('cashier.sale_with_idempotency_key', sale,
                  {'sales': 1, 'sale_lines': 1, 'sale_movements': 1, 'sale_operations': 1,
                   'on_hand_total': SEED_STOCK * len(ITEMS) - SALE_QUANTITY})

        def replay():
            status, receipt = self.cashier.post('/internal/api/commerce/sales', self.sale_body(), self.sale_key)
            expect(status == 200 and receipt['saleId'] == self.sale_id, f'repetición HTTP {status} o venta distinta')
            return {'http': [status], 'same_sale_id': True}
        self.step('cashier.replay_same_key_no_effect', replay, {'sales': 1, 'sale_operations': 1},
                  same_as_previous=('movements', 'operations', 'on_hand_total', 'sale_lines'))

        def conflict():
            body = self.sale_body()
            body['lines'][0]['quantity'] = SALE_QUANTITY + 1
            status, problem = self.cashier.post('/internal/api/commerce/sales', body, self.sale_key)
            expect(status == 409 and (problem or {}).get('code') == 'idempotency_conflict', f'misma clave, otro cuerpo: HTTP {status}')
            return {'http': [status], 'code': problem.get('code')}
        self.step('cashier.same_key_other_body_conflict', conflict, {'sales': 1, 'sale_operations': 1},
                  same_as_previous=('movements', 'operations', 'on_hand_total'))

        def recover():
            status, data = self.cashier.request('GET', '/internal/api/operations/commerce.sale.record', key=self.sale_key)
            expect(status == 200 and data['status'] == 'completed' and data['result']['value']['saleId'] == self.sale_id,
                   f'recuperación HTTP {status}')
            return {'http': [status], 'recovered': 'completed'}
        self.step('cashier.recover_by_key', recover, {'sales': 1}, same_as_previous=('movements', 'operations'))

        def logout():
            codes = [self.cashier.logout()]
            status, _ = self.cashier.request('GET', '/internal/api/security/me')
            codes.append(status)
            expect(codes == [204, 401], f'logout cajero {codes}')
            return {'http': codes}
        self.step('cashier.logout', logout, {'sales': 1, 'cashier_active_sessions': 0, 'active_sessions': 0},
                  same_as_previous=('movements', 'operations', 'on_hand_total'))

    def serve(self):
        session = {
            'warning': 'Credenciales SINTÉTICAS de una base desechable. No copiar a Git ni a evidencia.',
            'base_url': self.base_url, 'login_url': self.base_url + '/internal/login',
            'ca_cert': str(self.out / 'cert.pem'), 'database_name': self.database,
            'branch_id': self.ids['branch'], 'location_id': self.ids['location'], 'item_ids': self.ids['items'],
            'users': {role: {'loginName': u['loginName'], 'password': u['password'],
                             'role': 'Cashier' if role == 'Unassigned' else role, 'assigned': role != 'Unassigned'}
                      for role, u in self.users.items()},
        }
        credentials = self.out / 'session.json'
        descriptor = os.open(credentials, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(descriptor, 'w', encoding='utf-8') as handle:
            json.dump(session, handle, indent=2, ensure_ascii=False)
        os.chmod(credentials, 0o600)
        ready = {'base_url': self.base_url, 'credentials_file': 'session.json', 'pid': os.getpid(),
                 'users': {role: u['loginName'] for role, u in self.users.items()}}
        (self.out / 'serve-ready.json').write_text(json.dumps(ready, indent=2) + '\n', encoding='utf-8')
        print(f'\nSERVE base_url={self.base_url}', flush=True)
        for role, u in self.users.items():
            print(f'SERVE user {role}: {u["loginName"]}', flush=True)
        print(f'SERVE credenciales (0600): {credentials}', flush=True)
        print('SERVE API y base activas. Terminar con Ctrl+C o SIGTERM para detener la API y borrar la base.', flush=True)
        while True:
            if self.api.poll() is not None:
                raise HarnessError(f'la API terminó durante serve (código {self.api.returncode})')
            time.sleep(1)

    def teardown(self):
        records = {}
        began = time.monotonic()
        records['api_exit'] = self.stop_api() if self.api else None
        if self.drop_needed:
            dropped = self.helper('drop', self.database, allow_fail=True)
            exists = self.helper('exists', self.database, allow_fail=True)
            records['database_dropped'] = bool(dropped.get('ok')) and exists.get('exists') is False
        else:
            records['database_dropped'] = 'not_created'
        for name in ('session.json', 'serve-ready.json'):
            (self.out / name).unlink(missing_ok=True)
        log = self.private / 'api.log'
        if log.is_file():
            # Only counts leave the private log: its text is never copied to evidence.
            lines = log.read_text(encoding='utf-8', errors='replace').splitlines()
            records['api_log_lines'] = len(lines)
            records['api_log_fail_or_crit'] = sum(1 for line in lines if line.startswith(('fail:', 'crit:')))
            records['api_log_warn'] = sum(1 for line in lines if line.startswith('warn:'))
            if self.args.keep_private_log:
                kept = Path(self.args.keep_private_log)
                shutil.copyfile(log, kept)
                os.chmod(kept, 0o600)
        shutil.rmtree(self.private, ignore_errors=True)
        records['private_dir_removed'] = not self.private.exists()
        records['ms'] = round((time.monotonic() - began) * 1000)
        return records


def load_connection(path):
    """Read only MARTHA_TEST_SQL_CONNECTION from a private KEY=VALUE file (optional 'export', quotes)."""
    for line in Path(path).read_text(encoding='utf-8').splitlines():
        key, sep, value = line.strip().removeprefix('export ').partition('=')
        if sep and key.strip() == 'MARTHA_TEST_SQL_CONNECTION':
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in '\'"':
                value = value[1:-1]
            os.environ['MARTHA_TEST_SQL_CONNECTION'] = value


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--out', required=True, help='directorio de evidencia saneada')
    parser.add_argument('--mode', choices=['smoke', 'serve'], default='smoke')
    parser.add_argument('--no-build', action='store_true', help='usar binarios Release ya compilados')
    parser.add_argument('--sql-env-file', help='archivo privado con MARTHA_TEST_SQL_CONNECTION=… (no se imprime)')
    parser.add_argument('--keep-private-log', help='copiar el log crudo de la API (0600) a esta ruta FUERA de --out')
    parser.add_argument('--database', help=argparse.SUPPRESS)  # only to test the refusal guard
    args = parser.parse_args(argv)
    if args.keep_private_log and Path(args.keep_private_log).resolve().is_relative_to(Path(args.out).resolve()):
        parser.error('--keep-private-log debe quedar fuera de --out (el log crudo no es evidencia saneada)')
    if args.sql_env_file:
        load_connection(args.sql_env_file)
    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)
    harness = GoldenPath(args)
    outcome, error, code = 'FAIL', None, 1
    try:
        harness.setup()
        if args.mode == 'smoke':
            harness.smoke()
            outcome, code = 'PASS', 0
        else:
            harness.serve()
    except Stop as stop:
        outcome, error, code = ('STOPPED', f'señal {stop}', 0) if args.mode == 'serve' else ('FAIL', f'señal {stop}', 1)
    except HarnessError as failure:
        error = str(failure)
    except subprocess.CalledProcessError as failure:
        error = f'comando terminó con código {failure.returncode}'
    except Exception as failure:  # never print exception text: it may carry values
        error = f'excepción {type(failure).__name__}'
    finally:
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        try:
            cleanup = harness.teardown()
        except Exception as failure:
            cleanup = {'error': type(failure).__name__}
        harness.steps.append({'step': 'teardown.stop_api_drop_database', 'ms': cleanup.get('ms'),
                              'status': 'PASS' if cleanup.get('database_dropped') in (True, 'not_created')
                              and cleanup.get('private_dir_removed') and not cleanup.get('api_log_fail_or_crit')
                              else 'FAIL', **cleanup})
        if harness.steps[-1]['status'] != 'PASS':
            outcome, code = 'FAIL', 1
            error = error or 'retiro incompleto'
        table = harness.write_evidence(outcome, error)
        try:
            checked = harness.scan_for_secrets()
            print(f'Evidencia revisada: ningún secreto conocido ({checked} valores) en {harness.out}', flush=True)
        except HarnessError as leak:
            outcome, code = 'FAIL', 1
            print(f'FAIL {leak}', file=sys.stderr, flush=True)
        print('\n' + table, flush=True)
        print(f'\n{outcome}: camino dorado ({args.mode}) en {round((time.monotonic() - harness.started))} s'
              + (f' — {error}' if error else ''), flush=True)
    return code


if __name__ == '__main__':
    sys.exit(main())

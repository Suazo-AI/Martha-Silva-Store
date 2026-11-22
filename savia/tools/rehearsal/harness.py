"""Plumbing for the four-node rehearsal: its own SQL container, four databases, four API host processes,
one fault proxy per store, and the HTTP client the driver uses. Everything is local and removable.

Topology (localhost only):
  hub   Savia.Api Kind=Cloud   http://127.0.0.1:5310  SAVIA_SIM_R_hub
  a/b/c Savia.Api Kind=Branch  http://127.0.0.1:5311-5313  SAVIA_SIM_R_a/b/c
        each store's SyncWorker talks to the hub through its proxy http://127.0.0.1:5321-5323
"""
import hashlib
import http.client
import json
import os
import re
import secrets
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

SAVIA = Path(__file__).resolve().parents[2]
CONTAINER = "savia-sqlserver-rehearsal"
os.environ["SAVIA_SQL_CONTAINER"] = CONTAINER  # saviadb reads it at import time
sys.path.insert(0, str(SAVIA / "tools" / "db"))
import saviadb as db  # noqa: E402
import simulator as sim  # noqa: E402

IMAGE = "mcr.microsoft.com/mssql/server@sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718"
VOLUME = "savia_rehearsal_sql_data"
SQL_PORT = 14341
NODES = ["cloud", "a", "b", "c"]
STORES = ["a", "b", "c"]
API_PORT = {"cloud": 5310, "a": 5311, "b": 5312, "c": 5313}
PROXY_PORT = {"a": 5321, "b": 5322, "c": 5323}
DBN = {n: "SAVIA_SIM_R_" + ("hub" if n == "cloud" else n) for n in NODES}
sim.DBN.clear()
sim.DBN.update(DBN)  # the simulator's oracles (table hashes, row diff) now read the rehearsal databases
OUT = SAVIA / ".out" / "rehearsal"
API_DLL = OUT / "api" / "Savia.Api.dll"
MIGRATOR_DLL = OUT / "migrator" / "Savia.Migrator.dll"
APP_LOGIN = "savia_rehearsal_api"
STAFF = ["t_cashier_a", "t_cashier_b", "t_cashier_c", "t_super_a", "t_super_b", "t_super_c", "t_manager"]
INTERVAL = 5


def dotnet():
    for cand in (os.environ.get("SAVIA_DOTNET"), str(Path.home() / ".dotnet-sdk-10.0.402" / "dotnet.exe")):
        if cand and Path(cand).exists():
            return cand
    return "dotnet"


class Secrets:
    """Every throwaway secret of a run. scrub() removes them from text before it becomes evidence."""

    def __init__(self):
        self.values = set()

    def new(self, n=24):
        value = secrets.token_urlsafe(n) + "aA1"
        self.values.add(value)
        return value

    def add(self, value):
        if value:
            self.values.add(value)
        return value

    def scrub(self, text):
        for v in sorted(self.values, key=len, reverse=True):
            text = text.replace(v, "***")
        return re.sub(r"(Bearer|SaviaNode) [A-Za-z0-9._\-]{16,}", r"\1 ***", text)


# ---------------------------------------------------------------- container
def docker(*args, env=None, timeout=300):
    p = subprocess.run(["docker", *args], capture_output=True, text=True, encoding="utf-8", errors="replace",
                       env=env, timeout=timeout)
    return p.returncode, (p.stdout + p.stderr).strip()


def container_state():
    code, out = docker("inspect", "-f", "{{.State.Status}}", CONTAINER)
    return out if code == 0 else None


def port_open(port, host="127.0.0.1"):
    with socket.socket() as s:
        s.settimeout(0.5)
        return s.connect_ex((host, port)) == 0


def container_up(say=print):
    state = container_state()
    if state == "running":
        say(f"container {CONTAINER}: already running")
    elif state:
        code, out = docker("start", CONTAINER)
        if code:
            raise SystemExit(f"docker start {CONTAINER}: {out}")
    else:
        if port_open(SQL_PORT):
            raise SystemExit(f"127.0.0.1:{SQL_PORT} is already in use; refusing to start {CONTAINER}.")
        env = dict(os.environ, MSSQL_SA_PASSWORD=secrets.token_urlsafe(18) + "aA1")
        code, out = docker("run", "-d", "--name", CONTAINER, "--label", "savia.rehearsal=1",
                           "-e", "ACCEPT_EULA=Y", "-e", "MSSQL_PID=Developer", "-e", "MSSQL_SA_PASSWORD",
                           "-p", f"127.0.0.1:{SQL_PORT}:1433", "-v", f"{VOLUME}:/var/opt/mssql", IMAGE, env=env)
        if code:
            raise SystemExit(f"docker run {CONTAINER}: {out}")
    deadline = time.time() + 180
    while time.time() < deadline:
        code, _ = db.run_sql("master", "SELECT 1;", timeout=20)
        if code == 0:
            return
        time.sleep(3)
    raise SystemExit(f"{CONTAINER} did not accept SQL within 180 s")


def container_down():
    """Remove exactly this container and its volume. Never prunes, never touches other containers."""
    lines = []
    if container_state() is not None:
        lines.append(("rm", *docker("rm", "-f", CONTAINER)))
    code, out = docker("volume", "inspect", VOLUME)
    if code == 0:
        lines.append(("volume rm", *docker("volume", "rm", VOLUME)))
    return lines


def sa_password():
    code, out = docker("exec", CONTAINER, "printenv", "MSSQL_SA_PASSWORD")
    if code:
        raise SystemExit("cannot read the container password")
    return out.strip()


# ---------------------------------------------------------------- SQL
class Sql(sim.Sim):
    """The simulator's SQL plumbing and oracles, pointed at the rehearsal databases."""

    def __init__(self):
        super().__init__(seed=0, out=lambda *_: None)
        self.impersonate = None  # a database user name: every statement then runs under EXECUTE AS USER
        rows = self.fetch("cloud", "SET @out=(SELECT Name AS n,Id AS i FROM test.Ids FOR JSON PATH);")
        self.ids = {r["n"]: r["i"].upper() for r in rows}
        self.load_meta()

    def sql(self, node, text):
        if self.impersonate:
            text = f"EXECUTE AS USER = N'{self.impersonate}';\n{text}\nREVERT;"
        return super().sql(node, text)

    def as_user_repro(self, user):
        """Run the sync procedures one store round calls, as a database user, and return the first SQL error per step.
        Pull: hub reads, store applies. Push: store reads, hub applies. Credential: the hub reads the node hash."""
        out = {}
        steps = {"credential on hub": lambda: self.sql("cloud", f"EXEC sync.usp_GetNodeCredential @NodeId='{self.node_id('a')}';"),
                 "pull hub->a": lambda: self.pull("a", "cloud"),
                 "push a->hub": lambda: self.pull("cloud", "a")}
        self.impersonate = user
        try:
            for name, fn in steps.items():
                try:
                    fn()
                    out[name] = "ok"
                except sim.SqlError as e:
                    lines = [l.strip() for l in str(e).splitlines() if l.strip()]
                    i = next((k for k, l in enumerate(lines) if l.startswith("Msg ")), None)
                    out[name] = " ".join(lines[i:i + 2]) if i is not None else " ".join(lines[-2:])
        finally:
            self.impersonate = None
        return out

    def hashes(self):
        return {n: self.table_hashes(n) for n in NODES}

    def conservation_rows(self):
        out = {}
        for n in NODES:
            out[n] = self.fetch(n, """
DECLARE @v TABLE(CheckName varchar(60),KeyText nvarchar(200),Expected bigint,Actual bigint);
INSERT @v EXEC audit.usp_CheckConservation @Throw=0;
SET @out=(SELECT * FROM @v FOR JSON PATH, INCLUDE_NULL_VALUES);""") or []
        return out

    def snapshot(self, node):
        return self.fetch(node, """
SET @out=(SELECT
 (SELECT s.Id AS id,s.BranchId AS branch,s.TotalMinor AS total,s.[Status] AS st,
   (SELECT COUNT(*) FROM sales.SaleLines l WHERE l.SaleId=s.Id) AS nl,
   (SELECT ISNULL(SUM(l.Quantity),0) FROM sales.SaleLines l WHERE l.SaleId=s.Id) AS qty,
   (SELECT COUNT(*) FROM sales.SaleTenders t WHERE t.SaleId=s.Id) AS nt,
   (SELECT ISNULL(SUM(t.AmountMinor),0) FROM sales.SaleTenders t WHERE t.SaleId=s.Id) AS tsum,
   (SELECT ISNULL(SUM(m.OnHandDelta),0) FROM inventory.StockMovements m WHERE m.SourceId=s.Id) AS stock,
   (SELECT ISNULL(SUM(e.DeltaMinor),0) FROM sales.CashEntries e JOIN sales.SaleTenders t ON t.Id=e.SaleTenderId
     WHERE t.SaleId=s.Id) AS cash
  FROM sales.Sales s FOR JSON PATH) AS sales,
 (SELECT r.Id AS id,r.SaleId AS sale FROM sales.SaleReversals r FOR JSON PATH) AS reversals,
 (SELECT c.Id AS id,c.OriginalMinor AS orig,c.[Status] AS st FROM credits.Credits c FOR JSON PATH) AS credits,
 (SELECT a.CreditId AS credit,a.BranchId AS branch,SUM(a.AvailableMinor) AS av,SUM(a.HeldMinor) AS held
    FROM credits.CreditAllocations a GROUP BY a.CreditId,a.BranchId FOR JSON PATH) AS alloc,
 (SELECT b.LocationId AS loc,b.ItemId AS item,SUM(b.OnHand) AS onhand FROM inventory.StockBalances b
    GROUP BY b.LocationId,b.ItemId FOR JSON PATH) AS stock,
 (SELECT v.TransferId AS id,v.[Status] AS st,CONVERT(int,v.CancelOverridden) AS ov FROM credits.vw_TransferStatus v
    FOR JSON PATH) AS transfers
 FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);""") or {}

    def count_sales(self, node, sale_ids):
        quoted = ",".join(f"'{s}'" for s in sale_ids)
        return int(self.fetch(node, f"SET @out=CONCAT(N'[',(SELECT COUNT(*) FROM sales.Sales WHERE Id IN ({quoted})),N']');")[0])

    def admin(self, node, text):
        """Setup or manual action as sa (never used for an operation under test that has an HTTP route)."""
        return self.sql(node, text)


def create_databases():
    template = db.ensure_template()
    for n in NODES:
        code, out = db.clone(DBN[n], template)
        if code:
            raise SystemExit(f"clone {DBN[n]}: {out}")


def drop_databases():
    for n in NODES:
        db.drop(DBN[n])


def backup(node, tag):
    code, out = db.run_sql("master", f"BACKUP DATABASE [{DBN[node]}] TO DISK=N'{db.DATA_DIR}/R_{tag}.bak' WITH INIT, FORMAT, COPY_ONLY;")
    if code:
        raise SystemExit(out)


def restore(node, tag):
    code, out = db.run_sql("master", f"ALTER DATABASE [{DBN[node]}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; "
                                     f"RESTORE DATABASE [{DBN[node]}] FROM DISK=N'{db.DATA_DIR}/R_{tag}.bak' WITH REPLACE, RECOVERY; "
                                     f"ALTER DATABASE [{DBN[node]}] SET MULTI_USER;")
    if code:
        raise SystemExit(out)


# ---------------------------------------------------------------- HTTP
def call(base, method, path, body=None, token=None, headers=None, timeout=60):
    """Returns (status, parsed body or text). Never raises on an HTTP status."""
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(base + path, data=data, method=method)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            status, raw = r.status, r.read()
    except urllib.error.HTTPError as e:
        status, raw = e.code, e.read()
    except (urllib.error.URLError, ConnectionError, TimeoutError, socket.timeout) as e:
        return 0, str(e)
    text = raw.decode("utf-8", errors="replace")
    try:
        return status, json.loads(text) if text else None
    except ValueError:
        return status, text


# ---------------------------------------------------------------- fault proxy
class Proxy:
    """Sits between one store's SyncWorker and the hub. Modes:
      pass  relay every request
      down  close every connection without an answer (a cut link)
    Rules fire on a matching request: tamper the request or the answer, or run an action after the hub answered
    and drop the answer (the store never hears it). Every exchange is logged with its status.
    """

    def __init__(self, store, port, upstream_port):
        self.store, self.port, self.upstream = store, port, upstream_port
        self.mode = "pass"
        self.rules = []
        self.log = []
        self.lock = threading.Lock()
        proxy = self

        class Handler(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"

            def log_message(self, *_):
                pass

            def _any(self):
                proxy.handle(self)

            do_GET = do_POST = _any

        class Server(ThreadingHTTPServer):
            def handle_error(self, request, client_address):
                if not isinstance(sys.exc_info()[1], ConnectionError):  # a killed store resets its connection
                    super().handle_error(request, client_address)

        self.server = Server(("127.0.0.1", port), Handler)
        self.server.daemon_threads = True
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)

    def start(self):
        self.thread.start()
        return self

    def stop(self):
        self.server.shutdown()
        self.server.server_close()

    def add_rule(self, **rule):
        rule.setdefault("fired", 0)
        rule.setdefault("limit", 1)
        rule["event"] = threading.Event()
        with self.lock:
            self.rules.append(rule)
        return rule

    def record(self, **entry):
        entry["t"] = round(time.time(), 3)
        with self.lock:
            self.log.append(entry)

    def handle(self, h):
        length = int(h.headers.get("Content-Length") or 0)
        body = h.rfile.read(length) if length else b""
        path = h.path
        if self.mode == "down":
            self.record(path=path, status="cut")
            h.close_connection = True
            return
        cands = [r for r in list(self.rules) if r["fired"] < r["limit"] and r["path"] == path]
        active = [r for r in cands if r.get("on", "request") == "request" and r.get("contains", "").encode() in body.upper()]
        for r in active:
            if r["kind"] == "tamper_request":
                body = r["fn"](body)
        headers = {k: v for k, v in h.headers.items() if k.lower() not in ("host", "content-length", "connection")}
        try:
            conn = http.client.HTTPConnection("127.0.0.1", self.upstream, timeout=300)
            conn.request(h.command, path, body=body, headers=headers)
            resp = conn.getresponse()
            status, data, rh = resp.status, resp.read(), resp.getheaders()
            conn.close()
        except OSError as e:
            self.record(path=path, status="hub_unreachable", detail=str(e)[:120])
            h.close_connection = True
            return
        active += [r for r in cands if r.get("on") == "response" and r.get("contains", "").encode() in data.upper()]
        for r in active:
            if r["kind"] == "tamper_response":
                data = r["fn"](data)
        problem = data[:300].decode("utf-8", "replace") if status >= 400 else ""
        self.record(path=path, status=status, problem=problem,
                    rules=[r["name"] for r in active])
        for r in active:
            r["fired"] += 1
            r["status"], r["problem"] = status, problem
            if r["kind"] == "after":
                r["action"]()
                r["event"].set()
                self.record(path=path, status="answer_dropped", rules=[r["name"]])
                h.close_connection = True
                return
            r["event"].set()
        h.send_response(status)
        for k, v in rh:
            if k.lower() not in ("content-length", "transfer-encoding", "connection"):
                h.send_header(k, v)
        h.send_header("Content-Length", str(len(data)))
        h.end_headers()
        h.wfile.write(data)


# ---------------------------------------------------------------- hosts
class Host:
    def __init__(self, cluster, node):
        self.cluster, self.node = cluster, node
        self.proc = None
        self.log_path = cluster.run_dir / f"host-{'hub' if node == 'cloud' else node}.log"
        self.starts = 0

    @property
    def base(self):
        return f"http://127.0.0.1:{API_PORT[self.node]}"

    def env(self):
        c = self.cluster
        env = {k: v for k, v in os.environ.items()
               if not k.upper().startswith(("SAVIA", "OPENAI", "ASPNETCORE", "DOTNET_ENVIRONMENT"))}
        env.update({
            "DOTNET_CLI_TELEMETRY_OPTOUT": "1", "DOTNET_NOLOGO": "1",
            "ASPNETCORE_ENVIRONMENT": "Production",
            "ASPNETCORE_URLS": self.base,
            "Savia__Sql__ConnectionString": c.connection_string(self.node),
            "Savia__Node__NodeId": c.node_id(self.node),
            "Savia__Auth__LoginPerMinute": "0",
        })
        if self.node == "cloud":
            env["Savia__Node__Kind"] = "Cloud"
        else:
            K = self.node.upper()
            env.update({"Savia__Node__Kind": "Branch", "Savia__Node__BranchId": c.ids["branch" + K],
                        "Savia__Node__LocationId": c.ids["loc" + K],
                        "Savia__Sync__HubUrl": f"http://127.0.0.1:{PROXY_PORT[self.node]}",
                        "Savia__Sync__NodeSecret": c.node_secret[self.node],
                        "Savia__Sync__IntervalSeconds": str(INTERVAL)})
        return env

    def start(self, wait=True):
        if self.proc and self.proc.poll() is None:
            return
        if port_open(API_PORT[self.node]):
            raise SystemExit(f"port {API_PORT[self.node]} is busy; another host is still running")
        self.starts += 1
        self.mark(f"==== harness: start #{self.starts}")
        log = open(self.log_path, "ab")
        self.proc = subprocess.Popen([dotnet(), str(API_DLL)], cwd=str(API_DLL.parent), env=self.env(),
                                     stdout=log, stderr=subprocess.STDOUT,
                                     creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        log.close()
        if wait:
            self.wait_ready()

    def wait_ready(self, timeout=90):
        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.proc.poll() is not None:
                raise SystemExit(f"{self.node} host exited with {self.proc.returncode}; see {self.log_path}")
            status, _ = call(self.base, "GET", "/health/ready", timeout=5)
            if status == 200:
                return
            time.sleep(0.5)
        raise SystemExit(f"{self.node} host not ready in {timeout} s; see {self.log_path}")

    def kill(self, why="stop"):
        if self.proc and self.proc.poll() is None:
            self.proc.kill()
            self.proc.wait(timeout=30)
            self.mark(f"==== harness: killed ({why})")

    def alive(self):
        return self.proc is not None and self.proc.poll() is None

    def mark(self, text):
        with open(self.log_path, "ab") as f:
            f.write((text + f" at {time.strftime('%H:%M:%S')}\n").encode())

    def text(self):
        return self.log_path.read_text(encoding="utf-8", errors="replace") if self.log_path.exists() else ""

    def rounds(self):
        return self.text().count("Sync round: pulled")


ROUND_RE = re.compile(r"Sync round(?: refused| could not reach| timed out| failed|: pulled)[^\r\n]*")


class Cluster:
    def __init__(self, run_dir, identity, say=print):
        self.run_dir = Path(run_dir)
        self.run_dir.mkdir(parents=True, exist_ok=True)
        self.identity = identity  # 'sa' or 'restricted'
        self.say = say
        self.secrets = Secrets()
        self.hosts, self.proxies, self.tokens = {}, {}, {}
        self.passwords, self.node_secret = {}, {}
        self.sql = None
        self.app_password = None

    # --- identity and connection strings
    def node_id(self, n):
        return self.ids["nodeCloud" if n == "cloud" else "node" + n.upper()]

    def connection_string(self, n, as_sa=False):
        if as_sa or self.identity == "sa":
            user, pw = "sa", self.sa
        else:
            user, pw = APP_LOGIN, self.app_password
        return (f"Server=127.0.0.1,{SQL_PORT};Database={DBN[n]};User ID={user};Password={pw};"
                "TrustServerCertificate=True;Encrypt=True;Connect Timeout=15")

    def setup(self, seed_stock=500):
        self.sa = self.secrets.add(sa_password())
        create_databases()
        self.sql = Sql()
        self.ids = self.sql.ids
        # Node credentials, the product's path: the hub keeps SHA-256(UTF-8 secret) via sync.usp_SetNodeCredential.
        for s in STORES:
            self.node_secret[s] = self.secrets.new(32)
            digest = hashlib.sha256(self.node_secret[s].encode("utf-8")).hexdigest()
            self.sql.admin("cloud", f"EXEC sync.usp_SetNodeCredential @NodeId='{self.node_id(s)}',@SecretHash=0x{digest};")
        # Staff passwords, the product's path: Savia.Api provision-passwords on every node (staff is not synced).
        for login in STAFF:
            self.passwords[login] = self.secrets.new(12)
        for n in NODES:
            self.provision_passwords(n)
        if self.identity == "restricted":
            self.grant_restricted()
        for s in STORES:  # setup stock, like the simulator; every operation under test goes through HTTP
            K = s.upper()
            self.sql.admin(s, f"EXEC test.SeedStock @ItemId='{self.ids['item']}',@LocationId='{self.ids['loc' + K]}',"
                              f"@Quantity={seed_stock};")
        for n in NODES:
            self.hosts[n] = Host(self, n)
        for s in STORES:
            self.proxies[s] = Proxy(s, PROXY_PORT[s], API_PORT["cloud"]).start()

    def provision_passwords(self, n):
        env = Host(self, n).env()
        env["Savia__Sql__ConnectionString"] = self.connection_string(n, as_sa=True)
        env["Savia__Provision__Logins"] = ",".join(STAFF)
        for login in STAFF:
            env["SAVIA_PILOT_PASSWORD_" + login.split(".")[0].upper()] = self.passwords[login]
        p = subprocess.run([dotnet(), str(API_DLL), "provision-passwords"], cwd=str(API_DLL.parent), env=env,
                           capture_output=True, text=True, timeout=120)
        if p.returncode:
            raise SystemExit(f"provision-passwords on {n} failed: {self.secrets.scrub(p.stdout + p.stderr)[-800:]}")

    def grant_restricted(self):
        """A SQL login whose only database role is savia_api_host, granted by the product migrator."""
        if self.app_password is None:
            self.app_password = self.secrets.new(18)
            code, out = db.run_sql("master", f"IF SUSER_ID(N'{APP_LOGIN}') IS NOT NULL DROP LOGIN [{APP_LOGIN}]; "
                                             f"CREATE LOGIN [{APP_LOGIN}] WITH PASSWORD=N'{self.app_password}', CHECK_POLICY=OFF;")
            if code:
                raise SystemExit(self.secrets.scrub(out))
        log = []
        for n in NODES:
            env = {k: v for k, v in os.environ.items() if not k.upper().startswith(("SAVIA", "OPENAI"))}
            env["Savia__Sql__ConnectionString"] = self.connection_string(n, as_sa=True)
            p = subprocess.run([dotnet(), str(MIGRATOR_DLL), "--migrations", str(SAVIA / "db" / "migrations"),
                                "--grant-app-user", APP_LOGIN], env=env, capture_output=True, text=True, timeout=300)
            log.append(f"{n}: exit {p.returncode} {self.secrets.scrub((p.stdout + p.stderr).strip())[-400:]}")
            if p.returncode:
                raise SystemExit("migrator --grant-app-user failed:\n" + "\n".join(log))
        roles = self.sql.fetch("cloud", f"SET @out=(SELECT r.name AS role FROM sys.database_role_members m "
                                        f"JOIN sys.database_principals r ON r.principal_id=m.role_principal_id "
                                        f"JOIN sys.database_principals u ON u.principal_id=m.member_principal_id "
                                        f"WHERE u.name=N'{APP_LOGIN}' FOR JSON PATH);") or []
        self.restricted_roles = sorted(r["role"] for r in roles)
        self.grant_log = log

    # --- processes
    def start_all(self):
        self.hosts["cloud"].start()
        for s in STORES:
            self.hosts[s].start()

    def stop_all(self):
        for n in NODES:
            if n in self.hosts:
                self.hosts[n].kill("teardown")

    def close(self):
        self.stop_all()
        for p in self.proxies.values():
            try:
                p.stop()
            except Exception:
                pass

    def login(self, store, login):
        status, body = call(self.hosts[store].base, "POST", "/api/v1/auth/login",
                            {"loginName": login, "password": self.passwords[login]})
        if status != 200:
            raise SystemExit(f"login {login} at {store}: {status} {body}")
        self.secrets.add(body["token"])
        self.tokens[(store, login)] = body["token"]
        return body["token"]

    def token(self, store, role="cashier"):
        login = f"t_{'cashier' if role == 'cashier' else 'super'}_{store}"
        return self.tokens.get((store, login)) or self.login(store, login)

    def wait_rounds(self, stores, n=1, timeout=60):
        """Wait until each store host logs n more successful 'Sync round: pulled' lines (the hosted SyncWorker)."""
        start = {s: self.hosts[s].rounds() for s in stores}
        deadline = time.time() + timeout
        while time.time() < deadline:
            if all(self.hosts[s].rounds() >= start[s] + n for s in stores):
                return True
            time.sleep(0.5)
        return False

    def converge(self, timeout=180, poll=2.0):
        """Wait until the 21 synced tables hash the same on all four nodes. Returns (ok, seconds, differing tables)."""
        from checks import r1
        t0 = time.time()
        diff = []
        while time.time() - t0 < timeout:
            diff = r1(self.sql.hashes())
            if not diff:
                return True, round(time.time() - t0, 1), []
            time.sleep(poll)
        return False, round(time.time() - t0, 1), diff

    def round_lines(self, node):
        return [self.secrets.scrub(m.group(0)) for m in ROUND_RE.finditer(self.hosts[node].text())]

    def log_excerpt(self, node, pattern, limit=6):
        lines = self.hosts[node].text().splitlines()
        out = []
        for i, line in enumerate(lines):
            if re.search(pattern, line):
                out.append(self.secrets.scrub(line.strip())[:400])
                if len(out) >= limit:
                    break
        return out

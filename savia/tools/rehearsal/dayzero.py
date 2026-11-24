#!/usr/bin/env python3
"""Day-zero run (checklist D0): two empty databases to a paid and fulfilled web order, with shipped tools only.

  up       create and migrate the hub and store databases, then steps 1-10 (hosts keep running)
  note     record a step done by hand (the browser steps 11 and 12): --step N --status S --tool T --evidence E
  reserve  W2 after the browser order: the hub holds the unit reserved, and one order sent twice is stored once
  verify   step 13: the order is paid and fulfilled; the store's stock after sync
  skew     step 14: an empty migration on the hub only; the store is refused, upgraded, and syncs again
  report   write the transcript as Markdown: --out PATH [--transcript a saved transcript JSON]
  down     stop the hosts this run started, drop its databases and its SQL login, delete its state

Local only: container savia-sqlserver-dev, databases SAVIA_DEV_dayzero_hub and SAVIA_DEV_dayzero_store,
hub http://127.0.0.1:5410, store http://127.0.0.1:5411. Binaries: build them first into .out/dayzero (see --help).
State (ids, throwaway passwords, process ids) is in .out/dayzero/state.json; `down` deletes it.
The transcript (.out/dayzero/transcript.json) never holds a password, a node secret or a session token.
"""
import argparse
import json
import os
import re
import secrets
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

SAVIA = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(SAVIA / "tools" / "db"))
import saviadb as db  # noqa: E402  (savia-sqlserver-dev unless SAVIA_SQL_CONTAINER says otherwise)

OUT = SAVIA / ".out" / "dayzero"
STATE = OUT / "state.json"
TRANSCRIPT = OUT / "transcript.json"
API_DLL = OUT / "api" / "Savia.Api.dll"
MIGRATOR_DLL = OUT / "migrator" / "Savia.Migrator.dll"
MIGRATIONS = SAVIA / "db" / "migrations"
DBN = {"hub": "SAVIA_DEV_dayzero_hub", "store": "SAVIA_DEV_dayzero_store"}
PORT = {"hub": 5410, "store": 5411}
SQL_PORT = 14340
APP_LOGIN = "savia_dayzero_api"
STOREFRONT = "http://127.0.0.1:8787"
NODE_SECRET = "node-secret: "
STAFF_PASSWORD = "staff-password: "
# Three garments for the web: code, size, color, cost and price in cordobas.
PRODUCTS = [("DZ-0001", "Vestido día cero", "Vestido", "M", "Azul", "300", "950"),
            ("DZ-0002", "Blusa día cero", "Blusa", "S", "Blanco", "180", "520"),
            ("DZ-0003", "Falda día cero", "Falda", "L", "Negro", "220", "680")]
RECEIVED = 5          # units of each item the store receives
WEB_UNITS = 2         # units of DZ-0002 the store consigns to the web
NEW_PRICE = 55000     # minor units: the hub's price change for DZ-0002


def dotnet():
    for cand in (os.environ.get("SAVIA_DOTNET"), str(Path.home() / ".dotnet-sdk-10.0.402" / "dotnet.exe")):
        if cand and Path(cand).exists():
            return cand
    return "dotnet"


# ---------------------------------------------------------------- state and transcript
def load(path, default):
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else default


def save(path, value):
    OUT.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=1, ensure_ascii=False), encoding="utf-8", newline="\n")


class Run:
    def __init__(self):
        self.s = load(STATE, {})
        self.t = load(TRANSCRIPT, [])

    def scrub(self, text):
        text = str(text)
        for v in sorted(self.s.get("secrets", []), key=len, reverse=True):
            text = text.replace(v, "***")
        text = re.sub(r"(Bearer|SaviaNode) [A-Za-z0-9._\-]{16,}", r"\1 ***", text)
        return text.replace(str(SAVIA.parent), "<repo>").replace(str(Path.home()), "<home>")

    def secret(self, value):
        self.s.setdefault("secrets", []).append(value)
        save(STATE, self.s)
        return value

    def record(self, step, title, status, tool, evidence):
        entry = {"step": step, "title": title, "status": status, "tool": self.scrub(tool),
                 "evidence": [self.scrub(e) for e in (evidence if isinstance(evidence, list) else [evidence])],
                 "at": time.strftime("%Y-%m-%d %H:%M:%S")}
        self.t.append(entry)
        save(TRANSCRIPT, self.t)
        print(f"step {step} {status}: {title}\n  tool: {entry['tool']}\n  " + "\n  ".join(entry["evidence"]), flush=True)

    # ---------------------------------------------------------------- SQL connection strings
    def sa(self):
        code, out = db.docker(["exec", db.CONTAINER, "printenv", "MSSQL_SA_PASSWORD"])
        if code:
            raise SystemExit("cannot read the container password")
        return out.strip()

    def conn(self, node, admin=False):
        user, pw = ("sa", self.sa()) if admin else (APP_LOGIN, self.s["appPassword"])
        return (f"Server=127.0.0.1,{SQL_PORT};Database={DBN[node]};User ID={user};Password={pw};"
                "TrustServerCertificate=True;Encrypt=True;Connect Timeout=15")

    def fetch(self, node, query):
        """A read for evidence only (counts and ids), never a write."""
        code, out = db.run_sql(DBN[node], "SET NOCOUNT ON; " + query, opts="-h -1 -W")
        if code:
            raise SystemExit(self.scrub(out))
        return [l for l in out.splitlines() if l.strip()]

    # ---------------------------------------------------------------- tools
    def migrator(self, node, *args, migrations=MIGRATIONS, extra_env=None):
        env = clean_env()
        env["Savia__Sql__ConnectionString"] = self.conn(node, admin=True)
        env.update(extra_env or {})
        p = subprocess.run([dotnet(), str(MIGRATOR_DLL), "--migrations", str(migrations), *args], env=env,
                           capture_output=True, text=True, timeout=600)
        for line in p.stdout.splitlines():  # register printed secrets before any of this output is formatted
            for prefix in (NODE_SECRET, STAFF_PASSWORD):
                if line.startswith(prefix):
                    self.secret(line[len(prefix):].strip())
        if p.returncode:
            raise SystemExit(f"migrator {' '.join(args)} on {node}: exit {p.returncode}\n{self.scrub(p.stdout + p.stderr)}")
        return p.stdout

    def printed(self, out, prefix):
        return next(l[len(prefix):].strip() for l in out.splitlines() if l.startswith(prefix))

    def host_env(self, node):
        s = self.s
        env = clean_env()
        env.update({"DOTNET_CLI_TELEMETRY_OPTOUT": "1", "DOTNET_NOLOGO": "1", "ASPNETCORE_ENVIRONMENT": "Production",
                    "ASPNETCORE_URLS": base(node), "Savia__Sql__ConnectionString": self.conn(node),
                    "Savia__Web__Root": str(SAVIA / "web"), "Savia__Auth__LoginPerMinute": "0",
                    "Savia__Node__NodeId": s["ids"][node + "Node"], "Savia__WebStore__SweepSeconds": "5"})
        if node == "hub":
            env.update({"Savia__Node__Kind": "Cloud", "Savia__Public__AllowedOrigins": STOREFRONT,
                        "Savia__Public__BotCheck": "disabled", "Savia__Public__OrderPageUrl": STOREFRONT + "/pedido"})
        else:
            env.update({"Savia__Node__Kind": "Branch", "Savia__Node__BranchId": s["ids"]["branch"],
                        "Savia__Node__LocationId": s["ids"]["location"], "Savia__Sync__HubUrl": base("hub"),
                        "Savia__Sync__NodeSecret": s["nodeSecret"], "Savia__Sync__IntervalSeconds": "5"})
        return env

    def start(self, node):
        log = OUT / f"host-{node}.txt"
        flags = getattr(subprocess, "CREATE_NO_WINDOW", 0) | getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
        with open(log, "ab") as f:
            proc = subprocess.Popen([dotnet(), str(API_DLL)], cwd=str(API_DLL.parent), env=self.host_env(node),
                                    stdout=f, stderr=subprocess.STDOUT, creationflags=flags)
        self.s.setdefault("pids", {})[node] = proc.pid
        save(STATE, self.s)
        deadline = time.time() + 90
        while time.time() < deadline:
            if proc.poll() is not None:
                raise SystemExit(f"{node} host exited {proc.returncode}; see {log}")
            if call(node, "GET", "/health/ready")[0] == 200:
                return proc.pid
            time.sleep(0.5)
        raise SystemExit(f"{node} host not ready in 90 s; see {log}")

    def stop(self, node):
        pid = self.s.get("pids", {}).pop(node, None)
        for one in pid if isinstance(pid, list) else [pid] if pid else []:
            subprocess.run(["taskkill", "/PID", str(one), "/T", "/F"], capture_output=True)
        if pid:
            save(STATE, self.s)
        return pid

    def log_text(self, node):
        path = OUT / f"host-{node}.txt"
        return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""

    def wait_log(self, node, pattern, after, timeout=90):
        deadline = time.time() + timeout
        while time.time() < deadline:
            m = re.search(pattern, self.log_text(node)[after:])
            if m:
                return m.group(0)
            time.sleep(1)
        return None

    def login(self, node, who):
        status, body = call(node, "POST", "/api/v1/auth/login",
                            {"loginName": self.s["staff"][who]["login"], "password": self.s["staff"][who]["password"]})
        if status != 200:
            raise SystemExit(f"login {who} at {node}: {status} {body}")
        return self.secret(body["token"])


def clean_env():
    return {k: v for k, v in os.environ.items()
            if not k.upper().startswith(("SAVIA", "OPENAI", "ASPNETCORE", "DOTNET_ENVIRONMENT"))}


def base(node):
    return f"http://127.0.0.1:{PORT[node]}"


def call(node, method, path, body=None, token=None, headers=None):
    """Returns (status, parsed body or text). Never raises on an HTTP status."""
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(base(node) + path, data=data, method=method)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            status, raw = r.status, r.read()
    except urllib.error.HTTPError as e:
        status, raw = e.code, e.read()
    except (urllib.error.URLError, ConnectionError, TimeoutError) as e:
        return 0, str(e)
    text = raw.decode("utf-8", errors="replace")
    try:
        return status, json.loads(text) if text else None
    except ValueError:
        return status, text


def short(status, body):
    if isinstance(body, dict):
        keep = {k: body[k] for k in list(body)[:6]}
        return f"{status} {json.dumps(keep, ensure_ascii=False)[:300]}"
    return f"{status} {str(body)[:200]}"


def new_id():
    return str(uuid.uuid4()).upper()


# ---------------------------------------------------------------- up: databases and steps 1-10
def cmd_up(_):
    if STATE.exists():
        raise SystemExit("a run is already up; run `down` first")
    for p in (API_DLL, MIGRATOR_DLL):
        if not p.exists():
            raise SystemExit(f"missing {p}; build it first")
    r = Run()
    r.t = []
    ids = {k: new_id() for k in ("hubNode", "storeNode", "branch", "location", "register",
                                 "owner", "manager", "cashier")}
    r.s = {"ids": ids, "secrets": [], "staff": {}}
    r.s["appPassword"] = r.secret(secrets.token_urlsafe(18) + "aA1")
    save(STATE, r.s)
    infra(r)
    step1_owner(r)
    step2_branch(r)
    step3_staff(r)
    step4_node(r)
    step5_hosts(r)
    step6_import(r)
    step7_arrive(r)
    step8_receive(r)
    step9_sale(r)
    step10_consign(r)
    print("hosts are up; do steps 11 and 12 in a browser, then run `verify`.")


def infra(r):
    """Step 0 is infrastructure, the local stand-in for creating the Azure SQL database and the managed identity."""
    for n in DBN.values():
        db.drop(n)
        code, out = db.create(n)
        if code:
            raise SystemExit(out)
    code, out = db.run_sql("master", f"IF SUSER_ID(N'{APP_LOGIN}') IS NOT NULL DROP LOGIN [{APP_LOGIN}]; "
                                     f"CREATE LOGIN [{APP_LOGIN}] WITH PASSWORD=N'{r.s['appPassword']}', CHECK_POLICY=OFF;")
    if code:
        raise SystemExit(r.scrub(out))
    lines = []
    for node in DBN:
        out = r.migrator(node, "--grant-app-user", APP_LOGIN)
        lines.append(f"{node}: " + " | ".join(l for l in out.splitlines() if l.startswith("migrate: ledger") or "permissions" in l))
    r.record(0, "two empty databases, migrated by the production migrator; API login in savia_api_host only", "DONE",
             f"CREATE DATABASE (infra); Savia.Migrator --migrations db/migrations --grant-app-user {APP_LOGIN}", lines)


def provision_staff(r, node, who, role, branch, password):
    """Savia.Migrator --provision-staff. password: None (no password on this database), "print" (the migrator prints
    a one-time password), or "given" (the run's throwaway password through SAVIA_STAFF_PASSWORD)."""
    st, i = r.s["staff"][who], r.s["ids"]
    args = ["--provision-staff", "--staff-id", i[who], "--login", st["login"], "--display-name", st["name"], "--role", role]
    if branch:
        args += ["--branch-id", i["branch"]] + (["--approver"] if role == "MANAGER" else [])
    if password:
        args.append("--set-password")
    out = r.migrator(node, *args, extra_env={"SAVIA_STAFF_PASSWORD": st["password"]} if password == "given" else None)
    if password == "print":
        st["password"] = r.printed(out, STAFF_PASSWORD)
        save(STATE, r.s)
    return f"{node}: " + r.scrub(out).strip().replace("\n", " | ")


def step1_owner(r):
    r.s["staff"]["owner"] = {"login": "duena.dz", "name": "Dueña Día Cero"}
    save(STATE, r.s)
    line = provision_staff(r, "hub", "owner", "OWNER", False, "print")
    mark = r.fetch("hub", f"SELECT CAST(MustChangePassword AS int) FROM security.Staff WHERE Id='{r.s['ids']['owner']}';")[-1]
    r.record(1, "first hub OWNER account", "DONE" if mark == "1" else "BLOCKED",
             "Savia.Migrator --provision-staff --role OWNER --set-password on the hub (prints a one-time password once)",
             [line, f"security.Staff.MustChangePassword on the hub: {mark} (V064: the owner must replace it at the first sign-in)",
              "the owner changes it and signs in on the hub in steps 6 and 12"])


BRANCH = ["--branch-code", "DZ_MASAYA", "--branch-name", "Masaya día cero", "--store-name", "SAVIA Masaya",
          "--location-code", "DZ_MASAYA_TIENDA", "--location-name", "Tienda Masaya", "--register-code", "CAJA1",
          "--register-name", "Caja 1"]


def step2_branch(r):
    i = r.s["ids"]
    args = ["--provision-branch", "--branch-id", i["branch"], "--location-id", i["location"], "--register-id", i["register"],
            *BRANCH]
    lines = [f"{node}: " + r.scrub(r.migrator(node, *args)).strip() for node in DBN]
    lines.append("retry on the store: " + r.scrub(r.migrator("store", *args)).strip())
    counts = {n: r.fetch(n, "SELECT CONCAT((SELECT COUNT(*) FROM core.Branches),'/',(SELECT COUNT(*) FROM core.Locations),'/',"
                            "(SELECT COUNT(*) FROM sales.CashRegisters));")[-1] for n in DBN}
    r.record(2, "store branch, location and register on hub and store (same ids)", "DONE",
             "Savia.Migrator --provision-branch on both databases", lines + [f"branches/locations/registers: {counts}"])


def step3_staff(r):
    for who, login, name in (("manager", "gerente.dz", "Gerente Día Cero"), ("cashier", "cajera.dz", "Cajera Día Cero")):
        r.s["staff"][who] = {"login": login, "name": name, "password": r.secret(secrets.token_urlsafe(12) + "aA1")}
    save(STATE, r.s)
    lines = [provision_staff(r, node, who, role, True, "given")
             for node in DBN for who, role in (("manager", "MANAGER"), ("cashier", "CASHIER"))]
    # Staff is not synced (V053): the owner's row must exist on the store for the rows the owner writes on the hub.
    lines.append(provision_staff(r, "store", "owner", "OWNER", False, None))
    r.record(3, "store staff: a manager and a cashier (and the owner's row on the store)", "DONE",
             "Savia.Migrator --provision-staff on both databases; one password per person through SAVIA_STAFF_PASSWORD",
             lines)


def step4_node(r):
    i = r.s["ids"]
    hub = ["--node-id", i["hubNode"], "--node-kind", "azure", "--node-code", "DZ_HUB"]
    store = ["--node-id", i["storeNode"], "--branch-id", i["branch"], "--node-code", "DZ_MASAYA"]
    lines = [f"{node}: " + r.migrator(node, "--provision-node", "register", *args).strip()
             for node, args in (("hub", hub), ("store", hub), ("store", store))]
    # As on Azure (RUNBOOK 3.1): the operator generates the secret and passes it in SAVIA_NODE_SECRET; nothing is printed.
    secret = r.secret(secrets.token_urlsafe(32))
    out = r.migrator("hub", "--provision-node", "create", *store, extra_env={"SAVIA_NODE_SECRET": secret})
    if secret in out or NODE_SECRET in out:
        raise SystemExit("the migrator printed the node secret it was given")
    r.s["nodeSecret"] = secret
    save(STATE, r.s)
    lines.append("hub: " + r.scrub(out).strip().replace("\n", " | "))
    lines.append("migrator output holds no node-secret line and not the given value")
    hub_rows = r.fetch("hub", "SELECT CONCAT(NodeCode,':',Kind) FROM sync.Nodes ORDER BY NodeCode;")
    r.record(4, "node rows on both databases; store credential; store host configured with it", "DONE",
             "Savia.Migrator --provision-node register (hub node on the hub and the store, store node on the store) and "
             "create with SAVIA_NODE_SECRET (store node on the hub); the same value goes to the store host's Savia__Sync__NodeSecret",
             lines + [f"hub sync.Nodes: {hub_rows}"])


def step5_hosts(r):
    mark = len(r.log_text("store"))  # host logs are appended across runs: read only the lines of this start
    pids = {n: r.start(n) for n in ("hub", "store")}
    line = r.wait_log("store", r"Sync round(?: refused| could not reach| timed out| failed|: pulled)[^\r\n]*", mark, timeout=60)
    ok = bool(line and "pulled" in line)
    r.record(5, "both hosts start; first sync round", "DONE" if ok else "BLOCKED",
             "Savia.Api (hub Kind=Cloud, store Kind=Branch), store SyncWorker every 5 s",
             [f"host pids {pids}", f"first store round: {line}"])
    if not ok:
        raise SystemExit("first sync round failed; see " + str(OUT / "host-store.txt"))


def change_owner_password(r):
    """V064: the printed one-time password opens only the password change; afterwards every route answers."""
    owner = r.login("hub", "owner")
    # The hub has no stock location, so probe a hub route that needs none: the catalog lookup.
    probe = "/api/v1/catalog/lookup?code=DZ-0001"
    gate = call("hub", "GET", probe, token=owner)
    me = call("hub", "GET", "/api/v1/me", token=owner)
    st = r.s["staff"]["owner"]
    new = r.secret(secrets.token_urlsafe(16))
    change = call("hub", "POST", "/api/v1/auth/password", {"currentPassword": st["password"], "newPassword": new}, owner)
    if change[0] == 204:
        st["password"] = new
        save(STATE, r.s)
    after = call("hub", "GET", probe, token=owner)
    flag = me[1].get("mustChangePassword") if me[0] == 200 and isinstance(me[1], dict) else None
    ok = (gate[0] == 403 and isinstance(gate[1], dict) and gate[1].get("code") == "auth.password_change_required"
          and flag is True and change[0] == 204 and after[0] == 200)
    evidence = [f"before the change: GET /catalog/lookup {short(*gate)}", f"GET /me {me[0]} mustChangePassword={flag}",
                f"POST /auth/password {change[0]}", f"after the change, same session: GET /catalog/lookup {after[0]}"]
    return owner, ok, evidence


def step6_import(r):
    owner, changed, change_evidence = change_owner_password(r)
    rows = [{"row": n + 2, "code": c, "sku": None, "name": name, "type": kind, "size": size, "color": color,
             "cost": cost, "price": price, "stock": None} for n, (c, name, kind, size, color, cost, price) in enumerate(PRODUCTS)]
    request = {"batchId": new_id(), "fileName": "dia-cero.csv", "rows": rows}
    preview = call("hub", "POST", "/api/v1/catalog/import/preview", request, owner)
    result = call("hub", "POST", "/api/v1/catalog/import", request, owner)
    items = {}
    for code, *_ in PRODUCTS:
        status, body = call("hub", "GET", f"/api/v1/catalog/lookup?code={code}", token=owner)
        items[code] = body[0]["itemId"] if status == 200 and body else None
    r.s["items"] = items
    save(STATE, r.s)
    price = call("hub", "POST", f"/api/v1/catalog/items/{items['DZ-0002']}/values",
                 {"changeId": new_id(), "priceMinor": NEW_PRICE, "costMinor": 18000, "reason": "Día cero: precio de lanzamiento"}, owner)
    ok = changed and result[0] == 200 and all(items.values()) and price[0] == 204
    r.record(6, "owner replaces the one-time password; hub imports 3 products and sets a price", "DONE" if ok else "BLOCKED",
             "POST /api/v1/auth/password, then /catalog/import/preview, /catalog/import, GET /catalog/lookup, "
             "POST /catalog/items/{id}/values (OWNER on the hub)",
             change_evidence + [f"preview {short(*preview)}", f"import {short(*result)}", f"items {items}",
                                f"price DZ-0002 -> {NEW_PRICE}: {short(*price)}"])


def wait_store(r, check, timeout=90):
    deadline = time.time() + timeout
    while time.time() < deadline:
        got = check()
        if got:
            return got
        time.sleep(2)
    return None


def step7_arrive(r):
    cashier = r.login("store", "cashier")

    def arrived():
        found = {}
        for code, *_ in PRODUCTS:
            status, body = call("store", "GET", f"/api/v1/catalog/lookup?code={code}", token=cashier)
            if status != 200 or not body:
                return None
            found[code] = body[0]["unitPriceMinor"]
        return found if found["DZ-0002"] == NEW_PRICE else None
    got = wait_store(r, arrived)
    r.record(7, "the products and the new price arrive on the store", "DONE" if got else "BLOCKED",
             "store SyncWorker; GET /api/v1/catalog/lookup on the store", [f"store prices (minor): {got}"])


def step8_receive(r):
    sup = r.login("store", "manager")
    cashier = r.login("store", "cashier")
    supplier = new_id()
    created = call("hub", "POST", "/api/v1/suppliers", {"supplierId": supplier, "name": "Proveedor día cero"},
                   r.login("hub", "owner"))
    arrived = wait_store(r, lambda: call("store", "GET", "/api/v1/suppliers", token=cashier)[1])
    evidence = [f"hub POST /suppliers (owner): {short(*created)}", f"suppliers on the store after sync: {arrived}"]
    tool = ("POST /api/v1/suppliers (hub owner); POST /api/v1/receiving/sessions, /scans, /approve, /post "
            "(cashier scans, manager approves and posts)")
    blocked = created[0] != 204 or not arrived
    session, results = new_id(), []
    results.append(("open", call("store", "POST", "/api/v1/receiving/sessions",
                                 {"containerId": new_id(), "scanSessionId": session, "reference": "DIA-CERO-1",
                                  "supplierId": supplier}, cashier)))
    for code, *_ in PRODUCTS:
        results.append((f"scan {code}", call("store", "POST", f"/api/v1/receiving/sessions/{session}/scans",
                                              {"scanId": new_id(), "rawCode": code, "quantity": RECEIVED}, cashier)))
    results.append(("approve", call("store", "POST", f"/api/v1/receiving/sessions/{session}/approve", None, sup)))
    results.append(("post", call("store", "POST", f"/api/v1/receiving/sessions/{session}/post", None, sup)))
    bad = [n for n, (st, _) in results if st not in (200, 201, 204)]
    stock = call("store", "GET", "/api/v1/stock", token=sup)
    r.record(8, f"the store receives {RECEIVED} units of each product", "BLOCKED" if blocked or bad else "DONE",
             tool, evidence + [f"{n}: {short(*res)}" for n, res in results] + [f"GET /stock: {short(*stock)}"])


def step9_sale(r):
    cashier = r.login("store", "cashier")
    till = new_id()
    opened = call("store", "POST", "/api/v1/cash/tills",
                  {"tillId": till, "registerId": r.s["ids"]["register"], "currencyCode": "NIO", "openingMinor": 100000,
                   "lines": [{"denominationMinor": 50000, "quantity": 2}]}, cashier)
    price = 95000
    sale = call("store", "POST", "/api/v1/sales",
                {"saleId": new_id(), "tillId": till, "currencyCode": "NIO",
                 "lines": [{"lineNumber": 1, "itemId": r.s["items"]["DZ-0001"], "quantity": 1, "unitPriceMinor": price}],
                 "tenders": [{"tenderNumber": 1, "tenderKind": "cash", "amountMinor": price, "receivedMinor": price,
                              "changeMinor": 0}]}, cashier)
    ok = opened[0] in (200, 201, 204) and sale[0] in (200, 201, 204)
    r.record(9, "open a till and make one counter sale", "DONE" if ok else "BLOCKED",
             "POST /api/v1/cash/tills, POST /api/v1/sales (cashier)", [f"till {short(*opened)}", f"sale {short(*sale)}"])


def step10_consign(r):
    sup = r.login("store", "manager")
    item = r.s["items"]["DZ-0002"]
    consigned = call("store", "POST", "/api/v1/stock/web-consignments",
                     {"consignmentId": new_id(), "itemId": item, "qty": WEB_UNITS, "fromLocationId": r.s["ids"]["location"]}, sup)

    def on_catalog():
        status, body = call("hub", "GET", "/api/v1/public/catalog")
        rows = body.get("items", body) if isinstance(body, dict) else body
        hit = [x for x in (rows or []) if isinstance(x, dict) and x.get("sku") and x.get("available")]
        return hit or None
    got = wait_store(r, on_catalog, timeout=120)
    r.record(10, f"the store consigns {WEB_UNITS} units of DZ-0002 to the web; the hub's public catalog shows it",
             "DONE" if consigned[0] in (200, 201, 204) and got else "BLOCKED",
             "POST /api/v1/stock/web-consignments (manager, store); sync; hub sweep; GET /api/v1/public/catalog",
             [f"consign {short(*consigned)}", f"public catalog rows with stock: {json.dumps(got, ensure_ascii=False)[:400]}"])


# ---------------------------------------------------------------- note, reserve, verify, skew
def cmd_note(a):
    Run().record(a.step, a.title, a.status, a.tool, a.evidence)


def web_reserved(r):
    """Units of DZ-0002 reserved at the hub's web locations (WEB-<store location>; evidence read)."""
    item = r.s["items"]["DZ-0002"]
    return int(r.fetch("hub", f"SELECT CONCAT(SUM(b.Reserved),'') FROM inventory.StockBalances b JOIN core.Locations l "
                              f"ON l.Id=b.LocationId WHERE b.ItemId='{item}' AND l.Code LIKE 'WEB-%';")[-1] or 0)


def cmd_reserve(_):
    """W2 after the browser order of one unit: the hub holds it reserved. Then one public order sent twice with one
    Idempotency-Key (a double click) must store one order and reserve one more unit. That order stays unpaid and
    expires by itself."""
    r = Run()
    before = web_reserved(r)
    body = {"lines": [{"sku": "DZ-0002", "qty": 1}],
            "contact": {"name": "Compradora Reintento", "email": "reintento.dz@example.test", "phone": None},
            "shipping": {"zone": "managua", "address": "Calle de prueba 1", "city": "Managua", "notes": None},
            "provider": "manual", "locale": "es", "turnstileToken": None}
    headers = {"Idempotency-Key": str(uuid.uuid4()), "Origin": STOREFRONT}
    sent = [call("hub", "POST", "/api/v1/public/orders", body, headers=headers) for _ in range(2)]
    after = web_reserved(r)
    ids = [b.get("orderId") if isinstance(b, dict) else None for _, b in sent]
    for _, b in sent:
        if isinstance(b, dict) and b.get("accessToken"):
            r.secret(b["accessToken"])
    ok = bool(ids[0]) and ids[0] == ids[1] and (before, after) == (1, 2)
    r.record(11.1, "W2: the browser order reserves hub web stock; one order sent twice is stored once",
             "DONE" if ok else "BLOCKED",
             "POST /api/v1/public/orders twice with one Idempotency-Key; evidence reads of the hub web location's Reserved",
             [f"DZ-0002 reserved at the hub web location after the browser order: {before} (expected 1)",
              f"POST statuses {[s for s, _ in sent]}, codes {[b.get('code') if isinstance(b, dict) else b for _, b in sent]}, "
              f"order ids equal and present: {bool(ids[0]) and ids[0] == ids[1]}",
              f"reserved after the replay: {after} (expected 2: one new order, not two)"])


def cmd_verify(_):
    """Step 13. Web stock lives on the hub after consignment (ORDER-PATH.md), so the store's pool must not move
    with the web sale; the order itself is checked on the hub and the store is searched for any order notice."""
    r = Run()
    sup = r.login("store", "manager")
    item = r.s["items"]["DZ-0002"]
    store_stock = [x for x in call("store", "GET", "/api/v1/stock", token=sup)[1] if x["itemId"].upper() == item.upper()]
    owner = r.login("hub", "owner")
    status, orders = call("hub", "GET", "/api/v1/web-orders", token=owner)
    order = [(o.get("code"), o.get("status")) for o in orders] if status == 200 else orders
    web = r.fetch("hub", f"SELECT CONCAT(l.Code,'=',b.OnHand,'/',b.Reserved) FROM inventory.StockBalances b "
                         f"JOIN core.Locations l ON l.Id=b.LocationId WHERE b.ItemId='{item}' ORDER BY l.Code;")
    notices = r.fetch("store", "SELECT CONCAT(COUNT(*),'') FROM webstore.Orders;")[-1]
    stock_ok = [x["onHand"] for x in store_stock] == [RECEIVED - WEB_UNITS]
    fulfilled = status == 200 and [s for _, s in order].count("fulfilled") == 1
    r.record(13.1, "buyer page paid then fulfilled; hub order fulfilled; store stock after sync",
             "DONE" if stock_ok and fulfilled else "BLOCKED",
             "browser order page (step 12 screenshots); GET /api/v1/web-orders (hub); GET /api/v1/stock (store); "
             "evidence read of the hub's StockBalances",
             [f"hub orders: {order}", f"hub DZ-0002 balances (onHand/reserved): {web}",
              f"store GET /stock DZ-0002 onHand: {[x['onHand'] for x in store_stock]} (expected {RECEIVED - WEB_UNITS}: "
              f"received {RECEIVED}, consigned {WEB_UNITS}; the web sale moves hub stock only)"])
    r.record(13.2, "order or payment notice on the store", "DONE" if notices != "0" else "BLOCKED",
             "evidence read of webstore.Orders on the store; the store's #/pedidos-web screen",
             [f"webstore.Orders rows on the store: {notices}"]
             + ([] if notices != "0" else ["OPEN GAP by design (ORDER-PATH.md): web stock moves to the hub at consignment "
                                           "and web orders are worked on the hub screen; webstore.Orders is not synced and "
                                           "the store's #/pedidos-web says orders are handled on the hub"]))


def cmd_skew(_):
    r = Run()
    nxt = OUT / "migrations-next"
    shutil.rmtree(nxt, ignore_errors=True)
    shutil.copytree(MIGRATIONS, nxt)
    (nxt / "V999__dayzero_empty_test.sql").write_text("-- Day-zero D3 test: an empty migration.\nSELECT 1;\n", encoding="utf-8")
    hub_out = r.migrator("hub", migrations=nxt)
    mark = len(r.log_text("store"))
    refused = r.wait_log("store", r"Sync round refused[^\r\n]*", mark, timeout=60)
    r.record(14.1, "empty test migration V999 on the hub only; the store is refused", "DONE" if refused and "schema_mismatch" in refused else "BLOCKED",
             "Savia.Migrator on the hub database", [l for l in hub_out.splitlines() if "applying" in l or "ledger" in l] + [f"store log: {refused}"])
    pid = r.stop("store")
    store_out = r.migrator("store", migrations=nxt)
    restart = len(r.log_text("store"))
    r.start("store")
    resumed = r.wait_log("store", r"Sync round: pulled[^\r\n]*", restart, timeout=60)
    r.record(14.2, "store upgrade: stop the store host, migrate its database, start it; sync resumes", "DONE" if resumed else "BLOCKED",
             "stop host; Savia.Migrator on the store database; start host",
             [f"stopped pid {pid}"] + [l for l in store_out.splitlines() if "applying" in l or "ledger" in l] + [f"store log: {resumed}"])


def applied_range(text):
    """'applied now: V001__a.sql, ..., V062__b.sql' -> 'applied now: V001..V062 (56 files)'."""
    def shorten(m):
        names = m.group(1).split(", ")
        return f"applied now: {names[0][:4]}..{names[-1][:4]} ({len(names)} files)"
    return re.sub(r"applied now: (V\d{3}__\w+\.sql(?:, V\d{3}__\w+\.sql)+)", shorten, text)


def cmd_report(a):
    entries = load(Path(a.transcript), []) if a.transcript else Run().t
    lines = ["| Step | Status | Tool | Evidence |", "| --- | --- | --- | --- |"]
    for e in entries:
        ev = "<br>".join(applied_range(x).replace("|", "\\|") for x in e["evidence"])
        lines.append(f"| {e['step']} {e['title']} | {e['status']} | {e['tool'].replace('|', '/')} | {ev} |")
    Path(a.out).write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {a.out}")


def cmd_down(_):
    r = Run()
    stopped = [r.stop(n) for n in list(r.s.get("pids", {}))]
    for n in DBN.values():
        db.drop(n)
    db.run_sql("master", f"IF SUSER_ID(N'{APP_LOGIN}') IS NOT NULL DROP LOGIN [{APP_LOGIN}];")
    STATE.unlink(missing_ok=True)
    shutil.rmtree(OUT / "migrations-next", ignore_errors=True)
    print(f"stopped {stopped}; dropped {list(DBN.values())}; login {APP_LOGIN} removed")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("up")
    n = sub.add_parser("note")
    n.add_argument("--step", type=float, required=True)
    n.add_argument("--title", required=True)
    n.add_argument("--status", required=True, choices=["DONE", "BLOCKED"])
    n.add_argument("--tool", required=True)
    n.add_argument("--evidence", action="append", default=[])
    sub.add_parser("reserve")
    sub.add_parser("verify")
    sub.add_parser("skew")
    rp = sub.add_parser("report")
    rp.add_argument("--out", required=True)
    rp.add_argument("--transcript", help="a saved transcript JSON instead of the current run's")
    sub.add_parser("down")
    a = p.parse_args()
    {"up": cmd_up, "note": cmd_note, "reserve": cmd_reserve, "verify": cmd_verify, "skew": cmd_skew, "report": cmd_report, "down": cmd_down}[a.cmd](a)


if __name__ == "__main__":
    main()

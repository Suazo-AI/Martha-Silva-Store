#!/usr/bin/env python3
"""SAVIA single-branch pilot ("Masaya") on this PC. Local only: loopback API, dev container database.

Commands:
  up       create or reuse SAVIA_DEV_pilot, migrate, seed sample data, set sample passwords,
           then start the API on http://127.0.0.1:5080 (branch node Masaya) in the background
  down     stop the pilot API
  reset    stop the API, then drop and recreate SAVIA_DEV_pilot (empty; run `up` next)
  status   database, seed counts, API process and /health
  counts   seed row counts as one line (used to prove `up` is idempotent)

Secrets:
  The SQL password is read from savia/infra/.env (MSSQL_SA_PASSWORD), or SAVIA_ENV_FILE, or the dev container's
  own environment. It reaches the API only through its process environment and is never printed.
  Each sample staff password comes from SAVIA_PILOT_PASSWORD_CAJERA / _SUPERVISORA / _DUENA, or a hidden prompt.
  Shared SAVIA_PILOT_PASSWORD is refused unless SAVIA_PILOT_ALLOW_SHARED=1. up --no-provision only checks hashes.
  Passwords never come from a file in the repository. Sample logins: duena.muestra, supervisora.muestra, cajera.muestra.
"""
import argparse
import getpass
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]           # .../savia
sys.path.insert(0, str(ROOT / "tools" / "db"))
sys.path.insert(0, str(ROOT / "tools"))
import saviadb                                        # noqa: E402
from check import dotnet                              # noqa: E402

DB = "SAVIA_DEV_pilot"
HOST, PORT = "127.0.0.1", 5080
URL = f"http://{HOST}:{PORT}"
SEED = ROOT / "db" / "pilot" / "seed_masaya.sql"
API_PROJECT = ROOT / "src" / "Savia.Api"
API_DLL = API_PROJECT / "bin" / "Debug" / "net10.0" / "Savia.Api.dll"
STATE = ROOT / ".out" / "pilot"
PID_FILE = STATE / "api.pid"
LOG_FILE = STATE / "api.log"
NODE = {
    "Savia__Pilot__LocalCatalog": "true",
    "Savia__Node__Kind": "Branch",
    "Savia__Node__NodeId": "5A000000-0000-0000-0000-000000000D01",
    "Savia__Node__BranchId": "5A000000-0000-0000-0000-000000000B01",
    "Savia__Node__LocationId": "5A000000-0000-0000-0000-000000000A01",
}
LOGINS = "duena.muestra,supervisora.muestra,cajera.muestra"
COUNTS_SQL = """SET NOCOUNT ON;
SELECT CONCAT('branches=',(SELECT COUNT(*) FROM core.Branches),
 ' locations=',(SELECT COUNT(*) FROM core.Locations),' registers=',(SELECT COUNT(*) FROM sales.CashRegisters),
 ' nodes=',(SELECT COUNT(*) FROM sync.Nodes),' localnode=',(SELECT COUNT(*) FROM sync.LocalNode),
 ' staff=',(SELECT COUNT(*) FROM security.Staff),' staffroles=',(SELECT COUNT(*) FROM security.StaffRoles),
 ' access=',(SELECT COUNT(*) FROM security.StaffBranchAccess),' suppliers=',(SELECT COUNT(*) FROM sourcing.Suppliers),
 ' customers=',(SELECT COUNT(*) FROM crm.Customers),' sizes=',(SELECT COUNT(*) FROM catalog.Sizes),
 ' colors=',(SELECT COUNT(*) FROM catalog.Colors),' products=',(SELECT COUNT(*) FROM catalog.Products),
 ' items=',(SELECT COUNT(*) FROM catalog.Items),' identifiers=',(SELECT COUNT(*) FROM catalog.ItemIdentifiers),
 ' outbox=',(SELECT COUNT(*) FROM sync.Outbox));"""


def say(msg):
    print(f"pilot: {msg}", flush=True)


def env_file_values():
    path = Path(os.environ.get("SAVIA_ENV_FILE") or ROOT / "infra" / ".env")
    values = {}
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                key, value = line.split("=", 1)
                value = value.strip()
                if len(value) >= 2 and value[0] == value[-1] and value[0] in ('"', "'"):
                    value = value[1:-1]
                values[key.strip()] = value
    return values


def connection_string():
    """Built in memory; never printed or written to disk."""
    values = env_file_values()
    password = values.get("MSSQL_SA_PASSWORD")
    if not password or password.startswith("REPLACE_"):
        code, out = saviadb.docker(["exec", saviadb.CONTAINER, "printenv", "MSSQL_SA_PASSWORD"])
        if code != 0:
            raise SystemExit("pilot: cannot read the SQL password (no savia/infra/.env and the container did not answer).")
        password = out.strip()
    code, out = saviadb.docker(["port", saviadb.CONTAINER, "1433/tcp"])
    port = out.strip().splitlines()[0].rsplit(":", 1)[-1] if code == 0 and out.strip() else values.get("SAVIA_SQL_PORT")
    if not port:
        raise SystemExit("pilot: cannot find the SQL port of the dev container.")
    quoted_password = '"' + password.replace('"', '""') + '"'
    return (f"Server=127.0.0.1,{port};Database={DB};User ID=sa;Password={quoted_password};"
            "Encrypt=True;TrustServerCertificate=True;Connect Timeout=15")


def require_container():
    code, out = saviadb.docker(["inspect", "-f", "{{.State.Status}}", saviadb.CONTAINER])
    if code != 0 or out.strip() != "running":
        raise SystemExit(f"pilot: container {saviadb.CONTAINER} is not running. Start Docker Desktop, then `python savia/tools/db/saviadb.py up`.")


def db_exists():
    return saviadb.scalar("master", f"SELECT COUNT(*) FROM sys.databases WHERE name=N'{DB}';") == "1"


def counts():
    code, out = saviadb.run_sql(DB, COUNTS_SQL)
    if code != 0:
        raise SystemExit(f"pilot: counts failed\n{out}")
    lines = [l.strip() for l in out.splitlines() if l.strip().startswith("branches=")]
    return lines[-1] if lines else "?"


def health():
    try:
        with urllib.request.urlopen(URL + "/health", timeout=2) as r:
            return r.status
    except Exception:
        return None


def api_pid():
    try:
        pid = int(PID_FILE.read_text().strip())
    except (OSError, ValueError):
        return None
    if pid <= 0:
        return None
    # PID reuse must never allow us to stop another .NET service. Read command line locally.
    if os.name == "nt":
        command = f"(Get-CimInstance Win32_Process -Filter 'ProcessId = {pid}').CommandLine"
        result = subprocess.run(["powershell", "-NoProfile", "-NonInteractive", "-Command", command],
                                capture_output=True, text=True)
        out = result.stdout.strip()
    else:
        try:
            out = Path(f"/proc/{pid}/cmdline").read_bytes().decode().replace('\x00', ' ')
        except OSError:
            return None
    # Require the full, exact DLL argument, including its directory.
    args = re.findall(r'"([^"]*)"|(\S+)', out)
    expected = str(API_DLL).replace('\\', '/').casefold()
    return pid if any((a or b).replace('\\', '/').casefold() == expected for a, b in args) else None


def stop_api():
    pid = api_pid()
    if pid:
        subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"], capture_output=True)
        for _ in range(50):
            if api_pid() is None and health() is None:
                break
            time.sleep(0.2)
        say(f"stopped API pid {pid}")
    PID_FILE.unlink(missing_ok=True)


def pilot_passwords(roles=("CAJERA", "SUPERVISORA", "DUENA")):
    shared = os.environ.get("SAVIA_PILOT_PASSWORD")
    if shared and os.environ.get("SAVIA_PILOT_ALLOW_SHARED") != "1":
        raise SystemExit("pilot: SAVIA_PILOT_PASSWORD requires SAVIA_PILOT_ALLOW_SHARED=1; use one password per login.")
    passwords = {}
    for role in roles:
        key = "SAVIA_PILOT_PASSWORD_" + role
        value = os.environ.get(key) or shared
        if not value and sys.stdin.isatty():
            value = getpass.getpass(f"Sample {role} password (10+ chars, not stored): ")
        if not value:
            raise SystemExit(f"pilot: set {key} or use up --no-provision for existing hashes.")
        passwords[key] = value
    return passwords


def cmd_up(args):
    require_container()
    dn = dotnet()
    if dn is None:
        raise SystemExit("pilot: .NET SDK not found. Set SAVIA_DOTNET.")
    created = not db_exists()
    code, out = saviadb.create(DB)
    if code != 0:
        raise SystemExit(f"pilot: create failed\n{out}")
    say(("created " if created else "reusing ") + DB)
    code, out = saviadb.migrate(DB)
    say(f"migrate exit={code} {out.strip().splitlines()[-1] if out.strip() else ''}")
    if code != 0:
        raise SystemExit(out)
    code, out = saviadb.run_sql(DB, SEED.read_text(encoding="utf-8"))
    if code != 0:
        raise SystemExit(f"pilot: seed failed\n{out}")
    say(f"seed ok: {counts()}")

    stop_api()
    if health() is not None:
        raise SystemExit(f"pilot: {URL} answers but is not the pilot API started here. Stop that process first.")
    build = subprocess.run([dn, "build", str(API_PROJECT), "-nologo", "-v", "q"], cwd=ROOT, capture_output=True, text=True)
    if build.returncode != 0:
        raise SystemExit("pilot: build failed\n" + build.stdout[-3000:])
    say("build ok")

    env = {**os.environ, **NODE, "Savia__Sql__ConnectionString": connection_string(),
           "Savia__Web__Root": str(ROOT / "web"), "ASPNETCORE_ENVIRONMENT": "Development",
           "DOTNET_CLI_TELEMETRY_OPTOUT": "1"}
    # Loopback only: drop inherited ASP.NET endpoint settings that would override --urls (review finding, 2026-11-12).
    for key in [k for k in env if k.upper().startswith(("KESTREL__", "ASPNETCORE_URLS", "ASPNETCORE_HTTP_PORTS",
                                                         "ASPNETCORE_HTTPS_PORTS", "DOTNET_URLS", "URLS"))]:
        env.pop(key)
    passwords = {} if args.no_provision else pilot_passwords()
    provision_env = {**env, **passwords, "Savia__Provision__Logins": LOGINS,
                     "Savia__Provision__CheckOnly": str(args.no_provision).lower()}
    prov = subprocess.run([dn, str(API_DLL), "provision-passwords"], cwd=API_PROJECT, env=provision_env,
                          capture_output=True, text=True)
    for line in (prov.stdout + prov.stderr).splitlines():
        if line.startswith("provision:"):
            say(line[len("provision: "):])
    if prov.returncode != 0:
        raise SystemExit("pilot: password provisioning failed; all sample logins need hashes for --no-provision.")

    STATE.mkdir(parents=True, exist_ok=True)
    for key in list(env):
        if key.startswith("SAVIA_PILOT_PASSWORD") or key == "SAVIA_PILOT_ALLOW_SHARED":
            env.pop(key)
    log = open(LOG_FILE, "ab")
    flags = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
    proc = subprocess.Popen([dn, str(API_DLL), "--urls", URL], cwd=API_PROJECT, env=env, stdout=log,
                            stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, creationflags=flags)
    PID_FILE.write_text(str(proc.pid))
    for _ in range(150):
        if health() == 200:
            say(f"API up at {URL} pid {proc.pid} (log: {LOG_FILE.relative_to(ROOT)})")
            return 0
        if proc.poll() is not None:
            break
        time.sleep(0.2)
    raise SystemExit(f"pilot: API did not become healthy; see {LOG_FILE}")


def cmd_down(_):
    stop_api()
    return 0


def cmd_reset(_):
    require_container()
    stop_api()
    for step in (saviadb.drop, saviadb.create):
        code, out = step(DB)
        if code != 0:
            raise SystemExit(f"pilot: {step.__name__} failed\n{out}")
    say(f"{DB} dropped and recreated (empty). Next: python savia/tools/pilot.py up")
    return 0


def cmd_status(_):
    require_container()
    exists = db_exists()
    say(f"database {DB}: {'present' if exists else 'missing'}")
    if exists:
        applied = saviadb.scalar(DB, "SELECT CASE WHEN OBJECT_ID(N'dbo.SaviaMigrations') IS NULL THEN 0 ELSE (SELECT COUNT(*) FROM dbo.SaviaMigrations) END;")
        say(f"migrations applied: {applied}")
        if applied != "0":
            say(f"counts: {counts()}")
    pid = api_pid()
    say(f"api: pid {pid if pid else 'none'}, {URL}/health -> {health() or 'no answer'}")
    return 0


def cmd_counts(_):
    print(counts())
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["up", "down", "reset", "status", "counts"])
    parser.add_argument("--no-provision", action="store_true", help="up: verify all sample password hashes without changing them")
    args = parser.parse_args()
    return {"up": cmd_up, "down": cmd_down, "reset": cmd_reset, "status": cmd_status, "counts": cmd_counts}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())

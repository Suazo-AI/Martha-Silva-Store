#!/usr/bin/env python3
"""SAVIA development database tool. It only talks to the local dev container.

It never needs the SQL password: commands run inside the container, where the
password already lives in the container environment. Works from any checkout or
worktree on this machine while the container `savia-sqlserver-dev` is running.

Commands:
  status                    container state and SQL Server version
  up                        start the container (needs savia/infra/.env in this checkout)
  create NAME | drop NAME   NAME must look like SAVIA_DEV_x, SAVIA_T_x or SAVIA_SIM_x
  migrate NAME              apply db/migrations/V*.sql that are not applied yet
  clone NAME                fast copy of the migrated template (migrations + test fixture)
  run NAME FILE.sql         run one script with QUOTED_IDENTIFIER ON; exit code follows SQL errors
  test [PATTERN] [--jobs N] [--json] [--keep]
                            run db/tests/**/*.sql, each on its own fresh database
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
import re
import subprocess
import sys
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]          # .../savia
MIGRATIONS = ROOT / "db" / "migrations"
TESTS = ROOT / "db" / "tests"
OUT = ROOT / ".out" / "dbtests"
# SAVIA_SQL_CONTAINER selects another local SAVIA container, e.g. savia-sqlserver-express (F12).
CONTAINER = os.environ.get("SAVIA_SQL_CONTAINER", "savia-sqlserver-dev")
if not re.fullmatch(r"savia-sqlserver-[a-z0-9-]{1,40}", CONTAINER):
    sys.exit(f"SAVIA_SQL_CONTAINER must look like savia-sqlserver-x, got {CONTAINER!r}")
SQLCMD = '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C'
NAME_RE = re.compile(r"^SAVIA_(DEV|T|SIM)_[A-Za-z0-9_]{1,90}$")
DATA_DIR = "/var/opt/mssql/data"


def docker(args, data=None, timeout=600):
    proc = subprocess.run(["docker", *args], input=data, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, timeout=timeout)
    return proc.returncode, proc.stdout.decode("utf-8", errors="replace")


def check_name(name):
    if not NAME_RE.match(name):
        raise SystemExit(f"Refused: database name '{name}' is outside SAVIA_(DEV|T|SIM)_*.")
    return name


def run_sql(db, text, timeout=600, opts=""):
    """Run a SQL script (sqlcmd -b -I, plus extra sqlcmd options). Returns (exit_code, output)."""
    remote = f"/tmp/saviadb-{uuid.uuid4().hex}.sql"
    code, out = docker(["exec", "-i", CONTAINER, "bash", "-c", f"cat > {remote}"],
                       data=text.encode("utf-8"))
    if code != 0:
        return code, out
    try:
        return docker(["exec", CONTAINER, "bash", "-c",
                       f"{SQLCMD} -b -I {opts} -d {db} -i {remote}"], timeout=timeout)
    finally:
        docker(["exec", CONTAINER, "rm", "-f", remote])


def scalar(db, query):
    code, out = run_sql(db, "SET NOCOUNT ON; " + query)
    if code != 0:
        raise SystemExit(out)
    lines = [l.strip() for l in out.splitlines() if l.strip() and not set(l.strip()) <= {"-"}]
    return lines[-1] if lines else ""


def cmd_status(_):
    code, out = docker(["inspect", "-f", "{{.State.Status}} health={{.State.Health.Status}}", CONTAINER])
    print(out.strip())
    if code == 0:
        print(scalar("master", "SELECT CONVERT(varchar(128), SERVERPROPERTY('ProductVersion')) + ' ' + CONVERT(varchar(64), SERVERPROPERTY('Edition'));"))
    return code


def cmd_up(_):
    env = ROOT / "infra" / ".env"
    if not env.exists():
        raise SystemExit("Missing savia/infra/.env. Copy env.example to .env and set a local password.")
    proc = subprocess.run(["docker", "compose", "--env-file", str(env), "-f",
                           str(ROOT / "infra" / "docker-compose.dev.yml"), "up", "-d", "--wait"])
    return proc.returncode


def create(name):
    check_name(name)
    return run_sql("master", f"IF DB_ID(N'{name}') IS NULL CREATE DATABASE [{name}];")


def drop(name):
    check_name(name)
    return run_sql("master", f"IF DB_ID(N'{name}') IS NOT NULL BEGIN "
                             f"ALTER DATABASE [{name}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; "
                             f"DROP DATABASE [{name}]; END;")


def migration_files():
    return sorted(p for p in MIGRATIONS.glob("V*.sql"))


def migrate(name):
    check_name(name)
    code, out = run_sql(name, """
IF OBJECT_ID(N'dbo.SaviaMigrations') IS NULL
  CREATE TABLE dbo.SaviaMigrations(
    Version varchar(20) NOT NULL PRIMARY KEY, FileName nvarchar(200) NOT NULL,
    Sha256 char(64) NOT NULL, AppliedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME());""")
    if code != 0:
        return code, out
    log = []
    for path in migration_files():
        version = path.name.split("__")[0]
        sha = hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
        applied = scalar(name, f"SELECT COALESCE((SELECT Sha256 FROM dbo.SaviaMigrations WHERE Version='{version}'),'none');")
        if applied == sha:
            continue
        if applied != "none":
            return 1, f"{path.name}: already applied with a different checksum. Migrations are immutable."
        code, out = run_sql(name, path.read_text(encoding="utf-8"))
        if code != 0:
            return code, f"{path.name} FAILED\n{out}"
        code, out = run_sql(name, f"INSERT INTO dbo.SaviaMigrations(Version,FileName,Sha256) VALUES('{version}',N'{path.name}','{sha}');")
        if code != 0:
            return code, out
        log.append(path.name)
    return 0, "applied: " + (", ".join(log) if log else "nothing new")


def template_name():
    digest = hashlib.sha256()
    for path in [*migration_files(), TESTS / "_fixture.sql"]:
        digest.update(path.name.encode())
        digest.update(path.read_bytes().replace(b"\r\n", b"\n"))
    return "SAVIA_T_TEMPLATE_" + digest.hexdigest()[:12]


def ensure_template():
    """Migrated database + test fixture, kept as a backup file for fast clones."""
    name = template_name()
    bak = f"{DATA_DIR}/{name}.bak"
    code, _ = docker(["exec", CONTAINER, "test", "-f", bak])
    if code == 0:
        return name
    drop(name)
    for step, (code, out) in [("create", create(name)), ("migrate", migrate(name)),
                              ("fixture", run_sql(name, (TESTS / "_fixture.sql").read_text(encoding="utf-8")))]:
        if code != 0:
            raise SystemExit(f"Template {step} failed:\n{out}")
    code, out = run_sql("master", f"BACKUP DATABASE [{name}] TO DISK=N'{bak}' WITH INIT, FORMAT;")
    if code != 0:
        raise SystemExit(out)
    drop(name)
    return name


def clone(name, template=None):
    check_name(name)
    template = template or ensure_template()
    drop(name)
    return run_sql("master", f"""
RESTORE DATABASE [{name}] FROM DISK=N'{DATA_DIR}/{template}.bak' WITH
  MOVE N'{template}' TO N'{DATA_DIR}/{name}.mdf',
  MOVE N'{template}_log' TO N'{DATA_DIR}/{name}_log.ldf', RECOVERY;""")


def header(path, key):
    for line in path.read_text(encoding="utf-8").splitlines()[:12]:
        match = re.match(rf"\s*--\s*{key}:\s*(.+)", line)
        if match:
            return match.group(1).strip()
    return None


def run_test(path, template, keep):
    rel = path.relative_to(TESTS).as_posix()
    db = "SAVIA_T_" + re.sub(r"[^A-Za-z0-9]", "_", rel)[:50] + "_" + uuid.uuid4().hex[:8]
    code, out = clone(db, template)
    if code == 0:
        code, out = run_sql(db, path.read_text(encoding="utf-8"), timeout=300)
    if not keep:
        drop(db)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / (re.sub(r"[^A-Za-z0-9]", "_", rel) + ".log")).write_text(out, encoding="utf-8")
    xfail = header(path, "XFAIL")
    if header(path, "TEST") is None:
        verdict = "INVALID"            # every test states its claim
    elif code == 0:
        verdict = "XPASS" if xfail else "PASS"
    else:
        verdict = "XFAIL" if xfail else "FAIL"
    errors = [l for l in out.splitlines() if l.startswith("Msg ") or "FAIL" in l]
    detail = (xfail or "") if verdict in ("XFAIL", "XPASS") else (errors[-1][:160] if errors and code else "")
    return {"test": rel, "verdict": verdict, "claim": header(path, "TEST") or "", "detail": detail}


def cmd_test(args):
    files = sorted(p for p in TESTS.rglob("*.sql") if not p.name.startswith("_"))
    if args.pattern:
        files = [p for p in files if args.pattern in p.relative_to(TESTS).as_posix()]
    if not files:
        print("No tests matched.")
        return 1
    template = ensure_template()
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(lambda p: run_test(p, template, args.keep), files))
    counts = {}
    for r in results:
        counts[r["verdict"]] = counts.get(r["verdict"], 0) + 1
    bad = sum(counts.get(k, 0) for k in ("FAIL", "XPASS", "INVALID"))
    if args.json:
        print(json.dumps({"results": results, "counts": counts, "ok": bad == 0}, indent=1))
    else:
        for r in results:
            print(f"{r['verdict']:<7} {r['test']}" + (f"  -- {r['detail']}" if r["detail"] else ""))
        print("SUMMARY " + " ".join(f"{k}={v}" for k, v in sorted(counts.items())) + f"  logs: {OUT.relative_to(ROOT)}")
    # XFAIL is a known defect with a red test. XPASS means the marker must be removed.
    return 1 if bad else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("status"); sub.add_parser("up")
    for name in ("create", "drop", "migrate", "clone"):
        sub.add_parser(name).add_argument("name")
    run = sub.add_parser("run"); run.add_argument("name"); run.add_argument("file")
    test = sub.add_parser("test"); test.add_argument("pattern", nargs="?")
    test.add_argument("--jobs", type=int, default=4); test.add_argument("--json", action="store_true")
    test.add_argument("--keep", action="store_true")
    args = parser.parse_args()
    if args.command == "status":
        return cmd_status(args)
    if args.command == "up":
        return cmd_up(args)
    if args.command == "test":
        return cmd_test(args)
    if args.command == "run":
        code, out = run_sql(check_name(args.name), Path(args.file).read_text(encoding="utf-8"))
    else:
        code, out = {"create": create, "drop": drop, "migrate": migrate, "clone": clone}[args.command](args.name)
    print(out.strip())
    return code


if __name__ == "__main__":
    sys.exit(main())

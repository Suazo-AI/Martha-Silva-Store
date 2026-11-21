#!/usr/bin/env python3
"""Local proof of the SAVIA production images, against the dev SQL container only.

  python savia/deploy/local_proof.py [--build] [--evidence FILE]

What it proves, in order (exit 0 only if every step passes):
  1. SAVIA_DEV_deploytest is a fresh clone (saviadb.py clone) and the repo runner finds nothing new.
  2. The production migrator applies every migration to an empty database (SAVIA_DEV_deploytest_mig),
     a second run applies nothing, and a changed migration file is refused.
  3. The migrator reads the ledger written by saviadb.py (0 pending on the clone): both runners agree.
  4. An empty database migrated by saviadb.py (SAVIA_DEV_deploytest_ref) and the migrator database end with\n     the same schema fingerprint (object counts, module text and SET options, columns, ledger).
  5. The API image runs as a non-root user on 127.0.0.1:5090 with a least-privilege SQL login,
     /health answers ok, the login page is served, Docker reports the container healthy, and a
     wrong password returns 401 auth.bad_credentials (proves the SQL path, not only the process).
Cleanup always runs: the API container stops (--rm), the three databases and both temporary logins are dropped.

Uses only the local container savia-sqlserver-dev. Temporary SQL passwords are generated in memory,
reach Docker only through the process environment and are never printed or written to the evidence.
"""
import argparse
import json
import os
import secrets
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]                    # .../savia
sys.path.insert(0, str(ROOT / "tools" / "db"))
import saviadb  # noqa: E402

DB = "SAVIA_DEV_deploytest"
DB_MIG = "SAVIA_DEV_deploytest_mig"
DB_REF = "SAVIA_DEV_deploytest_ref"   # empty database migrated by saviadb.py, no test fixture
LOGIN_MIG = "savia_deploytest_mig"
LOGIN_API = "savia_deploytest_api"
API_IMAGE = "savia-api:deploytest"
MIG_IMAGE = "savia-migrator:deploytest"
API_CONTAINER = "savia-deploytest-api"
PORT = 5090
NETWORK = "savia-dev_default"
SQL_HOST = "savia-sqlserver-dev,1433"
CONN = "Savia__Sql__ConnectionString"

steps = []
secret_values = []


def record(name, ok, detail=""):
    steps.append({"step": name, "ok": bool(ok), "detail": detail})
    print(f"{'PASS' if ok else 'FAIL'}  {name}" + (f"  -- {detail}" if detail else ""))
    return ok


def scrub(text):
    for value in secret_values:
        text = text.replace(value, "<redacted>")
    return text


def connection(db, login, password):
    return (f"Server={SQL_HOST};Database={db};User ID={login};Password={password};"
            "Encrypt=True;TrustServerCertificate=True;Connect Timeout=15")


def docker_env(cmd, conn_string, timeout=600):
    env = dict(os.environ, **{CONN: conn_string})
    proc = subprocess.run(["docker", *cmd], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    return proc.returncode, scrub(proc.stdout.decode("utf-8", errors="replace"))


def migrator(db, password, *args, mounts=()):
    cmd = ["run", "--rm", "--network", NETWORK, "-e", CONN]
    for host, inside in mounts:
        cmd += ["-v", f"{host}:{inside}:ro"]
    return docker_env([*cmd, MIG_IMAGE, *args], connection(db, LOGIN_MIG, password))


def sql_ok(db, text):
    code, out = saviadb.run_sql(db, text)
    if code != 0:
        raise RuntimeError(f"SQL on {db} failed: {scrub(out)[-400:]}")


FINGERPRINT = r"""
SELECT CONCAT(
  (SELECT STRING_AGG(CONCAT(RTRIM(type), '=', n), ',') WITHIN GROUP (ORDER BY type)
     FROM (SELECT type, COUNT(*) n FROM sys.objects WHERE is_ms_shipped = 0 GROUP BY type) t), ' mod=',
  (SELECT LEFT(CONVERT(char(64), HASHBYTES('SHA2_256', CAST(STRING_AGG(CAST(CONCAT(s.name, '.', o.name, '|',
      m.uses_quoted_identifier, m.uses_ansi_nulls, '|', m.definition) AS nvarchar(max)), NCHAR(10))
      WITHIN GROUP (ORDER BY s.name, o.name) AS varbinary(max))), 2), 16)
     FROM sys.sql_modules m JOIN sys.objects o ON o.object_id = m.object_id JOIN sys.schemas s ON s.schema_id = o.schema_id), ' col=',
  (SELECT LEFT(CONVERT(char(64), HASHBYTES('SHA2_256', CAST(STRING_AGG(CAST(CONCAT(s.name, '.', o.name, '.', c.name, ':',
      c.system_type_id, ':', c.max_length, ':', c.is_nullable) AS nvarchar(max)), NCHAR(10))
      WITHIN GROUP (ORDER BY s.name, o.name, c.column_id) AS varbinary(max))), 2), 16)
     FROM sys.columns c JOIN sys.objects o ON o.object_id = c.object_id JOIN sys.schemas s ON s.schema_id = o.schema_id
     WHERE o.is_ms_shipped = 0 AND o.type = 'U'), ' ledger=',
  (SELECT LEFT(CONVERT(char(64), HASHBYTES('SHA2_256', CAST(STRING_AGG(CAST(CONCAT(Version, ':', Sha256) AS nvarchar(max)), ',')
      WITHIN GROUP (ORDER BY Version) AS varbinary(max))), 2), 16) FROM dbo.SaviaMigrations), ' ct=',
  (SELECT COUNT(*) FROM sys.change_tracking_tables), ' snapshot=',
  (SELECT snapshot_isolation_state FROM sys.databases WHERE name = DB_NAME()));
"""


def http(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(f"http://127.0.0.1:{PORT}{path}", data=data, method=method,
                                     headers={"Content-Type": "application/json"} if data else {})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return response.status, response.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode("utf-8", errors="replace")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--build", action="store_true", help="build both images first")
    parser.add_argument("--evidence", help="write a JSON summary (no secrets) to this file")
    args = parser.parse_args()
    started = datetime.now(timezone.utc).isoformat(timespec="seconds")
    pw_mig = "Aa1!" + secrets.token_hex(24)
    pw_api = "Aa1!" + secrets.token_hex(24)
    secret_values.extend([pw_mig, pw_api])
    ok = True
    try:
        if args.build:
            for target, tag in (("migrator", MIG_IMAGE), ("api", API_IMAGE)):
                code, out = docker_env(["build", "--target", target, "-t", tag, str(ROOT)], "", timeout=1800)
                ok &= record(f"docker build --target {target}", code == 0, out.strip().splitlines()[-1][:160] if out.strip() else "")
            if not ok:
                return 1

        # 1. Fresh clone, migrated by the repo runner.
        code, out = saviadb.clone(DB)
        ok &= record("saviadb clone " + DB, code == 0, scrub(out).strip()[-160:])
        code, out = saviadb.migrate(DB)
        ok &= record("saviadb migrate " + DB, code == 0 and "nothing new" in out, out.strip()[-160:])
        code, out = saviadb.drop(DB_MIG)
        code, out = saviadb.create(DB_MIG)
        ok &= record("saviadb create " + DB_MIG + " (empty)", code == 0)
        saviadb.drop(DB_REF)
        saviadb.create(DB_REF)
        code, out = saviadb.migrate(DB_REF)
        ok &= record("saviadb create + migrate " + DB_REF + " (reference, no fixture)", code == 0 and "V016" in out, out.strip()[-80:])

        # Temporary logins: migrator = db_owner of both test databases; API = login only, user made by the migrator.
        sql_ok("master", f"""
IF SUSER_ID(N'{LOGIN_MIG}') IS NOT NULL DROP LOGIN [{LOGIN_MIG}];
IF SUSER_ID(N'{LOGIN_API}') IS NOT NULL DROP LOGIN [{LOGIN_API}];
CREATE LOGIN [{LOGIN_MIG}] WITH PASSWORD = N'{pw_mig}', CHECK_POLICY = ON;
CREATE LOGIN [{LOGIN_API}] WITH PASSWORD = N'{pw_api}', CHECK_POLICY = ON;""")
        for db in (DB, DB_MIG):
            sql_ok(db, f"CREATE USER [{LOGIN_MIG}] FOR LOGIN [{LOGIN_MIG}]; ALTER ROLE db_owner ADD MEMBER [{LOGIN_MIG}];")
        record("temporary SQL logins created (passwords in memory only)", True)

        # 2. Migrator on an empty database: plan, apply, re-apply, refuse a changed file.
        files = len(saviadb.migration_files())
        code, out = migrator(DB_MIG, pw_mig, "--plan")
        ok &= record("migrator --plan on empty database", code == 0 and f"pending {files}" in out, out.strip().splitlines()[-1])
        code, out = migrator(DB_MIG, pw_mig)
        ok &= record("migrator apply on empty database", code == 0 and f"ledger complete ({files} versions)" in out,
                     [l for l in out.splitlines() if "ledger complete" in l or "migrate: SQL" in l][-1:][0][:160] if out else "")
        code, out = migrator(DB_MIG, pw_mig)
        ok &= record("migrator re-run is idempotent", code == 0 and "applied now: nothing new" in out, out.strip().splitlines()[-1][:160])
        tmp = Path(tempfile.mkdtemp(prefix="savia-mig-"))
        try:
            for path in saviadb.migration_files():
                shutil.copy(path, tmp / path.name)
            last = sorted(tmp.glob("V*.sql"))[-1]
            last.write_text(last.read_text(encoding="utf-8") + "\n-- edited after apply\n", encoding="utf-8")
            code, out = migrator(DB_MIG, pw_mig, "--plan", "--migrations", "/m", mounts=[(str(tmp), "/m")])
            ok &= record("migrator refuses a changed applied migration", code == 1 and "different checksum" in out,
                         out.strip().splitlines()[-1][:160])
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

        # 3. Ledger compatibility with saviadb.py, and least-privilege API user.
        code, out = migrator(DB, pw_mig, "--plan")
        ok &= record("migrator reads the saviadb.py ledger (0 pending)", code == 0 and "pending 0" in out, out.strip().splitlines()[-1][:160])
        code, out = migrator(DB, pw_mig, "--grant-app-user", LOGIN_API)
        ok &= record("migrator grants API host permissions", code == 0 and "permissions ensured" in out, out.strip().splitlines()[-1][:160])

        # 4. Same schema from both runners.
        a = saviadb.scalar(DB_REF, FINGERPRINT)
        b = saviadb.scalar(DB_MIG, FINGERPRINT)
        ok &= record("schema fingerprint equal (saviadb.py runner vs production migrator, same empty start)", a == b and "mod=" in a,
                     a if a == b else f"saviadb: {a} | migrator: {b}")

        # 5. API container against the clone, least privilege, loopback only.
        code, out = docker_env(["run", "-d", "--rm", "--name", API_CONTAINER, "--network", NETWORK,
                                "-p", f"127.0.0.1:{PORT}:8080", "-e", CONN,
                                "-e", "Savia__Node__Kind=Cloud", "-e", "Savia__Node__NodeId=5A000000-0000-0000-0000-00000000C0D1",
                                API_IMAGE], connection(DB, LOGIN_API, pw_api))
        ok &= record("docker run API on 127.0.0.1:5090", code == 0, out.strip()[:12])
        health = None
        for _ in range(60):
            try:
                health = http("GET", "/health")
                if health[0] == 200:
                    break
            except (urllib.error.URLError, ConnectionError, OSError):
                pass
            time.sleep(1)
        ok &= record("GET /health", health is not None and health[0] == 200 and '"ok"' in health[1], str(health)[:80])
        status, body = http("GET", "/")
        ok &= record("GET / serves the sign-in page", status == 200 and "<title>SAVIA" in body and 'id="access"' in body, f"HTTP {status}, {len(body)} bytes")
        status, body = http("GET", "/app.mjs")
        ok &= record("GET /app.mjs (static client)", status == 200, f"HTTP {status}")
        status, body = http("POST", "/api/v1/auth/login", {"loginName": "nadie.deploytest", "password": "wrong-password-123"})
        ok &= record("POST /api/v1/auth/login wrong password -> 401 (SQL reached as least-privilege user)",
                     status == 401 and "auth.bad_credentials" in body, f"HTTP {status} {body[:90]}")
        state = ""
        for _ in range(30):
            code, state = docker_env(["inspect", "-f", "{{.State.Health.Status}}", API_CONTAINER], "")
            if state.strip() == "healthy":
                break
            time.sleep(2)
        ok &= record("Docker HEALTHCHECK reports healthy", state.strip() == "healthy", state.strip())
        code, uid = docker_env(["exec", API_CONTAINER, "id", "-u"], "")
        ok &= record("process runs as non-root", code == 0 and uid.strip() not in ("", "0"), f"uid={uid.strip()}")
        code, logs = docker_env(["logs", API_CONTAINER], "")
        ok &= record("API logs contain no SQL password", all(p not in logs for p in (pw_mig, pw_api)))
    except Exception as error:   # report and still clean up
        ok = record("unexpected error", False, scrub(str(error))[:300]) and False
    finally:
        subprocess.run(["docker", "stop", API_CONTAINER], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for db in (DB, DB_MIG, DB_REF):
            saviadb.drop(db)
        saviadb.run_sql("master", f"IF SUSER_ID(N'{LOGIN_MIG}') IS NOT NULL DROP LOGIN [{LOGIN_MIG}]; "
                                  f"IF SUSER_ID(N'{LOGIN_API}') IS NOT NULL DROP LOGIN [{LOGIN_API}];")
        left_db = saviadb.scalar("master", f"SELECT COUNT(*) FROM sys.databases WHERE name IN (N'{DB}', N'{DB_MIG}', N'{DB_REF}');")
        left_login = saviadb.scalar("master", f"SELECT COUNT(*) FROM sys.server_principals WHERE name IN (N'{LOGIN_MIG}', N'{LOGIN_API}');")
        _, left_ctr = docker_env(["ps", "-a", "--filter", f"name={API_CONTAINER}", "--format", "{{.Names}}"], "")
        ok &= record("cleanup: databases dropped", left_db == "0", f"remaining={left_db}")
        ok &= record("cleanup: temporary logins dropped", left_login == "0", f"remaining={left_login}")
        ok &= record("cleanup: no API container left", left_ctr.strip() == "", left_ctr.strip())
        if args.evidence:
            Path(args.evidence).write_text(json.dumps({
                "started_utc": started, "finished_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                "result": "PASS" if ok else "FAIL", "sql_container": saviadb.CONTAINER,
                "images": {"api": API_IMAGE, "migrator": MIG_IMAGE}, "steps": steps,
                "note": "Local dev container only. No Azure resource was contacted. No secret is recorded.",
            }, indent=1) + "\n", encoding="utf-8")
    print("RESULT " + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

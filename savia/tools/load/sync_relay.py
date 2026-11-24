"""Client relay for the sync measurement: the store and the hub may live on different SQL servers.

    SAVIA_SQL_CONTAINER=savia-sqlserver-load SAVIA_HUB_ODBC="<ODBC connection string>" \
        python savia/tools/load/sync_relay.py push --store a --out push.json
    ... python savia/tools/load/sync_relay.py hub-load --scale 1.0 --seed a10-20261121
    ... python savia/tools/load/sync_relay.py parity --store a [--out parity.json]

sync_measure.py runs each page as one cross-database EXEC inside one SQL Server and restores backups; Azure SQL
Database allows neither. Here the client carries the JSON, page by page, the way the .NET P9 transport does:
  store sync.usp_SourceStateJson -> hub sync.usp_PlanJson -> store sync.usp_ReadBatch -> hub sync.usp_ApplyBatch
until the hub answers more=false (D-041). No cross-database EXEC, no BACKUP or RESTORE on the hub.

Store side: the local load container only (the SAVIA_SQL_CONTAINER guard of generate.py). The client connects to the
port the container publishes on 127.0.0.1, with the sa password read from the container environment in-process.
Hub side: any ODBC connection string in SAVIA_HUB_ODBC, for example
  Driver={ODBC Driver 18 for SQL Server};Server=tcp:<server>.database.windows.net,1433;Database=<db>;Encrypt=yes
plus, for Microsoft Entra ID, an access token in SAVIA_HUB_ACCESS_TOKEN (then the string must carry no UID, PWD,
Authentication or Trusted_Connection). The token is handed to the driver in-process (SQL_COPT_SS_ACCESS_TOKEN).
Neither the connection string nor the token is printed, logged or written; connection errors are scrubbed of both.

Requires pyodbc (pip install pyodbc==5.5.0) and Microsoft ODBC Driver 17 or 18 for SQL Server.
"""
import argparse
import json
import os
import pathlib
import re
import struct
import subprocess
import sys
import time

HERE = pathlib.Path(__file__).resolve()
SAVIA = HERE.parents[2]
STORE_CONTAINER_RE = r"savia-sqlserver-load\d*"
STORES = {"a": "SAVIA_SIM_load_a", "b": "SAVIA_SIM_load_b", "c": "SAVIA_SIM_load_c"}
CLOUD = "00000000-0000-0000-0000-0000000C10D0"
SQL_COPT_SS_ACCESS_TOKEN = 1256
GO_RE = re.compile(r"^[ \t]*GO[ \t]*(?:--.*)?$", re.IGNORECASE | re.MULTILINE)
SECRET_KEYS = re.compile(r"(?:^|;)\s*(uid|user id|pwd|password|authentication|trusted_connection)\s*=", re.IGNORECASE)


class RelayError(RuntimeError):
    pass


# ------------------------------------------------------------------ connections
def token_struct(token):
    """The ACCESS_TOKEN structure the SQL Server ODBC driver expects: little-endian length, then UTF-16-LE bytes."""
    raw = token.encode("utf-16-le")
    return struct.pack(f"<I{len(raw)}s", len(raw), raw)


def scrub(text, secrets):
    for s in secrets:
        if s:
            text = text.replace(s, "***")
    return text


def connect(conn_str, token=None, timeout=900):
    """Open an autocommit pyodbc connection; any error comes back with the string and token removed."""
    secrets = [conn_str, token] + re.findall(r"(?i)pwd\s*=\s*\{?([^;}]+)", conn_str)
    attrs = None
    if token:
        if SECRET_KEYS.search(conn_str):
            raise RelayError("SAVIA_HUB_ACCESS_TOKEN is set: the connection string must not carry UID, PWD, "
                             "Authentication or Trusted_Connection")
        attrs = {SQL_COPT_SS_ACCESS_TOKEN: token_struct(token)}
    import pyodbc  # imported here so the unit tests and --help run without it
    try:
        cn = pyodbc.connect(conn_str, autocommit=True, attrs_before=attrs, timeout=30)
    except Exception as e:  # noqa: BLE001  never let the driver echo the string
        raise RelayError("connect failed: " + scrub(f"{type(e).__name__}: {e}", secrets)[:400]) from None
    cn.timeout = timeout
    db = Db(cn, secrets)
    db.rows("SET NOCOUNT ON;")
    return db


class Db:
    def __init__(self, cn, secrets=()):
        self.cn, self.secrets = cn, list(secrets)

    def rows(self, sql, *params):
        """Run one batch, drain every result set (a late error would otherwise be lost), return all rows."""
        cur = self.cn.cursor()
        out = []
        try:
            cur.execute(sql, *params)  # NOCOUNT is set once per session: a prefix would break CREATE PROCEDURE batches
            while True:
                if cur.description:
                    out.extend(cur.fetchall())
                if not cur.nextset():
                    break
        except Exception as e:  # noqa: BLE001
            raise RelayError(scrub(f"{type(e).__name__}: {e}", self.secrets)[-1500:]) from None
        finally:
            cur.close()
        return out

    def scalar(self, sql, *params):
        r = self.rows(sql, *params)
        return r[-1][0] if r else None

    def out_json(self, proc_call, *params):
        """EXEC a procedure with parameters, adding @Json OUTPUT as the last argument; return that JSON text."""
        return self.scalar(f"DECLARE @j nvarchar(max);\n{proc_call},@Json=@j OUTPUT;\nSELECT @j;", *params)

    def script(self, text):
        """Run a sqlcmd-style script batch by batch (split on GO lines)."""
        for batch in split_go(text):
            self.rows(batch)


def split_go(text):
    return [b for b in GO_RE.split(text.replace("\r\n", "\n")) if b.strip()]


def store_conn_str(db):
    """ODBC string for a database in the guarded local load container. The password stays in this process."""
    container = os.environ.get("SAVIA_SQL_CONTAINER", "")
    if not re.fullmatch(STORE_CONTAINER_RE, container):
        sys.exit("refusing to run: set SAVIA_SQL_CONTAINER=savia-sqlserver-load or -load<n> (the store side)")
    port = subprocess.run(["docker", "port", container, "1433/tcp"], capture_output=True, text=True)
    m = re.search(r"127\.0\.0\.1:(\d+)", port.stdout)
    if port.returncode or not m:
        raise RelayError(f"{container} publishes no 127.0.0.1 port for 1433 (docker port exit {port.returncode})")
    pw = subprocess.run(["docker", "exec", container, "printenv", "MSSQL_SA_PASSWORD"], capture_output=True, text=True)
    if pw.returncode or not pw.stdout.strip():
        raise RelayError(f"cannot read the sa password from {container} (exit {pw.returncode})")
    secret = pw.stdout.strip().replace("}", "}}")
    return (f"Driver={{{driver()}}};Server=127.0.0.1,{m.group(1)};Database={db};UID=sa;PWD={{{secret}}};"
            "Encrypt=yes;TrustServerCertificate=yes")


def driver():
    import pyodbc
    for name in ("ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server"):
        if name in pyodbc.drivers():
            return name
    raise RelayError("no Microsoft ODBC Driver 17/18 for SQL Server installed")


def store(key, timeout=900):
    return connect(store_conn_str(STORES[key]), timeout=timeout)


def hub(timeout=900):
    cs = os.environ.get("SAVIA_HUB_ODBC", "")
    if not cs:
        sys.exit("set SAVIA_HUB_ODBC to the hub ODBC connection string")
    return connect(cs, token=os.environ.get("SAVIA_HUB_ACCESS_TOKEN") or None, timeout=timeout)


def local_node(db):
    node = db.scalar("SELECT CONVERT(varchar(36),NodeId) FROM sync.LocalNode;")
    if not node:
        raise RelayError("sync.LocalNode is empty: this database is not a sync node")
    return node


# ------------------------------------------------------------------ relay
def source_state(db):
    return db.scalar("DECLARE @j nvarchar(max);EXEC sync.usp_SourceStateJson @Json=@j OUTPUT;SELECT @j;")


def relay_page(src, tgt, src_node, tgt_node, mode="normal", apply=True):
    """One page carried by the client. Seconds are client wall-clock per call, network included."""
    t0 = time.perf_counter()
    st = source_state(src)
    t1 = time.perf_counter()
    pl = tgt.out_json("EXEC sync.usp_PlanJson @PeerNodeId=?,@StateJson=?,@Mode=?", src_node, st, mode)
    fork = None
    if (json.loads(pl) or {}).get("mode") == "rebuild":
        fork = json.loads(source_state(tgt))["fork"]
    t2 = time.perf_counter()
    b = src.out_json("EXEC sync.usp_ReadBatch @TargetNodeId=?,@PlanJson=?,@TargetForkGuid=?", tgt_node, pl, fork)
    t3 = time.perf_counter()
    r = tgt.out_json("EXEC sync.usp_ApplyBatch @PeerNodeId=?,@BatchJson=?", src_node, b) if apply else "{}"
    t4 = time.perf_counter()
    batch = json.loads(b)
    tables = [{"t": x.get("t"), "n": len(x.get("rows") or []), "done": x.get("done")} for x in batch.get("tables") or []]
    return {"page": batch.get("page"), "rows": sum(x["n"] for x in tables),
            "bytes": len(b.encode("utf-8")),  # the batch, store -> hub; UTF-8 length as in A-10
            "bytes_state": len(st.encode("utf-8")), "bytes_plan": len(pl.encode("utf-8")),
            "bytes_result": len(r.encode("utf-8")),
            "state_s": round(t1 - t0, 3), "plan_s": round(t2 - t1, 3), "read_s": round(t3 - t2, 3),
            "apply_s": round(t4 - t3, 3), "seconds": round(t4 - t0, 3),
            "result": json.loads(r), "tables": [x for x in tables if x["n"]]}


def relay(src, tgt, label, mode="normal", max_pages=None, on_page=None):
    """tgt pulls from src through this client until the source reports no more pages."""
    src_node, tgt_node = local_node(src), local_node(tgt)
    t = time.perf_counter()
    r = {"step": label, "mode": mode, "source_node": src_node, "target_node": tgt_node, "pages": []}
    try:
        while max_pages is None or len(r["pages"]) < max_pages:
            page = relay_page(src, tgt, src_node, tgt_node, mode)
            r["pages"].append(page)
            print(f"{label} page={page['page']} rows={page['rows']:,} bytes={page['bytes']:,} "
                  f"read={page['read_s']}s apply={page['apply_s']}s total={page['seconds']}s", flush=True)
            if on_page:
                on_page(r)
            if not page["result"].get("more"):
                break
    except RelayError as e:
        r["error"] = str(e)[-800:]
    pages = r["pages"]
    r.update(wall_s=round(time.perf_counter() - t, 2), page_count=len(pages), rows=sum(p["rows"] for p in pages),
             bytes=sum(p["bytes"] for p in pages),
             bytes_all=sum(p["bytes"] + p["bytes_state"] + p["bytes_plan"] + p["bytes_result"] for p in pages),
             max_page_bytes=max((p["bytes"] for p in pages), default=0),
             read_s=round(sum(p["read_s"] for p in pages), 3), apply_s=round(sum(p["apply_s"] for p in pages), 3),
             finished=bool(pages) and not pages[-1]["result"].get("more") and "error" not in r)
    return r


# ------------------------------------------------------------------ hub base catalog over a plain connection
def hub_load(db, seed, scale, created_at=None, migrations=None, fixture=None):
    """Migrations + test fixture + bulk catalog + local node = cloud: what generate.py gives SAVIA_SIM_load_hub,
    built over one plain connection (no CREATE DATABASE, no RESTORE). The database must be empty.

    created_at pins the catalog CreatedAt to the stores' value (generate.py takes it from the clock), so the
    generated rows match the stores byte for byte without shipping them. align_reference() fixes the rest."""
    import hashlib
    sys.path.insert(0, str(HERE.parent))
    import generate  # the same deterministic catalog_sql the stores were generated with
    if db.scalar("SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped=0;"):
        raise RelayError("hub-load needs an empty database: user tables already exist")
    timings = {}
    t = time.perf_counter()
    db.rows("""CREATE TABLE dbo.SaviaMigrations(
    Version varchar(20) NOT NULL PRIMARY KEY, FileName nvarchar(200) NOT NULL,
    Sha256 char(64) NOT NULL, AppliedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME());""")
    files = migrations or sorted((SAVIA / "db" / "migrations").glob("V*.sql"))
    for path in files:  # same registry, checksum and transactional envelope as saviadb.migrate
        version = path.name.split("__")[0]
        sha = hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()
        script = path.read_text(encoding="utf-8")
        registry = f"INSERT INTO dbo.SaviaMigrations(Version,FileName,Sha256) VALUES('{version}',N'{path.name}','{sha}');"
        try:
            if script.startswith("-- savia:transactional"):
                db.rows("SET XACT_ABORT ON; BEGIN TRAN;")
                db.script(script)
                db.rows("IF @@TRANCOUNT <> 1 OR XACT_STATE() <> 1 THROW 52200,'Migration transaction invalid.',1;\n"
                        + registry + "\nCOMMIT;")
            else:
                db.script(script)
                db.rows(registry)
        except RelayError as e:
            db.rows("IF @@TRANCOUNT > 0 ROLLBACK;")
            raise RelayError(f"{path.name} FAILED: {e}") from None
    timings["migrations_s"] = round(time.perf_counter() - t, 1)
    t = time.perf_counter()
    db.script((fixture or SAVIA / "db" / "tests" / "_fixture.sql").read_text(encoding="utf-8"))
    timings["fixture_s"] = round(time.perf_counter() - t, 1)
    t = time.perf_counter()
    gen = generate.Gen(argparse.Namespace(seed=seed, scale=scale, days=0, tickets=0))
    sql = gen.catalog_sql()
    if created_at:
        clock = "@at datetime2(3)=DATEADD(day,-90,core.ufn_BusinessNow())"
        if clock not in sql or not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d{1,7})?", created_at):
            raise RelayError("cannot pin the catalog CreatedAt: generate.catalog_sql changed or bad timestamp")
        sql = sql.replace(clock, f"@at datetime2(3)='{created_at}'")
    counts = db.rows(sql)
    timings["catalog_s"] = round(time.perf_counter() - t, 1)
    db.rows("EXEC sync.usp_SetLocalNode @NodeId=?;", CLOUD)
    return {"migrations": len(files), "catalog": [list(r) for r in counts], **timings}


def generated_created_at(src):
    """The CreatedAt generate.py stamped on the bulk catalog of a store-side database."""
    v = src.scalar("SELECT TOP(1) CONVERT(varchar(27),CreatedAt,126) FROM catalog.Items WHERE Sku LIKE 'LD%' ORDER BY Sku;")
    if not v:
        raise RelayError("no generated catalog (Sku LD*) in the source database")
    return v


def _row_hash_sql(select_list):
    return (f"CONVERT(char(64),HASHBYTES('SHA2_256',(SELECT {select_list} FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,"
            f"INCLUDE_NULL_VALUES)),2)")


def align_reference(hub_db, src):
    """Make the hub's own (cloud-owned) synced rows equal to the store-side template's, over plain connections.

    Rows the test fixture creates with NEWID() or the clock differ on every build, and the hub sends its own rows to
    the stores on pull (catalog.ItemIdentifiers would collide on UX_ItemIdentifier_Global). Rows are compared by the
    SHA-256 of their synced columns; only differing rows travel. Deletes and inserts run in one transaction with the
    touched tables' triggers and foreign keys off, then every foreign key is re-validated WITH CHECK."""
    shapes = src.rows("SELECT TableName,SelectList,OwnerExpr,InsList,WithList,ValList FROM sync.fn_TableShape() ORDER BY ApplyOrder;")
    plan = []
    for name, sel, owner, ins, with_list, val in shapes:
        where = f"({owner})=CONVERT(uniqueidentifier,'{CLOUD}')"
        q = f"SELECT {_row_hash_sql(sel)} FROM {name} t WHERE {where};"
        h, s = {r[0] for r in hub_db.rows(q)}, {r[0] for r in src.rows(q)}
        if h != s:
            plan.append((name, sel, where, ins, with_list, val, sorted(h - s), sorted(s - h)))
    report = {x[0]: {"hub_only": len(x[6]), "source_only": len(x[7])} for x in plan}
    if not plan:
        return report
    names = [x[0] for x in plan]
    fks = hub_db.rows("SELECT QUOTENAME(OBJECT_SCHEMA_NAME(parent_object_id))+'.'+QUOTENAME(OBJECT_NAME(parent_object_id)),"
                      "QUOTENAME(name) FROM sys.foreign_keys WHERE referenced_object_id IN (SELECT OBJECT_ID(value) FROM OPENJSON(?)) "
                      "OR parent_object_id IN (SELECT OBJECT_ID(value) FROM OPENJSON(?));", json.dumps(names), json.dumps(names))
    hub_db.rows("SET XACT_ABORT ON; BEGIN TRAN;")
    try:
        for t, fk in fks:
            hub_db.rows(f"ALTER TABLE {t} NOCHECK CONSTRAINT {fk};")
        for name in names:
            hub_db.rows(f"DISABLE TRIGGER ALL ON {name};")
        for name, sel, where, *_rest, gone, _new in reversed(plan):
            if gone:
                hub_db.rows(f"DELETE t FROM {name} t WHERE {where} AND {_row_hash_sql(sel)} IN (SELECT value FROM OPENJSON(?));",
                            json.dumps(gone))
        for name, sel, where, ins, with_list, val, _gone, new in plan:
            if new:
                rows = src.rows(f"SELECT x.j FROM (SELECT (SELECT {sel} FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES) j "
                                f"FROM {name} t WHERE {where}) x WHERE CONVERT(char(64),HASHBYTES('SHA2_256',x.j),2) "
                                f"IN (SELECT value FROM OPENJSON(?));", json.dumps(new))
                ident = hub_db.scalar(f"SELECT OBJECTPROPERTY(OBJECT_ID(N'{name}'),'TableHasIdentity');")
                on, off = (f"SET IDENTITY_INSERT {name} ON;", f"SET IDENTITY_INSERT {name} OFF;") if ident else ("", "")
                hub_db.rows(f"{on}INSERT {name}({ins}) SELECT {val} FROM OPENJSON(?) WITH ({with_list}) s;{off}",
                            "[" + ",".join(r[0] for r in rows) + "]")
        for name in names:
            hub_db.rows(f"ENABLE TRIGGER ALL ON {name};")
        for t, fk in fks:
            hub_db.rows(f"ALTER TABLE {t} WITH CHECK CHECK CONSTRAINT {fk};")
        hub_db.rows("COMMIT;")
    except RelayError:
        hub_db.rows("IF @@TRANCOUNT > 0 ROLLBACK;")
        raise
    return report


CATALOG_COLUMNS = {  # the generated values; CreatedAt follows the clock and rowversion follows the server
    "catalog.Products": "x.Id,x.Name,x.Status,x.CreatedBy",
    "catalog.Items": "x.Id,x.ProductId,x.SizeId,x.ColorId,x.Sku,x.VariantName,x.CurrencyCode,x.UnitPriceMinor,x.UnitCostMinor,x.Status",
    # Id left out: the test fixture registers its items through usp_RegisterItem, which draws identifier ids from NEWID().
    "catalog.ItemIdentifiers": "x.ItemId,x.Kind,x.RawCode,x.IsPrimary",
}


def catalog_fingerprint(db):
    """Counts and a SHA-256 over the base catalog and the migration registry, to compare two hub loads."""
    out = {"migrations": db.scalar("SELECT CONVERT(char(64),HASHBYTES('SHA2_256',STRING_AGG(CONVERT(varchar(max),"
                                   "CONCAT(Version,':',Sha256)),',') WITHIN GROUP (ORDER BY Version)),2) FROM dbo.SaviaMigrations;")}
    for t, cols in CATALOG_COLUMNS.items():
        n, h = db.rows(f"SELECT COUNT_BIG(*),CONVERT(char(64),HASHBYTES('SHA2_256',STRING_AGG(CONVERT(varchar(max),y.h),'') "
                       f"WITHIN GROUP (ORDER BY y.h)),2) FROM (SELECT CONVERT(char(64),HASHBYTES('SHA2_256',"
                       f"(SELECT {cols} FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)),2) AS h FROM {t} x) y;")[0]
        out[t] = [int(n), h]
    return out


# ------------------------------------------------------------------ parity
def table_digests(db, node):
    """Per synced table: rows owned by node, and SHA-256 over the per-row SHA-256 of the synced columns."""
    shapes = db.rows("SELECT TableName,SelectList,OwnerExpr FROM sync.fn_TableShape() ORDER BY ApplyOrder;")
    out = {}
    for name, select_list, owner in shapes:
        n, h = db.rows(
            f"SELECT COUNT_BIG(*),CONVERT(char(64),HASHBYTES('SHA2_256',STRING_AGG(CONVERT(varchar(max),x.h),'') "
            f"WITHIN GROUP (ORDER BY x.h)),2) FROM (SELECT CONVERT(char(64),HASHBYTES('SHA2_256',"
            f"(SELECT {select_list} FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)),2) AS h "
            f"FROM {name} t WHERE ({owner})=CONVERT(uniqueidentifier,?)) x;", node)[0]
        out[name] = {"rows": int(n), "sha256": h}
    return out


def parity(store_db, hub_db):
    node = local_node(store_db)
    s, h = table_digests(store_db, node), table_digests(hub_db, node)
    tables = [{"table": t, "store_rows": s.get(t, {}).get("rows"), "hub_rows": h.get(t, {}).get("rows"),
               "store_sha256": s.get(t, {}).get("sha256"), "hub_sha256": h.get(t, {}).get("sha256"),
               "match": t in s and t in h and s[t] == h[t]} for t in sorted(set(s) | set(h))]
    total = sum(x["store_rows"] or 0 for x in tables)
    problems = [f"{x['table']}: store {x['store_rows']} rows, hub {x['hub_rows']} rows"
                + ("" if x["store_rows"] != x["hub_rows"] else ", checksum differs") for x in tables if not x["match"]]
    if total == 0:
        problems.append("no store-origin rows at all: wrong node or empty store, nothing was compared")
    return {"store_node": node, "tables": tables, "store_rows_total": total, "ok": not problems, "problems": problems}


# ------------------------------------------------------------------ CLI
def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    push = sub.add_parser("push", help="the hub pulls from one store through this client")
    push.add_argument("--store", choices=sorted(STORES), required=True)
    push.add_argument("--mode", default="normal", choices=["normal", "rebuild"])
    push.add_argument("--max-pages", type=int)
    push.add_argument("--cap", type=int, default=900, help="per-statement timeout, seconds")
    push.add_argument("--out", required=True)
    pull = sub.add_parser("pull", help="one store pulls from the hub through this client")
    pull.add_argument("--store", choices=sorted(STORES), required=True)
    pull.add_argument("--cap", type=int, default=900)
    pull.add_argument("--out", required=True)
    load = sub.add_parser("hub-load", help="base catalog on an empty hub database over the plain connection")
    load.add_argument("--seed", required=True)
    load.add_argument("--scale", type=float, required=True)
    load.add_argument("--template", default="SAVIA_SIM_load_hub",
                      help="store-side database generate.py built the stores with: source of CreatedAt and of the "
                           "hub's own reference rows (align); 'none' skips both")
    load.add_argument("--out")
    par = sub.add_parser("parity", help="store-origin rows: count and SHA-256 per synced table, store vs hub")
    par.add_argument("--store", choices=sorted(STORES), required=True)
    par.add_argument("--out")
    a = p.parse_args(argv)

    def save(obj, path):
        if path:
            pathlib.Path(path).write_text(json.dumps(obj, indent=1, default=str), encoding="utf-8")

    if a.cmd in ("push", "pull"):
        s, h = store(a.store, a.cap), hub(a.cap)
        src, tgt = (s, h) if a.cmd == "push" else (h, s)
        label = f"{a.store}->hub" if a.cmd == "push" else f"hub->{a.store}"
        r = relay(src, tgt, label, getattr(a, "mode", "normal"), getattr(a, "max_pages", None),
                  on_page=lambda x: save(x, a.out))
        save(r, a.out)
        print(f"{label} pages={r['page_count']} rows={r['rows']:,} bytes={r['bytes']:,} max_page={r['max_page_bytes']:,} "
              f"read={r['read_s']}s apply={r['apply_s']}s wall={r['wall_s']}s finished={r['finished']}"
              + (f" ERROR {r['error'][:300]}" if "error" in r else ""))
        return 0 if r["finished"] else 1
    if a.cmd == "hub-load":
        h = hub()
        src = None if a.template == "none" else connect(store_conn_str(a.template))
        r = hub_load(h, a.seed, a.scale, created_at=generated_created_at(src) if src else None)
        save(r, a.out)
        if src:
            t = time.perf_counter()
            r["aligned"] = align_reference(h, src)
            r["align_s"] = round(time.perf_counter() - t, 1)
            r["aligned_after"] = align_reference(h, src)  # must be {}: every hub-owned synced row now equals the template
            save(r, a.out)
        print(json.dumps(r))
        return 0
    r = parity(store(a.store), hub())
    save(r, a.out)
    for x in r["tables"]:
        print(f"{'OK ' if x['match'] else 'BAD'} {x['table']:<36} store={x['store_rows']} hub={x['hub_rows']}")
    print(("PARITY OK" if r["ok"] else "PARITY FAILED: " + "; ".join(r["problems"]))
          + f" store_rows={r['store_rows_total']} node={r['store_node']}")
    return 0 if r["ok"] else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RelayError as e:
        sys.exit(f"relay error: {e}")

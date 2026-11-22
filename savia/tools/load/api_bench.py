"""A-10 API latency bench: the real Savia.Api (branch A) against SAVIA_SIM_load_a, one client, loopback, keep-alive.

    SAVIA_SQL_CONTAINER=savia-sqlserver-load SAVIA_DOTNET=<dotnet 10> python savia/tools/load/api_bench.py [--out file.json] [--n 200]

Needs a built API (dotnet build savia/src/Savia.Api). Starts it on 127.0.0.1:5191, provisions fresh random passwords
for t_cashier_a, t_super_a and t_manager (generated here, kept in memory, never printed), measures, then stops it.
The SQL password is read from the load container's own environment and passed only through the process environment.
Warm-up calls are excluded. Latency is client wall time per request (ms). DMV deltas give logical reads and CPU per procedure.
"""
import argparse
import http.client
import json
import os
import pathlib
import re
import secrets
import subprocess
import sys
import tempfile
import time
import uuid

# A load container only (savia-sqlserver-load, or a numbered one such as savia-sqlserver-load2 for a parallel run).
if not re.fullmatch(r"savia-sqlserver-load\d*", os.environ.get("SAVIA_SQL_CONTAINER", "")):
    sys.exit("refusing to run: set SAVIA_SQL_CONTAINER=savia-sqlserver-load (or savia-sqlserver-load<n>)")
ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "db"))
import saviadb as d  # noqa: E402

DB = "SAVIA_SIM_load_a"
PORT = int(os.environ.get("SAVIA_BENCH_API_PORT", "5191"))  # another port when two benches share the PC
A = {"branch": "A0000000-0000-0000-0000-00000000000A", "loc": "A0000000-0000-0000-0000-0000000000A1",
     "node": "A0000000-0000-0000-0000-0000000000A2", "register": "A0000000-0000-0000-0000-0000000000A3"}
SUPPLIER = "00000000-0000-0000-0000-0000000050A1"
API_PROJECT = ROOT / "src" / "Savia.Api"
API_DLL = API_PROJECT / "bin" / "Debug" / "net10.0" / "Savia.Api.dll"


def q(text):
    code, out = d.run_sql(DB, "SET NOCOUNT ON;" + text, opts="-h -1 -W")
    if code != 0:
        raise SystemExit(out[-2000:])
    return [l.strip() for l in out.splitlines() if l.strip()]


def ean13(base12):
    """Append the EAN-13 check digit (the import validates it)."""
    t = sum(int(c) * (3 if i % 2 else 1) for i, c in enumerate(base12))
    return base12 + str((10 - t % 10) % 10)


def pct(xs):
    s = sorted(xs)
    if not s:
        return {}
    at = lambda p: s[min(len(s) - 1, max(0, int(round(p / 100 * len(s) + 0.5)) - 1))]  # noqa: E731  nearest rank
    return {"n": len(s), "p50": round(at(50), 1), "p95": round(at(95), 1), "max": round(s[-1], 1)}


class Api:
    def __init__(self, timeout=120):
        self.timeout = timeout
        self.c = http.client.HTTPConnection("127.0.0.1", PORT, timeout=timeout)
        self.token = None
        self.link = None

    def call(self, method, path, body=None, token=None):
        h = {"Content-Type": "application/json"}
        if token or self.token:
            h["Authorization"] = "Bearer " + (token or self.token)
        data = json.dumps(body).encode() if body is not None else None
        t = time.perf_counter()
        try:
            self.c.request(method, path, body=data, headers=h)
            r = self.c.getresponse()
            raw = r.read()
            self.link = r.getheader("Link")
        except (TimeoutError, OSError, http.client.HTTPException) as e:  # record, reconnect, keep measuring
            self.c.close()
            self.c = http.client.HTTPConnection("127.0.0.1", PORT, timeout=self.timeout)
            return 0, f"client {type(e).__name__} after {(time.perf_counter() - t):.0f}s".encode(), (time.perf_counter() - t) * 1000
        ms = (time.perf_counter() - t) * 1000
        return r.status, raw, ms

    def login(self, name, pw):
        s, raw, _ = self.call("POST", "/api/v1/auth/login", {"loginName": name, "password": pw})
        if s != 200:
            raise SystemExit(f"login {name} failed: {s} {raw[:300]}")
        return json.loads(raw)["token"]


def measure(api, name, reqs, res, token=None, warm=3, expect=(200, 204)):
    lat, bad, size = [], [], 0
    for i, (m, path, body) in enumerate(reqs):
        s, raw, ms = api.call(m, path, body, token)
        if s not in expect:
            bad.append(f"{s} {path[:80]} {raw[:200]!r} after {ms:.0f} ms")
            continue
        if i >= warm:
            lat.append(ms)
            size = max(size, len(raw))
    r = {**pct(lat), "errors": len(bad), "max_bytes": size}
    if bad:
        r["first_error"] = bad[0]
    res[name] = r
    print(f"{name:28} {r}", flush=True)
    return r


def page_through(api, name, first, res):
    """Reads a whole list by following Link rel="next" (D-041); before V042 the first page is the whole list."""
    lat, rows, size, path, t = [], 0, 0, first, time.perf_counter()
    while path:
        s, raw, ms = api.call("GET", path)
        if s != 200:
            res[name] = {"error": f"{s} {path[:80]} {raw[:200]!r}"}
            print(f"{name:28} {res[name]}", flush=True)
            return
        lat.append(ms)
        rows += len(json.loads(raw))
        size = max(size, len(raw))
        link = re.match(r'<([^>]*)>;\s*rel="next"', api.link or "")
        path = link.group(1) if link else None
    res[name] = {"pages": len(lat), "rows": rows, "total_ms": round((time.perf_counter() - t) * 1000), "first_page_ms": round(lat[0]),
                 "last_page_ms": round(lat[-1]), "page_p95": pct(lat).get("p95"), "max_bytes": size}
    print(f"{name:28} {res[name]}", flush=True)


def other_containers_cpu():
    """CPU % of every running container except the bench's own, e.g. {"savia-sqlserver-dev": "1.25%"}."""
    code, out = d.docker(["stats", "--no-stream", "--format", "{{.Name}} {{.CPUPerc}}"])
    pairs = [line.split() for line in out.splitlines() if line.strip()] if code == 0 else []
    return {name: cpu for name, cpu in pairs if name != d.CONTAINER}


def dmv():
    rows = q(f"""SELECT CONCAT(OBJECT_SCHEMA_NAME(ps.object_id,ps.database_id),'.',OBJECT_NAME(ps.object_id,ps.database_id),'|',ps.execution_count,'|',
ps.total_logical_reads,'|',ps.total_worker_time,'|',ps.total_elapsed_time,'|',ps.max_logical_reads)
FROM sys.dm_exec_procedure_stats ps WHERE ps.database_id=DB_ID('{DB}')""")
    out = {}
    for r in rows:
        p = r.split("|")
        if len(p) == 6:
            out[p[0]] = [int(x) for x in p[1:]]
    return out


def adhoc_top():
    return q(f"""SELECT TOP 8 CONCAT(qs.execution_count,'|',qs.total_logical_reads/qs.execution_count,'|',qs.total_worker_time/qs.execution_count/1000,'|',
REPLACE(REPLACE(LEFT(LTRIM(st.text),110),CHAR(10),' '),CHAR(13),' '))
FROM sys.dm_exec_query_stats qs CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
WHERE st.dbid IS NULL OR st.dbid=DB_ID('{DB}') ORDER BY qs.total_logical_reads DESC""")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "docs/evidence/load-a10-20261121/api.json"))
    ap.add_argument("--n", type=int, default=200)
    ap.add_argument("--label", default="unconstrained")
    ap.add_argument("--reads-only", action="store_true")
    ap.add_argument("--sections", default="lookup,search,receipt,reports,kpi,lists,writes,import",
                    help="comma list; results merge into --out under this --label")
    a = ap.parse_args()
    dn = os.environ.get("SAVIA_DOTNET") or "dotnet"
    code, pw_sql = d.docker(["exec", d.CONTAINER, "printenv", "MSSQL_SA_PASSWORD"])
    code2, port = d.docker(["port", d.CONTAINER, "1433/tcp"])
    if code or code2:
        raise SystemExit("cannot read SQL password or port from the load container")
    sqlport = port.strip().splitlines()[0].rsplit(":", 1)[-1]
    cs = (f"Server=127.0.0.1,{sqlport};Database={DB};User ID=sa;Password=\"{pw_sql.strip().replace(chr(34), chr(34) * 2)}\";"
          "Encrypt=True;TrustServerCertificate=True;Connect Timeout=15")
    env = {k: v for k, v in os.environ.items() if not k.upper().startswith(("KESTREL__", "ASPNETCORE_URLS", "DOTNET_URLS", "URLS"))}
    env.update({"Savia__Pilot__LocalCatalog": "true", "Savia__Node__Kind": "Branch", "Savia__Node__NodeId": A["node"],
                "Savia__Node__BranchId": A["branch"], "Savia__Node__LocationId": A["loc"], "Savia__Sql__ConnectionString": cs,
                "ASPNETCORE_ENVIRONMENT": "Development", "DOTNET_CLI_TELEMETRY_OPTOUT": "1", "Logging__LogLevel__Default": "Warning"})
    pws = {n: secrets.token_urlsafe(18) for n in ("t_cashier_a", "t_super_a", "t_manager")}
    prov = subprocess.run([dn, str(API_DLL), "provision-passwords"], cwd=API_PROJECT, capture_output=True, text=True,
                          env={**env, "Savia__Provision__Logins": ",".join(pws),
                               **{"SAVIA_PILOT_PASSWORD_" + n.upper(): p for n, p in pws.items()}})
    if prov.returncode != 0:
        raise SystemExit("provision failed: " + "\n".join(l for l in (prov.stdout + prov.stderr).splitlines() if l.startswith("provision"))[-800:])
    log = open(pathlib.Path(tempfile.gettempdir()) / f"savia-a10-api-{a.label}.log", "wb")
    proc = subprocess.Popen([dn, str(API_DLL), "--urls", f"http://127.0.0.1:{PORT}"], cwd=API_PROJECT, env=env, stdout=log, stderr=log)
    sec = set(a.sections.split(","))
    outp = pathlib.Path(a.out)
    allres = json.loads(outp.read_text(encoding="utf-8")) if outp.exists() else {}
    res = allres.setdefault(a.label, {})
    try:
        for _ in range(60):
            try:
                c = http.client.HTTPConnection("127.0.0.1", PORT, timeout=2)
                c.request("GET", "/health")
                if c.getresponse().status == 200:
                    break
            except OSError:
                time.sleep(1)
        api = Api()
        tok = {n: api.login(n, p) for n, p in pws.items()}
        api.token = tok["t_super_a"]
        n = a.n
        reps, kreps = min(13, max(5, n // 15 + 3)), min(23, max(6, n // 9 + 3))  # 13 and 23 at the default n=200
        q("DBCC FREEPROCCACHE WITH NO_INFOMSGS;")
        before = dmv()
        # --- inputs from the database (deterministic order)
        codes = q(f"SELECT TOP {n + 3} b.RawCode FROM catalog.ItemIdentifiers b JOIN inventory.StockBalances s ON s.ItemId=b.ItemId "
                  f"AND s.LocationId='{A['loc']}' WHERE b.Kind='barcode' ORDER BY CHECKSUM(b.RawCode),b.RawCode")
        sales = q(f"SELECT TOP {n + 3} CONVERT(char(36),Id) FROM sales.Sales WHERE BranchId='{A['branch']}' ORDER BY CHECKSUM(Id),Id")
        dates = q("SELECT DISTINCT TOP 60 CONVERT(char(10),CONVERT(date,CreatedAt),23) d FROM sales.Sales ORDER BY d DESC")
        terms = ["Blusa", "Blusa Lino", "Vestido Seda Noche", "M12345", "M4", "Aniversario", "zzqx", "LD004321"]
        enc = lambda s: s.replace(" ", "%20")  # noqa: E731
        if "lookup" in sec:
          measure(api, "lookup_by_code", [("GET", f"/api/v1/catalog/lookup?code={c}", None) for c in codes], res)
        if "search" in sec:
          measure(api, "search_text", [("GET", f"/api/v1/catalog/search?q={enc(terms[i % len(terms)])}&limit=20", None)
                                     for i in range(n + 3)], res)
          for t in terms:
            measure(api, f"search[{t}]", [("GET", f"/api/v1/catalog/search?q={enc(t)}&limit=20", None)] * reps, res)
        if "receipt" in sec:
          measure(api, "receipt_lookup", [("GET", f"/api/v1/sales/{s}", None) for s in sales], res)
          measure(api, "sales_history_page", [("GET", f"/api/v1/sales?from={dates[-1]}&to={dates[0]}&page={1 + i % 20}&pageSize=25", None)
                                            for i in range(53)], res)
        if "reports" in sec:
          measure(api, "day_report", [("GET", f"/api/v1/reports/day?date={dates[i % len(dates)]}", None) for i in range(63)], res)
        for period in (("day", "week", "month") if "kpi" in sec else ()):
            measure(api, f"kpi_business[{period}]", [("GET", f"/api/v1/reports/kpi/business?period={period}&date={dates[i % 30]}", None)
                                                     for i in range(kreps)], res)
            measure(api, f"kpi_team[{period}]", [("GET", f"/api/v1/reports/kpi/team?period={period}&date={dates[i % 30]}", None)
                                                 for i in range(kreps)], res)
        if "lists" in sec:  # first page (the whole list before V042): 3 calls, the first is warm-up; then one full read
          measure(api, "catalog_items_first_page", [("GET", "/api/v1/catalog/items", None)] * 3, res, warm=1)
          measure(api, "stock_first_page", [("GET", "/api/v1/stock", None)] * 3, res, warm=1)
          page_through(api, "catalog_items_all_pages", "/api/v1/catalog/items", res)
          page_through(api, "stock_all_pages", "/api/v1/stock", res)
        if not a.reads_only and "writes" in sec:
            # --- checkout: a till for today, then n sales with 1-3 lines, card tender
            till = str(uuid.uuid4())
            s, raw, _ = api.call("POST", "/api/v1/cash/tills", {"tillId": till, "registerId": A["register"], "currencyCode": "NIO",
                                 "openingMinor": 100000, "lines": [{"denominationMinor": 50000, "quantity": 2}]}, tok["t_cashier_a"])
            res["open_till"] = s
            items = [l.split("|") for l in q(f"SELECT TOP {3 * n + 9} CONCAT(i.Id,'|',i.UnitPriceMinor) FROM inventory.StockBalances b "
                                              f"JOIN catalog.Items i ON i.Id=b.ItemId WHERE b.LocationId='{A['loc']}' AND b.OnHand>=2 "
                                              f"ORDER BY CHECKSUM(i.Id),i.Id")]
            reqs, k = [], 0
            for i in range(n + 3):
                nl = 1 + i % 3
                lines = [{"lineNumber": j + 1, "itemId": items[k + j][0], "quantity": 1, "unitPriceMinor": int(items[k + j][1])}
                         for j in range(nl)]
                k += nl
                total = sum(x["unitPriceMinor"] for x in lines)
                reqs.append(("POST", "/api/v1/sales", {"saleId": str(uuid.uuid4()), "tillId": till, "currencyCode": "NIO", "lines": lines,
                                                       "tenders": [{"tenderNumber": 1, "tenderKind": "card", "amountMinor": total}]}))
            measure(api, "checkout_post_sale", reqs, res, token=tok["t_cashier_a"], expect=(200, 201))
        if not a.reads_only and "import" in sec:
            # --- catalog import 1,000 rows: preview then import, 3 batches of new products.
            # The CPU of the other containers is kept with each commit: contention, not the code, slowed earlier runs.
            for b in range(3):
                rows = [{"row": r + 2, "code": ean13(f"75{b}{r:09d}"), "sku": f"IMP{b}-{r:05d}", "name": f"Import Prueba {b} {r}",
                         "type": "Blusa", "size": "M", "color": "Negro", "cost": "150", "price": "350", "stock": "2"} for r in range(1000)]
                body = {"batchId": str(uuid.uuid4()), "fileName": f"load-{b}.csv", "rows": rows}
                for kind, path in (("preview", "/api/v1/catalog/import/preview"), ("import", "/api/v1/catalog/import")):
                    others = other_containers_cpu()
                    s, raw, ms = api.call("POST", path, body, tok["t_manager"])
                    res.setdefault(f"import_1000_{kind}", []).append({"status": s, "ms": round(ms), "bytes": len(raw),
                                                                       "body": raw[:160].decode("utf-8", "replace") if s != 200 else None,
                                                                       "other_containers_cpu": others})
                print("import batch", b, res["import_1000_preview"][-1], res["import_1000_import"][-1], flush=True)
        if not a.reads_only and "writes" in sec:
            # --- receiving: one session, 100 scans of one code
            cont, sess = str(uuid.uuid4()), str(uuid.uuid4())
            s, raw, _ = api.call("POST", "/api/v1/receiving/sessions", {"containerId": cont, "scanSessionId": sess,
                                 "reference": f"A10-{sess[:8]}", "supplierId": SUPPLIER}, tok["t_manager"])
            res["open_scan_session"] = s if s in (200, 204) else f"{s} {raw[:200]!r}"
            scans = [("POST", f"/api/v1/receiving/sessions/{sess}/scans", {"scanId": str(uuid.uuid4()), "rawCode": codes[0], "quantity": 1})
                     for _ in range(100)]
            lat = []
            for m, path, body in scans:
                s, raw, ms = api.call(m, path, body, tok["t_manager"])
                lat.append(ms if s == 200 else None)
            ok = [x for x in lat if x is not None]
            res["receiving_100_scans"] = {**pct(ok), "errors": 100 - len(ok), "first10_p50": pct(ok[:10]).get("p50"),
                                          "last10_p50": pct(ok[-10:]).get("p50")}
            print("receiving_100_scans", res["receiving_100_scans"], flush=True)
        after = dmv()
        procs = []
        for name, v in after.items():
            b0 = before.get(name, [0] * 5)
            ex = v[0] - b0[0]
            if ex > 0:
                procs.append({"proc": name, "exec": ex, "avg_reads": (v[1] - b0[1]) // ex, "avg_cpu_ms": round((v[2] - b0[2]) / ex / 1000, 1),
                              "avg_elapsed_ms": round((v[3] - b0[3]) / ex / 1000, 1), "max_reads": v[4]})
        res["procedures"] = sorted(procs, key=lambda x: -x["avg_reads"])
        res["adhoc_top_reads"] = adhoc_top()
        for p in res["procedures"][:15]:
            print(f"  {p['proc']:45} exec={p['exec']:>5} reads={p['avg_reads']:>9,} cpu={p['avg_cpu_ms']:>7}ms elapsed={p['avg_elapsed_ms']}ms")
        for l in res["adhoc_top_reads"]:
            print("  adhoc", l)
    finally:
        proc.terminate()
        try:
            proc.wait(10)
        except subprocess.TimeoutExpired:
            proc.kill()
        log.close()
        outp.write_text(json.dumps(allres, indent=1), encoding="utf-8")
        print("wrote", a.out)


if __name__ == "__main__":
    main()

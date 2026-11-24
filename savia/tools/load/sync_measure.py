"""A-10 sync measurement on the databases built by generate.py (P9 procedures, server side, no HTTP).

    SAVIA_SQL_CONTAINER=savia-sqlserver-load python savia/tools/load/sync_measure.py [--out file.json] [--sales 500]

Each pull loops pages (D-041): source state -> receiver plan -> source usp_ReadBatch -> receiver usp_ApplyBatch,
the same procedure chain the .NET P9 transport runs, here as cross-database EXEC so the JSON stays in SQL Server.
A page holds at most 5,000 rows per table and stops adding tables at 19 MB; the loop ends when the receiver
answers more=false. Steps:
  1. restore the four presync backups together, migrate them, and stamp their forks (freshly installed nodes)
  2. initial push: the hub pulls from C, B, then A (smallest first); then hub space used
  3. initial pull: A pulls from the hub
  4. --sales sales at store A, then one round: hub<-A, A<-hub, then an empty round A<-hub
  5. A is restored from a backup taken after step 4 (new recovery fork) and rebuilds from the hub:
     --kill-after pages, one more page read and dropped, then a fresh process resumes; then one normal round
Results are saved after every step; a failed or capped step is recorded with its error and the run continues.
Bytes are the UTF-8 length of the batch JSON. Times are wall-clock milliseconds inside SQL Server.
"""
import argparse
import json
import os
import pathlib
import sys
import time

if os.environ.get("SAVIA_SQL_CONTAINER") != "savia-sqlserver-load":
    sys.exit("refusing to run: set SAVIA_SQL_CONTAINER=savia-sqlserver-load")
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "db"))
import saviadb as d  # noqa: E402

NODE = {"a": "A0000000-0000-0000-0000-0000000000A2", "b": "B0000000-0000-0000-0000-0000000000B2",
        "c": "C0000000-0000-0000-0000-0000000000C2", "hub": "00000000-0000-0000-0000-0000000C10D0"}
DB = {k: f"SAVIA_SIM_load_{k}" for k in NODE}
U8 = "Latin1_General_100_CI_AS_SC_UTF8"


def run(db, text, timeout=900):
    code, out = d.run_sql(db, "SET NOCOUNT ON;\n" + text, timeout=timeout, opts="-y 0")
    if code != 0:
        raise RuntimeError(out[-3000:])
    return out


def kill_running(dbs):
    """After a client-side cap the query can keep running in SQL Server: kill it."""
    names = ",".join(f"DB_ID(N'{DB[k]}')" for k in dbs)
    run("master", f"""DECLARE @k nvarchar(max)=N'';SELECT @k+=CONCAT('KILL ',session_id,';') FROM sys.dm_exec_requests
WHERE session_id<>@@SPID AND session_id>50 AND database_id IN ({names});EXEC(@k);""", timeout=120)


def pull(tgt, src, mode="normal", cap=900, max_pages=None, drop_last_read=False):
    """tgt pulls from src page by page until the source reports no more pages (D-041).

    Each page is: fresh source state -> receiver plan (continues an open pass) -> source usp_ReadBatch ->
    receiver usp_ApplyBatch. max_pages stops the loop early, as a killed process would; drop_last_read then
    reads one more page and throws it away, as a response lost in transit would. Returns totals and per-page rows."""
    t = time.time()
    r = {"step": f"{src}->{tgt}", "mode": mode, "pages": []}
    try:
        while max_pages is None or len(r["pages"]) < max_pages:
            page = _page(tgt, src, mode, cap, apply=True)
            r["pages"].append(page)
            if not page["result"].get("more"):
                break
        if drop_last_read:
            r["dropped_read"] = _page(tgt, src, mode, cap, apply=False)
    except Exception as e:  # noqa: BLE001  record and continue
        if "TimeoutExpired" in type(e).__name__:
            kill_running([tgt, src])
        r["error"] = f"{type(e).__name__}: {str(e)[-600:]}"
    pages = r["pages"]
    r.update(wall_s=round(time.time() - t, 1), page_count=len(pages),
             rows=sum(x["rows"] for x in pages), bytes=sum(x["bytes"] or 0 for x in pages),
             max_page_bytes=max((x["bytes"] or 0 for x in pages), default=0),
             read_ms=sum(x["read_ms"] for x in pages), apply_ms=sum(x["apply_ms"] for x in pages),
             finished=bool(pages) and not pages[-1]["result"].get("more") and "error" not in r)
    print(f"{r['step']:>8} {mode:8} pages={r['page_count']:>4} rows={r['rows']:>9,} bytes={r['bytes']:>12,} "
          f"max_page={r['max_page_bytes']:>11,} read={r['read_ms']}ms apply={r['apply_ms']}ms "
          f"finished={r['finished']} wall={r['wall_s']}s" + (f" ERROR {r['error'][:300]}" if "error" in r else ""), flush=True)
    return r


def _page(tgt, src, mode, cap, apply):
    out = run(DB[tgt], f"""
DECLARE @st nvarchar(max),@pl nvarchar(max),@b nvarchar(max),@r nvarchar(max)=N'{{}}',@ts nvarchar(max),@fork uniqueidentifier=NULL,
        @t0 datetime2(7)=SYSUTCDATETIME(),@t1 datetime2(7),@t2 datetime2(7),@t3 datetime2(7);
EXEC [{DB[src]}].sync.usp_SourceStateJson @Json=@st OUTPUT;
EXEC [{DB[tgt]}].sync.usp_PlanJson @PeerNodeId='{NODE[src]}',@StateJson=@st,@Mode='{mode}',@Json=@pl OUTPUT;
IF JSON_VALUE(@pl,'$.mode')='rebuild' BEGIN EXEC [{DB[tgt]}].sync.usp_SourceStateJson @Json=@ts OUTPUT;SET @fork=JSON_VALUE(@ts,'$.fork');END;
SET @t1=SYSUTCDATETIME();
EXEC [{DB[src]}].sync.usp_ReadBatch @TargetNodeId='{NODE[tgt]}',@PlanJson=@pl,@TargetForkGuid=@fork,@Json=@b OUTPUT;
SET @t2=SYSUTCDATETIME();
IF {int(apply)}=1 EXEC [{DB[tgt]}].sync.usp_ApplyBatch @PeerNodeId='{NODE[src]}',@BatchJson=@b,@Json=@r OUTPUT;
SET @t3=SYSUTCDATETIME();
SELECT CONCAT('RESULT ',(SELECT JSON_VALUE(@b,'$.page') AS page,DATEDIFF_BIG(ms,@t0,@t1) AS plan_ms,DATEDIFF_BIG(ms,@t1,@t2) AS read_ms,
  DATEDIFF_BIG(ms,@t2,@t3) AS apply_ms,DATALENGTH(CAST(@b COLLATE {U8} AS varchar(max))) AS bytes,JSON_QUERY(@r) AS result,
  (SELECT SUM(x.n) FROM (SELECT (SELECT COUNT(*) FROM OPENJSON(t.rows)) n FROM OPENJSON(@b,'$.tables') WITH (rows nvarchar(max) AS JSON) t) x) AS rows,
  JSON_QUERY((SELECT x.t,(SELECT COUNT(*) FROM OPENJSON(x.rows)) AS n,x.done FROM OPENJSON(@b,'$.tables')
              WITH (t nvarchar(200),rows nvarchar(max) AS JSON,done bit) x FOR JSON PATH)) AS tables
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));""", timeout=cap)
    page = json.loads(next(l for l in out.splitlines() if l.startswith("RESULT "))[7:])
    page["rows"] = page.get("rows") or 0
    return page


def restore(names, bak_prefix, fresh_install=False):
    """Restore, then bring the schema to the current migrations (the backups predate V060).

    fresh_install stamps the restored fork as the node's own: the presync backups play freshly installed
    nodes, not a restored store, so they must not start in the recovery lock (51864)."""
    for k in names:
        run("master", f"""IF DB_ID(N'{DB[k]}') IS NOT NULL ALTER DATABASE [{DB[k]}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
RESTORE DATABASE [{DB[k]}] FROM DISK=N'{d.DATA_DIR}/{bak_prefix}_{k}.bak' WITH REPLACE,RECOVERY;
ALTER DATABASE [{DB[k]}] SET MULTI_USER;""")
        code, out = d.migrate(DB[k])
        if code != 0:
            raise RuntimeError(out[-2000:])
        if fresh_install:
            run(DB[k], "UPDATE sync.LocalNode SET ForkGuid=(SELECT ForkGuid FROM sync.CurrentFork);")


def sales_at_a(n):
    """n sales at store A, now (real clock), through sales.usp_PostSale; deterministic item choice."""
    t = time.time()
    out = run(DB["a"], f"""
DECLARE @loc uniqueidentifier='A0000000-0000-0000-0000-0000000000A1',@branch uniqueidentifier='A0000000-0000-0000-0000-00000000000A',
 @node uniqueidentifier='{NODE['a']}',@cashier uniqueidentifier='A0000000-0000-0000-0000-0000000000A4',
 @till uniqueidentifier=CAST(HASHBYTES('MD5','a10:inc:till') AS uniqueidentifier),@i int=0,@sale uniqueidentifier,@item uniqueidentifier,
 @price bigint,@max int,@ok int=0,@bad int=0,@err nvarchar(2048);
EXEC sales.usp_OpenTillCounted @till,'A0000000-0000-0000-0000-0000000000A3',@cashier,'NIO',100000,@node,N'[{{"denominationMinor":50000,"quantity":2}}]';
SELECT IDENTITY(int,1,1) n,b.ItemId,i.UnitPriceMinor price INTO #st FROM inventory.StockBalances b JOIN catalog.Items i ON i.Id=b.ItemId
WHERE b.LocationId=@loc AND b.Pool='store' AND b.OnHand-b.Reserved>=1 ORDER BY i.Sku;
SET @max=@@ROWCOUNT;
WHILE @i<{n}
BEGIN
 SELECT @item=ItemId,@price=price FROM #st WHERE n=1+(@i*7919)%@max;
 SET @sale=CAST(HASHBYTES('MD5',CONCAT('a10:inc:sale:',@i)) AS uniqueidentifier);
 BEGIN TRY
  EXEC sys.sp_executesql N'DECLARE @l sales.SaleLineRequest,@t sales.SaleTenderRequest;INSERT @l VALUES(1,@item,1,@price,0);
   INSERT @t(TenderNumber,TenderKind,AmountMinor) VALUES(1,''card'',@price);
   EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,@CurrencyCode=''NIO'',@OriginNodeId=@node,
     @Lines=@l,@Tenders=@t,@TillId=@till;',N'@item uniqueidentifier,@price bigint,@sale uniqueidentifier,@branch uniqueidentifier,
     @loc uniqueidentifier,@cashier uniqueidentifier,@node uniqueidentifier,@till uniqueidentifier',@item,@price,@sale,@branch,@loc,@cashier,@node,@till;
  SET @ok+=1;
 END TRY BEGIN CATCH SET @bad+=1;IF @err IS NULL SET @err=ERROR_MESSAGE(); END CATCH;
 SET @i+=1;
END;
SELECT CONCAT('SALES ok=',@ok,' failed=',@bad,' first_error=',@err);""")
    print(next(l for l in out.splitlines() if l.startswith("SALES")), f"in {time.time() - t:.1f}s", flush=True)


def oracle(k):
    out = run(DB[k], "DECLARE @v TABLE(c varchar(60),k nvarchar(200),e bigint,a bigint);INSERT @v EXEC audit.usp_CheckConservation @Throw=0;"
                     "SELECT CONCAT('ORACLE ',COUNT(*),' ',MIN(c)) FROM @v;")
    return next(l for l in out.splitlines() if l.startswith("ORACLE"))[7:]


def space(k):
    out = run(DB[k], "DECLARE @u bigint=(SELECT SUM(CAST(FILEPROPERTY(name,'SpaceUsed') AS bigint))*8/1024 FROM sys.database_files WHERE type=0);"
                     "SELECT CONCAT('SPACE used_data_mb=',@u,' file_mb=',(SELECT SUM(size)*8/1024 FROM sys.database_files WHERE type=0));")
    return next(l for l in out.splitlines() if l.startswith("SPACE"))[6:]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--out", default=str(pathlib.Path(__file__).resolve().parents[2] / "docs/evidence/load-a10-20261121/sync.json"))
    p.add_argument("--sales", type=int, default=500)
    p.add_argument("--skip-rebuild", action="store_true")
    p.add_argument("--cap", type=int, default=900, help="client cap per page, seconds")
    p.add_argument("--kill-after", type=int, default=3, help="rebuild pages applied before the simulated kill")
    a = p.parse_args()
    res = {"steps": [], "cap_s": a.cap}
    save = lambda: pathlib.Path(a.out).write_text(json.dumps(res, indent=1), encoding="utf-8")  # noqa: E731
    restore(["a", "b", "c", "hub"], "presync", fresh_install=True)
    for k in "cba":
        res["steps"].append(pull("hub", k, cap=a.cap)); save()
    res["hub_space_after_push"] = space("hub"); print("hub space", res["hub_space_after_push"]); save()
    res["steps"].append(pull("a", "hub", cap=a.cap)); save()
    sales_at_a(a.sales)
    res["steps"].append(pull("hub", "a", cap=a.cap)); save()
    res["steps"].append(pull("a", "hub", cap=a.cap)); save()
    res["steps"].append(pull("a", "hub", cap=a.cap)); save()  # the empty round: nothing changed since the last one
    if not a.skip_rebuild:
        run("master", f"BACKUP DATABASE [{DB['a']}] TO DISK=N'{d.DATA_DIR}/postinc_a.bak' WITH INIT,FORMAT,COMPRESSION;")
        restore(["a"], "postinc")
        res["steps"].append(pull("a", "hub", "rebuild", cap=a.cap, max_pages=a.kill_after, drop_last_read=True)); save()
        res["steps"].append(pull("a", "hub", "rebuild", cap=a.cap)); save()
        res["steps"].append(pull("a", "hub", cap=a.cap)); save()
    res["oracle"] = {k: oracle(k) for k in ("a", "b", "c", "hub")}
    print("oracle", res["oracle"])
    save()
    print("wrote", a.out)


if __name__ == "__main__":
    main()

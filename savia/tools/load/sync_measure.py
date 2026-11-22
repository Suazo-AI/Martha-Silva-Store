"""A-10 sync measurement on the databases built by generate.py (P9 procedures, server side, no HTTP).

    SAVIA_SQL_CONTAINER=savia-sqlserver-load python savia/tools/load/sync_measure.py [--out file.json] [--sales 500]

Steps (each pull is: source state -> receiver plan -> source usp_ReadBatch -> receiver usp_ApplyBatch,
the same procedure chain the .NET P9 transport runs, here as cross-database EXEC so the JSON stays in SQL Server):
  1. restore the four presync backups together
  2. initial push: the hub pulls from C, B, then A (smallest first: three size points before the largest batch)
     (HTTP: a request body, bound by the 30 MB Kestrel limit); then hub sp_spaceused
  3. initial pull: A pulls from the hub                  (HTTP: a response body; bound by the 300 s timeout)
  4. --sales sales at store A, then one round: hub<-A, then A<-hub
  5. A is restored from a backup taken after step 4 (new recovery fork) and rebuilds from the hub (mode rebuild)
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


def pull(tgt, src, mode="normal", cap=900):
    """tgt pulls from src; returns timings, bytes and rows per table (or the error after the cap)."""
    t = time.time()
    try:
        out = _pull_sql(tgt, src, mode, cap)
    except Exception as e:  # noqa: BLE001  record and continue
        if "TimeoutExpired" in type(e).__name__:
            kill_running([tgt, src])
        r = {"step": f"{src}->{tgt}", "mode": mode, "wall_s": round(time.time() - t, 1), "error": f"{type(e).__name__}: {str(e)[-600:]}"}
        print(f"{r['step']:>8} {mode:8} FAILED after {r['wall_s']}s: {r['error'][:300]}", flush=True)
        return r
    line = next(l for l in out.splitlines() if l.startswith("RESULT "))
    r = json.loads(line[7:])
    r.update(step=f"{src}->{tgt}", mode=mode, wall_s=round(time.time() - t, 1),
             rows=sum(x["n"] for x in r.get("tables") or []))
    print(f"{r['step']:>8} {mode:8} rows={r['rows']:>9,} bytes={r['bytes'] or 0:>12,} plan={r['plan_ms']}ms "
          f"read={r['read_ms']}ms apply={r['apply_ms']}ms changed={(r['result'] or {}).get('changed')}", flush=True)
    return r


def _pull_sql(tgt, src, mode, cap):
    return run(DB[tgt], f"""
DECLARE @st nvarchar(max),@pl nvarchar(max),@b nvarchar(max),@r nvarchar(max),@ts nvarchar(max),@fork uniqueidentifier=NULL,
        @t0 datetime2(7)=SYSUTCDATETIME(),@t1 datetime2(7),@t2 datetime2(7),@t3 datetime2(7);
EXEC [{DB[src]}].sync.usp_SourceStateJson @Json=@st OUTPUT;
EXEC [{DB[tgt]}].sync.usp_PlanJson @PeerNodeId='{NODE[src]}',@StateJson=@st,@Mode='{mode}',@Json=@pl OUTPUT;
IF '{mode}'='rebuild' BEGIN EXEC [{DB[tgt]}].sync.usp_SourceStateJson @Json=@ts OUTPUT;SET @fork=JSON_VALUE(@ts,'$.fork');END;
SET @t1=SYSUTCDATETIME();
EXEC [{DB[src]}].sync.usp_ReadBatch @TargetNodeId='{NODE[tgt]}',@PlanJson=@pl,@TargetForkGuid=@fork,@Json=@b OUTPUT;
SET @t2=SYSUTCDATETIME();
EXEC [{DB[tgt]}].sync.usp_ApplyBatch @PeerNodeId='{NODE[src]}',@BatchJson=@b,@Json=@r OUTPUT;
SET @t3=SYSUTCDATETIME();
SELECT CONCAT('RESULT ',(SELECT DATEDIFF_BIG(ms,@t0,@t1) AS plan_ms,DATEDIFF_BIG(ms,@t1,@t2) AS read_ms,DATEDIFF_BIG(ms,@t2,@t3) AS apply_ms,
  DATALENGTH(CAST(@b COLLATE {U8} AS varchar(max))) AS bytes,JSON_QUERY(@r) AS result,
  JSON_QUERY((SELECT p.t,p.a FROM OPENJSON(@pl,'$.tables') WITH (t nvarchar(200),a nvarchar(40)) p FOR JSON PATH)) AS [plan],
  JSON_QUERY((SELECT x.t,(SELECT COUNT(*) FROM OPENJSON(x.rows)) AS n,DATALENGTH(CAST(x.rows COLLATE {U8} AS varchar(max))) AS bytes
              FROM OPENJSON(@b,'$.tables') WITH (t nvarchar(200),rows nvarchar(max) AS JSON) x FOR JSON PATH)) AS tables
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER));""", timeout=cap)


def restore(names, bak_prefix):
    for k in names:
        run("master", f"""IF DB_ID(N'{DB[k]}') IS NOT NULL ALTER DATABASE [{DB[k]}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
RESTORE DATABASE [{DB[k]}] FROM DISK=N'{d.DATA_DIR}/{bak_prefix}_{k}.bak' WITH REPLACE,RECOVERY;
ALTER DATABASE [{DB[k]}] SET MULTI_USER;""")


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
    p.add_argument("--cap", type=int, default=900, help="client cap per pull, seconds")
    a = p.parse_args()
    res = {"steps": [], "cap_s": a.cap}
    save = lambda: pathlib.Path(a.out).write_text(json.dumps(res, indent=1), encoding="utf-8")  # noqa: E731
    restore(["a", "b", "c", "hub"], "presync")
    for k in "cba":
        res["steps"].append(pull("hub", k, cap=a.cap)); save()
    res["hub_space_after_push"] = space("hub"); print("hub space", res["hub_space_after_push"]); save()
    res["steps"].append(pull("a", "hub", cap=a.cap)); save()
    sales_at_a(a.sales)
    res["steps"].append(pull("hub", "a", cap=a.cap)); save()
    res["steps"].append(pull("a", "hub", cap=a.cap)); save()
    if not a.skip_rebuild:
        run("master", f"BACKUP DATABASE [{DB['a']}] TO DISK=N'{d.DATA_DIR}/postinc_a.bak' WITH INIT,FORMAT,COMPRESSION;")
        restore(["a"], "postinc")
        res["steps"].append(pull("a", "hub", "rebuild", cap=a.cap)); save()
    res["oracle"] = {k: oracle(k) for k in ("a", "b", "c", "hub")}
    print("oracle", res["oracle"])
    save()
    print("wrote", a.out)


if __name__ == "__main__":
    main()

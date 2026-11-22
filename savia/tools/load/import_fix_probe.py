"""A-10 proof for the import hot spot, on a disposable load database only (no product code change).

    SAVIA_SQL_CONTAINER=savia-sqlserver-load python savia/tools/load/import_fix_probe.py [--db SAVIA_SIM_load_b] [--rows 1000]

Copies catalog.usp_ImportCatalog into dbo.usp_ImportCatalog_probe with one change: the SKU duplicate check compares
`i.Sku=r.Sku COLLATE Latin1_General_100_BIN2` (the column's own collation) instead of `COLLATE DATABASE_DEFAULT`.
Then runs a preview (@Commit=0) of the same rows through both and prints logical reads and CPU. The probe is dropped.
"""
import argparse
import json
import os
import pathlib
import re
import sys

if os.environ.get("SAVIA_SQL_CONTAINER") != "savia-sqlserver-load":
    sys.exit("refusing to run: set SAVIA_SQL_CONTAINER=savia-sqlserver-load")
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "db"))
import saviadb as d  # noqa: E402

OLD = "i.Sku=r.Sku COLLATE DATABASE_DEFAULT"
NEW = "i.Sku=r.Sku COLLATE Latin1_General_100_BIN2"


def ean13(base12):
    t = sum(int(c) * (3 if i % 2 else 1) for i, c in enumerate(base12))
    return base12 + str((10 - t % 10) % 10)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--db", default="SAVIA_SIM_load_b")
    p.add_argument("--rows", type=int, default=1000)
    a = p.parse_args()
    rows = [{"row": r + 2, "code": ean13(f"769{r:09d}"), "sku": f"PRB-{r:05d}", "name": f"Probe {r}", "type": "Blusa",
             "size": "M", "color": "Negro", "cost": "150", "price": "350", "stock": "2"} for r in range(a.rows)]
    js = json.dumps(rows).replace("'", "''")
    create = f"""SET NOCOUNT ON;DECLARE @def nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID('catalog.usp_ImportCatalog'));
IF CHARINDEX(N'{OLD}',@def)=0 THROW 50000,'pattern not found',1;
SET @def=REPLACE(@def,N'{OLD}',N'{NEW}');
SET @def=STUFF(@def,PATINDEX(N'%PROCEDURE%',@def),PATINDEX(N'%@BatchId%',@def)-PATINDEX(N'%PROCEDURE%',@def),N'PROCEDURE dbo.usp_ImportCatalog_probe ');
SET @def=STUFF(@def,1,PATINDEX(N'%PROCEDURE%',@def)-1,N'CREATE OR ALTER ');
EXEC(@def);"""
    code, out = d.run_sql(a.db, create, opts="-W")
    if code:
        raise SystemExit(out[-1500:])
    res = {}
    try:
        for name in ("catalog.usp_ImportCatalog", "dbo.usp_ImportCatalog_probe"):
            sql = f"""SET NOCOUNT ON;DECLARE @a uniqueidentifier=(SELECT Id FROM security.Staff WHERE LoginName='t_manager');
DECLARE @b uniqueidentifier=NEWID(),@br uniqueidentifier=(SELECT TOP 1 BranchId FROM core.Locations WHERE Id IN (SELECT LocationId FROM inventory.StockBalances) ORDER BY BranchId),
 @loc uniqueidentifier,@node uniqueidentifier=(SELECT TOP 1 NodeId FROM sync.LocalNode);
SET @loc=(SELECT TOP 1 Id FROM core.Locations WHERE BranchId=@br ORDER BY Id);
SET STATISTICS IO ON;SET STATISTICS TIME ON;
EXEC {name} @BatchId=@b,@BranchId=@br,@LocationId=@loc,@ActorId=@a,@FileName=N'probe.csv',@OriginNodeId=@node,@RowsJson=N'{js}',@Commit=0;"""
            code, out = d.run_sql(a.db, sql, timeout=600, opts="-y 0")
            reads = sum(int(m) for m in re.findall(r"(?<!lob )logical reads (\d+)", out))
            times = re.findall(r"CPU time = (\d+) ms,\s+elapsed time = (\d+) ms", out)
            summary = re.search(r'\{"rowsCount".{0,120}', out)
            res[name] = {"exit": code, "logical_reads": reads, "cpu_ms": int(times[-1][0]) if times else None,
                         "elapsed_ms": int(times[-1][1]) if times else None, "preview": summary.group(0) if summary else out[-300:]}
            print(name, res[name], flush=True)
    finally:
        d.run_sql(a.db, "DROP PROCEDURE IF EXISTS dbo.usp_ImportCatalog_probe;")
    out = pathlib.Path(__file__).resolve().parents[2] / "docs/evidence/load-a10-20261121/import-fix-probe.json"
    out.write_text(json.dumps({"db": a.db, "rows": a.rows, "change": {"from": OLD, "to": NEW}, "results": res}, indent=1), encoding="utf-8")
    print("wrote", out)


if __name__ == "__main__":
    main()

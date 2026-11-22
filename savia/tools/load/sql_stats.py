"""A-10 per-query cost: logical reads, CPU and elapsed time (SET STATISTICS IO/TIME) plus the scan operators of the
actual plan (SET STATISTICS XML), for the queries the store API runs. Input for the DTU-risk estimate and hot spots.

    SAVIA_SQL_CONTAINER=savia-sqlserver-load python savia/tools/load/sql_stats.py [--label unconstrained] [--db SAVIA_SIM_load_a]

Each query runs 3 times (the unpaged full lists 2 times): plain runs give cold and warm elapsed and CPU; the last run carries
the plan (SET STATISTICS XML) and gives the logical reads. CPU and elapsed are the outer statement totals.
The inline queries run through sp_executesql with the same parameters as the .NET code (CatalogStore, InventoryStore).
"""
import argparse
import json
import os
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

if os.environ.get("SAVIA_SQL_CONTAINER") != "savia-sqlserver-load":
    sys.exit("refusing to run: set SAVIA_SQL_CONTAINER=savia-sqlserver-load")
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "db"))
import saviadb as d  # noqa: E402

BRANCH, LOC = "A0000000-0000-0000-0000-00000000000A", "A0000000-0000-0000-0000-0000000000A1"
NS = "{http://schemas.microsoft.com/sqlserver/2004/07/showplan}"

SEARCH = """SELECT TOP (@limit) i.Id,i.Sku,p.Name,i.VariantName,sz.Code,co.Code,
  (SELECT TOP (1) x.RawCode FROM catalog.ItemIdentifiers x WHERE x.ItemId=i.Id AND x.Kind='barcode' AND x.IsActive=1 ORDER BY x.IsPrimary DESC,x.CreatedAt,x.Id),
  i.UnitPriceMinor,i.CurrencyCode,i.Status,
  CASE WHEN @location IS NULL THEN NULL ELSE ISNULL(st.OnHand,0) END,CASE WHEN @location IS NULL THEN NULL ELSE ISNULL(st.Available,0) END
FROM catalog.Items i JOIN catalog.Products p ON p.Id=i.ProductId
LEFT JOIN catalog.Sizes sz ON sz.Id=i.SizeId LEFT JOIN catalog.Colors co ON co.Id=i.ColorId
OUTER APPLY (SELECT SUM(v.OnHand) AS OnHand,SUM(v.Available) AS Available FROM inventory.vw_StockAvailable v
             WHERE v.ItemId=i.Id AND v.LocationId=@location AND v.Pool='store') st
WHERE i.Status IN ('active','draft')
  AND (p.Name COLLATE Latin1_General_100_CI_AI LIKE @pattern ESCAPE '\\'
    OR i.VariantName COLLATE Latin1_General_100_CI_AI LIKE @pattern ESCAPE '\\'
    OR i.Sku COLLATE Latin1_General_100_CI_AI LIKE @pattern ESCAPE '\\'
    OR EXISTS (SELECT 1 FROM catalog.ItemIdentifiers x WHERE x.ItemId=i.Id AND x.IsActive=1
               AND x.RawCode COLLATE Latin1_General_100_CI_AI LIKE @pattern ESCAPE '\\'))
ORDER BY p.Name,i.Sku"""
STOCK = """SELECT ItemId,Sku,VariantName,LocationId,Pool,OnHand,Reserved,Available FROM inventory.vw_StockAvailable
WHERE (@branch IS NULL OR BranchId=@branch) AND (@item IS NULL OR ItemId=@item) ORDER BY Sku,LocationId,Pool"""


def q(s):
    return s.replace("'", "''")


def queries(db):
    def scalar(sql):
        code, out = d.run_sql(db, "SET NOCOUNT ON;" + sql, opts="-h -1 -W")
        return out.strip().splitlines()[0].strip()
    code_ = scalar(f"SELECT TOP 1 x.RawCode FROM catalog.ItemIdentifiers x JOIN inventory.StockBalances b ON b.ItemId=x.ItemId "
                   f"AND b.LocationId='{LOC}' WHERE x.IsPrimary=1 ORDER BY x.RawCode DESC")
    sale = scalar(f"SELECT TOP 1 Id FROM sales.Sales WHERE BranchId='{BRANCH}' ORDER BY CreatedAt DESC")
    day = scalar(f"SELECT CONVERT(char(10),MAX(CAST(CreatedAt AS date)),23) FROM sales.Sales WHERE BranchId='{BRANCH}'")
    frm = scalar(f"SELECT CONVERT(char(10),DATEADD(day,-60,'{day}'),23)")
    actor = scalar("SELECT Id FROM security.Staff WHERE LoginName='t_manager'")
    srch = lambda pat, lim=50: (f"EXEC sp_executesql N'{q(SEARCH)}',N'@limit int,@location uniqueidentifier,@pattern nvarchar(4000)',"
                                f"@limit={lim},@location='{LOC}',@pattern=N'{pat}'")
    return {
        "lookup_by_scan": f"EXEC catalog.usp_LookupByScan @RawCode=N'{code_}',@SupplierId=NULL",
        "search[Blusa]": srch("%Blusa%"),
        "search[M12345]": srch("%M12345%"),
        "search[zzqx no match]": srch("%zzqx%"),
        "receipt_detail": f"EXEC sales.usp_GetSaleDetail @BranchId='{BRANCH}',@SaleId='{sale}'",
        "day_report (usp_GetDayReport)": f"EXEC sales.usp_GetDayReport @BranchId='{BRANCH}',@Date='{day}'",
        "day_report (usp_GetReturnsByKind)": f"EXEC sales.usp_GetReturnsByKind @BranchId='{BRANCH}',@Date='{day}'",
        "sales_search_page": f"EXEC sales.usp_SearchSales @BranchId='{BRANCH}',@From='{frm}',@To='{day}',@Query=NULL,@Page=1,@PageSize=25",
        "kpi_business[day]": f"EXEC sales.usp_KpiBusiness @BranchId='{BRANCH}',@ActorId='{actor}',@Period='day',@Date='{day}'",
        "kpi_business[month]": f"EXEC sales.usp_KpiBusiness @BranchId='{BRANCH}',@ActorId='{actor}',@Period='month',@Date='{day}'",
        "kpi_team[month]": f"EXEC sales.usp_KpiTeam @BranchId='{BRANCH}',@ActorId='{actor}',@Period='month',@Date='{day}'",
        "kpi_business[year]": f"EXEC sales.usp_KpiBusiness @BranchId='{BRANCH}',@ActorId='{actor}',@Period='year',@Date='{day}'",
        "catalog_items_full (usp_ListSaleCatalog)": f"EXEC catalog.usp_ListSaleCatalog @LocationId='{LOC}'",
        "stock_full (/stock)": f"EXEC sp_executesql N'{q(STOCK)}',N'@branch uniqueidentifier,@item uniqueidentifier',@branch='{BRANCH}',@item=NULL",
    }


def run_one(db, sql, xml):
    pre = "SET NOCOUNT ON;SET STATISTICS IO ON;SET STATISTICS TIME ON;" + ("SET STATISTICS XML ON;" if xml else "")
    # -r1 sends the STATISTICS messages to stderr, which saviadb merges into the output; result rows are counted only by size.
    code, out = d.run_sql(db, pre + "\n" + sql, timeout=600, opts="-y 0 -r1")
    if code != 0:
        raise RuntimeError(out[-2000:])
    reads = sum(int(m) for m in re.findall(r"(?<!lob )logical reads (\d+)", out))
    times = re.findall(r"CPU time = (\d+) ms,\s+elapsed time = (\d+) ms", out)
    cpu, ela = (int(times[-1][0]), int(times[-1][1])) if times else (None, None)
    plans = [l[l.index("<ShowPlanXML"):] for l in out.splitlines() if "<ShowPlanXML" in l]
    return reads, cpu, ela, plans, len(out)


def scans(plans):
    found = []
    for p in plans:
        try:
            root = ET.fromstring(p)
        except ET.ParseError:
            continue
        for op in root.iter(f"{NS}RelOp"):
            phys = op.get("PhysicalOp", "")
            if "Scan" not in phys:
                continue
            obj = op.find(f".//{NS}Object")
            rows = sum(int(r.get("ActualRows", 0)) for r in op.iter(f"{NS}RunTimeCountersPerThread"))
            read = sum(int(r.get("ActualRowsRead", 0) or 0) for r in op.iter(f"{NS}RunTimeCountersPerThread"))
            execs = sum(int(r.get("ActualExecutions", 0)) for r in op.iter(f"{NS}RunTimeCountersPerThread"))
            if obj is None or (read or rows) < 1000:
                continue
            found.append({"op": phys, "object": f"{obj.get('Schema','')}.{obj.get('Table','')}.{obj.get('Index','')}".replace("[", "").replace("]", ""),
                          "rows_read": read or rows, "rows_out": rows, "executions": execs})
    found.sort(key=lambda x: -x["rows_read"])
    return found[:6]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--db", default="SAVIA_SIM_load_a")
    p.add_argument("--label", default="unconstrained")
    p.add_argument("--out", default=None)
    a = p.parse_args()
    out = a.out or str(pathlib.Path(__file__).resolve().parents[2] / f"docs/evidence/load-a10-20261121/sql-stats-{a.label}.json")
    res = {"db": a.db, "label": a.label, "queries": {}}
    for name, sql in queries(a.db).items():
        full = "full" in name  # unpaged full lists: one plain run, then the plan run
        runs = [run_one(a.db, sql, xml=False)[:3] for _ in range(1 if full else 2)]
        runs = runs * 2 if full else runs
        reads, cpu, ela, plans, n = run_one(a.db, sql, xml=True)
        r = {"logical_reads": reads, "cpu_ms": cpu, "elapsed_ms": ela, "cold_elapsed_ms": runs[0][2], "warm_cpu_ms": runs[1][1],
             "warm_elapsed_ms": runs[1][2], "big_scans": scans(plans)}
        res["queries"][name] = r
        print(f"{name:42} reads={reads:>10,} cpu={runs[1][1]}ms elapsed={runs[1][2]}ms scans={[(s['object'], s['rows_read']) for s in r['big_scans'][:2]]}", flush=True)
    pathlib.Path(out).write_text(json.dumps(res, indent=1), encoding="utf-8")
    print("wrote", out)


if __name__ == "__main__":
    main()

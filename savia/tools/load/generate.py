"""A-10 load generator: a disposable SAVIA network with 50,000 products and 250,000 variants.

    SAVIA_SQL_CONTAINER=savia-sqlserver-load python savia/tools/load/generate.py [--scale 1.0] [--days 60]

What it builds, inside the load container only:
  SAVIA_SIM_load_base   template migrations + fixture + bulk catalog (no stock, no sales)
  SAVIA_SIM_load_a/b/c  one database per store: opening receipts + 60 days of sales through the real procedures
  SAVIA_SIM_load_hub    the cloud node: base catalog, local node = cloud, nothing synced yet
  presync_*.bak         a backup of all four nodes at the same pre-sync point (restore them together)

Determinism: every bulk id, code, quantity, price and sale choice is a hash of (--seed, tag, row number).
Ids that a procedure creates internally (sale lines, tenders, cash entries, outbox rows) use NEWID() and are not seeded.
The catalog is inserted set-based (same rows usp_RegisterProduct / usp_RegisterItem write, without their outbox events:
the catalog is not a synced table and the outbox is local). Opening stock is inserted set-based as posted scan
receipts that satisfy audit.usp_CheckConservation. Sales, tills, cash counts and closures go through the real procedures.
"""
import argparse
import os
import pathlib
import re
import sys
import time

# A load container only (savia-sqlserver-load, or a numbered one such as savia-sqlserver-load2 for a parallel run).
if not re.fullmatch(r"savia-sqlserver-load\d*", os.environ.get("SAVIA_SQL_CONTAINER", "")):
    sys.exit("refusing to run: set SAVIA_SQL_CONTAINER=savia-sqlserver-load or -load<n> (this script drops and creates databases)")
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "db"))
import saviadb as d  # noqa: E402

MANAGER = "00000000-0000-0000-0000-00000000AD01"
SUPPLIER = "00000000-0000-0000-0000-0000000050A1"
CLOUD = "00000000-0000-0000-0000-0000000C10D0"
SIZES = [("S", "00000000-0000-0000-0000-000000005121"), ("M", "00000000-0000-0000-0000-000000005122"),
         ("L", "00000000-0000-0000-0000-000000005123")]
COLORS = [("NEG", "Negro", "00000000-0000-0000-0000-00000000C0B1"), ("BLA", "Blanco", "00000000-0000-0000-0000-00000000C0B2"),
          ("ROJ", "Rojo", "00000000-0000-0000-0000-00000000C0B3")]
COVER = {"A": 100, "B": 60, "C": 40}  # percent of variants each store stocks


def fx(k, x):
    """Fixture id: branch A = A0000000-0000-0000-0000-00000000000A, location A = ...0000000000A1, and so on."""
    return f"{k}0000000-0000-0000-0000-{('0' * 12 + k + x)[-12:]}"


def ids(k):
    return {"branch": fx(k, ""), "loc": fx(k, "1"), "node": fx(k, "2"), "register": fx(k, "3"), "cashier": fx(k, "4")}


def sql(db, text, timeout=3600, quiet=False):
    t = time.time()
    code, out = d.run_sql(db, "SET NOCOUNT ON;\n" + text, timeout=timeout)
    if code != 0:
        sys.exit(f"SQL failed on {db} (exit {code}):\n{out[-3000:]}")
    if not quiet and out.strip():
        print(out.strip())
    return out, time.time() - t


class Gen:
    def __init__(self, a):
        self.seed, self.P, self.days, self.tpd = a.seed, max(10, int(50000 * a.scale)), a.days, a.tickets
        self.data = d.DATA_DIR

    def g(self, tag, expr):
        return f"CAST(HASHBYTES('MD5',CONCAT('{self.seed}:{tag}:',{expr})) AS uniqueidentifier)"

    def h(self, tag, expr, mod):
        return f"(CAST(SUBSTRING(HASHBYTES('MD5',CONCAT('{self.seed}:{tag}:',{expr})),1,3) AS int)%{mod})"

    def restore(self, bak, name, files_as):
        """Restore bak as database name with physical files named after files_as (so names can be reused)."""
        sql("master", f"""
IF DB_ID(N'{name}') IS NOT NULL BEGIN ALTER DATABASE [{name}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{name}]; END;
RESTORE DATABASE [{name}] FROM DISK=N'{self.data}/{bak}.bak' WITH
  MOVE N'{self.logical[0]}' TO N'{self.data}/{files_as}.mdf', MOVE N'{self.logical[1]}' TO N'{self.data}/{files_as}_log.ldf', REPLACE, RECOVERY;
ALTER DATABASE [{name}] SET RECOVERY SIMPLE;""", quiet=True)

    def backup(self, name, bak):
        sql("master", f"BACKUP DATABASE [{name}] TO DISK=N'{self.data}/{bak}.bak' WITH INIT, FORMAT, COMPRESSION;", quiet=True)

    # ---------------------------------------------------------------- catalog
    def catalog_sql(self):
        types = ["Blusa", "Vestido", "Pantalón", "Camisa", "Falda", "Jeans", "Chaqueta", "Sandalia", "Zapato", "Bolso",
                 "Short", "Top", "Blazer", "Suéter", "Cárdigan", "Leggings"]
        mats = ["Lino", "Algodón", "Denim", "Seda", "Satén", "Punto", "Encaje", "Cuero", "Gamuza", "Chiffon", "Viscosa", "Popelina"]
        styles = ["Casual", "Formal", "Playa", "Oficina", "Noche", "Básico", "Estampado", "Rayas", "Floral", "Oversize"]
        vals = lambda xs: ",".join(f"({i},N'{w}')" for i, w in enumerate(xs))  # noqa: E731
        sizes = ",".join(f"({i},'{c}','{g}')" for i, (c, g) in enumerate(SIZES))
        colors = ",".join(f"({i},'{c}',N'{n}','{g}')" for i, (c, n, g) in enumerate(COLORS))
        return f"""
SET XACT_ABORT ON;
DECLARE @mgr uniqueidentifier='{MANAGER}',@at datetime2(3)=DATEADD(day,-90,core.ufn_BusinessNow());
SELECT TOP ({self.P}) ROW_NUMBER() OVER(ORDER BY (SELECT NULL))-1 AS n INTO #n FROM sys.all_columns a CROSS JOIN sys.all_columns b;
CREATE TABLE #t(k int PRIMARY KEY,w nvarchar(40));INSERT #t VALUES {vals(types)};
CREATE TABLE #m(k int PRIMARY KEY,w nvarchar(40));INSERT #m VALUES {vals(mats)};
CREATE TABLE #s(k int PRIMARY KEY,w nvarchar(40));INSERT #s VALUES {vals(styles)};
CREATE TABLE #sz(k int PRIMARY KEY,c varchar(8),id uniqueidentifier);INSERT #sz VALUES {sizes};
CREATE TABLE #co(k int PRIMARY KEY,c varchar(8),nm nvarchar(20),id uniqueidentifier);INSERT #co VALUES {colors};
INSERT catalog.Products(Id,Name,Status,CreatedBy,CreatedAt)
SELECT {self.g('p', 'n.n')},
       CONCAT(t.w,N' ',m.w,N' ',s.w,CASE WHEN n.n%1000=7 THEN N' Edición Aniversario' ELSE N'' END,N' M',n.n),'active',@mgr,@at
FROM #n n JOIN #t t ON t.k={self.h('pt', 'n.n', len(types))} JOIN #m m ON m.k={self.h('pm', 'n.n', len(mats))}
JOIN #s s ON s.k={self.h('ps', 'n.n', len(styles))};
SELECT n.n,v.v,n.n*5+v.v AS i,(n.n+2*v.v)%9 AS c,(199+{self.h('pr', 'n.n', 40)}*50)*100 AS price
INTO #i FROM #n n CROSS JOIN (VALUES(0),(1),(2),(3),(4)) v(v);
INSERT catalog.Items(Id,ProductId,SizeId,ColorId,Sku,VariantName,CurrencyCode,UnitPriceMinor,UnitCostMinor,Status,CreatedBy,CreatedAt)
SELECT {self.g('i', 'i.i')},{self.g('p', 'i.n')},sz.id,co.id,CONCAT('LD',RIGHT(CONCAT('000000',i.n),6),'-',sz.c,'-',co.c),
       CONCAT(sz.c,N' / ',co.nm),'NIO',i.price,i.price*45/100,'active',@mgr,@at
FROM #i i JOIN #sz sz ON sz.k=i.c/3 JOIN #co co ON co.k=i.c%3;
INSERT catalog.ItemIdentifiers(Id,ItemId,Kind,RawCode,IsPrimary,CreatedBy,CreatedAt)
SELECT {self.g('bc', 'i.i')},{self.g('i', 'i.i')},'barcode',CONCAT('74',RIGHT(CONCAT('00000000000',i.i),11)),1,@mgr,@at FROM #i i;
SELECT (SELECT COUNT(*) FROM catalog.Products) products,(SELECT COUNT(*) FROM catalog.Items) items,
       (SELECT COUNT(*) FROM catalog.ItemIdentifiers) identifiers;"""

    # ---------------------------------------------------------------- opening stock
    def stock_sql(self, k):
        x = ids(k)
        return f"""
SET XACT_ABORT ON;
DECLARE @mgr uniqueidentifier='{MANAGER}',@sup uniqueidentifier='{SUPPLIER}',@loc uniqueidentifier='{x['loc']}',
        @branch uniqueidentifier='{x['branch']}',@at datetime2(3)=DATEADD(day,-{self.days + 1},core.ufn_BusinessNow());
DECLARE @store nvarchar(150)=(SELECT Name FROM core.Branches WHERE Id=@branch);
IF @store IS NULL THROW 51990,'fixture branch not found',1;
SELECT i.Id AS ItemId,i.Sku,i.UnitCostMinor AS cost,b.RawCode,CONVERT(int,SUBSTRING(i.Sku,3,6))*5 AS k,
       1+{self.h('q' + k, 'i.Sku', 6)} AS q,ROW_NUMBER() OVER(ORDER BY i.Sku)-1 AS rn
INTO #s FROM catalog.Items i JOIN catalog.ItemIdentifiers b ON b.ItemId=i.Id AND b.Kind='barcode' AND b.IsPrimary=1
WHERE i.Sku LIKE 'LD%' AND {self.h('cov' + k, 'i.Sku', 100)}<{COVER[k]};
ALTER TABLE #s ADD r AS rn/500 PERSISTED, ln AS rn%500+1 PERSISTED;
SELECT r,SUM(CONVERT(bigint,q)*cost) AS total INTO #r FROM #s GROUP BY r;
INSERT receiving.ImportContainers(Id,Reference,SupplierId,LocationId,ArrivalAt,Status,CreatedAt)
SELECT {self.g(k + 'ct', 'r')},CONCAT(N'CARGA-INICIAL-{k}-',r),@sup,@loc,@at,'closed',@at FROM #r;
INSERT receiving.ScanSessions(Id,ContainerId,DeviceCode,Status,ClosedAt,ReviewedBy,ReviewedAt,CreatedAt)
SELECT {self.g(k + 'ss', 'r')},{self.g(k + 'ct', 'r')},N'LOAD','posted',@at,@mgr,@at,@at FROM #r;
INSERT receiving.ScanEvents(Id,ScanSessionId,ItemId,RawCode,Quantity,MatchStatus,CreatedAt)
SELECT {self.g(k + 'se', 'Sku')},{self.g(k + 'ss', 'r')},ItemId,RawCode,q,'matched',@at FROM #s;
INSERT purchasing.GoodsReceipts(Id,ScanSessionId,ContainerId,LocationId,CurrencyCode,TotalCostMinor,Status,PostedAt,CreatedBy,CreatedAt)
SELECT {self.g(k + 'gr', 'r')},{self.g(k + 'ss', 'r')},{self.g(k + 'ct', 'r')},@loc,'NIO',total,'posted',@at,@mgr,@at FROM #r;
INSERT purchasing.GoodsReceiptLines(Id,GoodsReceiptId,LineNumber,ItemId,Quantity,UnitCostMinor,Pool,CreatedBy,CreatedAt)
SELECT {self.g(k + 'gl', 'Sku')},{self.g(k + 'gr', 'r')},ln,ItemId,q,cost,'store',@mgr,@at FROM #s;
INSERT inventory.StockBalances(ItemId,LocationId,Pool,OnHand,Reserved,CreatedBy,CreatedAt)
SELECT ItemId,@loc,'store',q,0,@mgr,@at FROM #s;
INSERT inventory.StockMovements(Id,OperationId,ItemId,LocationId,Pool,Kind,OnHandDelta,ReservedDelta,OnHandAfter,ReservedAfter,
       UnitCostMinor,SourceType,SourceId,Status,CreatedBy,CreatedAt)
SELECT {self.g(k + 'mv', 'Sku')},{self.g(k + 'op', 'Sku')},ItemId,@loc,'store','receive',q,0,q,0,cost,'goods_receipt_line',
       {self.g(k + 'gl', 'Sku')},'posted',@mgr,@at FROM #s;
INSERT labels.PrintJobs(Id,ReceiptLineId,ItemId,BranchId,StoreNameSnapshot,SkuSnapshot,BarcodeSnapshot,CopiesRequested,
       CopiesAcknowledged,Status,CreatedBy,CreatedAt)
SELECT {self.g(k + 'pj', 'Sku')},{self.g(k + 'gl', 'Sku')},ItemId,@branch,@store,Sku,RawCode,q,q,'printed',@mgr,@at FROM #s;
SELECT '{k}' store,COUNT(*) balances,SUM(q) units,COUNT(DISTINCT r) receipts FROM #s;"""

    # ---------------------------------------------------------------- sales history (real procedures)
    def sales_sql(self, k):
        x = ids(k)
        return f"""
DECLARE @mgr uniqueidentifier='{MANAGER}',@loc uniqueidentifier='{x['loc']}',@branch uniqueidentifier='{x['branch']}',
        @node uniqueidentifier='{x['node']}',@register uniqueidentifier='{x['register']}',@cashier uniqueidentifier='{x['cashier']}';
DECLARE @today date=CONVERT(date,DATEADD(hour,-6,SYSUTCDATETIME())),@days int={self.days},@day int=0,@j int,@perDay int,@wd int,
        @at datetime2(3),@saleAt datetime2(3),@till uniqueidentifier,@sale uniqueidentifier,@nl int,@ln int,@pick int,@u float,
        @item uniqueidentifier,@price bigint,@total bigint,@kind varchar(20),@sellers nvarchar(max),@ok int=0,@bad int=0,
        @cash bigint,@countJson nvarchar(max),@remaining bigint,@d bigint,@q int,@max int,@err nvarchar(2048)=NULL;
SELECT IDENTITY(int,1,1) AS n,b.ItemId,i.UnitPriceMinor AS price INTO #st
FROM inventory.StockBalances b JOIN catalog.Items i ON i.Id=b.ItemId WHERE b.LocationId=@loc AND b.Pool='store' ORDER BY i.Sku;
CREATE UNIQUE CLUSTERED INDEX cx ON #st(n);SET @max=(SELECT COUNT(*) FROM #st);
CREATE TABLE #l(LineNumber int,ItemId uniqueidentifier,Quantity int,UnitPriceMinor bigint,DiscountMinor bigint);
WHILE @day<@days
BEGIN
 SET @at=DATEADD(hour,16,CONVERT(datetime2,DATEADD(day,@day-@days,@today)));   -- 10:00 Nicaragua
 EXEC core.usp_SetDemoDate @at;
 SET @till={self.g(k + 'till', '@day')};
 EXEC sales.usp_OpenTillCounted @till,@register,@cashier,'NIO',100000,@node,N'[{{"denominationMinor":50000,"quantity":2}}]';
 SET @wd=DATEDIFF(day,'19000101',DATEADD(day,@day-@days,@today))%7;   -- 0 = Monday
 SET @perDay=CASE @wd WHEN 4 THEN 45 WHEN 5 THEN 55 WHEN 6 THEN 40 ELSE 30 END*{self.tpd}/40;
 IF @perDay<1 SET @perDay=1;
 SET @j=0;
 WHILE @j<@perDay
 BEGIN
  SET @saleAt=DATEADD(second,(32400/@perDay)*@j+{self.h(k + 'sec', "@day,'.',@j", 300)},@at);
  EXEC core.usp_SetDemoDate @saleAt;
  SET @sale={self.g(k + 'sale', "@day,'.',@j")};
  SET @nl=CASE WHEN {self.h(k + 'nl', "@day,'.',@j", 100)}<55 THEN 1 WHEN {self.h(k + 'nl', "@day,'.',@j", 100)}<85 THEN 2 ELSE 3 END;
  TRUNCATE TABLE #l;SET @ln=1;
  WHILE @ln<=@nl
  BEGIN
   SET @u={self.h(k + 'it', "@day,'.',@j,'.',@ln", 1000000)}/1000000.0;
   SET @pick=1+CONVERT(int,@u*@u*@max);
   SET @item=NULL;
   SELECT TOP 1 @item=s.ItemId,@price=s.price FROM #st s JOIN inventory.StockBalances b ON b.ItemId=s.ItemId AND b.LocationId=@loc AND b.Pool='store'
   WHERE s.n>=@pick AND b.OnHand-b.Reserved>=1 AND NOT EXISTS(SELECT 1 FROM #l WHERE ItemId=s.ItemId) ORDER BY s.n;
   IF @item IS NOT NULL INSERT #l VALUES(@ln,@item,1,@price,0);SET @ln+=1;
  END;
  SELECT @total=SUM(UnitPriceMinor) FROM #l;
  SET @kind=CASE WHEN {self.h(k + 'tk', "@day,'.',@j", 100)}<40 THEN 'cash' WHEN {self.h(k + 'tk', "@day,'.',@j", 100)}<85 THEN 'card' ELSE 'transfer' END;
  SET @sellers=NULL;   -- the cashier holds the CASHIER role, so the sale needs no seller list
  BEGIN TRY
   EXEC sys.sp_executesql N'DECLARE @l sales.SaleLineRequest,@t sales.SaleTenderRequest;
    INSERT @l SELECT LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor FROM #l;
    INSERT @t(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor,Reference) VALUES(1,@kind,@total,
      CASE WHEN @kind=''cash'' THEN @total END,CASE WHEN @kind=''cash'' THEN 0 END,CASE WHEN @kind=''transfer'' THEN N''Comprobante'' END);
    EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,@CurrencyCode=''NIO'',
      @OriginNodeId=@node,@Lines=@l,@Tenders=@t,@TillId=@till,@SellersJson=@sellers;',
    N'@kind varchar(20),@total bigint,@sale uniqueidentifier,@branch uniqueidentifier,@loc uniqueidentifier,@cashier uniqueidentifier,
      @node uniqueidentifier,@till uniqueidentifier,@sellers nvarchar(max)',
    @kind,@total,@sale,@branch,@loc,@cashier,@node,@till,@sellers;
   SET @ok+=1;
  END TRY
  BEGIN CATCH
   SET @bad+=1;IF @err IS NULL SET @err=ERROR_MESSAGE();
  END CATCH;
  SET @j+=1;
 END;
 SET @saleAt=DATEADD(hour,10,@at);EXEC core.usp_SetDemoDate @saleAt;
 SELECT @cash=SUM(DeltaMinor) FROM sales.CashEntries WHERE TillId=@till;
 SET @remaining=@cash;SET @countJson=N'[';
 DECLARE denom CURSOR LOCAL FAST_FORWARD FOR SELECT DenominationMinor FROM sales.CashDenominations WHERE CurrencyCode='NIO' ORDER BY DenominationMinor DESC;
 OPEN denom;FETCH NEXT FROM denom INTO @d;
 WHILE @@FETCH_STATUS=0 BEGIN SET @q=@remaining/@d;SET @remaining-=@q*@d;
  SET @countJson+=CASE WHEN LEN(@countJson)>1 THEN N',' ELSE N'' END+CONCAT(N'{{"denominationMinor":',@d,N',"quantity":',@q,N'}}');
  FETCH NEXT FROM denom INTO @d;END;
 CLOSE denom;DEALLOCATE denom;SET @countJson+=N']';
 DECLARE @count uniqueidentifier={self.g(k + 'cnt', '@day')},@usd uniqueidentifier={self.g(k + 'usd', '@day')},
         @closure uniqueidentifier={self.g(k + 'cls', '@day')};
 EXEC sales.usp_RecordCashCount @count,@till,@mgr,@countJson,@usd,N'[{{"denominationMinor":100,"quantity":0}}]';
 EXEC sales.usp_CloseTill @closure,@till,@count,@mgr,@node,@usd;
 SET @day+=1;
END;
EXEC core.usp_SetDemoDate NULL;
SELECT '{k}' store,@ok sales_ok,@bad sales_failed,LEFT(@err,300) first_error;"""

    # ---------------------------------------------------------------- pipeline
    def run(self):
        t0 = time.time()
        for db in ("SAVIA_SIM_load_base", "SAVIA_DEV_pilot", "SAVIA_SIM_load_a", "SAVIA_SIM_load_b", "SAVIA_SIM_load_c", "SAVIA_SIM_load_hub"):
            d.drop(db) if d.scalar("master", f"SELECT COUNT(*) FROM sys.databases WHERE name='{db}'") != "0" else None
        d.clone("SAVIA_SIM_load_base")
        sql("master", "ALTER DATABASE [SAVIA_SIM_load_base] SET RECOVERY SIMPLE;", quiet=True)
        out = d.scalar("SAVIA_SIM_load_base", "SELECT STRING_AGG(name,',') WITHIN GROUP (ORDER BY type) FROM sys.database_files")
        self.logical = out.split(",")
        _, s = sql("SAVIA_SIM_load_base", self.catalog_sql())
        print(f"catalog: {s:.1f}s")
        self.backup("SAVIA_SIM_load_base", "load_base")
        for k in "ABC":
            # usp_SetDemoDate only runs in SAVIA_DEV_pilot, so each store is generated under that name and renamed.
            self.restore("load_base", "SAVIA_DEV_pilot", f"SAVIA_SIM_load_{k.lower()}")
            sql("SAVIA_DEV_pilot", f"EXEC sync.usp_SetLocalNode @NodeId='{ids(k)['node']}';", quiet=True)
            _, s = sql("SAVIA_DEV_pilot", self.stock_sql(k))
            print(f"stock {k}: {s:.1f}s")
            _, s = sql("SAVIA_DEV_pilot", self.sales_sql(k))
            print(f"sales {k}: {s:.1f}s")
            _, s = sql("SAVIA_DEV_pilot", "EXEC audit.usp_CheckConservation @Throw=1;SELECT 'oracle clean' result;")
            sql("master", f"""ALTER DATABASE [SAVIA_DEV_pilot] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
ALTER DATABASE [SAVIA_DEV_pilot] MODIFY NAME=[SAVIA_SIM_load_{k.lower()}];
ALTER DATABASE [SAVIA_SIM_load_{k.lower()}] SET MULTI_USER;""", quiet=True)
        self.restore("load_base", "SAVIA_SIM_load_hub", "SAVIA_SIM_load_hub")
        sql("SAVIA_SIM_load_hub", f"EXEC sync.usp_SetLocalNode @NodeId='{CLOUD}';", quiet=True)
        for db in ("a", "b", "c", "hub"):
            sql(f"SAVIA_SIM_load_{db}", "DBCC SHRINKFILE(2,64) WITH NO_INFOMSGS;", quiet=True)
            self.backup(f"SAVIA_SIM_load_{db}", f"presync_{db}")
        sql("master", """SELECT d.name,CONVERT(decimal(9,1),SUM(CASE WHEN f.type=0 THEN f.size END)*8/1024.0) data_mb,
CONVERT(decimal(9,1),SUM(CASE WHEN f.type=1 THEN f.size END)*8/1024.0) log_mb
FROM sys.databases d JOIN sys.master_files f ON f.database_id=d.database_id WHERE d.name LIKE 'SAVIA_SIM_load%' GROUP BY d.name ORDER BY d.name;""")
        print(f"total: {time.time() - t0:.0f}s seed={self.seed} products={self.P} variants={self.P * 5} days={self.days}")


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--scale", type=float, default=1.0, help="1.0 = 50,000 products / 250,000 variants")
    p.add_argument("--days", type=int, default=60)
    p.add_argument("--tickets", type=int, default=40, help="average tickets per store per day (weekend busier)")
    p.add_argument("--seed", default="a10-20261121")
    Gen(p.parse_args()).run()

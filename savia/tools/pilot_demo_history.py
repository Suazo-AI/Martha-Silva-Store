#!/usr/bin/env python3
"""Invented 60-day history, exclusively in SAVIA_DEV_pilot, through the real SQL procedures.

Run after migration + seed, with the API stopped. No credentials are printed.
The development business clock is connection-scoped; authentication always uses real UTC.
"""
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/db'))
import saviadb

DB='SAVIA_DEV_pilot'

def history_sql():
    return r"""
SET NOCOUNT ON;SET XACT_ABORT ON;
IF DB_NAME()<>N'SAVIA_DEV_pilot' THROW 52008,'Solo SAVIA_DEV_pilot.',1;
IF EXISTS(SELECT 1 FROM sales.Sales) THROW 52008,'Use reset --demo para una historia nueva.',1;
DECLARE @branch uniqueidentifier='5A000000-0000-0000-0000-000000000B01',@loc uniqueidentifier='5A000000-0000-0000-0000-000000000A01',
 @register uniqueidentifier='5A000000-0000-0000-0000-000000000C01',@node uniqueidentifier='5A000000-0000-0000-0000-000000000D01',
 @manager uniqueidentifier='5A000000-0000-0000-0000-000000000E02',@stock uniqueidentifier='5A000000-0000-0000-0000-000000000E05',
 @seller1 uniqueidentifier='5A000000-0000-0000-0000-000000000E03',@seller2 uniqueidentifier='5A000000-0000-0000-0000-000000000E04',
 @supplier uniqueidentifier='5A000000-0000-0000-0000-000000000F01',@supplier2 uniqueidentifier='5A000000-0000-0000-0000-000000000F03',
 @customer uniqueidentifier='5A000000-0000-0000-0000-000000000F02';
DECLARE @items TABLE(n int PRIMARY KEY,Id uniqueidentifier,Barcode nvarchar(128),Price bigint);
INSERT @items SELECT ROW_NUMBER() OVER(ORDER BY i.Sku),i.Id,x.RawCode,i.UnitPriceMinor FROM catalog.Items i
CROSS APPLY(SELECT TOP(1) RawCode FROM catalog.ItemIdentifiers WHERE ItemId=i.Id AND Kind='barcode' AND IsActive=1 ORDER BY IsPrimary DESC,Id) x WHERE i.Status='active';
DECLARE @today date=CONVERT(date,DATEADD(hour,-6,SYSUTCDATETIME())),@at datetime2(3),@day int=0,@n int,@max int=(SELECT COUNT(*) FROM @items),
 @container uniqueidentifier,@session uniqueidentifier,@scan uniqueidentifier,@receipt uniqueidentifier,@item uniqueidentifier,@barcode nvarchar(128),@price bigint,@check uniqueidentifier;
SET @at=DATEADD(hour,15,CONVERT(datetime2,DATEADD(day,-59,@today)));EXEC core.usp_SetDemoDate @at;
SET @container=NEWID();SET @session=NEWID();
EXEC receiving.usp_OpenScanSession @container,@session,N'HISTORIA-INICIAL',@supplier,@loc,@stock;
DECLARE @scanResult TABLE(ScanId uniqueidentifier,ItemId uniqueidentifier,MatchStatus varchar(16),Quantity int);
SET @n=1;
WHILE @n<=@max
BEGIN
 SELECT @item=Id,@barcode=Barcode FROM @items WHERE n=@n;SET @scan=NEWID();SET @check=NEWID();
 IF @n>1
 BEGIN
  INSERT @scanResult EXEC receiving.usp_RecordScan @scan,@session,@barcode,15,NULL,@stock;
  EXEC receiving.usp_RecordQuality @check,@session,@item,15,0,0,0,0,N'Revisión inicial de prendas',@stock,@loc;
 END;
 SET @n+=1;
END;
EXEC receiving.usp_ApproveScanSession @session,@manager;
EXEC receiving.usp_PostScanSession @session,@manager,@node,@receipt OUTPUT,'NIO';
DECLARE @previous uniqueidentifier=NULL,@sale uniqueidentifier,@till uniqueidentifier,@count uniqueidentifier,@usdCount uniqueidentifier,@closure uniqueidentifier,
 @line uniqueidentifier,@reverse uniqueidentifier,@credit uniqueidentifier,@j int,@total bigint,@price2 bigint,@item2 uniqueidentifier,@discount bigint,@kind varchar(20),@cash bigint,@difference bigint,@countJson nvarchar(max),@sellers nvarchar(max),@shortNote nvarchar(500);
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest,@returnLines sales.ReturnLineRequest;
DECLARE @weekday int,@perDay int,@saleAt datetime2(3),@first uniqueidentifier,@second uniqueidentifier,@shared bit,@hasTwo bit;
WHILE @day<60
BEGIN
 SET @at=DATEADD(hour,15,CONVERT(datetime2,DATEADD(day,@day-59,@today)));
 -- Before 15:00 UTC the last day would be in the future; keep it in today's Nicaragua date, just before now.
 IF @at>DATEADD(millisecond,-10,SYSUTCDATETIME()) SET @at=DATEADD(millisecond,-10,SYSUTCDATETIME());
 IF @day=59 AND @at<DATEADD(hour,6,CONVERT(datetime2,@today)) SET @at=DATEADD(hour,6,CONVERT(datetime2,@today));
 EXEC core.usp_SetDemoDate @at;
 SET @till=NEWID();EXEC sales.usp_OpenTillCounted @till,@register,@manager,'NIO',100000,@node,N'[{"denominationMinor":50000,"quantity":2}]';
 -- Replenishment with a damaged and a missing unit; only the three good units are sellable.
 IF @day%7=0
 BEGIN
  SELECT @item=Id,@barcode=Barcode FROM @items WHERE n=1+(@day%@max);
  SET @container=NEWID();SET @session=NEWID();SET @scan=NEWID();SET @check=NEWID();
  DECLARE @supp uniqueidentifier=CASE WHEN @day%2=0 THEN @supplier ELSE @supplier2 END;
  DECLARE @ref nvarchar(100)=CONCAT(N'HISTORIA-',@day);
  EXEC receiving.usp_OpenScanSession @container,@session,@ref,@supp,@loc,@stock;
  INSERT @scanResult EXEC receiving.usp_RecordScan @scan,@session,@barcode,5,NULL,@stock;
  EXEC receiving.usp_RecordQuality @check,@session,@item,3,1,0,0,1,N'Una dañada, una faltante al verificar entrega',@stock,@loc;
  EXEC receiving.usp_ApproveScanSession @session,@manager;
  EXEC receiving.usp_PostScanSession @session,@manager,@node,@receipt OUTPUT,'NIO';
 END;
 IF @previous IS NOT NULL AND (@day%9=0 OR DAY(@at)=1)
 BEGIN
  SELECT TOP(1) @line=Id FROM sales.SaleLines WHERE SaleId=@previous ORDER BY LineNumber;
  SET @reverse=NEWID();SET @credit=NEWID();
  -- Table variables are reset by scope in a helper block via a JSON-backed procedure batch below.
  DECLARE @returnJson nvarchar(max)=CONCAT(N'[{"saleLineId":"',@line,N'","quantity":1,"restockPool":"store"}]');
  EXEC sys.sp_executesql N'DECLARE @l sales.ReturnLineRequest;INSERT @l SELECT saleLineId,quantity,restockPool FROM OPENJSON(@json) WITH(saleLineId uniqueidentifier,quantity int,restockPool varchar(12));EXEC sales.usp_PostCreditReturn @reversal,@credit,@sale,@branch,@loc,@till,@manager,@manager,@customer,N"Cambio de talla",@node,@l;',
   N'@json nvarchar(max),@reversal uniqueidentifier,@credit uniqueidentifier,@sale uniqueidentifier,@branch uniqueidentifier,@loc uniqueidentifier,@till uniqueidentifier,@manager uniqueidentifier,@customer uniqueidentifier,@node uniqueidentifier',@returnJson,@reverse,@credit,@previous,@branch,@loc,@till,@manager,@customer,@node;
 END;
 SET @j=0;
 -- Invented rhythm, the same on every run: busier Friday to Sunday, 3 to 8 tickets a day spread over the day,
 -- one or two garments, about one ticket in three shared by the two sellers, and Ana opens 3 of every 5 tickets.
 SET @weekday=DATEDIFF(day,'19000101',CONVERT(date,DATEADD(hour,-6,@at)))%7;   -- 0 = Monday
 SET @perDay=3+(@day*5)%3+CASE @weekday WHEN 5 THEN 3 WHEN 4 THEN 2 WHEN 6 THEN 1 ELSE 0 END;
 WHILE @j<@perDay
 BEGIN
  SET @saleAt=DATEADD(minute,50*@j+(@day*13)%40,@at);
  IF @saleAt>DATEADD(millisecond,-10,SYSUTCDATETIME()) SET @saleAt=DATEADD(millisecond,-10,SYSUTCDATETIME());
  EXEC core.usp_SetDemoDate @saleAt;
  SET @first=CASE WHEN (@day*2+@j)%5 IN (0,2,3) THEN @seller1 ELSE @seller2 END;
  SET @shared=CASE WHEN (@day+@j*2)%3=0 THEN 1 ELSE 0 END;
  SET @hasTwo=CASE WHEN @shared=1 OR (@day+@j)%4=1 THEN 1 ELSE 0 END;
  SET @second=CASE WHEN @shared=0 THEN @first WHEN @first=@seller1 THEN @seller2 ELSE @seller1 END;
  SELECT @item=Id,@price=Price FROM @items WHERE n=1+((@day*3+@j)%@max);
  SELECT @item2=Id,@price2=Price FROM @items WHERE n=1+((@day*3+@j+17)%@max);
  SET @discount=CASE WHEN (@day+@j)%7=0 THEN @price/10 ELSE 0 END;SET @total=@price-@discount+CASE WHEN @hasTwo=1 THEN @price2 ELSE 0 END;
  SET @kind=CASE (@day+@j)%3 WHEN 0 THEN 'cash' WHEN 1 THEN 'card' ELSE 'transfer' END;
  SET @sale=NEWID();SET @shortNote=N'Gerente confirmó existencia física al atender';
  SET @sellers=(SELECT v.lineNumber,v.sellerId FROM (VALUES(1,@first),(2,@second)) v(lineNumber,sellerId) WHERE v.lineNumber=1 OR @hasTwo=1 FOR JSON PATH);
  -- Each execution gets fresh typed table variables; no physical DELETE on business or staging tables.
  EXEC sys.sp_executesql N'DECLARE @l sales.SaleLineRequest,@t sales.SaleTenderRequest;
   INSERT @l VALUES(1,@one,1,@p1,@disc);IF @hasTwo=1 INSERT @l VALUES(2,@two,1,@p2,0);
   INSERT @t(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor,Reference) VALUES(1,@kind,@total,CASE WHEN @kind=''cash'' THEN @total ELSE NULL END,CASE WHEN @kind=''cash'' THEN 0 ELSE NULL END,CASE WHEN @kind=''transfer'' THEN N''Comprobante de tienda'' ELSE NULL END);
   EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@manager,@CurrencyCode=''NIO'',@OriginNodeId=@node,@Lines=@l,@Tenders=@t,@TillId=@till,@DiscountReason=N''Atención comercial de gerente'',@StockExceptionNote=@note,@SellersJson=@sellers;',
   N'@one uniqueidentifier,@two uniqueidentifier,@p1 bigint,@p2 bigint,@disc bigint,@kind varchar(20),@total bigint,@sale uniqueidentifier,@branch uniqueidentifier,@loc uniqueidentifier,@manager uniqueidentifier,@node uniqueidentifier,@till uniqueidentifier,@note nvarchar(500),@sellers nvarchar(max),@hasTwo bit',
   @item,@item2,@price,@price2,@discount,@kind,@total,@sale,@branch,@loc,@manager,@node,@till,@shortNote,@sellers,@hasTwo;
  SET @previous=@sale;SET @j+=1;
 END;
 SELECT @cash=SUM(DeltaMinor) FROM sales.CashEntries WHERE TillId=@till;
 SET @difference=CASE WHEN @day%11=0 THEN 10 WHEN @day%17=0 THEN -10 ELSE 0 END;
 DECLARE @remaining bigint=@cash+@difference;
 DECLARE @denoms TABLE(d bigint,q int);
 -- A fresh scope prevents count rows from accumulating between days.
 SET @countJson=N'[';
 DECLARE denom CURSOR LOCAL FAST_FORWARD FOR SELECT DenominationMinor FROM sales.CashDenominations WHERE CurrencyCode='NIO' ORDER BY DenominationMinor DESC;
 DECLARE @d bigint,@q int;OPEN denom;FETCH NEXT FROM denom INTO @d;
 WHILE @@FETCH_STATUS=0 BEGIN SET @q=@remaining/@d;SET @remaining=@remaining-@q*@d;SET @countJson+=CASE WHEN LEN(@countJson)>1 THEN N',' ELSE N'' END+CONCAT(N'{"denominationMinor":',@d,N',"quantity":',@q,N'}');FETCH NEXT FROM denom INTO @d;END;
 CLOSE denom;DEALLOCATE denom;SET @countJson+=N']';
 SET @count=NEWID();SET @usdCount=NEWID();SET @closure=NEWID();EXEC sales.usp_RecordCashCount @count,@till,@manager,@countJson,@usdCount,N'[{"denominationMinor":100,"quantity":0}]';EXEC sales.usp_CloseTill @closure,@till,@count,@manager,@node,@usdCount;
 SET @day+=1;
END;
DECLARE @exception uniqueidentifier;
DECLARE exceptions CURSOR LOCAL FAST_FORWARD FOR SELECT Id FROM sales.StockExceptions WHERE ReviewedAt IS NULL;
OPEN exceptions;FETCH NEXT FROM exceptions INTO @exception;
WHILE @@FETCH_STATUS=0 BEGIN EXEC sales.usp_ReviewStockException @branch,@exception,@manager,N'Conteo físico revisado con bodega';FETCH NEXT FROM exceptions INTO @exception;END;
CLOSE exceptions;DEALLOCATE exceptions;
EXEC core.usp_SetDemoDate NULL;
EXEC audit.usp_CheckConservation @Throw=1;
SELECT CONCAT('DEMO PASS days=',@day,' sales=',(SELECT COUNT(*) FROM sales.Sales),' items=',@max);
""".replace('N"Cambio de talla"', "N''Cambio de talla''")

def run():
    code,out=saviadb.run_sql(DB,history_sql(),timeout=600)
    if code:
        raise SystemExit('demo history failed:\n'+out[-2500:])
    print(out.strip())
    return 0

if __name__=='__main__':sys.exit(run())

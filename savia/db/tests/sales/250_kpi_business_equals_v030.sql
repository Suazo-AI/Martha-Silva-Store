-- TEST: V040 usp_KpiBusiness returns the same JSON as the V030 procedure for every period, with sales, a return and stale stock.
SET NOCOUNT ON;
GO
-- The V030 procedure, copied unchanged under a test name: the reference result.
CREATE PROCEDURE test.usp_KpiBusinessV030 @BranchId uniqueidentifier,@ActorId uniqueidentifier,@Period varchar(8),@Date date
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffBranchAccess a ON a.StaffId=s.Id JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId
  WHERE s.Id=@ActorId AND s.IsEnabled=1 AND a.BranchId=@BranchId AND a.IsActive=1 AND r.IsActive=1 AND r.Code IN ('MANAGER','OWNER')) THROW 52001,'Sin acceso a indicadores del negocio.',1;
 IF @Period NOT IN ('day','week','month','year') OR @Date IS NULL OR @Date<'19000101' OR @Date>='99990101' THROW 51900,'Periodo o fecha invalida.',1;
 DECLARE @from date=CASE @Period WHEN 'week' THEN DATEADD(day,-DATEDIFF(day,'19000101',@Date)%7,@Date) WHEN 'month' THEN DATEFROMPARTS(YEAR(@Date),MONTH(@Date),1) WHEN 'year' THEN DATEFROMPARTS(YEAR(@Date),1,1) ELSE @Date END;
 DECLARE @until date=CASE @Period WHEN 'week' THEN DATEADD(day,7,@from) WHEN 'month' THEN DATEADD(month,1,@from) WHEN 'year' THEN DATEADD(year,1,@from) ELSE DATEADD(day,1,@from) END;
 DECLARE @start datetime2=DATEADD(hour,6,CONVERT(datetime2,@from)),@end datetime2=DATEADD(hour,6,CONVERT(datetime2,@until)),@now datetime2=core.ufn_BusinessNow();
 DECLARE @days int=DATEDIFF(day,@from,@until);
 SELECT s.Id,s.CreatedAt,s.SubtotalMinor,s.DiscountMinor,s.TotalMinor INTO #s FROM sales.Sales s
  WHERE s.BranchId=@BranchId AND s.CurrencyCode='NIO' AND s.Status<>'cancelled' AND s.CreatedAt>=@start AND s.CreatedAt<@end;
 SELECT r.Id,r.SettlementKind,r.CreditMinor INTO #r FROM sales.SaleReversals r
  WHERE r.BranchId=@BranchId AND r.CurrencyCode='NIO' AND r.Status='approved' AND r.CreatedAt>=@start AND r.CreatedAt<@end;
 DECLARE @count bigint=(SELECT COUNT(*) FROM #s),@sold bigint=(SELECT COALESCE(SUM(TotalMinor),0) FROM #s),
  @subtotal bigint=(SELECT COALESCE(SUM(SubtotalMinor),0) FROM #s),@discount bigint=(SELECT COALESCE(SUM(DiscountMinor),0) FROM #s),
  @returns bigint=(SELECT COALESCE(SUM(CreditMinor),0) FROM #r),
  @units bigint=(SELECT COALESCE(SUM(CONVERT(bigint,l.Quantity)),0) FROM #s s JOIN sales.SaleLines l ON l.SaleId=s.Id),
  @cogs bigint=(SELECT COALESCE(SUM(l.COGSMinor),0) FROM #s s JOIN sales.SaleLines l ON l.SaleId=s.Id)
   -(SELECT COALESCE(SUM(l.COGSReversedMinor),0) FROM #r r JOIN sales.SaleReversalLines l ON l.ReversalId=r.Id);
 DECLARE @refundRevenue bigint;
 -- Reverse tax cumulatively per original line so split refunds conserve the original tax.
 -- The difference between the end and start allocations belongs to this period.
 ;WITH PeriodRefunds AS (
  SELECT rl.SaleLineId,SUM(rl.CreditMinor) AS GrossMinor
  FROM #r r JOIN sales.SaleReversalLines rl ON rl.ReversalId=r.Id
  GROUP BY rl.SaleLineId
 )
 SELECT @refundRevenue=COALESCE(SUM(p.GrossMinor-COALESCE(CONVERT(bigint,
   ((tax.EndProduct-tax.EndProduct%denom.GrossMinor)-(tax.StartProduct-tax.StartProduct%denom.GrossMinor))
   /denom.GrossMinor),0)),0)
 FROM PeriodRefunds p
 JOIN sales.SaleLines l ON l.Id=p.SaleLineId
 CROSS APPLY(
  SELECT COALESCE(SUM(rl.CreditMinor),0) AS GrossMinor
  FROM sales.SaleReversals r JOIN sales.SaleReversalLines rl ON rl.ReversalId=r.Id
  WHERE r.SaleId=l.SaleId AND rl.SaleLineId=l.Id AND r.BranchId=@BranchId AND r.CurrencyCode='NIO'
    AND r.Status='approved' AND r.CreatedAt<@start
 ) prior
 -- Remove the remainder before division to floor exactly, even at bigint limits.
 CROSS APPLY(SELECT NULLIF(l.TotalMinor,0) AS GrossMinor) denom
 CROSS APPLY(SELECT CONVERT(decimal(38,0),prior.GrossMinor)*l.TaxMinor AS StartProduct,
                    CONVERT(decimal(38,0),prior.GrossMinor+p.GrossMinor)*l.TaxMinor AS EndProduct) tax;
 DECLARE @revenue bigint=@subtotal-@discount-@refundRevenue;
 DECLARE @margin bigint=@revenue-@cogs;
 SELECT i.Id AS ItemId,i.ProductId,i.Sku,i.VariantName,i.UnitCostMinor,SUM(CONVERT(bigint,b.OnHand)) AS OnHand INTO #stock
  FROM inventory.StockBalances b JOIN core.Locations loc ON loc.Id=b.LocationId JOIN catalog.Items i ON i.Id=b.ItemId
  WHERE loc.BranchId=@BranchId AND b.Pool='store' GROUP BY i.Id,i.ProductId,i.Sku,i.VariantName,i.UnitCostMinor;
 DECLARE @stockUnits bigint=(SELECT COALESCE(SUM(OnHand),0) FROM #stock),@stockValue bigint=(SELECT COALESCE(SUM(OnHand*COALESCE(UnitCostMinor,0)),0) FROM #stock);
 SELECT (SELECT @Period AS period,@Date AS date,@from AS startDate,DATEADD(day,-1,@until) AS endDate,'NIO' AS currencyCode,
  @sold AS grossSalesMinor,@sold-@returns AS netSalesMinor,@count AS salesCount,
  CASE WHEN @count=0 THEN 0 ELSE @sold/@count END AS averageTicketMinor,
  @units AS unitsSold,CASE WHEN @count=0 THEN 0 ELSE @units*100/@count END AS unitsPerTicketX100,
  @revenue AS revenueMinor,@cogs AS costOfGoodsMinor,@margin AS grossMarginMinor,
  CASE WHEN @revenue<=0 THEN 0 ELSE @margin*10000/@revenue END AS grossMarginBps,
  @discount AS discountsMinor,CASE WHEN @subtotal=0 THEN 0 ELSE @discount*10000/@subtotal END AS discountsBps,
  @returns AS returnsMinor,(SELECT COUNT(*) FROM #r) AS returnsCount,CASE WHEN @sold=0 THEN 0 ELSE @returns*10000/@sold END AS returnsBps,
  JSON_QUERY(COALESCE((SELECT SettlementKind AS kind,COUNT(*) AS returnsCount,SUM(CreditMinor) AS amountMinor FROM #r GROUP BY SettlementKind ORDER BY SettlementKind FOR JSON PATH),N'[]')) AS refundsByKind,
  @stockUnits AS stockUnits,@stockValue AS stockValueAtCostMinor,
  CASE WHEN @units=0 THEN NULL ELSE @stockUnits*@days/@units END AS daysOfInventory,
  JSON_QUERY(COALESCE((SELECT TOP(50) p.Id AS productId,p.Name AS name,x.received AS unitsReceived,x.sold AS unitsSold,
    CASE WHEN x.received=0 THEN 0 ELSE x.sold*10000/x.received END AS sellThroughBps
   FROM catalog.Products p CROSS APPLY(SELECT
    (SELECT COALESCE(SUM(CONVERT(bigint,m.OnHandDelta)),0) FROM inventory.StockMovements m JOIN catalog.Items i ON i.Id=m.ItemId JOIN core.Locations loc ON loc.Id=m.LocationId
      WHERE i.ProductId=p.Id AND loc.BranchId=@BranchId AND m.CreatedAt<@end AND (m.Kind='receive' OR (m.Kind='adjust' AND m.SourceType='catalog_import'))) AS received,
    (SELECT COALESCE(SUM(CONVERT(bigint,l.Quantity)-returned.Quantity),0)
     FROM sales.SaleLines l JOIN sales.Sales s ON s.Id=l.SaleId JOIN catalog.Items i ON i.Id=l.ItemId
     CROSS APPLY(
      SELECT COALESCE(SUM(CONVERT(bigint,rl.Quantity)),0) AS Quantity
      FROM sales.SaleReversals r JOIN sales.SaleReversalLines rl ON rl.ReversalId=r.Id
      WHERE r.SaleId=s.Id AND rl.SaleLineId=l.Id AND r.Status='approved' AND r.CreatedAt<@end
     ) returned
     WHERE i.ProductId=p.Id AND s.BranchId=@BranchId AND s.Status<>'cancelled' AND s.CreatedAt<@end) AS sold) x
   WHERE x.received>0 ORDER BY sellThroughBps DESC,p.Name,p.Id FOR JSON PATH),N'[]')) AS sellThrough,
  JSON_QUERY(COALESCE((SELECT TOP(100) st.ItemId AS itemId,st.Sku AS sku,st.VariantName AS name,st.OnHand AS onHand,lm.LastAt AS lastMovementAt
   FROM #stock st OUTER APPLY(SELECT MAX(m.CreatedAt) AS LastAt FROM inventory.StockMovements m JOIN core.Locations loc ON loc.Id=m.LocationId WHERE m.ItemId=st.ItemId AND loc.BranchId=@BranchId) lm
   WHERE st.OnHand>0 AND (lm.LastAt IS NULL OR lm.LastAt<DATEADD(day,-60,@now)) ORDER BY lm.LastAt,st.Sku FOR JSON PATH),N'[]')) AS staleItems,
  (SELECT COUNT(*) FROM sales.StockExceptions e JOIN sales.SaleLines l ON l.Id=e.SaleLineId JOIN #s s ON s.Id=l.SaleId) AS stockExceptionsCount,
  (SELECT COALESCE(SUM(CONVERT(bigint,q.Damaged+q.Stained+q.Odor+q.Missing)),0) FROM receiving.vw_CurrentQuality q
    JOIN receiving.ScanSessions ss ON ss.Id=q.ScanSessionId JOIN receiving.ImportContainers c ON c.Id=ss.ContainerId JOIN core.Locations loc ON loc.Id=c.LocationId
    WHERE loc.BranchId=@BranchId AND q.CreatedAt>=@start AND q.CreatedAt<@end) AS qualityRejects,
  (SELECT COUNT(*) FROM sales.CashClosures cl JOIN sales.CashTills t ON t.Id=cl.TillId JOIN sales.CashRegisters reg ON reg.Id=t.RegisterId
    WHERE t.ParentTillId IS NULL AND t.CurrencyCode='NIO' AND reg.BranchId=@BranchId AND cl.ClosedAt>=@start AND cl.ClosedAt<@end) AS tillClosures,
  (SELECT COUNT(*) FROM sales.CashClosures cl JOIN sales.CashTills t ON t.Id=cl.TillId JOIN sales.CashRegisters reg ON reg.Id=t.RegisterId
    WHERE t.ParentTillId IS NULL AND t.CurrencyCode='NIO' AND reg.BranchId=@BranchId AND cl.ClosedAt>=@start AND cl.ClosedAt<@end AND
      (cl.DifferenceMinor<>0 OR EXISTS(
        SELECT 1 FROM sales.CashTills usd JOIN sales.CashClosures usdCl ON usdCl.TillId=usd.Id
        WHERE usd.ParentTillId=t.Id AND usd.CurrencyCode='USD' AND usdCl.DifferenceMinor<>0
      ))) AS tillClosuresWithDifference,
  (SELECT COALESCE(SUM(cl.DifferenceMinor),0) FROM sales.CashClosures cl JOIN sales.CashTills t ON t.Id=cl.TillId JOIN sales.CashRegisters reg ON reg.Id=t.RegisterId
    WHERE t.ParentTillId IS NULL AND t.CurrencyCode='NIO' AND reg.BranchId=@BranchId AND cl.ClosedAt>=@start AND cl.ClosedAt<@end) AS tillDifferenceMinor,
  (SELECT COALESCE(SUM(cl.DifferenceMinor),0) FROM sales.CashClosures cl JOIN sales.CashTills t ON t.Id=cl.TillId JOIN sales.CashRegisters reg ON reg.Id=t.RegisterId
    WHERE t.CurrencyCode='USD' AND t.ParentTillId IS NOT NULL AND reg.BranchId=@BranchId AND cl.ClosedAt>=@start AND cl.ClosedAt<@end) AS usdTillDifferenceMinor,
  JSON_QUERY(COALESCE((SELECT DATEPART(hour,DATEADD(hour,-6,CreatedAt)) AS hour,COUNT(*) AS salesCount,SUM(TotalMinor) AS totalMinor
   FROM #s GROUP BY DATEPART(hour,DATEADD(hour,-6,CreatedAt)) ORDER BY hour FOR JSON PATH),N'[]')) AS salesByHour
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS Json;
END;
GO
SET NOCOUNT ON;SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),@item uniqueidentifier=test.Id('item'),
 @item2 uniqueidentifier=test.Id('item2'),@node uniqueidentifier=test.Id('nodeA'),@owner uniqueidentifier=test.Id('manager'),
 @manager uniqueidentifier=test.Id('supervisorA'),@cashier uniqueidentifier=test.Id('cashierA'),@register uniqueidentifier=test.Id('registerA'),
 @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@sale2 uniqueidentifier=NEWID(),@rev uniqueidentifier=NEWID(),
 @product2 uniqueidentifier=NEWID(),@dress uniqueidentifier=NEWID(),@stale uniqueidentifier=NEWID(),@e uniqueidentifier;
-- A second product so sell-through orders more than one row; one of its variants has only old stock.
SET @e=NEWID();EXEC catalog.usp_RegisterProduct @ProductId=@product2,@Name=N'Vestido Test',@ActorId=@owner,@OriginNodeId=@node,@EventId=@e;
SET @e=NEWID();EXEC catalog.usp_RegisterItem @ProductId=@product2,@Sku=N'T-VES-0001',@VariantName=N'Vestido Azul M',@CurrencyCode='NIO',
 @UnitPriceMinor=200000,@UnitCostMinor=90000,@Barcode=N'0000222000333',@ActorId=@owner,@ItemId=@dress,@OriginNodeId=@node,@EventId=@e;
DECLARE @sL uniqueidentifier=test.Id('sizeL');
SET @e=NEWID();EXEC catalog.usp_RegisterItem @ProductId=@product2,@Sku=N'T-VES-0002',@VariantName=N'Vestido Azul L',@CurrencyCode='NIO',
 @UnitPriceMinor=200000,@UnitCostMinor=90000,@Barcode=N'0000222000444',@SizeId=@sL,@ActorId=@owner,@ItemId=@stale,@OriginNodeId=@node,@EventId=@e;
EXEC test.SeedStock @item,@loc,10;EXEC test.SeedStock @item2,@loc,5;EXEC test.SeedStock @dress,@loc,4;EXEC test.SeedStock @stale,@loc,3;
UPDATE inventory.StockMovements SET CreatedAt=DATEADD(day,-90,CreatedAt) WHERE ItemId=@stale;
EXEC sales.usp_OpenTill @till,@register,@cashier,'NIO',0,@node;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT @lines VALUES(1,@item,2,120000,0),(2,@dress,1,200000,0);
INSERT @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',440000,440000,0);
EXEC sales.usp_PostSale @sale,@branch,@loc,@cashier,'NIO',@node,@lines,@tenders,@TillId=@till;
DELETE @lines;DELETE @tenders;
INSERT @lines VALUES(1,@item2,1,85000,0);
INSERT @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',97750,97750,0);
EXEC sales.usp_PostSale @sale2,@branch,@loc,@cashier,'NIO',@node,@lines,@tenders,@TillId=@till;
UPDATE sales.Sales SET CreatedAt=DATEADD(day,-1,CreatedAt) WHERE Id=@sale2;
DECLARE @r sales.ReturnLineRequest,@none sales.SaleLineRequest,@noTender sales.SaleTenderRequest;
INSERT @r SELECT Id,1,'store' FROM sales.SaleLines WHERE SaleId=@sale AND LineNumber=1;
EXEC sales.usp_PostReturnOutcome @rev,@sale,@branch,@loc,@till,@manager,'cash',N'Talla',NULL,@node,@r,NULL,@none,@noTender;
DECLARE @today date=CONVERT(date,DATEADD(hour,-6,core.ufn_BusinessNow())),@old nvarchar(max),@new nvarchar(max),@what nvarchar(200),
 @period varchar(8),@date date,@same bigint,@rows bigint;
DECLARE @t TABLE(Json nvarchar(max));
DECLARE c CURSOR LOCAL FAST_FORWARD FOR
 SELECT p.v,d.v FROM (VALUES('day'),('week'),('month'),('year')) p(v) CROSS JOIN (VALUES(@today),(DATEADD(day,-1,@today))) d(v);
OPEN c;FETCH NEXT FROM c INTO @period,@date;
WHILE @@FETCH_STATUS=0
BEGIN
 DELETE @t;INSERT @t EXEC test.usp_KpiBusinessV030 @branch,@owner,@period,@date;SET @old=(SELECT Json FROM @t);
 DELETE @t;INSERT @t EXEC sales.usp_KpiBusiness @branch,@owner,@period,@date;SET @new=(SELECT Json FROM @t);
 SET @same=CASE WHEN @old=@new COLLATE Latin1_General_100_BIN2 THEN 1 ELSE 0 END;
 IF @same=0 PRINT CONCAT(N'V030: ',@old,NCHAR(10),N'V040: ',@new);
 SET @what=CONCAT(N'same JSON for ',@period,N' ',CONVERT(char(10),@date,23));
 EXEC test.AssertEq @what,1,@same;
 FETCH NEXT FROM c INTO @period,@date;
END;
CLOSE c;DEALLOCATE c;
-- The comparison covers real rows, not two empty lists.
SET @rows=(SELECT COUNT(*) FROM OPENJSON(@new,'$.sellThrough'));EXEC test.AssertEq N'sell-through rows (year)',2,@rows;
SET @rows=(SELECT COUNT(*) FROM OPENJSON(@new,'$.staleItems'));EXEC test.AssertEq N'stale items (year)',1,@rows;
PRINT 'PASS';

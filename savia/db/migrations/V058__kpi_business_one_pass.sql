-- savia:transactional
-- V058 (P2, money-and-speed 2026-11-22): business KPIs under 1 s on A-10 without a summary table.
-- V040 spent its time on period-independent breadth: four passes over 253k items, two of them into 253k-row temp tables,
-- and a sort of every stale item by SKU. Stock totals and the stale top 100 now take one pass each, and sell-through
-- reads receipts only for sold products unless fewer than 50 of them are positive.
-- Same result as V030 and V040 (db/tests/sales/250_kpi_business_equals_v030.sql compares them on the fixture).
CREATE OR ALTER PROCEDURE sales.usp_KpiBusiness @BranchId uniqueidentifier,@ActorId uniqueidentifier,@Period varchar(8),@Date date
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
 SELECT Id INTO #loc FROM core.Locations WHERE BranchId=@BranchId;
 DECLARE @stockUnits bigint,@stockValue bigint;
 SELECT @stockUnits=COALESCE(SUM(CONVERT(bigint,b.OnHand)),0),@stockValue=COALESCE(SUM(CONVERT(bigint,b.OnHand)*COALESCE(i.UnitCostMinor,0)),0)
  FROM inventory.StockBalances b JOIN catalog.Items i ON i.Id=b.ItemId WHERE b.Pool='store' AND b.LocationId IN(SELECT Id FROM #loc);
 -- Sell-through and stale items aggregate the branch movements and sales once, grouped by product or item.
 SELECT rl.SaleLineId,SUM(CONVERT(bigint,rl.Quantity)) AS Quantity INTO #returned
  FROM sales.SaleReversals r JOIN sales.SaleReversalLines rl ON rl.ReversalId=r.Id JOIN sales.SaleLines l ON l.Id=rl.SaleLineId
  WHERE r.SaleId=l.SaleId AND r.Status='approved' AND r.CreatedAt<@end GROUP BY rl.SaleLineId;
 SELECT i.ProductId,SUM(CONVERT(bigint,l.Quantity)-COALESCE(rt.Quantity,0)) AS Sold INTO #sold
  FROM sales.Sales s JOIN sales.SaleLines l ON l.SaleId=s.Id JOIN catalog.Items i ON i.Id=l.ItemId LEFT JOIN #returned rt ON rt.SaleLineId=l.Id
  WHERE s.BranchId=@BranchId AND s.Status<>'cancelled' AND s.CreatedAt<@end GROUP BY i.ProductId;
 -- Only a product that sold can have positive sell-through, so its receipts are read first; the full pass runs
 -- only when fewer than 50 products are positive and the zero-or-negative tail decides the list.
 SELECT so.ProductId,SUM(CONVERT(bigint,m.OnHandDelta)) AS Received INTO #received
  FROM #sold so JOIN catalog.Items i ON i.ProductId=so.ProductId JOIN inventory.StockMovements m ON m.ItemId=i.Id
  WHERE so.Sold>0 AND m.LocationId IN(SELECT Id FROM #loc) AND m.CreatedAt<@end
   AND (m.Kind='receive' OR (m.Kind='adjust' AND m.SourceType='catalog_import')) GROUP BY so.ProductId;
 IF (SELECT COUNT(*) FROM #received x JOIN #sold so ON so.ProductId=x.ProductId WHERE x.Received>0 AND so.Sold*10000/x.Received>0)<50
 BEGIN
  TRUNCATE TABLE #received;
  INSERT #received(ProductId,Received) SELECT i.ProductId,SUM(CONVERT(bigint,m.OnHandDelta))
   FROM inventory.StockMovements m JOIN #loc loc ON loc.Id=m.LocationId JOIN catalog.Items i ON i.Id=m.ItemId
   WHERE m.CreatedAt<@end AND (m.Kind='receive' OR (m.Kind='adjust' AND m.SourceType='catalog_import')) GROUP BY i.ProductId;
 END;
 -- Stale items: one pass per item over balances, movements and items, all ordered by item id, kept to the top 100.
 ;WITH st AS (SELECT b.ItemId,SUM(CONVERT(bigint,b.OnHand)) AS OnHand FROM inventory.StockBalances b
   WHERE b.Pool='store' AND b.LocationId IN(SELECT Id FROM #loc) GROUP BY b.ItemId HAVING SUM(CONVERT(bigint,b.OnHand))>0),
  lm AS (SELECT m.ItemId,MAX(m.CreatedAt) AS LastAt FROM inventory.StockMovements m WHERE m.LocationId IN(SELECT Id FROM #loc) GROUP BY m.ItemId)
 SELECT TOP(100) st.ItemId,i.Sku,i.VariantName,st.OnHand,lm.LastAt INTO #stale
  FROM st JOIN catalog.Items i ON i.Id=st.ItemId LEFT JOIN lm ON lm.ItemId=st.ItemId
  WHERE lm.LastAt IS NULL OR lm.LastAt<DATEADD(day,-60,@now) ORDER BY lm.LastAt,i.Sku;
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
  JSON_QUERY(COALESCE((SELECT TOP(50) p.Id AS productId,p.Name AS name,x.Received AS unitsReceived,COALESCE(so.Sold,0) AS unitsSold,
    COALESCE(so.Sold,0)*10000/x.Received AS sellThroughBps
   FROM #received x JOIN catalog.Products p ON p.Id=x.ProductId LEFT JOIN #sold so ON so.ProductId=x.ProductId
   WHERE x.Received>0 ORDER BY sellThroughBps DESC,p.Name,p.Id FOR JSON PATH),N'[]')) AS sellThrough,
  JSON_QUERY(COALESCE((SELECT TOP(100) st.ItemId AS itemId,st.Sku AS sku,st.VariantName AS name,st.OnHand AS onHand,st.LastAt AS lastMovementAt
   FROM #stale st ORDER BY st.LastAt,st.Sku FOR JSON PATH),N'[]')) AS staleItems,
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

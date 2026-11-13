-- V026: the business KPIs also return what was sold before returns (grossSalesMinor).
-- With it the owner's cards reconcile: sold - returns = net sales; sold / sales = average ticket;
-- and the sellers' sold amounts in sales.usp_KpiTeam add up to it. No other change to the procedure.
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
 DECLARE @revenue bigint=@subtotal-@discount-@returns;
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
    (SELECT COALESCE(SUM(CONVERT(bigint,l.Quantity-l.ReturnedQuantity)),0) FROM sales.SaleLines l JOIN sales.Sales s ON s.Id=l.SaleId JOIN catalog.Items i ON i.Id=l.ItemId
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
    WHERE reg.BranchId=@BranchId AND cl.ClosedAt>=@start AND cl.ClosedAt<@end) AS tillClosures,
  (SELECT COUNT(*) FROM sales.CashClosures cl JOIN sales.CashTills t ON t.Id=cl.TillId JOIN sales.CashRegisters reg ON reg.Id=t.RegisterId
    WHERE reg.BranchId=@BranchId AND cl.ClosedAt>=@start AND cl.ClosedAt<@end AND cl.DifferenceMinor<>0) AS tillClosuresWithDifference,
  (SELECT COALESCE(SUM(cl.DifferenceMinor),0) FROM sales.CashClosures cl JOIN sales.CashTills t ON t.Id=cl.TillId JOIN sales.CashRegisters reg ON reg.Id=t.RegisterId
    WHERE reg.BranchId=@BranchId AND cl.ClosedAt>=@start AND cl.ClosedAt<@end) AS tillDifferenceMinor,
  JSON_QUERY(COALESCE((SELECT DATEPART(hour,DATEADD(hour,-6,CreatedAt)) AS hour,COUNT(*) AS salesCount,SUM(TotalMinor) AS totalMinor
   FROM #s GROUP BY DATEPART(hour,DATEADD(hour,-6,CreatedAt)) ORDER BY hour FOR JSON PATH),N'[]')) AS salesByHour
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS Json;
END;
GO

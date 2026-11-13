-- Local branch read models. Periods are Nicaragua calendar days, Monday weeks, months and years.
CREATE OR ALTER PROCEDURE sales.usp_ListStockExceptions @BranchId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON;
 SELECT (SELECT e.Id AS id,l.SaleId AS saleId,e.SaleLineId AS saleLineId,e.ItemId AS itemId,
 l.SkuSnapshot AS sku,l.NameSnapshot AS name,e.QuantityShort AS quantityShort,e.CashierId AS cashierId,
 st.DisplayName AS cashierName,e.CreatedAt AS createdAt,e.Note AS note,e.ReviewedBy AS reviewedBy,
 e.ReviewedAt AS reviewedAt,e.ReviewNote AS reviewNote
 FROM sales.StockExceptions e JOIN sales.SaleLines l ON l.Id=e.SaleLineId
 JOIN sales.Sales s ON s.Id=l.SaleId JOIN security.Staff st ON st.Id=e.CashierId
 WHERE s.BranchId=@BranchId ORDER BY CASE WHEN e.ReviewedAt IS NULL THEN 0 ELSE 1 END,e.CreatedAt DESC,e.Id
 FOR JSON PATH,INCLUDE_NULL_VALUES) AS Json;
END;
GO
CREATE OR ALTER PROCEDURE sales.usp_ReviewStockException
 @BranchId uniqueidentifier,@ExceptionId uniqueidentifier,@ActorId uniqueidentifier,@Reason nvarchar(500)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffBranchAccess a ON a.StaffId=s.Id
 JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId
 WHERE s.Id=@ActorId AND s.IsEnabled=1 AND a.BranchId=@BranchId AND a.IsActive=1 AND r.Code IN ('MANAGER','OWNER'))
 THROW 51544,'Se requiere supervision.',1;
 IF NULLIF(LTRIM(RTRIM(@Reason)),N'') IS NULL THROW 51547,'Indique el resultado de la revision.',1;
 BEGIN TRAN;
 BEGIN TRY
  DECLARE @line uniqueidentifier,@cashier uniqueidentifier,@note nvarchar(500),@reviewed datetime2;
  SELECT @line=e.SaleLineId,@cashier=e.CashierId,@note=e.Note,@reviewed=e.ReviewedAt
  FROM sales.StockExceptions e WITH(UPDLOCK,HOLDLOCK) JOIN sales.SaleLines l ON l.Id=e.SaleLineId
  JOIN sales.Sales s ON s.Id=l.SaleId WHERE e.Id=@ExceptionId AND s.BranchId=@BranchId;
  IF @line IS NULL THROW 51548,'La excepcion no existe en esta sucursal.',1;
  IF @reviewed IS NOT NULL BEGIN COMMIT; RETURN; END;
  UPDATE sales.StockExceptions SET ReviewedBy=@ActorId,ReviewedAt=SYSUTCDATETIME(),ReviewNote=@Reason WHERE Id=@ExceptionId;
  INSERT INTO sales.StockExceptionReviews(SaleLineId,ReviewerId,Evidence,Outcome,ResponsibleActorId,NextReviewAt,Status,CreatedBy)
  VALUES(@line,@ActorId,@note,@Reason,@cashier,DATEADD(day,1,SYSUTCDATETIME()),'resolved',@ActorId);
  COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE sales.usp_GetPeriodSummary @BranchId uniqueidentifier,@Period varchar(8),@Date date
AS
BEGIN
 SET NOCOUNT ON;
 IF @Period NOT IN ('day','week','month','year') OR @Date IS NULL OR @Date<'1900-01-01' OR @Date>='9999-01-01'
 THROW 51900,'Periodo o fecha invalida.',1;
 DECLARE @from date=CASE @Period WHEN 'week' THEN DATEADD(day,-(DATEDIFF(day,'19000101',@Date)%7),@Date)
 WHEN 'month' THEN DATEFROMPARTS(YEAR(@Date),MONTH(@Date),1) WHEN 'year' THEN DATEFROMPARTS(YEAR(@Date),1,1) ELSE @Date END;
 DECLARE @until date=CASE @Period WHEN 'week' THEN DATEADD(day,7,@from) WHEN 'month' THEN DATEADD(month,1,@from)
 WHEN 'year' THEN DATEADD(year,1,@from) ELSE DATEADD(day,1,@from) END;
 DECLARE @start datetime2=DATEADD(hour,6,CONVERT(datetime2,@from)),@end datetime2=DATEADD(hour,6,CONVERT(datetime2,@until));
 SELECT s.* INTO #sales FROM sales.Sales s WHERE s.BranchId=@BranchId AND s.CurrencyCode='NIO'
 AND s.Status<>'cancelled' AND s.CreatedAt>=@start AND s.CreatedAt<@end;
 SELECT r.* INTO #returns FROM sales.SaleReversals r JOIN sales.Sales s ON s.Id=r.SaleId
 WHERE r.BranchId=@BranchId AND r.CurrencyCode='NIO' AND r.Status='approved' AND r.CreatedAt>=@start AND r.CreatedAt<@end;
 SELECT (SELECT @Period AS period,@Date AS date,@from AS startDate,DATEADD(day,-1,@until) AS endDate,@BranchId AS branchId,'NIO' AS currencyCode,
 (SELECT COUNT(*) FROM #sales) AS salesCount,
 (SELECT COALESCE(SUM(CONVERT(bigint,l.Quantity)),0) FROM #sales s JOIN sales.SaleLines l ON l.SaleId=s.Id) AS unitsSold,
 (SELECT COALESCE(SUM(SubtotalMinor),0) FROM #sales) AS grossMinor,
 (SELECT COALESCE(SUM(DiscountMinor),0) FROM #sales) AS discountsMinor,
 (SELECT COALESCE(SUM(TotalMinor),0) FROM #sales) AS salesMinor,
 (SELECT COALESCE(SUM(TotalMinor),0) FROM #sales)-(SELECT COALESCE(SUM(CreditMinor),0) FROM #returns) AS netMinor,
 (SELECT COUNT(*) FROM #returns) AS returnsCount,(SELECT COALESCE(SUM(CreditMinor),0) FROM #returns) AS returnsMinor,
 (SELECT COALESCE(AVG(TotalMinor),0) FROM #sales) AS averageTicketMinor,
 (SELECT COUNT(DISTINCT CustomerId) FROM #sales) AS customersServed,
 (SELECT COUNT(DISTINCT s.CustomerId) FROM #sales s WHERE s.CustomerId IS NOT NULL AND NOT EXISTS
 (SELECT 1 FROM sales.Sales old WHERE old.BranchId=@BranchId AND old.CustomerId=s.CustomerId AND old.Status<>'cancelled' AND old.CreatedAt<@start)) AS newCustomers,
 (SELECT COUNT(*) FROM sales.StockExceptions e JOIN sales.SaleLines l ON l.Id=e.SaleLineId JOIN #sales s ON s.Id=l.SaleId) AS stockExceptionsCount,
 JSON_QUERY((SELECT t.TenderKind AS tenderKind,t.CurrencyCode AS currencyCode,COUNT(DISTINCT s.Id) AS saleCount,SUM(t.AmountMinor) AS totalMinor
 FROM #sales s JOIN sales.SaleTenders t ON t.SaleId=s.Id WHERE t.Status='captured' GROUP BY t.TenderKind,t.CurrencyCode ORDER BY t.TenderKind FOR JSON PATH)) AS tenders,
 JSON_QUERY((SELECT r.Id AS reversalId,r.SaleId AS saleId,r.CreditMinor AS creditMinor,r.SettlementKind AS settlementKind FROM #returns r ORDER BY r.CreatedAt,r.Id FOR JSON PATH)) AS returns,
 JSON_QUERY((SELECT TOP(20) l.ItemId AS itemId,l.SkuSnapshot AS sku,l.NameSnapshot AS name,SUM(CONVERT(bigint,l.Quantity)) AS unitsSold,SUM(l.TotalMinor) AS totalMinor
 FROM #sales s JOIN sales.SaleLines l ON l.SaleId=s.Id GROUP BY l.ItemId,l.SkuSnapshot,l.NameSnapshot ORDER BY unitsSold DESC,l.SkuSnapshot FOR JSON PATH)) AS topItems,
 JSON_QUERY((SELECT CONVERT(date,DATEADD(hour,-6,s.CreatedAt)) AS date,COUNT(*) AS salesCount,SUM(s.TotalMinor) AS totalMinor
 FROM #sales s GROUP BY CONVERT(date,DATEADD(hour,-6,s.CreatedAt)) ORDER BY date FOR JSON PATH)) AS salesByDay,
 JSON_QUERY((SELECT s.CashierId AS cashierId,st.DisplayName AS name,COUNT(*) AS salesCount,SUM(s.TotalMinor) AS totalMinor
 FROM #sales s JOIN security.Staff st ON st.Id=s.CashierId GROUP BY s.CashierId,st.DisplayName ORDER BY st.DisplayName,s.CashierId FOR JSON PATH)) AS cashiers
 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS Json;
END;
GO
GRANT EXECUTE ON sales.usp_OpenTillCounted TO savia_pos_app;
GRANT EXECUTE ON sales.usp_ReviewStockException TO savia_pos_app;
GO

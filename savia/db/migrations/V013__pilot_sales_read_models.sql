-- Read models only. All mutations remain in existing domain procedures (ADR-001 D2).
-- Pilot business dates use Nicaragua time (UTC-06:00, no DST).
CREATE OR ALTER PROCEDURE sales.usp_SearchSales
 @BranchId uniqueidentifier,@From date=NULL,@To date=NULL,@Query nvarchar(100)=N'',@Page int=1,@PageSize int=25
AS
BEGIN
 SET NOCOUNT ON;
 IF @Page<1 OR @Page>1000000 OR @PageSize NOT BETWEEN 1 AND 100
   OR @From>@To OR @From>='9999-01-01' OR @To>='9999-01-01'
   THROW 51900,'Rango de fechas o pagina invalida.',1;
 DECLARE @start datetime2=DATEADD(hour,6,CONVERT(datetime2,@From)),
         @end datetime2=DATEADD(hour,6,DATEADD(day,1,CONVERT(datetime2,@To)));
 DECLARE @matches TABLE(Id uniqueidentifier PRIMARY KEY,CreatedAt datetime2);
 INSERT INTO @matches
 SELECT s.Id,s.CreatedAt FROM sales.Sales s LEFT JOIN crm.Customers c ON c.Id=s.CustomerId
 WHERE s.BranchId=@BranchId AND (@start IS NULL OR s.CreatedAt>=@start) AND (@end IS NULL OR s.CreatedAt<@end)
 AND (@Query=N'' OR CHARINDEX(@Query,CONVERT(nvarchar(36),s.Id))>0
   OR CHARINDEX(@Query,c.DisplayName COLLATE Latin1_General_100_CI_AI)>0
   OR CHARINDEX(@Query,c.CustomerCode)>0
   OR EXISTS(SELECT 1 FROM sales.SaleLines l WHERE l.SaleId=s.Id
     AND (CHARINDEX(@Query,l.SkuSnapshot COLLATE Latin1_General_100_CI_AI)>0
       OR CHARINDEX(@Query,l.NameSnapshot COLLATE Latin1_General_100_CI_AI)>0)));
 SELECT (SELECT @Page AS page,@PageSize AS pageSize,(SELECT COUNT(*) FROM @matches) AS total,
   JSON_QUERY(COALESCE((SELECT s.Id AS saleId,s.CreatedAt AS createdAt,s.Status AS status,s.CurrencyCode AS currencyCode,
     s.TotalMinor AS totalMinor,s.CustomerId AS customerId,c.DisplayName AS customerName,
     s.CashierId AS cashierId,st.DisplayName AS cashierName,s.TillId AS tillId
     FROM @matches m JOIN sales.Sales s ON s.Id=m.Id
     JOIN security.Staff st ON st.Id=s.CashierId LEFT JOIN crm.Customers c ON c.Id=s.CustomerId
     ORDER BY m.CreatedAt DESC,m.Id DESC OFFSET (@Page-1)*@PageSize ROWS FETCH NEXT @PageSize ROWS ONLY
     FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS items
   FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS Json;
END;
GO
CREATE OR ALTER PROCEDURE sales.usp_GetSaleDetail @BranchId uniqueidentifier,@SaleId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON;
 SELECT (SELECT s.Id AS saleId,s.SubtotalMinor AS subtotalMinor,s.DiscountMinor AS discountMinor,
   s.TaxMinor AS taxMinor,s.TotalMinor AS totalMinor,s.Status AS status,s.CurrencyCode AS currencyCode,
   s.CreatedAt AS createdAt,s.CustomerId AS customerId,c.DisplayName AS customerName,
   s.CashierId AS cashierId,st.DisplayName AS cashierName,s.TillId AS tillId,reg.Name AS registerName,
   JSON_QUERY(COALESCE((SELECT l.Id AS saleLineId,l.LineNumber AS lineNumber,l.ItemId AS itemId,l.SkuSnapshot AS sku,
     l.NameSnapshot AS name,sz.Code AS sizeCode,l.Quantity AS quantity,l.ReturnedQuantity AS returnedQuantity,
     l.UnitPriceMinor AS unitPriceMinor,l.DiscountMinor AS discountMinor,l.TaxMinor AS taxMinor,l.TotalMinor AS totalMinor
     FROM sales.SaleLines l JOIN catalog.Items i ON i.Id=l.ItemId LEFT JOIN catalog.Sizes sz ON sz.Id=i.SizeId
     WHERE l.SaleId=s.Id ORDER BY l.LineNumber FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS lines,
   JSON_QUERY(COALESCE((SELECT t.Id AS tenderId,t.TenderKind AS tenderKind,t.AmountMinor AS amountMinor,t.ReceivedMinor AS receivedMinor,
     t.ChangeMinor AS changeMinor,t.Reference AS reference,t.CreditId AS creditId,t.Status AS status
     FROM sales.SaleTenders t WHERE t.SaleId=s.Id ORDER BY t.CreatedAt,t.Id FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS tenders,
   JSON_QUERY(COALESCE((SELECT r.Id AS reversalId,r.Kind AS kind,r.SettlementKind AS settlementKind,r.Reason AS reason,
     r.CreditMinor AS creditMinor,r.CurrencyCode AS currencyCode,r.Status AS status,r.CreatedAt AS createdAt,
     r.ApprovedBy AS approvedBy,r.ActorId AS actorId,r.TillId AS tillId,cr.Id AS creditId,
     JSON_QUERY(COALESCE((SELECT rl.SaleLineId AS saleLineId,rl.Quantity AS quantity,rl.CreditMinor AS creditMinor,
       rl.RestockPool AS restockPool FROM sales.SaleReversalLines rl WHERE rl.ReversalId=r.Id
       ORDER BY rl.SaleLineId FOR JSON PATH),N'[]')) AS lines
     FROM sales.SaleReversals r LEFT JOIN credits.Credits cr ON cr.SourceReversalId=r.Id
     WHERE r.SaleId=s.Id ORDER BY r.CreatedAt,r.Id FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS reversals
   FROM sales.Sales s JOIN security.Staff st ON st.Id=s.CashierId
   LEFT JOIN crm.Customers c ON c.Id=s.CustomerId LEFT JOIN sales.CashTills ti ON ti.Id=s.TillId
   LEFT JOIN sales.CashRegisters reg ON reg.Id=ti.RegisterId
   WHERE s.Id=@SaleId AND s.BranchId=@BranchId FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER) AS Json;
END;
GO
CREATE OR ALTER PROCEDURE crm.usp_SearchCustomers @Query nvarchar(100)
AS
BEGIN
 SET NOCOUNT ON;
 IF LEN(LTRIM(RTRIM(@Query)))<2 THROW 51901,'Escriba al menos 2 caracteres para buscar clientes.',1;
 SELECT TOP (50) Id,CustomerCode,DisplayName,Phone,Email FROM crm.Customers
 WHERE IsActive=1 AND (CHARINDEX(@Query,DisplayName COLLATE Latin1_General_100_CI_AI)>0
   OR CHARINDEX(@Query,CustomerCode)>0 OR CHARINDEX(@Query,Phone)>0 OR CHARINDEX(@Query,Email)>0)
 ORDER BY DisplayName,Id;
END;
GO
CREATE OR ALTER PROCEDURE sales.usp_GetDayReport @BranchId uniqueidentifier,@Date date
AS
BEGIN
 SET NOCOUNT ON;
 IF @Date IS NULL OR @Date>='9999-01-01' THROW 51900,'Fecha invalida.',1;
 DECLARE @start datetime2=DATEADD(hour,6,CONVERT(datetime2,@Date)),
   @end datetime2=DATEADD(day,1,DATEADD(hour,6,CONVERT(datetime2,@Date)));
 SELECT (SELECT @Date AS date,@BranchId AS branchId,
   (SELECT COUNT(*) FROM sales.Sales WHERE BranchId=@BranchId AND CreatedAt>=@start AND CreatedAt<@end AND Status<>'cancelled') AS salesCount,
   (SELECT COALESCE(SUM(CONVERT(bigint,l.Quantity)),0) FROM sales.Sales s JOIN sales.SaleLines l ON l.SaleId=s.Id
     WHERE s.BranchId=@BranchId AND s.CreatedAt>=@start AND s.CreatedAt<@end AND s.Status<>'cancelled') AS unitsSold,
   JSON_QUERY(COALESCE((SELECT CurrencyCode AS currencyCode,COUNT(*) AS saleCount,SUM(TotalMinor) AS totalMinor
     FROM sales.Sales WHERE BranchId=@BranchId AND CreatedAt>=@start AND CreatedAt<@end AND Status<>'cancelled'
     GROUP BY CurrencyCode ORDER BY CurrencyCode FOR JSON PATH),N'[]')) AS totals,
   JSON_QUERY(COALESCE((SELECT t.CurrencyCode AS currencyCode,t.TenderKind AS tenderKind,COUNT(DISTINCT s.Id) AS saleCount,SUM(t.AmountMinor) AS totalMinor
     FROM sales.Sales s JOIN sales.SaleTenders t ON t.SaleId=s.Id
     WHERE s.BranchId=@BranchId AND s.CreatedAt>=@start AND s.CreatedAt<@end AND s.Status<>'cancelled' AND t.Status='captured'
     GROUP BY t.CurrencyCode,t.TenderKind ORDER BY t.CurrencyCode,t.TenderKind FOR JSON PATH),N'[]')) AS tenders,
   JSON_QUERY(COALESCE((SELECT r.Id AS reversalId,r.SaleId AS saleId,r.CurrencyCode AS currencyCode,r.SettlementKind AS settlementKind,
     r.CreditMinor AS creditMinor,(SELECT COALESCE(SUM(CONVERT(bigint,Quantity)),0) FROM sales.SaleReversalLines WHERE ReversalId=r.Id) AS unitsReturned
     FROM sales.SaleReversals r WHERE r.BranchId=@BranchId AND r.Status='approved' AND r.CreatedAt>=@start AND r.CreatedAt<@end
     ORDER BY r.CreatedAt,r.Id FOR JSON PATH),N'[]')) AS returns,
   JSON_QUERY(COALESCE((SELECT t.Id AS tillId,t.CashierId AS cashierId,st.DisplayName AS cashierName,reg.Name AS registerName,
     t.CurrencyCode AS currencyCode,t.Status AS status,t.OpenedAt AS openedAt,t.ClosedAt AS closedAt,
     COALESCE(cl.ExpectedMinor,e.ExpectedMinor,0) AS expectedMinor,cl.CountedMinor AS countedMinor,cl.DifferenceMinor AS differenceMinor,
     cl.Id AS closureId,d.Id AS accountingDocumentId,d.DocumentNumber AS documentNumber,d.Status AS accountingStatus,
     d.SaleGrossMinor AS saleGrossMinor,d.ReturnGrossMinor AS returnGrossMinor,d.NetSalesMinor AS netSalesMinor
     FROM sales.CashTills t JOIN sales.CashRegisters reg ON reg.Id=t.RegisterId JOIN security.Staff st ON st.Id=t.CashierId
     LEFT JOIN sales.CashClosures cl ON cl.TillId=t.Id LEFT JOIN accounting.CloseDocuments d ON d.ClosureId=cl.Id
     OUTER APPLY(SELECT SUM(DeltaMinor) AS ExpectedMinor FROM sales.CashEntries WHERE TillId=t.Id) e
     WHERE reg.BranchId=@BranchId AND ((t.OpenedAt>=@start AND t.OpenedAt<@end) OR (t.ClosedAt>=@start AND t.ClosedAt<@end))
     ORDER BY t.OpenedAt,t.Id FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS tills,
   JSON_QUERY(COALESCE((SELECT TOP (5) l.ItemId AS itemId,MAX(l.SkuSnapshot) AS sku,MAX(l.NameSnapshot) AS name,SUM(CONVERT(bigint,l.Quantity)) AS unitsSold
     FROM sales.Sales s JOIN sales.SaleLines l ON l.SaleId=s.Id
     WHERE s.BranchId=@BranchId AND s.CreatedAt>=@start AND s.CreatedAt<@end AND s.Status<>'cancelled'
     GROUP BY l.ItemId ORDER BY SUM(CONVERT(bigint,l.Quantity)) DESC,l.ItemId FOR JSON PATH),N'[]')) AS topItems
   FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS Json;
END;
GO
GRANT EXECUTE ON OBJECT::sales.usp_SearchSales TO savia_pos_app;
GRANT EXECUTE ON OBJECT::sales.usp_GetSaleDetail TO savia_pos_app;
GRANT EXECUTE ON OBJECT::sales.usp_GetDayReport TO savia_pos_app;
GRANT EXECUTE ON OBJECT::crm.usp_SearchCustomers TO savia_pos_app;
GO

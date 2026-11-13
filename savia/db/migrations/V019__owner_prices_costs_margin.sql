-- Price/cost history is append-only; Items is the current-value projection used by sale validation.
CREATE TABLE catalog.ItemValueHistory(
 Id uniqueidentifier NOT NULL PRIMARY KEY,ItemId uniqueidentifier NOT NULL REFERENCES catalog.Items(Id),
 OldPriceMinor bigint NOT NULL,NewPriceMinor bigint NOT NULL CHECK(NewPriceMinor>=0),
 OldCostMinor bigint NULL,NewCostMinor bigint NOT NULL CHECK(NewCostMinor>=0),
 ActorId uniqueidentifier NOT NULL REFERENCES security.Staff(Id),Reason nvarchar(250) NOT NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT(SYSUTCDATETIME()));
GO
CREATE OR ALTER PROCEDURE catalog.usp_SetItemValues @ChangeId uniqueidentifier,@ItemId uniqueidentifier,@NewPriceMinor bigint,@NewCostMinor bigint,@ActorId uniqueidentifier,@OriginNodeId uniqueidentifier,@Reason nvarchar(250)
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId WHERE s.Id=@ActorId AND s.IsEnabled=1 AND r.Code='OWNER' AND r.IsActive=1)
 THROW 52001,'Solo la dueña cambia precio y costo.',1;
 IF @NewPriceMinor IS NULL OR @NewCostMinor IS NULL OR @NewPriceMinor<0 OR @NewCostMinor<0 OR NULLIF(LTRIM(RTRIM(@Reason)),N'') IS NULL THROW 51206,'Precio, costo o motivo invalido.',1;
 BEGIN TRAN;BEGIN TRY
  DECLARE @oldPrice bigint,@oldCost bigint;
  SELECT @oldPrice=UnitPriceMinor,@oldCost=UnitCostMinor FROM catalog.Items WITH(UPDLOCK,HOLDLOCK) WHERE Id=@ItemId AND Status='active';
  IF @oldPrice IS NULL THROW 51207,'Variante activa inexistente.',1;
  IF EXISTS(SELECT 1 FROM catalog.ItemValueHistory WHERE Id=@ChangeId)
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM catalog.ItemValueHistory WHERE Id=@ChangeId AND ItemId=@ItemId AND NewPriceMinor=@NewPriceMinor AND NewCostMinor=@NewCostMinor AND ActorId=@ActorId AND Reason=@Reason) THROW 52004,'Identificador reutilizado.',1;
   COMMIT;RETURN;
  END;
  INSERT catalog.ItemValueHistory VALUES(@ChangeId,@ItemId,@oldPrice,@NewPriceMinor,@oldCost,@NewCostMinor,@ActorId,@Reason,SYSUTCDATETIME());
  EXEC catalog.usp_ChangePrice @ItemId,@NewPriceMinor,@ActorId,@OriginNodeId,@ChangeId,@Reason;
  UPDATE catalog.Items SET UnitCostMinor=@NewCostMinor,ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId WHERE Id=@ItemId;
  COMMIT;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE catalog.usp_GetItemValues @BranchId uniqueidentifier,@ActorId uniqueidentifier,@Query nvarchar(100)=N''
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId JOIN security.StaffBranchAccess a ON a.StaffId=s.Id
 WHERE s.Id=@ActorId AND s.IsEnabled=1 AND r.Code IN ('OWNER','MANAGER') AND r.IsActive=1 AND a.BranchId=@BranchId AND a.IsActive=1) THROW 52001,'Sin acceso a costos.',1;
 SELECT (SELECT TOP(100) i.Id AS itemId,i.Sku AS sku,i.VariantName AS name,i.UnitPriceMinor AS priceMinor,i.UnitCostMinor AS costMinor,
 JSON_QUERY((SELECT h.Id AS id,h.OldPriceMinor AS oldPriceMinor,h.NewPriceMinor AS newPriceMinor,h.OldCostMinor AS oldCostMinor,h.NewCostMinor AS newCostMinor,
 st.DisplayName AS actorName,h.ActorId AS actorId,h.Reason AS reason,h.CreatedAt AS time FROM catalog.ItemValueHistory h JOIN security.Staff st ON st.Id=h.ActorId WHERE h.ItemId=i.Id ORDER BY h.CreatedAt DESC,h.Id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS history
 FROM catalog.Items i WHERE i.Status='active' AND (@Query=N'' OR CHARINDEX(@Query,i.Sku)>0 OR CHARINDEX(@Query,i.VariantName)>0)
 ORDER BY i.Sku FOR JSON PATH,INCLUDE_NULL_VALUES) AS Json;
END;
GO
CREATE OR ALTER PROCEDURE [catalog].[usp_ChangePrice]
 @ItemId uniqueidentifier,@NewPriceMinor bigint,@ActorId uniqueidentifier,
 @OriginNodeId uniqueidentifier,@EventId uniqueidentifier,@Reason nvarchar(250)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId WHERE s.Id=@ActorId AND s.IsEnabled=1 AND r.Code='OWNER' AND r.IsActive=1)
 THROW 52001,'Solo la dueña cambia precios.',1;
 IF @NewPriceMinor<0 OR LEN(LTRIM(RTRIM(@Reason)))=0 THROW 51206,'Precio/razon invalida.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   DECLARE @old bigint,@currency varchar(3);
   SELECT @old=UnitPriceMinor,@currency=CurrencyCode FROM catalog.Items WITH(UPDLOCK,HOLDLOCK) WHERE Id=@ItemId AND Status='active';
   IF @old IS NULL THROW 51207,'Variante activa inexistente.',1;
   IF @old<>@NewPriceMinor
   BEGIN
      UPDATE catalog.Items SET UnitPriceMinor=@NewPriceMinor,ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@ItemId;
      INSERT INTO catalog.PriceHistory(ItemId,OldPriceMinor,NewPriceMinor,CurrencyCode,EffectiveAt,Reason,CreatedBy)
         VALUES(@ItemId,@old,@NewPriceMinor,@currency,SYSUTCDATETIME(),@Reason,@ActorId);
   END;
   DECLARE @payload nvarchar(max)=(SELECT @ItemId AS itemId,@NewPriceMinor AS priceMinor,
         @currency AS currency,@EventId AS eventId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'item',@ItemId,'catalog.price_changed',@payload;
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
 (SELECT COALESCE(SUM(l.COGSMinor),0) FROM #sales s JOIN sales.SaleLines l ON l.SaleId=s.Id)-(SELECT COALESCE(SUM(l.COGSReversedMinor),0) FROM #returns r JOIN sales.SaleReversalLines l ON l.ReversalId=r.Id) AS costOfGoodsMinor,
 (SELECT COALESCE(SUM(SubtotalMinor-DiscountMinor),0) FROM #sales)-(SELECT COALESCE(SUM(CreditMinor),0) FROM #returns)
 -(SELECT COALESCE(SUM(l.COGSMinor),0) FROM #sales s JOIN sales.SaleLines l ON l.SaleId=s.Id)+(SELECT COALESCE(SUM(l.COGSReversedMinor),0) FROM #returns r JOIN sales.SaleReversalLines l ON l.ReversalId=r.Id) AS grossMarginMinor,
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

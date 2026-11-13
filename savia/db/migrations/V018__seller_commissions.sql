-- Seller attribution and immutable commission snapshots. Rates use basis points: 300 = 3%.
CREATE TABLE sales.SellerRates(SellerId uniqueidentifier NOT NULL PRIMARY KEY REFERENCES security.Staff(Id),RateBps int NOT NULL DEFAULT(300) CHECK(RateBps BETWEEN 0 AND 10000));
CREATE TABLE sales.SellerRateHistory(Id uniqueidentifier NOT NULL PRIMARY KEY,SellerId uniqueidentifier NOT NULL REFERENCES security.Staff(Id),
 OldRateBps int NOT NULL,NewRateBps int NOT NULL,ActorId uniqueidentifier NOT NULL REFERENCES security.Staff(Id),Reason nvarchar(250) NOT NULL,CreatedAt datetime2(3) NOT NULL DEFAULT(SYSUTCDATETIME()));
ALTER TABLE sales.SaleLines ADD SellerId uniqueidentifier NULL REFERENCES security.Staff(Id),CommissionRateBps int NULL,CommissionMinor bigint NULL;
GO
CREATE OR ALTER PROCEDURE sales.usp_SetSellerRate @ChangeId uniqueidentifier,@SellerId uniqueidentifier,@RateBps int,@ActorId uniqueidentifier,@Reason nvarchar(250)
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId WHERE s.Id=@ActorId AND s.IsEnabled=1 AND r.Code='OWNER' AND r.IsActive=1)
 THROW 52001,'Solo la dueña cambia comisiones.',1;
 IF @RateBps IS NULL OR @RateBps NOT BETWEEN 0 AND 10000 OR NULLIF(LTRIM(RTRIM(@Reason)),N'') IS NULL THROW 52003,'Porcentaje o motivo invalido.',1;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId WHERE s.Id=@SellerId AND s.IsEnabled=1 AND r.Code='SELLER' AND r.IsActive=1)
 THROW 52002,'Vendedora invalida.',1;
 BEGIN TRAN;BEGIN TRY
  DECLARE @old int=300;
  SELECT @old=RateBps FROM sales.SellerRates WITH(UPDLOCK,HOLDLOCK) WHERE SellerId=@SellerId;
  IF EXISTS(SELECT 1 FROM sales.SellerRateHistory WHERE Id=@ChangeId)
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM sales.SellerRateHistory WHERE Id=@ChangeId AND SellerId=@SellerId AND NewRateBps=@RateBps AND Reason=@Reason AND ActorId=@ActorId) THROW 52004,'Identificador reutilizado.',1;
   COMMIT;RETURN;
  END;
  INSERT sales.SellerRateHistory VALUES(@ChangeId,@SellerId,@old,@RateBps,@ActorId,@Reason,SYSUTCDATETIME());
  IF EXISTS(SELECT 1 FROM sales.SellerRates WHERE SellerId=@SellerId) UPDATE sales.SellerRates SET RateBps=@RateBps WHERE SellerId=@SellerId;
  ELSE INSERT sales.SellerRates VALUES(@SellerId,@RateBps);
  COMMIT;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE sales.usp_ListSellers @BranchId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON;
 SELECT (SELECT s.Id AS sellerId,s.DisplayName AS name,COALESCE(rate.RateBps,300) AS rateBps
 FROM security.Staff s JOIN security.StaffBranchAccess a ON a.StaffId=s.Id
 LEFT JOIN sales.SellerRates rate ON rate.SellerId=s.Id
 WHERE a.BranchId=@BranchId AND a.IsActive=1 AND s.IsEnabled=1 AND EXISTS(SELECT 1 FROM security.StaffRoles sr JOIN security.Roles r ON r.Id=sr.RoleId WHERE sr.StaffId=s.Id AND r.Code='SELLER' AND r.IsActive=1)
 ORDER BY s.DisplayName,s.Id FOR JSON PATH) AS Json;
END;
GO
CREATE OR ALTER PROCEDURE sales.usp_GetCommissions @BranchId uniqueidentifier,@ActorId uniqueidentifier,@Period varchar(8),@Date date
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @all bit=0;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffBranchAccess a ON a.StaffId=s.Id JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId
 WHERE s.Id=@ActorId AND s.IsEnabled=1 AND a.BranchId=@BranchId AND a.IsActive=1 AND r.IsActive=1 AND r.Code IN ('SELLER','MANAGER','OWNER')) THROW 52001,'Sin acceso a comisiones.',1;
 IF EXISTS(SELECT 1 FROM security.StaffRoles sr JOIN security.Roles r ON r.Id=sr.RoleId WHERE sr.StaffId=@ActorId AND r.Code IN ('MANAGER','OWNER') AND r.IsActive=1) SET @all=1;
 IF @Period NOT IN ('day','week','month','year') OR @Date IS NULL OR @Date<'19000101' OR @Date>='99990101' THROW 51900,'Periodo o fecha invalida.',1;
 DECLARE @from date=CASE @Period WHEN 'week' THEN DATEADD(day,-DATEDIFF(day,'19000101',@Date)%7,@Date) WHEN 'month' THEN DATEFROMPARTS(YEAR(@Date),MONTH(@Date),1) WHEN 'year' THEN DATEFROMPARTS(YEAR(@Date),1,1) ELSE @Date END;
 DECLARE @until date=CASE @Period WHEN 'week' THEN DATEADD(day,7,@from) WHEN 'month' THEN DATEADD(month,1,@from) WHEN 'year' THEN DATEADD(year,1,@from) ELSE DATEADD(day,1,@from) END;
 DECLARE @start datetime2=DATEADD(hour,6,CONVERT(datetime2,@from)),@end datetime2=DATEADD(hour,6,CONVERT(datetime2,@until));
 SELECT (SELECT st.Id AS sellerId,st.DisplayName AS name,COALESCE(rate.RateBps,300) AS rateBps,
 COALESCE(s.lines,0) AS salesLines,COALESCE(s.units,0) AS units,COALESCE(s.net,0) AS netSoldMinor,
 COALESCE(ret.units,0) AS returnedUnits,COALESCE(ret.net,0) AS returnsMinor,
 COALESCE(s.earned,0) AS commissionEarnedMinor,COALESCE(ret.reversed,0) AS commissionReversedMinor,
 COALESCE(s.earned,0)-COALESCE(ret.reversed,0) AS commissionPayableMinor
 FROM security.Staff st LEFT JOIN sales.SellerRates rate ON rate.SellerId=st.Id
 OUTER APPLY(SELECT COUNT(*) AS lines,SUM(CONVERT(bigint,l.Quantity)) AS units,SUM(l.UnitPriceMinor*l.Quantity-l.DiscountMinor) AS net,SUM(l.CommissionMinor) AS earned
 FROM sales.SaleLines l JOIN sales.Sales v ON v.Id=l.SaleId WHERE l.SellerId=st.Id AND v.BranchId=@BranchId AND v.CreatedAt>=@start AND v.CreatedAt<@end) s
 OUTER APPLY(SELECT SUM(CONVERT(bigint,q.Quantity)) AS units,SUM(q.CreditMinor) AS net,
 SUM(CONVERT(bigint,FLOOR(CONVERT(decimal(28,4),q.CommissionMinor)*q.cumulative/q.sold))-CONVERT(bigint,FLOOR(CONVERT(decimal(28,4),q.CommissionMinor)*(q.cumulative-q.Quantity)/q.sold))) AS reversed
 FROM (SELECT rl.Quantity,rl.CreditMinor,l.CommissionMinor,l.Quantity AS sold,r.CreatedAt,r.BranchId,
 SUM(rl.Quantity) OVER(PARTITION BY l.Id ORDER BY r.CreatedAt,r.Id ROWS UNBOUNDED PRECEDING) AS cumulative
 FROM sales.SaleReversalLines rl JOIN sales.SaleReversals r ON r.Id=rl.ReversalId JOIN sales.SaleLines l ON l.Id=rl.SaleLineId
 WHERE l.SellerId=st.Id AND r.Status='approved') q WHERE q.BranchId=@BranchId AND q.CreatedAt>=@start AND q.CreatedAt<@end) ret
 WHERE (@all=1 OR st.Id=@ActorId) AND EXISTS(SELECT 1 FROM security.StaffBranchAccess a WHERE a.StaffId=st.Id AND a.BranchId=@BranchId AND a.IsActive=1)
 AND EXISTS(SELECT 1 FROM security.StaffRoles sr JOIN security.Roles r ON r.Id=sr.RoleId WHERE sr.StaffId=st.Id AND r.Code='SELLER')
 ORDER BY st.DisplayName,st.Id FOR JSON PATH) AS Json;
END;
GO

CREATE OR ALTER PROCEDURE [sales].[usp_PostSale]
 @SaleId uniqueidentifier,@BranchId uniqueidentifier,@LocationId uniqueidentifier,
 @CashierId uniqueidentifier,@CurrencyCode varchar(3),@OriginNodeId uniqueidentifier,
 @Lines [sales].[SaleLineRequest] READONLY,
 @Tenders [sales].[SaleTenderRequest] READONLY,
 @CustomerId uniqueidentifier=NULL,@TillId uniqueidentifier=NULL,
 @DiscountApproverId uniqueidentifier=NULL,@DiscountReason nvarchar(250)=NULL,@StockExceptionNote nvarchar(500)=NULL,@SellersJson nvarchar(max)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @CustomerId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM @Tenders WHERE TenderKind='credit')
 AND NOT EXISTS(SELECT 1 FROM security.StaffRoles sr JOIN security.Roles r ON r.Id=sr.RoleId WHERE sr.StaffId=@CashierId AND r.Code='CASHIER')
 THROW 52005,'Una venta normal no lleva datos de cliente.',1;
 DECLARE @sellers TABLE(LineNumber int PRIMARY KEY,SellerId uniqueidentifier);
 IF @SellersJson IS NOT NULL
 BEGIN
  IF ISJSON(@SellersJson)<>1 THROW 52002,'Indique la vendedora de cada linea.',1;
  INSERT @sellers SELECT lineNumber,sellerId FROM OPENJSON(@SellersJson) WITH(lineNumber int,sellerId uniqueidentifier);
 END;
 -- Old CASHIER fixtures can replay historical API contracts. Real pilot roles always require attribution.
 IF @SellersJson IS NULL AND NOT EXISTS(SELECT 1 FROM security.StaffRoles sr JOIN security.Roles r ON r.Id=sr.RoleId WHERE sr.StaffId=@CashierId AND r.Code='CASHIER')
 THROW 52002,'Indique la vendedora de cada linea.',1;
 IF @SellersJson IS NOT NULL AND (EXISTS(SELECT 1 FROM @Lines l LEFT JOIN @sellers s ON s.LineNumber=l.LineNumber WHERE s.SellerId IS NULL)
 OR EXISTS(SELECT 1 FROM @sellers s WHERE NOT EXISTS(SELECT 1 FROM @Lines l WHERE l.LineNumber=s.LineNumber))
 OR EXISTS(SELECT 1 FROM @sellers x WHERE NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId
 JOIN security.StaffBranchAccess a ON a.StaffId=s.Id WHERE s.Id=x.SellerId AND s.IsEnabled=1 AND r.Code='SELLER' AND r.IsActive=1 AND a.BranchId=@BranchId AND a.IsActive=1)))
 THROW 52002,'La vendedora debe estar activa en esta sucursal.',1;

 IF NOT EXISTS(SELECT 1 FROM @Lines) THROW 51507,'Venta sin articulos.',1;
 IF EXISTS(SELECT 1 FROM @Lines WHERE Quantity NOT BETWEEN 1 AND 1000000 OR
      UnitPriceMinor<0 OR DiscountMinor<0 OR
      CAST(UnitPriceMinor AS decimal(28,0))*Quantity<DiscountMinor)
   THROW 51508,'Linea de venta invalida.',1;
 IF EXISTS(SELECT 1 FROM @Tenders WHERE AmountMinor<=0 OR TenderKind NOT IN
   ('cash','card','transfer','credit','other') OR
   (TenderKind='credit' AND (CreditId IS NULL OR @CustomerId IS NULL)) OR
   (TenderKind<>'credit' AND CreditId IS NOT NULL) OR
   (TenderKind='cash' AND (ReceivedMinor IS NULL OR ChangeMinor IS NULL OR
      ReceivedMinor-ChangeMinor<>AmountMinor)) OR
   (TenderKind<>'cash' AND (ReceivedMinor IS NOT NULL OR ChangeMinor IS NOT NULL)) OR
   (TenderKind='transfer' AND (Reference IS NULL OR LEN(LTRIM(RTRIM(Reference)))=0)))
   THROW 51509,'Formas de pago invalidas o sin autorizacion de referencia.',1;
 DECLARE @input nvarchar(max)=(SELECT @BranchId AS branchId,@LocationId AS locationId,
   JSON_QUERY(@SellersJson) AS sellers,@CashierId AS cashierId,@DiscountReason AS discountReason,@StockExceptionNote AS stockExceptionNote,@CurrencyCode AS currency,@CustomerId AS customerId,@TillId AS tillId,
   JSON_QUERY((SELECT * FROM @Lines ORDER BY LineNumber FOR JSON PATH)) AS lines,
   JSON_QUERY((SELECT * FROM @Tenders ORDER BY TenderNumber FOR JSON PATH)) AS tenders
   FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
 DECLARE @fingerprint varbinary(32)=HASHBYTES('SHA2_256',CONVERT(varbinary(max),@input));
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM sales.Sales WITH(UPDLOCK,HOLDLOCK) WHERE Id=@SaleId)
   BEGIN
     IF EXISTS(SELECT 1 FROM sales.Sales WHERE Id=@SaleId AND RequestHash<>@fingerprint)
       THROW 51510,'SaleId reutilizado con datos distintos.',1;
     COMMIT; RETURN;
   END;
   IF EXISTS(SELECT 1 FROM @Lines WHERE DiscountMinor>0)
   BEGIN
     SET @DiscountApproverId=COALESCE(@DiscountApproverId,@CashierId);
     IF NOT EXISTS(SELECT 1 FROM security.Staff s
       JOIN security.StaffBranchAccess a ON a.StaffId=s.Id AND a.BranchId=@BranchId AND a.IsActive=1
       JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId
       WHERE s.Id=@DiscountApproverId AND s.IsEnabled=1 AND r.Code IN ('MANAGER','OWNER'))
       THROW 51544,'Todo descuento requiere autorizacion de supervision.',1;
     IF NULLIF(LTRIM(RTRIM(@DiscountReason)),N'') IS NULL THROW 51547,'Indique el motivo del descuento.',1;
   END;
   ELSE BEGIN SET @DiscountApproverId=NULL; SET @DiscountReason=NULL; END;
   IF NOT EXISTS(SELECT 1 FROM core.Locations WHERE Id=@LocationId AND BranchId=@BranchId)
      THROW 51511,'Ubicacion no pertenece a sucursal.',1;
   IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId
      WHERE a.StaffId=@CashierId AND a.BranchId=@BranchId AND a.IsActive=1 AND s.IsEnabled=1)
      THROW 51512,'Cajero sin acceso a sucursal.',1;
   IF EXISTS(SELECT 1 FROM @Lines l LEFT JOIN catalog.Items i ON i.Id=l.ItemId
       WHERE i.Id IS NULL OR i.Status<>'active' OR i.UnitCostMinor IS NULL OR i.CurrencyCode<>@CurrencyCode
        OR i.UnitPriceMinor<>l.UnitPriceMinor)
      THROW 51513,'Producto, moneda o precio desactualizado.',1;
   IF @TillId IS NULL THROW 51514,'Venta POS requiere turno de caja abierto, incluso con tarjeta.',1;
   BEGIN

     IF NOT EXISTS(SELECT 1 FROM sales.CashTills t JOIN sales.CashRegisters r ON r.Id=t.RegisterId
         WHERE t.Id=@TillId AND t.Status='open' AND t.CurrencyCode=@CurrencyCode
         AND r.BranchId=@BranchId AND r.LocationId=@LocationId AND t.CashierId=@CashierId)
        THROW 51515,'El turno de caja no coincide con la venta.',1;
   END;
   DECLARE @calc TABLE(LineNumber int PRIMARY KEY,ItemId uniqueidentifier,Quantity int,
      UnitPriceMinor bigint,DiscountMinor bigint,TaxMinor bigint,TotalMinor bigint);
   INSERT INTO @calc(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor,TaxMinor,TotalMinor)
   SELECT l.LineNumber,l.ItemId,l.Quantity,l.UnitPriceMinor,l.DiscountMinor,
      CAST(ROUND((CAST(l.UnitPriceMinor AS decimal(28,0))*l.Quantity-l.DiscountMinor)
          *i.TaxRateBps/10000.0,0) AS bigint),
      CAST(l.UnitPriceMinor AS bigint)*l.Quantity-l.DiscountMinor+
        CAST(ROUND((CAST(l.UnitPriceMinor AS decimal(28,0))*l.Quantity-l.DiscountMinor)
          *i.TaxRateBps/10000.0,0) AS bigint)
   FROM @Lines l JOIN catalog.Items i ON i.Id=l.ItemId;
   DECLARE @subtotal bigint=(SELECT SUM(CAST(UnitPriceMinor AS bigint)*Quantity) FROM @calc),
     @discount bigint=(SELECT SUM(DiscountMinor) FROM @calc),
     @tax bigint=(SELECT SUM(TaxMinor) FROM @calc),
     @total bigint=(SELECT SUM(TotalMinor) FROM @calc);
   IF @total IS NULL OR @total<0 OR @total>9000000000000
      THROW 51516,'Total de venta invalido.',1;
   IF (SELECT COALESCE(SUM(AmountMinor),0) FROM @Tenders)<>@total
      THROW 51517,'Pagos no coinciden con total.',1;
   -- The branch row serializes its receipt sequence. Rolled-back sales consume no number.
   DECLARE @sequence bigint;
   SELECT @sequence=1 FROM core.Branches WITH(UPDLOCK,HOLDLOCK) WHERE Id=@BranchId;
   SELECT @sequence=COALESCE(MAX(ReceiptSequence),0)+1 FROM sales.Sales WHERE BranchId=@BranchId;
   INSERT INTO sales.Sales(Id,BranchId,LocationId,CustomerId,CashierId,TillId,CurrencyCode,
     SubtotalMinor,DiscountMinor,TaxMinor,TotalMinor,Channel,OriginNodeId,RequestHash,CreatedBy,DiscountApprovedBy,DiscountReason,ReceiptSequence)
     VALUES(@SaleId,@BranchId,@LocationId,@CustomerId,@CashierId,@TillId,@CurrencyCode,
     @subtotal,@discount,@tax,@total,'pos',@OriginNodeId,@fingerprint,@CashierId,@DiscountApproverId,@DiscountReason,@sequence);
   INSERT INTO sales.SaleLines(SaleId,LineNumber,ItemId,SkuSnapshot,NameSnapshot,
     Quantity,UnitPriceMinor,CostUnitSnapshotMinor,COGSMinor,DiscountMinor,TaxMinor,TotalMinor,CreatedBy,SellerId,CommissionRateBps,CommissionMinor)
   SELECT @SaleId,c.LineNumber,c.ItemId,i.Sku,i.VariantName,c.Quantity,c.UnitPriceMinor,
     i.UnitCostMinor,i.UnitCostMinor*CONVERT(bigint,c.Quantity),
     c.DiscountMinor,c.TaxMinor,c.TotalMinor,@CashierId,x.SellerId,COALESCE(rate.RateBps,300),
     CONVERT(bigint,FLOOR(CONVERT(decimal(28,4),c.UnitPriceMinor*c.Quantity-c.DiscountMinor)*COALESCE(rate.RateBps,300)/10000))
   FROM @calc c JOIN catalog.Items i ON i.Id=c.ItemId LEFT JOIN @sellers x ON x.LineNumber=c.LineNumber
   LEFT JOIN sales.SellerRates rate ON rate.SellerId=x.SellerId;
   DECLARE @item uniqueidentifier,@qty int,@op uniqueidentifier,@mv uniqueidentifier,@negQty int,@lineNo int,@available int,@short int,@exception uniqueidentifier;
   DECLARE lineCursor CURSOR LOCAL FAST_FORWARD FOR SELECT LineNumber,ItemId,Quantity FROM @calc ORDER BY ItemId,LineNumber;
   OPEN lineCursor; FETCH NEXT FROM lineCursor INTO @lineNo,@item,@qty;
   WHILE @@FETCH_STATUS=0
   BEGIN
     SET @available=0;
     SELECT @available=OnHand-Reserved FROM inventory.StockBalances WITH(UPDLOCK,HOLDLOCK)
      WHERE ItemId=@item AND LocationId=@LocationId AND Pool='store';
     SET @short=@qty-COALESCE(@available,0);
     IF @short>0
     BEGIN
       IF NULLIF(LTRIM(RTRIM(@StockExceptionNote)),N'') IS NULL
        THROW 51102,'Confirme que la prenda esta en la tienda e indique una nota.',1;
       SET @exception=NEWID();
       INSERT INTO sales.StockExceptions(Id,SaleLineId,ItemId,QuantityShort,CashierId,Note)
        SELECT @exception,Id,@item,@short,@CashierId,@StockExceptionNote FROM sales.SaleLines WHERE SaleId=@SaleId AND LineNumber=@lineNo;
       SET @op=NEWID(); SET @mv=NULL;
       -- Recognize physical stock omitted by the system, then sell it normally.
       -- Source is the exception, so sale.stock_vs_lines still sees exactly -Quantity.
       EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@LocationId,
        @Pool='store',@Kind='adjust',@OnHandDelta=@short,@SourceType='stock_exception',@SourceId=@exception,
        @ActorId=@CashierId,@MovementId=@mv OUTPUT;
     END;
     SET @op=NEWID(); SET @mv=NULL; SET @negQty=-@qty;
     EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@LocationId,
       @Pool='store',@Kind='sale',@OnHandDelta=@negQty,
       @SourceType='sale',@SourceId=@SaleId,@ActorId=@CashierId,@MovementId=@mv OUTPUT;
     FETCH NEXT FROM lineCursor INTO @lineNo,@item,@qty;
   END;
   CLOSE lineCursor; DEALLOCATE lineCursor;
   DECLARE @tno int,@tkind varchar(20),@amt bigint,@credit uniqueidentifier,
      @received bigint,@change bigint,@ref nvarchar(120),@tenderId uniqueidentifier,@redeemId uniqueidentifier;
   DECLARE tenderCursor CURSOR LOCAL FAST_FORWARD FOR
      SELECT TenderNumber,TenderKind,AmountMinor,CreditId,ReceivedMinor,ChangeMinor,Reference
      FROM @Tenders ORDER BY TenderNumber;
   OPEN tenderCursor; FETCH NEXT FROM tenderCursor INTO @tno,@tkind,@amt,@credit,@received,@change,@ref;
   WHILE @@FETCH_STATUS=0
   BEGIN
     SET @tenderId=NEWID();
     INSERT INTO sales.SaleTenders(Id,SaleId,TenderKind,CurrencyCode,AmountMinor,Reference,
       CreditId,ReceivedMinor,ChangeMinor,CreatedBy)
       VALUES(@tenderId,@SaleId,@tkind,@CurrencyCode,@amt,@ref,@credit,@received,@change,@CashierId);
     IF @tkind='cash'
       INSERT INTO sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy)
         VALUES(NEWID(),@TillId,@CurrencyCode,'sale',@amt,@tenderId,@CashierId,@CashierId);
     IF @tkind='credit'
     BEGIN
       SET @redeemId=NEWID();
       EXEC credits.usp_RedeemCredit @RedemptionId=@redeemId,@CreditId=@credit,@BranchId=@BranchId,
          @SaleId=@SaleId,@AmountMinor=@amt,@ActorId=@CashierId;
     END;
     FETCH NEXT FROM tenderCursor INTO @tno,@tkind,@amt,@credit,@received,@change,@ref;
   END;
   CLOSE tenderCursor; DEALLOCATE tenderCursor;
   DECLARE @event uniqueidentifier=NEWID(),@payload nvarchar(max)=(
     SELECT @SaleId AS saleId,@BranchId AS branchId,@LocationId AS locationId,
        @CurrencyCode AS currency,@total AS totalMinor,@OriginNodeId AS originNodeId,
        JSON_QUERY((SELECT sl.ItemId,sl.Quantity,sl.UnitPriceMinor,sl.TaxMinor,sl.TotalMinor
          FROM sales.SaleLines sl WHERE sl.SaleId=@SaleId FOR JSON PATH)) AS lines,
        JSON_QUERY((SELECT st.TenderKind,st.AmountMinor,st.CreditId
          FROM sales.SaleTenders st WHERE st.SaleId=@SaleId FOR JSON PATH)) AS tenders
       FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @event,@OriginNodeId,'sale',@SaleId,'sales.sale_posted',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH
   IF CURSOR_STATUS('local','lineCursor')>=0 BEGIN CLOSE lineCursor; DEALLOCATE lineCursor; END;
   IF CURSOR_STATUS('local','tenderCursor')>=0 BEGIN CLOSE tenderCursor; DEALLOCATE tenderCursor; END;
   IF @@TRANCOUNT>0 ROLLBACK;
   THROW;
 END CATCH;
END;
GO

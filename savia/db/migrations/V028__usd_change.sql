-- savia:transactional
-- USD change; NULL ForeignChangeMinor preserves immutable V027 tender semantics.
ALTER TABLE sales.SaleTenders ADD ForeignChangeMinor bigint NULL;
GO
ALTER TABLE sales.SaleTenders ADD ForeignChangeNioMinor AS
 CONVERT(bigint,ROUND(CONVERT(decimal(28,4),ForeignChangeMinor)*ExchangeRate,0)) PERSISTED;
GO
ALTER TABLE sales.SaleTenders DROP CONSTRAINT CK_Tenders_Cash,CK_Tenders_FX;
ALTER TABLE sales.SaleTenders ADD CONSTRAINT CK_Tenders_Cash CHECK((TenderKind='cash' AND ReceivedMinor IS NOT NULL AND ChangeMinor IS NOT NULL
 AND ReceivedMinor>=0 AND ChangeMinor>=0
 AND ReceivedMinor-ChangeMinor-COALESCE(ForeignChangeNioMinor,0)-COALESCE(RoundingMinor,0)=AmountMinor)
 OR (TenderKind<>'cash' AND ReceivedMinor IS NULL AND ChangeMinor IS NULL));
ALTER TABLE sales.SaleTenders ADD CONSTRAINT CK_Tenders_FX CHECK(
 (ForeignCurrencyCode IS NULL AND ForeignReceivedMinor IS NULL AND ExchangeRateId IS NULL
 AND ExchangeRate IS NULL AND RoundingMinor IS NULL AND ForeignChangeMinor IS NULL)
 OR (ForeignCurrencyCode IS NOT NULL AND ForeignCurrencyCode='USD' AND ForeignCurrencyCode<>CurrencyCode
 AND TenderKind='cash' AND ForeignReceivedMinor IS NOT NULL AND ForeignReceivedMinor>0
 AND ExchangeRateId IS NOT NULL AND ExchangeRate IS NOT NULL AND ExchangeRate BETWEEN 1 AND 1000
 AND ReceivedMinor IS NOT NULL AND ReceivedMinor>=0 AND ChangeMinor IS NOT NULL AND ChangeMinor>=0
 AND RoundingMinor IS NOT NULL
 AND ReceivedMinor=ROUND(CONVERT(decimal(28,4),ForeignReceivedMinor)*ExchangeRate,0)
 AND ((ForeignChangeMinor IS NULL AND ChangeMinor%100=0 AND RoundingMinor BETWEEN -99 AND 99)
 OR (ForeignChangeMinor IS NOT NULL AND ForeignChangeMinor>=0 AND ForeignChangeMinor<ForeignReceivedMinor
 AND ((ChangeMinor%5=0 AND ChangeMinor NOT IN (5,15) AND RoundingMinor BETWEEN 0 AND 9
 AND (RoundingMinor<=4 OR ChangeMinor IN (0,10)))
 OR (ForeignChangeMinor=0 AND ChangeMinor=0 AND RoundingMinor BETWEEN -99 AND -1))))));
DROP INDEX UX_CashEntries_Tender ON sales.CashEntries;
CREATE UNIQUE INDEX UX_CashEntries_Tender ON sales.CashEntries(SaleTenderId,Kind)
 WHERE SaleTenderId IS NOT NULL AND Kind <> 'change';
CREATE UNIQUE INDEX UX_CashEntries_Change ON sales.CashEntries(SaleTenderId,TillId)
 WHERE SaleTenderId IS NOT NULL AND Kind = 'change';
INSERT sales.CashDenominations(CurrencyCode,DenominationMinor) VALUES('USD',50),('USD',25),('USD',10),('USD',5),('USD',1);
GO
CREATE OR ALTER PROCEDURE [sales].[usp_PostSale]
 @SaleId uniqueidentifier,@BranchId uniqueidentifier,@LocationId uniqueidentifier,
 @CashierId uniqueidentifier,@CurrencyCode varchar(3),@OriginNodeId uniqueidentifier,
 @Lines [sales].[SaleLineRequest] READONLY,
 @Tenders [sales].[SaleTenderRequest] READONLY,
 @CustomerId uniqueidentifier=NULL,@TillId uniqueidentifier=NULL,
 @DiscountApproverId uniqueidentifier=NULL,@DiscountReason nvarchar(250)=NULL,@StockExceptionNote nvarchar(500)=NULL,@SellersJson nvarchar(max)=NULL,@FxJson nvarchar(max)=NULL
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
 IF (SELECT COUNT(DISTINCT SellerId) FROM @sellers)>3 THROW 52009,'Una venta admite hasta tres vendedoras.',1;

 IF NOT EXISTS(SELECT 1 FROM @Lines) THROW 51507,'Venta sin articulos.',1;
 IF EXISTS(SELECT 1 FROM @Lines WHERE Quantity NOT BETWEEN 1 AND 1000000 OR
      UnitPriceMinor<0 OR DiscountMinor<0 OR
      CAST(UnitPriceMinor AS decimal(28,0))*Quantity<DiscountMinor)
   THROW 51508,'Linea de venta invalida.',1;
 IF EXISTS(SELECT 1 FROM @Tenders WHERE AmountMinor<=0 OR TenderKind NOT IN
   ('cash','card','transfer','credit','other') OR
   (TenderKind='credit' AND (CreditId IS NULL OR @CustomerId IS NULL)) OR
   (TenderKind<>'credit' AND CreditId IS NOT NULL) OR
   (TenderKind='cash' AND @FxJson IS NULL AND (ReceivedMinor IS NULL OR ChangeMinor IS NULL OR
      ReceivedMinor-ChangeMinor<>AmountMinor)) OR
   (TenderKind<>'cash' AND (ReceivedMinor IS NOT NULL OR ChangeMinor IS NOT NULL)) OR
   (TenderKind='transfer' AND (Reference IS NULL OR LEN(LTRIM(RTRIM(Reference)))=0)))
   THROW 51509,'Formas de pago invalidas o sin autorizacion de referencia.',1;
 DECLARE @input nvarchar(max)=(SELECT JSON_QUERY(@FxJson) AS fx, @BranchId AS branchId,@LocationId AS locationId,
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
   -- Replay was resolved first. Lock drawers in the same order as pair close.
   DECLARE @parentStatus varchar(16),@child uniqueidentifier,@childStatus varchar(16);
   SELECT @parentStatus=Status FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TillId AND ParentTillId IS NULL AND CurrencyCode='NIO';
   IF @TillId IS NULL THROW 51514,'Indique el turno de caja.',1;
   IF EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId AND ParentTillId IS NOT NULL) THROW 52106,'Use el turno padre NIO.',1;
   IF @parentStatus IS NULL OR @parentStatus<>'open' THROW 51515,'Turno padre no abierto.',1;
   SELECT @child=Id,@childStatus=Status FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE ParentTillId=@TillId;
   DECLARE @fx TABLE(TenderNumber int,ForeignCurrencyCode varchar(3),ForeignReceivedMinor bigint,ExchangeRateId uniqueidentifier,
     ExchangeRate decimal(9,4),RoundingMinor bigint,ReceivedMinor bigint,ChangeMinor bigint,ForeignChangeMinor bigint,ForeignChangeNioMinor bigint);
   IF @FxJson IS NOT NULL
   BEGIN
    IF ISJSON(@FxJson)<>1 THROW 52102,'Pago extranjero invalido.',1;
    INSERT @fx(TenderNumber,ForeignCurrencyCode,ForeignReceivedMinor,ExchangeRateId,RoundingMinor,ExchangeRate,ForeignChangeMinor)
     SELECT tenderNumber,foreignCurrencyCode,foreignReceivedMinor,exchangeRateId,roundingMinor,exchangeRate,COALESCE(foreignChangeMinor,0) FROM OPENJSON(@FxJson)
     WITH(tenderNumber int,foreignCurrencyCode varchar(3),foreignReceivedMinor bigint,exchangeRateId uniqueidentifier,roundingMinor bigint,exchangeRate decimal(9,4),foreignChangeMinor bigint);
    IF (SELECT COUNT(*) FROM @fx)<>1 OR @child IS NULL OR @childStatus<>'open' OR @CurrencyCode<>'NIO'
     OR EXISTS(SELECT 1 FROM @fx f LEFT JOIN @Tenders t ON t.TenderNumber=f.TenderNumber WHERE t.TenderNumber IS NULL OR t.TenderKind<>'cash'
       OR f.ForeignCurrencyCode IS NULL OR f.ForeignCurrencyCode<>'USD' OR f.ForeignReceivedMinor IS NULL OR f.ForeignReceivedMinor<=0 OR f.ExchangeRateId IS NULL OR f.ForeignChangeMinor<0 OR f.ForeignChangeMinor>=f.ForeignReceivedMinor)
     THROW 52102,'Pago extranjero invalido o gaveta USD no abierta.',1;
    DECLARE @rateId uniqueidentifier,@rate decimal(9,4);
    SELECT TOP(1) @rateId=Id,@rate=Rate FROM core.ExchangeRates WITH(HOLDLOCK)
      WHERE CurrencyCode='USD' AND EffectiveFrom<=CAST(DATEADD(hour,-6,core.ufn_BusinessNow()) AS date) ORDER BY EffectiveFrom DESC;
    IF @rateId IS NULL OR EXISTS(SELECT 1 FROM @fx WHERE ExchangeRateId<>@rateId OR (ExchangeRate IS NOT NULL AND ExchangeRate<>@rate))
      THROW 52103,'Tasa no vigente.',1;
    UPDATE @fx SET ReceivedMinor=CONVERT(bigint,ROUND(CONVERT(decimal(28,4),ForeignReceivedMinor)*@rate,0));
    UPDATE @fx SET ForeignChangeNioMinor=CONVERT(bigint,ROUND(CONVERT(decimal(28,4),ForeignChangeMinor)*@rate,0));
    IF EXISTS(SELECT 1 FROM @fx f JOIN @Tenders t ON t.TenderNumber=f.TenderNumber
     WHERE (f.ReceivedMinor<t.AmountMinor AND f.ForeignChangeMinor<>0)
     OR (f.ReceivedMinor>=t.AmountMinor AND f.ForeignChangeNioMinor>f.ReceivedMinor-t.AmountMinor))
     THROW 52104,'Vuelto USD invalido.',1;
    UPDATE f SET ChangeMinor=CASE WHEN f.ReceivedMinor>=t.AmountMinor THEN
     (f.ReceivedMinor-t.AmountMinor-f.ForeignChangeNioMinor)-(f.ReceivedMinor-t.AmountMinor-f.ForeignChangeNioMinor)%5 ELSE 0 END
     FROM @fx f JOIN @Tenders t ON t.TenderNumber=f.TenderNumber;
    UPDATE @fx SET ChangeMinor=ChangeMinor-5 WHERE ChangeMinor IN (5,15);
    IF EXISTS(SELECT 1 FROM @fx f JOIN @Tenders t ON t.TenderNumber=f.TenderNumber WHERE f.ReceivedMinor-t.AmountMinor<=-100
      OR (t.ReceivedMinor IS NOT NULL AND t.ReceivedMinor<>f.ReceivedMinor) OR (t.ChangeMinor IS NOT NULL AND t.ChangeMinor<>f.ChangeMinor)
      OR (f.RoundingMinor IS NOT NULL AND f.RoundingMinor<>f.ReceivedMinor-f.ChangeMinor-f.ForeignChangeNioMinor-t.AmountMinor))
      THROW 52104,'Conversion o redondeo invalido.',1;
    UPDATE f SET RoundingMinor=f.ReceivedMinor-f.ChangeMinor-f.ForeignChangeNioMinor-t.AmountMinor,ExchangeRate=@rate FROM @fx f JOIN @Tenders t ON t.TenderNumber=f.TenderNumber;
    IF (SELECT COALESCE(SUM(DeltaMinor),0) FROM sales.CashEntries WHERE TillId=@TillId)
     +(SELECT COALESCE(SUM(t.AmountMinor),0) FROM @Tenders t WHERE t.TenderKind='cash'
       AND NOT EXISTS(SELECT 1 FROM @fx f WHERE f.TenderNumber=t.TenderNumber))<(SELECT ChangeMinor FROM @fx)
      THROW 52105,'No hay cordobas para el vuelto.',1;
   END;
   IF EXISTS(SELECT 1 FROM @Tenders t WHERE t.TenderKind='cash' AND NOT EXISTS(SELECT 1 FROM @fx f WHERE f.TenderNumber=t.TenderNumber)
     AND (t.ReceivedMinor IS NULL OR t.ChangeMinor IS NULL OR t.ReceivedMinor-t.ChangeMinor<>t.AmountMinor)) THROW 51509,'Efectivo invalido.',1;
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
       CreditId,ReceivedMinor,ChangeMinor,CreatedBy,ForeignCurrencyCode,ForeignReceivedMinor,ExchangeRateId,ExchangeRate,RoundingMinor,ForeignChangeMinor)
       SELECT @tenderId,@SaleId,@tkind,@CurrencyCode,@amt,@ref,@credit,COALESCE(f.ReceivedMinor,@received),COALESCE(f.ChangeMinor,@change),@CashierId,
       f.ForeignCurrencyCode,f.ForeignReceivedMinor,f.ExchangeRateId,f.ExchangeRate,f.RoundingMinor,f.ForeignChangeMinor FROM (VALUES(1)) v(n) LEFT JOIN @fx f ON f.TenderNumber=@tno;
     IF @tkind='cash' AND NOT EXISTS(SELECT 1 FROM @fx WHERE TenderNumber=@tno)
       INSERT INTO sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy)
         VALUES(NEWID(),@TillId,@CurrencyCode,'sale',@amt,@tenderId,@CashierId,@CashierId);
     IF EXISTS(SELECT 1 FROM @fx WHERE TenderNumber=@tno)
     BEGIN
      INSERT sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy)
       SELECT NEWID(),@child,'USD','sale',ForeignReceivedMinor,@tenderId,@CashierId,@CashierId FROM @fx WHERE TenderNumber=@tno;
      INSERT sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy)
       SELECT NEWID(),@TillId,'NIO','change',-ChangeMinor,@tenderId,@CashierId,@CashierId FROM @fx WHERE TenderNumber=@tno AND ChangeMinor>0;
      INSERT sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy)
       SELECT NEWID(),@child,'USD','change',-ForeignChangeMinor,@tenderId,@CashierId,@CashierId FROM @fx WHERE TenderNumber=@tno AND ForeignChangeMinor>0;
     END;
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
        JSON_QUERY((SELECT st.TenderKind,st.AmountMinor,st.CreditId,st.ForeignCurrencyCode,st.ForeignReceivedMinor,st.ReceivedMinor,st.ChangeMinor,st.ForeignChangeMinor,st.ForeignChangeNioMinor,st.RoundingMinor,st.ExchangeRate,st.ExchangeRateId
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
CREATE OR ALTER PROCEDURE sales.usp_GetSaleDetail @BranchId uniqueidentifier,@SaleId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON;
 SELECT (SELECT s.Id AS saleId,CONCAT((SELECT Code FROM core.Branches WHERE Id=s.BranchId),'-',RIGHT(CONCAT('000000',s.ReceiptSequence),CASE WHEN LEN(CONVERT(varchar(20),s.ReceiptSequence))>6 THEN LEN(CONVERT(varchar(20),s.ReceiptSequence)) ELSE 6 END)) AS receiptNumber,s.DiscountApprovedBy AS discountApprovedBy,s.DiscountReason AS discountReason,s.SubtotalMinor AS subtotalMinor,s.DiscountMinor AS discountMinor,
   s.TaxMinor AS taxMinor,s.TotalMinor AS totalMinor,s.Status AS status,s.CurrencyCode AS currencyCode,
   s.CreatedAt AS createdAt,s.CustomerId AS customerId,c.DisplayName AS customerName,
   s.CashierId AS cashierId,st.DisplayName AS cashierName,s.TillId AS tillId,reg.Name AS registerName,
   JSON_QUERY(COALESCE((SELECT l.SellerId AS sellerId,(SELECT DisplayName FROM security.Staff WHERE Id=l.SellerId) AS sellerName,l.Id AS saleLineId,l.LineNumber AS lineNumber,l.ItemId AS itemId,l.SkuSnapshot AS sku,
     l.NameSnapshot AS name,sz.Code AS sizeCode,l.Quantity AS quantity,l.ReturnedQuantity AS returnedQuantity,
     l.UnitPriceMinor AS unitPriceMinor,l.DiscountMinor AS discountMinor,l.TaxMinor AS taxMinor,l.TotalMinor AS totalMinor
     FROM sales.SaleLines l JOIN catalog.Items i ON i.Id=l.ItemId LEFT JOIN catalog.Sizes sz ON sz.Id=i.SizeId
     WHERE l.SaleId=s.Id ORDER BY l.LineNumber FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS lines,
   JSON_QUERY(COALESCE((SELECT t.Id AS tenderId,t.TenderKind AS tenderKind,t.AmountMinor AS amountMinor,t.ReceivedMinor AS receivedMinor,
     t.ChangeMinor AS changeMinor,t.ForeignCurrencyCode AS foreignCurrencyCode,t.ForeignReceivedMinor AS foreignReceivedMinor,t.ExchangeRateId AS exchangeRateId,t.ExchangeRate AS exchangeRate,t.ForeignChangeMinor AS foreignChangeMinor,t.ForeignChangeNioMinor AS foreignChangeNioMinor,t.RoundingMinor AS roundingMinor,t.Reference AS reference,t.CreditId AS creditId,t.Status AS status
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
CREATE OR ALTER PROCEDURE [audit].[usp_CheckConservation] @Throw bit = 0
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @v TABLE(CheckName varchar(60) NOT NULL, KeyText nvarchar(200) NOT NULL, Expected bigint NULL, Actual bigint NULL);

 /* ---- stock: a balance is the sum of its movements, and stays inside its bounds */
 WITH m AS (SELECT ItemId,LocationId,Pool,SUM(CONVERT(bigint,OnHandDelta)) AS OnHand,
                   SUM(CONVERT(bigint,ReservedDelta)) AS Reserved
            FROM inventory.StockMovements GROUP BY ItemId,LocationId,Pool)
 INSERT INTO @v
 SELECT x.CheckName,CONCAT(COALESCE(b.ItemId,m.ItemId),N'/',COALESCE(b.LocationId,m.LocationId),N'/',COALESCE(b.Pool,m.Pool)),
        x.Expected,x.Actual
 FROM inventory.StockBalances b
 FULL JOIN m ON m.ItemId=b.ItemId AND m.LocationId=b.LocationId AND m.Pool=b.Pool
 CROSS APPLY (VALUES ('stock.onhand_vs_movements',COALESCE(m.OnHand,0),CONVERT(bigint,COALESCE(b.OnHand,0))),
                     ('stock.reserved_vs_movements',COALESCE(m.Reserved,0),CONVERT(bigint,COALESCE(b.Reserved,0)))) x(CheckName,Expected,Actual)
 WHERE x.Expected<>x.Actual;

 INSERT INTO @v
 SELECT 'stock.bounds',CONCAT(ItemId,N'/',LocationId,N'/',Pool),0,OnHand
 FROM inventory.StockBalances WHERE OnHand<0 OR Reserved<0 OR Reserved>OnHand;

 INSERT INTO @v
 SELECT 'stock.reserved_vs_reservations',CONCAT(b.ItemId,N'/',b.LocationId,N'/',b.Pool),COALESCE(r.Quantity,0),b.Reserved
 FROM inventory.StockBalances b
 OUTER APPLY (SELECT SUM(CONVERT(bigint,Quantity)) AS Quantity FROM inventory.StockReservations
              WHERE ItemId=b.ItemId AND LocationId=b.LocationId AND Pool=b.Pool AND Status='active') r
 WHERE COALESCE(r.Quantity,0)<>b.Reserved;

 /* ---- receiving: what was counted is what was received, moved once and labelled once */
 INSERT INTO @v
 SELECT 'receipt.line_vs_movement',CONVERT(nvarchar(36),l.Id),l.Quantity,COALESCE(m.Quantity,0)
 FROM purchasing.GoodsReceiptLines l
 OUTER APPLY (SELECT SUM(CONVERT(bigint,OnHandDelta)) AS Quantity,COUNT(*) AS Movements FROM inventory.StockMovements
              WHERE SourceType='goods_receipt_line' AND SourceId=l.Id AND Kind='receive') m
 WHERE COALESCE(m.Quantity,0)<>l.Quantity OR COALESCE(m.Movements,0)<>1;

 INSERT INTO @v
 SELECT 'receipt.vs_scans',CONVERT(nvarchar(36),r.Id),s.Quantity-COALESCE((SELECT SUM(CONVERT(bigint,q.Missing)) FROM receiving.vw_CurrentQuality q WHERE q.ScanSessionId=r.ScanSessionId),0),l.Quantity
 FROM purchasing.GoodsReceipts r
 CROSS APPLY (SELECT COALESCE(SUM(CONVERT(bigint,Quantity)),0) AS Quantity FROM receiving.ScanEvents
              WHERE ScanSessionId=r.ScanSessionId AND MatchStatus='matched') s
 CROSS APPLY (SELECT COALESCE(SUM(CONVERT(bigint,Quantity)),0) AS Quantity FROM purchasing.GoodsReceiptLines
              WHERE GoodsReceiptId=r.Id) l
 WHERE r.ScanSessionId IS NOT NULL AND s.Quantity-COALESCE((SELECT SUM(CONVERT(bigint,q.Missing)) FROM receiving.vw_CurrentQuality q WHERE q.ScanSessionId=r.ScanSessionId),0)<>l.Quantity;

 INSERT INTO @v
 SELECT 'receipt.unmatched_scan_in_posted_session',CONVERT(nvarchar(36),e.Id),0,1
 FROM receiving.ScanEvents e JOIN receiving.ScanSessions s ON s.Id=e.ScanSessionId
 WHERE s.Status='posted' AND e.MatchStatus IN ('unknown','ambiguous');

 INSERT INTO @v
 SELECT 'receipt.label_job',CONVERT(nvarchar(36),l.Id),l.Quantity,COALESCE(j.Copies,0)
 FROM purchasing.GoodsReceiptLines l
 OUTER APPLY (SELECT SUM(CONVERT(bigint,CopiesRequested)) AS Copies,COUNT(*) AS Jobs FROM labels.PrintJobs
              WHERE ReceiptLineId=l.Id) j
 WHERE COALESCE(j.Copies,0)<>l.Quantity OR COALESCE(j.Jobs,0)<>1;

 /* ---- sales: lines, payments, stock and cash agree with the sale; one event per sale */
 INSERT INTO @v
 SELECT x.CheckName,CONVERT(nvarchar(36),s.Id),x.Expected,x.Actual
 FROM sales.Sales s
 OUTER APPLY (SELECT SUM(TotalMinor) AS Total,SUM(CONVERT(bigint,Quantity)) AS Quantity FROM sales.SaleLines WHERE SaleId=s.Id) l
 OUTER APPLY (SELECT SUM(AmountMinor) AS Total FROM sales.SaleTenders WHERE SaleId=s.Id) t
 OUTER APPLY (SELECT SUM(CONVERT(bigint,OnHandDelta)) AS Quantity FROM inventory.StockMovements
              WHERE SourceType='sale' AND SourceId=s.Id) m
 OUTER APPLY (SELECT COUNT(*) AS Events FROM sync.Outbox WHERE AggregateId=s.Id AND EventType='sales.sale_posted') o
 CROSS APPLY (VALUES ('sale.lines_vs_total',s.TotalMinor,COALESCE(l.Total,0)),
                     ('sale.tenders_vs_total',s.TotalMinor,COALESCE(t.Total,0)),
                     ('sale.stock_vs_lines',-COALESCE(l.Quantity,0),COALESCE(m.Quantity,0)),
                     ('sale.outbox_event',CONVERT(bigint,1),CONVERT(bigint,COALESCE(o.Events,0)))) x(CheckName,Expected,Actual)
 WHERE s.Channel='pos' AND x.Expected<>x.Actual;

 INSERT INTO @v
 SELECT 'sale.cash_tender_vs_cash_entry',CONVERT(nvarchar(36),t.Id),COALESCE(t.ForeignReceivedMinor,t.AmountMinor),COALESCE(e.Total,0)
 FROM sales.SaleTenders t JOIN sales.Sales s ON s.Id=t.SaleId
 OUTER APPLY(SELECT SUM(e.DeltaMinor) AS Total,COUNT(*) AS Entries FROM sales.CashEntries e
 WHERE e.SaleTenderId=t.Id AND e.Kind='sale' AND e.CurrencyCode=COALESCE(t.ForeignCurrencyCode,t.CurrencyCode)
 AND e.TillId=CASE WHEN t.ForeignCurrencyCode IS NULL THEN s.TillId ELSE (SELECT Id FROM sales.CashTills WHERE ParentTillId=s.TillId) END) e
 WHERE t.TenderKind='cash' AND (COALESCE(e.Total,0)<>COALESCE(t.ForeignReceivedMinor,t.AmountMinor) OR e.Entries<>1 OR (SELECT COUNT(*) FROM sales.CashEntries x WHERE x.SaleTenderId=t.Id AND x.Kind='sale')<>1);
 INSERT INTO @v
 SELECT 'sale.fx_change',CONVERT(nvarchar(36),t.Id),-t.ChangeMinor,COALESCE(e.Total,0)
 FROM sales.SaleTenders t JOIN sales.Sales s ON s.Id=t.SaleId
 OUTER APPLY(SELECT SUM(DeltaMinor) AS Total,COUNT(*) AS Entries FROM sales.CashEntries WHERE SaleTenderId=t.Id AND Kind='change' AND TillId=s.TillId AND CurrencyCode='NIO') e
 WHERE t.ForeignCurrencyCode IS NOT NULL AND (COALESCE(e.Total,0)<>-t.ChangeMinor OR e.Entries<>CASE WHEN t.ChangeMinor=0 THEN 0 ELSE 1 END
 OR (SELECT COUNT(*) FROM sales.CashEntries x WHERE x.SaleTenderId=t.Id AND x.Kind='change')<>CASE WHEN t.ChangeMinor=0 THEN 0 ELSE 1 END+CASE WHEN COALESCE(t.ForeignChangeMinor,0)=0 THEN 0 ELSE 1 END);
 INSERT INTO @v
 SELECT 'sale.fx_usd_change',CONVERT(nvarchar(36),t.Id),-COALESCE(t.ForeignChangeMinor,0),COALESCE(e.Total,0)
 FROM sales.SaleTenders t JOIN sales.Sales s ON s.Id=t.SaleId
 OUTER APPLY(SELECT SUM(e.DeltaMinor) AS Total,COUNT(*) AS Entries FROM sales.CashEntries e
 JOIN sales.CashTills c ON c.Id=e.TillId WHERE e.SaleTenderId=t.Id AND e.Kind='change'
 AND e.CurrencyCode='USD' AND c.ParentTillId=s.TillId) e
 WHERE t.ForeignCurrencyCode IS NOT NULL AND (COALESCE(e.Total,0)<>-COALESCE(t.ForeignChangeMinor,0)
 OR e.Entries<>CASE WHEN COALESCE(t.ForeignChangeMinor,0)=0 THEN 0 ELSE 1 END
 OR EXISTS(SELECT 1 FROM sales.CashEntries x WHERE x.SaleTenderId=t.Id AND x.Kind NOT IN ('sale','change')));
 INSERT INTO @v
 SELECT 'sale.fx_conversion',CONVERT(nvarchar(36),t.Id),t.ReceivedMinor,CONVERT(bigint,ROUND(t.ForeignReceivedMinor*r.Rate,0))
 FROM sales.SaleTenders t LEFT JOIN core.ExchangeRates r ON r.Id=t.ExchangeRateId
 WHERE t.ForeignCurrencyCode IS NOT NULL AND (r.Id IS NULL OR r.Rate<>t.ExchangeRate OR t.ReceivedMinor<>ROUND(t.ForeignReceivedMinor*t.ExchangeRate,0)
 OR t.ReceivedMinor-t.ChangeMinor-COALESCE(t.ForeignChangeNioMinor,0)-t.RoundingMinor<>t.AmountMinor
 OR (t.ForeignChangeMinor IS NULL AND (t.RoundingMinor NOT BETWEEN -99 AND 99 OR t.ChangeMinor%100<>0))
 OR (t.ForeignChangeMinor IS NOT NULL AND NOT (t.ForeignChangeMinor IS NOT NULL AND t.ForeignChangeMinor>=0 AND t.ForeignChangeMinor<t.ForeignReceivedMinor
 AND ((t.ChangeMinor%5=0 AND t.ChangeMinor NOT IN (5,15) AND t.RoundingMinor BETWEEN 0 AND 9
 AND (t.RoundingMinor<=4 OR t.ChangeMinor IN (0,10)))
 OR (t.ForeignChangeMinor=0 AND t.ChangeMinor=0 AND t.RoundingMinor BETWEEN -99 AND -1)))));
 INSERT INTO @v
 SELECT 'cash.drawer_pair',CONVERT(nvarchar(36),c.Id),0,1 FROM sales.CashTills c LEFT JOIN sales.CashTills p ON p.Id=c.ParentTillId
 WHERE c.ParentTillId IS NOT NULL AND (p.Id IS NULL OR p.ParentTillId IS NOT NULL OR p.CurrencyCode<>'NIO' OR c.CurrencyCode<>'USD'
 OR p.RegisterId<>c.RegisterId OR p.CashierId<>c.CashierId OR p.Status<>c.Status);

 /* ---- cash: a closure matches the entries and the count, and has one accounting document */
 INSERT INTO @v
 SELECT x.CheckName,CONVERT(nvarchar(36),c.Id),x.Expected,x.Actual
 FROM sales.CashClosures c
 OUTER APPLY (SELECT COALESCE(SUM(DeltaMinor),0) AS Total FROM sales.CashEntries WHERE TillId=c.TillId) e
 OUTER APPLY (SELECT COALESCE(SUM(CONVERT(bigint,DenominationMinor)*Quantity),0) AS Total FROM sales.CashCountLines WHERE CashCountId=c.CashCountId) n
 OUTER APPLY (SELECT COUNT(*) AS Documents FROM accounting.CloseDocuments WHERE ClosureId=c.Id) d
 OUTER APPLY (SELECT COUNT(*) AS Jobs FROM accounting.ExportJobs j JOIN accounting.CloseDocuments cd ON cd.Id=j.CloseDocumentId
              WHERE cd.ClosureId=c.Id AND j.RecipientCode=N'ACCOUNTANT') j
 CROSS APPLY (VALUES ('cash.closure_expected_vs_entries',e.Total,c.ExpectedMinor),
                     ('cash.closure_counted_vs_count',n.Total,c.CountedMinor),
                     ('cash.closure_difference',c.CountedMinor-c.ExpectedMinor,c.DifferenceMinor),
                     ('cash.closure_document',CONVERT(bigint,1),CONVERT(bigint,d.Documents)),
                     ('cash.closure_export_job',CONVERT(bigint,1),CONVERT(bigint,j.Jobs))) x(CheckName,Expected,Actual)
 WHERE x.Expected<>x.Actual;

 INSERT INTO @v
 SELECT 'cash.till_status_vs_closure',CONVERT(nvarchar(36),t.Id),CASE WHEN t.Status='closed' THEN 1 ELSE 0 END,c.Closures
 FROM sales.CashTills t
 CROSS APPLY (SELECT COUNT(*) AS Closures FROM sales.CashClosures WHERE TillId=t.Id) c
 WHERE c.Closures<>CASE WHEN t.Status='closed' THEN 1 ELSE 0 END;

 /* ---- credits: money issued = money still held somewhere + money spent + money in transit (V009) */
 INSERT INTO @v
 SELECT 'credit.conservation',CONVERT(nvarchar(36),c.Id),c.OriginalMinor,a.Total+r.Total+t.Total
 FROM credits.Credits c
 CROSS APPLY (SELECT COALESCE(SUM(AvailableMinor+HeldMinor),0) AS Total FROM credits.CreditAllocations WHERE CreditId=c.Id) a
 CROSS APPLY (SELECT COALESCE(SUM(AmountMinor),0) AS Total FROM credits.CreditRedemptions WHERE CreditId=c.Id AND Status='posted') r
 CROSS APPLY (SELECT COALESCE(SUM(q.AmountMinor),0) AS Total FROM credits.TransferDispatches d
              JOIN credits.TransferRequests q ON q.Id=d.TransferId
              WHERE q.CreditId=c.Id AND NOT EXISTS(SELECT 1 FROM credits.TransferReceipts x WHERE x.TransferId=d.TransferId)) t
 WHERE c.OriginalMinor<>a.Total+r.Total+t.Total;

 /* ---- credits (V009): each dispatch has exactly one -amount leg at the origin, each receipt one +amount leg at the destination */
 INSERT INTO @v
 SELECT 'credit.transfer_leg',CONCAT(q.Id,N'/',x.Kind),x.Expected,x.Legs
 FROM credits.TransferRequests q
 CROSS APPLY (SELECT 'transfer_out' AS Kind,
                (SELECT COUNT(*) FROM credits.CreditMovements m WHERE m.SourceType='credit_transfer' AND m.SourceId=q.Id
                   AND m.Kind='transfer_out' AND m.BranchId=q.FromBranchId AND m.AvailableDeltaMinor=-q.AmountMinor) AS Legs,
                CASE WHEN EXISTS(SELECT 1 FROM credits.TransferDispatches WHERE TransferId=q.Id) THEN 1 ELSE 0 END AS Expected
              UNION ALL
              SELECT 'transfer_in',
                (SELECT COUNT(*) FROM credits.CreditMovements m WHERE m.SourceType='credit_transfer' AND m.SourceId=q.Id
                   AND m.Kind='transfer_in' AND m.BranchId=q.ToBranchId AND m.AvailableDeltaMinor=q.AmountMinor),
                CASE WHEN EXISTS(SELECT 1 FROM credits.TransferReceipts WHERE TransferId=q.Id) THEN 1 ELSE 0 END) x
 WHERE x.Legs<>x.Expected;

 INSERT INTO @v
 SELECT 'credit.bounds',CONCAT(CreditId,N'/',BranchId),0,CASE WHEN AvailableMinor<0 THEN AvailableMinor ELSE HeldMinor END
 FROM credits.CreditAllocations WHERE AvailableMinor<0 OR HeldMinor<0;

 WITH m AS (SELECT CreditId,BranchId,SUM(AvailableDeltaMinor) AS Available,SUM(HeldDeltaMinor) AS Held
            FROM credits.CreditMovements GROUP BY CreditId,BranchId)
 INSERT INTO @v
 SELECT x.CheckName,CONCAT(COALESCE(a.CreditId,m.CreditId),N'/',COALESCE(a.BranchId,m.BranchId)),x.Expected,x.Actual
 FROM credits.CreditAllocations a
 FULL JOIN m ON m.CreditId=a.CreditId AND m.BranchId=a.BranchId
 CROSS APPLY (VALUES ('credit.available_vs_movements',COALESCE(m.Available,0),COALESCE(a.AvailableMinor,0)),
                     ('credit.held_vs_movements',COALESCE(m.Held,0),COALESCE(a.HeldMinor,0))) x(CheckName,Expected,Actual)
 WHERE x.Expected<>x.Actual;


 /* ---- returns (V024): settlements equal the returned value; cash leaves the till once; exchanges pay their sale */
 INSERT INTO @v
 SELECT x.CheckName,CONVERT(nvarchar(36),r.Id),x.Expected,x.Actual
 FROM sales.SaleReversals r
 OUTER APPLY (SELECT COALESCE(SUM(AmountMinor),0) AS Total,COALESCE(SUM(CASE WHEN Kind='cash' THEN AmountMinor END),0) AS Cash FROM sales.ReturnSettlements WHERE ReversalId=r.Id) s
 OUTER APPLY (SELECT COALESCE(SUM(DeltaMinor),0) AS Total FROM sales.CashEntries WHERE ReversalId=r.Id AND Kind='refund') e
 CROSS APPLY (VALUES ('return.settlements_vs_value',r.CreditMinor,s.Total),('return.cash_refund_vs_till',-s.Cash,e.Total)) x(CheckName,Expected,Actual)
 WHERE r.SettlementKind IN ('cash','transfer','exchange') AND x.Expected<>x.Actual;

 INSERT INTO @v
 SELECT 'return.exchange_tender',CONVERT(nvarchar(36),s.Id),s.AmountMinor,COALESCE(t.Total,0)
 FROM sales.ReturnSettlements s
 OUTER APPLY (SELECT SUM(AmountMinor) AS Total FROM sales.SaleTenders WHERE SaleId=s.ExchangeSaleId AND TenderKind='other'
              AND Reference=CONCAT(N'CAMBIO ',CONVERT(nvarchar(36),s.ReversalId))) t
 WHERE s.Kind='exchange' AND COALESCE(t.Total,0)<>s.AmountMinor;
 SELECT CheckName,KeyText,Expected,Actual FROM @v ORDER BY CheckName,KeyText;
 IF @Throw=1 AND EXISTS(SELECT 1 FROM @v)
 BEGIN
   DECLARE @msg nvarchar(900)=(SELECT TOP(1) CONCAT(N'CONSERVATION FAIL: ',CheckName,N' key=',KeyText,
       N' expected=',Expected,N' actual=',Actual,N' (',(SELECT COUNT(*) FROM @v),N' violations)')
     FROM @v ORDER BY CheckName,KeyText);
   THROW 59100,@msg,1;
 END;
END;
GO

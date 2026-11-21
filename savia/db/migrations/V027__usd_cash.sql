-- USD cash. Existing NIO tills remain valid without a child.
CREATE TABLE core.ExchangeRates(
 Id uniqueidentifier NOT NULL PRIMARY KEY, CurrencyCode varchar(3) NOT NULL CHECK(CurrencyCode='USD'),
 EffectiveFrom date NOT NULL, Rate decimal(9,4) NOT NULL CHECK(Rate BETWEEN 1 AND 1000),
 SetBy uniqueidentifier NOT NULL REFERENCES security.Staff(Id), SetAt datetime2(3) NOT NULL DEFAULT(SYSUTCDATETIME()),
 Reason nvarchar(250) NOT NULL CHECK(LEN(LTRIM(RTRIM(Reason)))>0), UNIQUE(CurrencyCode,EffectiveFrom));
ALTER TABLE sales.CashTills ADD ParentTillId uniqueidentifier NULL REFERENCES sales.CashTills(Id);
GO
ALTER TABLE sales.CashTills ADD CONSTRAINT CK_Till_ChildCurrency CHECK(ParentTillId IS NULL OR (CurrencyCode='USD' AND ParentTillId<>Id));
DROP INDEX UX_OpenTill_Register ON sales.CashTills;
CREATE UNIQUE INDEX UX_OpenTill_Register ON sales.CashTills(RegisterId) WHERE Status='open' AND ParentTillId IS NULL;
CREATE UNIQUE INDEX UX_Till_Child ON sales.CashTills(ParentTillId) WHERE ParentTillId IS NOT NULL;
ALTER TABLE sales.SaleTenders ADD ForeignCurrencyCode varchar(3) COLLATE Latin1_General_100_BIN2 NULL,ForeignReceivedMinor bigint NULL,
 ExchangeRateId uniqueidentifier NULL REFERENCES core.ExchangeRates(Id),ExchangeRate decimal(9,4) NULL,RoundingMinor bigint NULL;
GO
ALTER TABLE sales.SaleTenders DROP CONSTRAINT CK_Tenders_Cash;
ALTER TABLE sales.SaleTenders ADD CONSTRAINT CK_Tenders_Cash CHECK(
 (TenderKind='cash' AND ReceivedMinor IS NOT NULL AND ChangeMinor IS NOT NULL AND ReceivedMinor>=0 AND ChangeMinor>=0
 AND ReceivedMinor-ChangeMinor-COALESCE(RoundingMinor,0)=AmountMinor)
 OR (TenderKind<>'cash' AND ReceivedMinor IS NULL AND ChangeMinor IS NULL));
ALTER TABLE sales.SaleTenders ADD CONSTRAINT CK_Tenders_FX CHECK(
 (ForeignCurrencyCode IS NULL AND ForeignReceivedMinor IS NULL AND ExchangeRateId IS NULL AND ExchangeRate IS NULL AND RoundingMinor IS NULL)
 OR (ForeignCurrencyCode IS NOT NULL AND ForeignCurrencyCode='USD' AND ForeignCurrencyCode<>CurrencyCode AND TenderKind='cash'
 AND ForeignReceivedMinor IS NOT NULL AND ForeignReceivedMinor>0 AND ExchangeRateId IS NOT NULL AND ExchangeRate IS NOT NULL
 AND ExchangeRate BETWEEN 1 AND 1000 AND RoundingMinor IS NOT NULL AND RoundingMinor>-100 AND RoundingMinor<100
 AND ChangeMinor%100=0 AND ReceivedMinor=ROUND(CONVERT(decimal(28,4),ForeignReceivedMinor)*ExchangeRate,0)));
CREATE UNIQUE INDEX UX_Tenders_OneFX ON sales.SaleTenders(SaleId) WHERE ForeignCurrencyCode IS NOT NULL;
ALTER TABLE sales.CashEntries DROP CONSTRAINT CK_CashEntries_Kind,CK_CashEntries_Source;
ALTER TABLE sales.CashEntries ADD CONSTRAINT CK_CashEntries_Kind CHECK(Kind IN ('opening','sale','refund','payout','deposit','adjustment','change')),
 CONSTRAINT CK_CashEntries_Source CHECK(
 (Kind='sale' AND SaleTenderId IS NOT NULL AND ReversalId IS NULL AND DeltaMinor>0) OR
 (Kind='change' AND SaleTenderId IS NOT NULL AND ReversalId IS NULL AND DeltaMinor<0) OR
 (Kind='refund' AND ReversalId IS NOT NULL AND SaleTenderId IS NULL AND DeltaMinor<0) OR
 (Kind NOT IN ('sale','refund','change') AND SaleTenderId IS NULL AND ReversalId IS NULL));
DROP INDEX UX_CashEntries_Tender ON sales.CashEntries;
CREATE UNIQUE INDEX UX_CashEntries_Tender ON sales.CashEntries(SaleTenderId,Kind) WHERE SaleTenderId IS NOT NULL;
ALTER TABLE sales.CashDenominations ADD CurrencyCode varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL DEFAULT('NIO');
GO
DECLARE @pk sysname=(SELECT name FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID('sales.CashDenominations') AND type='PK');
EXEC('ALTER TABLE sales.CashDenominations DROP CONSTRAINT '+@pk);
ALTER TABLE sales.CashDenominations ADD CONSTRAINT PK_CashDenominations PRIMARY KEY(CurrencyCode,DenominationMinor);
INSERT sales.CashDenominations(CurrencyCode,DenominationMinor) VALUES('USD',10000),('USD',5000),('USD',2000),('USD',1000),('USD',500),('USD',200),('USD',100);
GO

CREATE OR ALTER PROCEDURE core.usp_SetExchangeRate
 @Id uniqueidentifier,@EffectiveFrom date,@Rate decimal(9,4),@ActorId uniqueidentifier,@Reason nvarchar(250)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffRoles sr ON sr.StaffId=s.Id
 JOIN security.Roles r ON r.Id=sr.RoleId WHERE s.Id=@ActorId AND s.IsEnabled=1 AND r.IsActive=1 AND r.Code IN ('MANAGER','OWNER'))
 THROW 52100,'Solo gerente o duena puede fijar la tasa.',1;
 IF @EffectiveFrom IS NULL OR @EffectiveFrom<CAST(DATEADD(hour,-6,core.ufn_BusinessNow()) AS date)
 OR @Rate IS NULL OR @Rate NOT BETWEEN 1 AND 1000 OR NULLIF(LTRIM(RTRIM(@Reason)),N'') IS NULL
 THROW 52101,'Fecha, tasa o motivo invalido.',1;
 INSERT core.ExchangeRates(Id,CurrencyCode,EffectiveFrom,Rate,SetBy,Reason) VALUES(@Id,'USD',@EffectiveFrom,@Rate,@ActorId,@Reason);
END;
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
     ExchangeRate decimal(9,4),RoundingMinor bigint,ReceivedMinor bigint,ChangeMinor bigint);
   IF @FxJson IS NOT NULL
   BEGIN
    IF ISJSON(@FxJson)<>1 THROW 52102,'Pago extranjero invalido.',1;
    INSERT @fx(TenderNumber,ForeignCurrencyCode,ForeignReceivedMinor,ExchangeRateId,RoundingMinor,ExchangeRate)
     SELECT tenderNumber,foreignCurrencyCode,foreignReceivedMinor,exchangeRateId,roundingMinor,exchangeRate FROM OPENJSON(@FxJson)
     WITH(tenderNumber int,foreignCurrencyCode varchar(3),foreignReceivedMinor bigint,exchangeRateId uniqueidentifier,roundingMinor bigint,exchangeRate decimal(9,4));
    IF (SELECT COUNT(*) FROM @fx)<>1 OR @child IS NULL OR @childStatus<>'open' OR @CurrencyCode<>'NIO'
     OR EXISTS(SELECT 1 FROM @fx f LEFT JOIN @Tenders t ON t.TenderNumber=f.TenderNumber WHERE t.TenderNumber IS NULL OR t.TenderKind<>'cash'
       OR f.ForeignCurrencyCode IS NULL OR f.ForeignCurrencyCode<>'USD' OR f.ForeignReceivedMinor IS NULL OR f.ForeignReceivedMinor<=0 OR f.ExchangeRateId IS NULL)
     THROW 52102,'Pago extranjero invalido o gaveta USD no abierta.',1;
    DECLARE @rateId uniqueidentifier,@rate decimal(9,4);
    SELECT TOP(1) @rateId=Id,@rate=Rate FROM core.ExchangeRates WITH(HOLDLOCK)
      WHERE CurrencyCode='USD' AND EffectiveFrom<=CAST(DATEADD(hour,-6,core.ufn_BusinessNow()) AS date) ORDER BY EffectiveFrom DESC;
    IF @rateId IS NULL OR EXISTS(SELECT 1 FROM @fx WHERE ExchangeRateId<>@rateId OR (ExchangeRate IS NOT NULL AND ExchangeRate<>@rate))
      THROW 52103,'Tasa no vigente.',1;
    UPDATE @fx SET ReceivedMinor=CONVERT(bigint,ROUND(CONVERT(decimal(28,4),ForeignReceivedMinor)*@rate,0));
    UPDATE f SET ChangeMinor=CASE WHEN f.ReceivedMinor>=t.AmountMinor THEN (f.ReceivedMinor-t.AmountMinor)/100*100 ELSE 0 END
      FROM @fx f JOIN @Tenders t ON t.TenderNumber=f.TenderNumber;
    IF EXISTS(SELECT 1 FROM @fx f JOIN @Tenders t ON t.TenderNumber=f.TenderNumber WHERE f.ReceivedMinor-t.AmountMinor<=-100
      OR (t.ReceivedMinor IS NOT NULL AND t.ReceivedMinor<>f.ReceivedMinor) OR (t.ChangeMinor IS NOT NULL AND t.ChangeMinor<>f.ChangeMinor)
      OR (f.RoundingMinor IS NOT NULL AND f.RoundingMinor<>f.ReceivedMinor-f.ChangeMinor-t.AmountMinor))
      THROW 52104,'Conversion o redondeo invalido.',1;
    UPDATE f SET RoundingMinor=f.ReceivedMinor-f.ChangeMinor-t.AmountMinor,ExchangeRate=@rate FROM @fx f JOIN @Tenders t ON t.TenderNumber=f.TenderNumber;
    IF (SELECT COALESCE(SUM(DeltaMinor),0) FROM sales.CashEntries WHERE TillId=@TillId)<(SELECT ChangeMinor FROM @fx)
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
       CreditId,ReceivedMinor,ChangeMinor,CreatedBy,ForeignCurrencyCode,ForeignReceivedMinor,ExchangeRateId,ExchangeRate,RoundingMinor)
       SELECT @tenderId,@SaleId,@tkind,@CurrencyCode,@amt,@ref,@credit,COALESCE(f.ReceivedMinor,@received),COALESCE(f.ChangeMinor,@change),@CashierId,
       f.ForeignCurrencyCode,f.ForeignReceivedMinor,f.ExchangeRateId,f.ExchangeRate,f.RoundingMinor FROM (VALUES(1)) v(n) LEFT JOIN @fx f ON f.TenderNumber=@tno;
     IF @tkind='cash' AND NOT EXISTS(SELECT 1 FROM @fx WHERE TenderNumber=@tno)
       INSERT INTO sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy)
         VALUES(NEWID(),@TillId,@CurrencyCode,'sale',@amt,@tenderId,@CashierId,@CashierId);
     IF EXISTS(SELECT 1 FROM @fx WHERE TenderNumber=@tno)
     BEGIN
      INSERT sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy)
       SELECT NEWID(),@child,'USD','sale',ForeignReceivedMinor,@tenderId,@CashierId,@CashierId FROM @fx WHERE TenderNumber=@tno;
      INSERT sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy)
       SELECT NEWID(),@TillId,'NIO','change',-ChangeMinor,@tenderId,@CashierId,@CashierId FROM @fx WHERE TenderNumber=@tno AND ChangeMinor>0;
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
        JSON_QUERY((SELECT st.TenderKind,st.AmountMinor,st.CreditId,st.ForeignCurrencyCode,st.ForeignReceivedMinor,st.ReceivedMinor,st.ChangeMinor,st.RoundingMinor,st.ExchangeRate,st.ExchangeRateId
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

CREATE OR ALTER PROCEDURE [sales].[usp_RecordDrawerCount]
 @CashCountId uniqueidentifier,@TillId uniqueidentifier,@ActorId uniqueidentifier,@LinesJson nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF ISJSON(@LinesJson)<>1 THROW 51540,'Arqueo: lineas con formato invalido.',1;
 DECLARE @lines TABLE(DenominationMinor bigint NULL,Quantity int NULL);
 INSERT INTO @lines(DenominationMinor,Quantity)
   SELECT denominationMinor,quantity FROM OPENJSON(@LinesJson)
     WITH (denominationMinor bigint '$.denominationMinor', quantity int '$.quantity');
 IF NOT EXISTS(SELECT 1 FROM @lines) OR EXISTS(SELECT 1 FROM @lines l
      WHERE DenominationMinor IS NULL OR Quantity IS NULL OR DenominationMinor<=0 OR Quantity<0 OR Quantity>1000000 OR NOT EXISTS(SELECT 1 FROM sales.CashDenominations d WHERE d.DenominationMinor=l.DenominationMinor AND d.CurrencyCode=(SELECT CurrencyCode FROM sales.CashTills WHERE Id=@TillId)))
   THROW 51541,'Arqueo: cada linea necesita denominacion mayor a cero y cantidad no negativa.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM sales.CashCounts WITH(UPDLOCK,HOLDLOCK) WHERE Id=@CashCountId)
   BEGIN
     IF NOT EXISTS(SELECT 1 FROM sales.CashCounts WHERE Id=@CashCountId AND TillId=@TillId)
      OR EXISTS(SELECT DenominationMinor,SUM(Quantity) FROM @lines GROUP BY DenominationMinor EXCEPT SELECT DenominationMinor,Quantity FROM sales.CashCountLines WHERE CashCountId=@CashCountId)
      OR EXISTS(SELECT DenominationMinor,Quantity FROM sales.CashCountLines WHERE CashCountId=@CashCountId EXCEPT SELECT DenominationMinor,SUM(Quantity) FROM @lines GROUP BY DenominationMinor)
       THROW 51542,'CashCountId reutilizado con otro turno.',1;
     COMMIT; RETURN;
   END;
   IF NOT EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId AND Status='open')
     THROW 51543,'Turno de caja inexistente o cerrado.',1;
   INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy)
     VALUES(@CashCountId,@TillId,@ActorId,'draft',@ActorId);
   INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity)
     SELECT @CashCountId,DenominationMinor,SUM(Quantity) FROM @lines GROUP BY DenominationMinor;
   EXEC sales.usp_SubmitCashCount @CashCountId=@CashCountId,@ActorId=@ActorId;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE sales.usp_RecordCashCount
 @CashCountId uniqueidentifier,@TillId uniqueidentifier,@ActorId uniqueidentifier,@LinesJson nvarchar(max),
 @UsdCashCountId uniqueidentifier=NULL,@UsdLinesJson nvarchar(max)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRAN;
 BEGIN TRY
 DECLARE @parent uniqueidentifier,@child uniqueidentifier;
 SELECT @parent=Id FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TillId AND ParentTillId IS NULL AND CurrencyCode='NIO';
 IF @parent IS NULL THROW 52106,'Use el turno padre.',1;
 SELECT @child=Id FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE ParentTillId=@TillId;
 EXEC sales.usp_RecordDrawerCount @CashCountId,@TillId,@ActorId,@LinesJson;
 IF @UsdCashCountId IS NOT NULL OR @UsdLinesJson IS NOT NULL
 BEGIN
  IF @child IS NULL OR @UsdCashCountId IS NULL OR @UsdLinesJson IS NULL THROW 52106,'Arqueo USD incompleto.',1;
  EXEC sales.usp_RecordDrawerCount @UsdCashCountId,@child,@ActorId,@UsdLinesJson;
 END;
 COMMIT;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE sales.usp_OpenTillCounted
 @TillId uniqueidentifier,@RegisterId uniqueidentifier,@CashierId uniqueidentifier,
 @CurrencyCode varchar(3),@OpeningMinor bigint,@OriginNodeId uniqueidentifier,@LinesJson nvarchar(max),@UsdLinesJson nvarchar(max)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 SET @UsdLinesJson=COALESCE(@UsdLinesJson,N'[{"denominationMinor":100,"quantity":0}]');
 IF ISJSON(@LinesJson)<>1 OR @LinesJson IS NULL THROW 51545,'Cuente el efectivo inicial por denominacion.',1;
 DECLARE @lines TABLE(DenominationMinor bigint,Quantity int);
 INSERT INTO @lines SELECT denominationMinor,quantity FROM OPENJSON(@LinesJson)
 WITH(denominationMinor bigint,quantity int);
 IF NOT EXISTS(SELECT 1 FROM @lines) OR EXISTS(SELECT 1 FROM @lines l WHERE Quantity IS NULL OR Quantity NOT BETWEEN 0 AND 1000000 OR
 NOT EXISTS(SELECT 1 FROM sales.CashDenominations d WHERE d.DenominationMinor=l.DenominationMinor AND d.CurrencyCode='NIO')) OR
 EXISTS(SELECT DenominationMinor FROM @lines GROUP BY DenominationMinor HAVING COUNT(*)>1) OR
 @OpeningMinor<>(SELECT SUM(DenominationMinor*CONVERT(bigint,Quantity)) FROM @lines) OR @CurrencyCode<>'NIO'
 THROW 51545,'El fondo inicial debe coincidir con el desglose de billetes y monedas.',1;
 BEGIN TRAN;
 BEGIN TRY
  IF EXISTS(SELECT 1 FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TillId)
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId AND ParentTillId IS NULL AND RegisterId=@RegisterId AND CashierId=@CashierId AND CurrencyCode=@CurrencyCode)
    OR EXISTS(SELECT DenominationMinor,Quantity FROM @lines EXCEPT SELECT l.DenominationMinor,l.Quantity FROM sales.CashCounts c JOIN sales.CashCountLines l ON l.CashCountId=c.Id WHERE c.TillId=@TillId AND c.CountKind='opening')
    OR EXISTS(SELECT l.DenominationMinor,l.Quantity FROM sales.CashCounts c JOIN sales.CashCountLines l ON l.CashCountId=c.Id WHERE c.TillId=@TillId AND c.CountKind='opening' EXCEPT SELECT DenominationMinor,Quantity FROM @lines)
    THROW 51502,'TillId reutilizado con otro desglose.',1;
   DECLARE @existingChild uniqueidentifier=(SELECT Id FROM sales.CashTills WHERE ParentTillId=@TillId);
   IF @UsdLinesJson IS NOT NULL
   BEGIN
    IF @existingChild IS NULL THROW 51502,'Apertura distinta.',1;
    EXEC sales.usp_RecordDrawerCount @existingChild,@existingChild,@CashierId,@UsdLinesJson;
   END;
   COMMIT; RETURN;
  END;
  EXEC sales.usp_OpenTill @TillId,@RegisterId,@CashierId,@CurrencyCode,@OpeningMinor,@OriginNodeId;
  EXEC sales.usp_RecordCashCount @TillId,@TillId,@CashierId,@LinesJson;
  UPDATE sales.CashCounts SET CountKind='opening' WHERE Id=@TillId;
  -- New counted openings always create a USD drawer; omitted dollars mean zero.
  DECLARE @child uniqueidentifier=NEWID(),@usd bigint;
  SET @UsdLinesJson=COALESCE(@UsdLinesJson,N'[{"denominationMinor":100,"quantity":0}]');
  SELECT @usd=SUM(CONVERT(bigint,denominationMinor)*quantity) FROM OPENJSON(@UsdLinesJson) WITH(denominationMinor bigint,quantity int);
  INSERT sales.CashTills(Id,RegisterId,CashierId,CurrencyCode,ParentTillId,CreatedBy)
    VALUES(@child,@RegisterId,@CashierId,'USD',@TillId,@CashierId);
  INSERT sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,ActorId,CreatedBy)
    VALUES(NEWID(),@child,'USD','opening',@usd,@CashierId,@CashierId);
  EXEC sales.usp_RecordDrawerCount @child,@child,@CashierId,@UsdLinesJson;
  UPDATE sales.CashCounts SET CountKind='opening' WHERE Id=@child;
  COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [sales].[usp_CloseDrawer]
 @ClosureId uniqueidentifier,@TillId uniqueidentifier,@CashCountId uniqueidentifier,
 @ActorId uniqueidentifier,@OriginNodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
   -- BUG-002: lock the till BEFORE looking for a closure. Two simultaneous retries are then serialized
   -- and the second one finds the committed closure instead of failing with 51522.
   DECLARE @status varchar(16),@currency varchar(3),@opened datetime2(3);
   SELECT @status=Status,@currency=CurrencyCode,@opened=OpenedAt FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TillId;
   IF EXISTS(SELECT 1 FROM sales.CashClosures WHERE TillId=@TillId)
   BEGIN
     IF NOT EXISTS(SELECT 1 FROM sales.CashClosures WHERE Id=@ClosureId AND TillId=@TillId AND CashCountId=@CashCountId)
       THROW 51521,'Turno ya cerrado con otro comprobante.',1;
     COMMIT; RETURN;
   END;
   IF @status IS NULL OR @status<>'open' THROW 51522,'Turno no abierto.',1;
   -- D-B-04: the closer needs active access to the branch of the till.
   IF NOT EXISTS(SELECT 1 FROM sales.CashTills t JOIN sales.CashRegisters r ON r.Id=t.RegisterId
      JOIN security.StaffBranchAccess a ON a.BranchId=r.BranchId AND a.IsActive=1
      JOIN security.Staff s ON s.Id=a.StaffId AND s.IsEnabled=1
      WHERE t.Id=@TillId AND a.StaffId=@ActorId)
     THROW 51537,'Actor sin acceso a la sucursal del turno.',1;
   IF NOT EXISTS(SELECT 1 FROM sales.CashCounts WITH(UPDLOCK,HOLDLOCK)
       WHERE Id=@CashCountId AND TillId=@TillId AND Status='submitted' AND CountKind='closing')
       THROW 51523,'Arqueo no presentado o no corresponde al turno.',1;
   DECLARE @expected bigint=(SELECT COALESCE(SUM(DeltaMinor),0) FROM sales.CashEntries WHERE TillId=@TillId);
   DECLARE @counted bigint=(SELECT COALESCE(SUM(CONVERT(bigint,DenominationMinor)*Quantity),0)
      FROM sales.CashCountLines WHERE CashCountId=@CashCountId);
   IF @expected<0 OR @counted<0 THROW 51524,'Arqueo negativo o caja sin fondos.',1;
   INSERT INTO sales.CashClosures(Id,TillId,CashCountId,ExpectedMinor,CountedMinor,
     DifferenceMinor,ClosedBy,CreatedBy)
      VALUES(@ClosureId,@TillId,@CashCountId,@expected,@counted,@counted-@expected,@ActorId,@ActorId);
   UPDATE sales.CashTills SET Status='closed',ClosedAt=core.ufn_BusinessNow(),ModifiedBy=@ActorId,
     ModifiedAt=core.ufn_BusinessNow() WHERE Id=@TillId;
   DECLARE @doc uniqueidentifier=NEWID(),@gross bigint=0,@tax bigint=0,@discount bigint=0,
      @sales int=0,@returns bigint=0,@card bigint=0,@credit bigint=0,
      @saleCOGS bigint=0,@returnCOGS bigint=0;
   SELECT @gross=COALESCE(SUM(s.TotalMinor),0),@tax=COALESCE(SUM(s.TaxMinor),0),
        @discount=COALESCE(SUM(s.DiscountMinor),0),@sales=COUNT(*)
      FROM sales.Sales s WHERE s.TillId=@TillId;
   SELECT @returns=COALESCE(SUM(CreditMinor),0) FROM sales.SaleReversals
      WHERE TillId=@TillId AND Status='approved';
   SELECT @saleCOGS=COALESCE(SUM(l.COGSMinor),0) FROM sales.SaleLines l
     JOIN sales.Sales s ON s.Id=l.SaleId WHERE s.TillId=@TillId;
   SELECT @returnCOGS=COALESCE(SUM(l.COGSReversedMinor),0) FROM sales.SaleReversalLines l
     JOIN sales.SaleReversals r ON r.Id=l.ReversalId
     WHERE r.TillId=@TillId AND r.Status='approved';
   SELECT @card=COALESCE(SUM(st.AmountMinor),0) FROM sales.SaleTenders st
     JOIN sales.Sales s ON s.Id=st.SaleId
     WHERE s.TillId=@TillId AND st.TenderKind='card' AND st.Status='captured';
   SELECT @credit=COALESCE(SUM(st.AmountMinor),0) FROM sales.SaleTenders st
     JOIN sales.Sales s ON s.Id=st.SaleId
     WHERE s.TillId=@TillId AND st.TenderKind='credit' AND st.Status='captured';
   INSERT INTO accounting.CloseDocuments(Id,ClosureId,DocumentNumber,DocumentKind,Status,
      CurrencyCode,CashExpectedMinor,CashCountedMinor,CashDifferenceMinor,SaleGrossMinor,
      SaleTaxMinor,SaleDiscountMinor,SaleCount,ReturnGrossMinor,NetSalesMinor,
      SaleCOGSMinor,ReturnedCOGSMinor,NetCOGSMinor,CardCapturedMinor,CreditRedeemedMinor,
      PeriodStartAt,PeriodEndAt,CreatedBy)
     VALUES(@doc,@ClosureId,CONCAT(N'CIERRE-',CONVERT(nvarchar(36),@ClosureId)),
       'accounting_summary','prepared',@currency,@expected,@counted,@counted-@expected,
       @gross,@tax,@discount,@sales,@returns,@gross-@returns,
       @saleCOGS,@returnCOGS,@saleCOGS-@returnCOGS,@card,@credit,
       @opened,core.ufn_BusinessNow(),@ActorId);
   INSERT INTO accounting.CloseDocumentLines(CloseDocumentId,[LineNo],ConceptCode,ConceptName,AmountMinor)
      SELECT v.* FROM (VALUES(@doc,1,'EXPECTED_CASH',N'Efectivo esperado',@expected),
            (@doc,2,'COUNTED_CASH',N'Efectivo contado',@counted),
            (@doc,3,'CASH_DIFFERENCE',N'Diferencia de caja',@counted-@expected),
            (@doc,4,'SALE_GROSS',N'Ventas del turno (todos los medios)',@gross),
            (@doc,5,'RETURN_GROSS',N'Devoluciones del turno',-@returns),
            (@doc,6,'NET_SALES',N'Venta neta del turno',@gross-@returns),
            (@doc,7,'CARD_TENDERS',N'Pagos con tarjeta registrados',@card),
            (@doc,8,'CREDIT_REDEMPTIONS',N'Anticipos canjeados',@credit),
            (@doc,9,'COGS_GROSS',N'Costo de venta del turno (costo snapshot)',@saleCOGS),
            (@doc,10,'COGS_RETURNED',N'Costo revertido por devoluciones',-@returnCOGS),
            (@doc,11,'COGS_NET',N'Costo de venta neto',@saleCOGS-@returnCOGS)) v(doc,line,code,name,amount) WHERE @currency='NIO' OR v.line<=3;
   INSERT INTO accounting.CloseDocumentLines(CloseDocumentId,[LineNo],ConceptCode,ConceptName,AmountMinor)
     SELECT @doc,11+ROW_NUMBER() OVER(ORDER BY SettlementKind),CONCAT('REFUND_',UPPER(SettlementKind)),
       CONCAT(N'Devoluciones: ',CASE SettlementKind WHEN 'credit' THEN N'anticipo' WHEN 'cash' THEN N'efectivo' WHEN 'transfer' THEN N'transferencia' WHEN 'exchange' THEN N'cambio' ELSE SettlementKind END),
       -SUM(CreditMinor)
     FROM sales.SaleReversals WHERE TillId=@TillId AND Status='approved' GROUP BY SettlementKind;
   IF @currency='NIO'
     INSERT accounting.CloseDocumentLines(CloseDocumentId,[LineNo],ConceptCode,ConceptName,AmountMinor)
      SELECT @doc,100,'CASH_ROUNDING',N'Redondeo de efectivo',COALESCE(SUM(t.RoundingMinor),0)
      FROM sales.SaleTenders t JOIN sales.Sales s ON s.Id=t.SaleId WHERE s.TillId=@TillId;
   -- Se crea salida contable automatica; no se inventa una factura fiscal.
   INSERT INTO accounting.ExportJobs(Id,CloseDocumentId,RecipientCode,Format,Status,CreatedBy)
     VALUES(NEWID(),@doc,N'ACCOUNTANT','PDF','pending',@ActorId);
   DECLARE @evt uniqueidentifier=NEWID(),@payload nvarchar(max)=(
     SELECT @ClosureId AS closureId,@TillId AS tillId,@CashCountId AS cashCountId,
        @doc AS accountingDocumentId,@expected AS expectedMinor,@counted AS countedMinor,
        @currency AS currency FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @evt,@OriginNodeId,'cash_closure',@ClosureId,'cash.till_closed',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE sales.usp_CloseTill
 @ClosureId uniqueidentifier,@TillId uniqueidentifier,@CashCountId uniqueidentifier,@ActorId uniqueidentifier,@OriginNodeId uniqueidentifier,
 @UsdCashCountId uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRAN;
 BEGIN TRY
 DECLARE @parent uniqueidentifier,@child uniqueidentifier,@childClosure uniqueidentifier;
 SELECT @parent=Id FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TillId AND ParentTillId IS NULL AND CurrencyCode='NIO';
 IF @parent IS NULL
 BEGIN
  IF EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId AND (ParentTillId IS NOT NULL OR CurrencyCode<>'NIO')) THROW 52106,'Use el turno padre.',1;
  THROW 51522,'Turno no abierto.',1;
 END;
 SELECT @child=Id FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE ParentTillId=@TillId;
 IF @child IS NOT NULL AND (@UsdCashCountId IS NULL OR NOT EXISTS(SELECT 1 FROM sales.CashCounts WHERE Id=@UsdCashCountId AND TillId=@child AND CountKind='closing' AND Status='submitted'))
 THROW 51523,'Falta el arqueo USD.',1;
 SELECT @childClosure=Id FROM sales.CashClosures WHERE TillId=@child;
 SET @childClosure=COALESCE(@childClosure,NEWID());
 EXEC sales.usp_CloseDrawer @ClosureId,@TillId,@CashCountId,@ActorId,@OriginNodeId;
 IF @child IS NOT NULL EXEC sales.usp_CloseDrawer @childClosure,@child,@UsdCashCountId,@ActorId,@OriginNodeId;
 COMMIT;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [sales].[usp_RecordCashEntry]
 @EntryId uniqueidentifier,@TillId uniqueidentifier,@ActorId uniqueidentifier,
 @Kind varchar(16),@DeltaMinor bigint,@Reason nvarchar(400),@OriginNodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId AND (ParentTillId IS NOT NULL OR CurrencyCode<>'NIO')) THROW 52106,'Use el turno padre NIO.',1;
 IF @Kind NOT IN ('payout','deposit','adjustment') OR LEN(LTRIM(RTRIM(@Reason)))=0
   THROW 51505,'Solo operaciones manuales justificadas.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
  DECLARE @lockedTill uniqueidentifier;
  SELECT @lockedTill=Id FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TillId;
  SELECT @lockedTill=Id FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE ParentTillId=@TillId;
   IF EXISTS(SELECT 1 FROM sales.CashEntries WHERE Id=@EntryId)
   BEGIN
     -- D-B-05: only an identical retry returns success.
     IF NOT EXISTS(SELECT 1 FROM sales.CashEntries WHERE Id=@EntryId AND TillId=@TillId AND Kind=@Kind
        AND DeltaMinor=@DeltaMinor AND ActorId=@ActorId AND Reason=@Reason)
       THROW 51536,'EntryId reutilizado con otro contenido.',1;
     COMMIT; RETURN;
   END;
   DECLARE @currency varchar(3),@status varchar(16);
   SELECT @currency=CurrencyCode,@status=Status FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TillId;
   IF @status IS NULL OR @status<>'open' THROW 51506,'Turno de caja cerrado.',1;
   -- D-B-02: the actor needs active access to the branch of the till.
   IF NOT EXISTS(SELECT 1 FROM sales.CashTills t JOIN sales.CashRegisters r ON r.Id=t.RegisterId
      JOIN security.StaffBranchAccess a ON a.BranchId=r.BranchId AND a.IsActive=1
      JOIN security.Staff s ON s.Id=a.StaffId AND s.IsEnabled=1
      WHERE t.Id=@TillId AND a.StaffId=@ActorId)
     THROW 51537,'Actor sin acceso a la sucursal del turno.',1;
   INSERT INTO sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,ActorId,Reason,CreatedBy)
     VALUES(@EntryId,@TillId,@currency,@Kind,@DeltaMinor,@ActorId,@Reason,@ActorId);
   DECLARE @evt uniqueidentifier=NEWID(),@payload nvarchar(max)=(SELECT @EntryId AS cashEntryId,
      @TillId AS tillId,@Kind AS kind,@DeltaMinor AS amountMinor,@currency AS currency
      FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @evt,@OriginNodeId,'cash_entry',@EntryId,'cash.manual_entry',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

-- 3. Cash refund, bank transfer refund and exchange. Same line rules as the credit return.
CREATE OR ALTER PROCEDURE sales.usp_PostReturnOutcome
 @ReversalId uniqueidentifier,@SaleId uniqueidentifier,@BranchId uniqueidentifier,@LocationId uniqueidentifier,@TillId uniqueidentifier,
 @ActorId uniqueidentifier,@Outcome varchar(16),@Reason nvarchar(500),@Reference nvarchar(120)=NULL,@OriginNodeId uniqueidentifier,
 @Lines sales.ReturnLineRequest READONLY,
 @ExchangeSaleId uniqueidentifier=NULL,@NewLines sales.SaleLineRequest READONLY,@NewTenders sales.SaleTenderRequest READONLY,
 @SellersJson nvarchar(max)=NULL,@DifferenceKind varchar(16)=NULL,@DifferenceReference nvarchar(120)=NULL,@FxJson nvarchar(max)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId AND (ParentTillId IS NOT NULL OR CurrencyCode<>'NIO')) THROW 52106,'Use el turno padre NIO.',1;
 IF @FxJson IS NOT NULL THROW 52102,'Cambio no admite dolares.',1;
 IF @Outcome IS NULL OR @Outcome NOT IN ('cash','transfer','exchange') THROW 52020,'Elija cambio, efectivo o transferencia.',1;
 IF NOT EXISTS(SELECT 1 FROM @Lines) OR NULLIF(LTRIM(RTRIM(@Reason)),N'') IS NULL THROW 51525,'Devolucion sin prendas o motivo.',1;
 IF @Outcome='transfer' AND NULLIF(LTRIM(RTRIM(@Reference)),N'') IS NULL THROW 52021,'Indique la referencia de la transferencia.',1;
 IF @Outcome='exchange' AND (@ExchangeSaleId IS NULL OR NOT EXISTS(SELECT 1 FROM @NewLines)) THROW 52022,'Indique las prendas del cambio.',1;
 IF @Outcome<>'exchange' AND (@ExchangeSaleId IS NOT NULL OR EXISTS(SELECT 1 FROM @NewLines) OR EXISTS(SELECT 1 FROM @NewTenders) OR @DifferenceKind IS NOT NULL)
  THROW 52022,'Solo un cambio lleva prendas nuevas.',1;
 IF @DifferenceKind IS NOT NULL AND @DifferenceKind NOT IN ('cash','transfer') THROW 52020,'La diferencia se devuelve en efectivo o transferencia.',1;
 IF @DifferenceKind='transfer' AND NULLIF(LTRIM(RTRIM(@DifferenceReference)),N'') IS NULL THROW 52021,'Indique la referencia de la transferencia.',1;
 IF EXISTS(SELECT 1 FROM @Lines WHERE Quantity<=0 OR RestockPool NOT IN ('store','quarantine')) THROW 51531,'Cantidad o condicion no valida.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
  DECLARE @lockedTill uniqueidentifier;
  SELECT @lockedTill=Id FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TillId;
  SELECT @lockedTill=Id FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE ParentTillId=@TillId;
  IF EXISTS(SELECT 1 FROM sales.SaleReversals WITH(UPDLOCK,HOLDLOCK) WHERE Id=@ReversalId)
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM sales.SaleReversals WHERE Id=@ReversalId AND SaleId=@SaleId AND SettlementKind=@Outcome)
    OR EXISTS(SELECT SaleLineId,Quantity FROM @Lines EXCEPT SELECT SaleLineId,Quantity FROM sales.SaleReversalLines WHERE ReversalId=@ReversalId)
    OR EXISTS(SELECT SaleLineId,Quantity FROM sales.SaleReversalLines WHERE ReversalId=@ReversalId EXCEPT SELECT SaleLineId,Quantity FROM @Lines)
    THROW 51538,'ReversalId reutilizado con otro contenido.',1;
   COMMIT; RETURN;
  END;
  IF NOT EXISTS(SELECT 1 FROM core.Locations WHERE Id=@LocationId AND BranchId=@BranchId) THROW 51527,'Ubicacion de devolucion no pertenece a sucursal.',1;
  IF NOT EXISTS(SELECT 1 FROM sales.CashTills t JOIN sales.CashRegisters r ON r.Id=t.RegisterId
   WHERE t.Id=@TillId AND t.Status='open' AND r.BranchId=@BranchId AND r.LocationId=@LocationId) THROW 51528,'Turno de devolucion no abierto.',1;
  IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId WHERE a.StaffId=@ActorId AND s.IsEnabled=1
   AND a.BranchId=@BranchId AND a.CanApproveReturns=1 AND a.IsActive=1) THROW 51529,'Supervisor sin permiso para devoluciones.',1;
  DECLARE @currency varchar(3),@saleStatus varchar(24),@saleBranch uniqueidentifier,@saleCreated datetime2(3);
  SELECT @currency=CurrencyCode,@saleStatus=Status,@saleBranch=BranchId,@saleCreated=CreatedAt FROM sales.Sales WITH(UPDLOCK,HOLDLOCK) WHERE Id=@SaleId;
  IF @saleBranch IS NOT NULL AND @saleBranch<>@BranchId THROW 51535,'La venta pertenece a otra sucursal.',1;
  IF @saleStatus IS NULL OR @saleStatus IN ('cancelled','returned') THROW 51530,'Venta original no valida para devolucion.',1;
  IF @saleCreated<DATEADD(day,-sales.ufn_ReturnWindowDays(@BranchId),core.ufn_BusinessNow()) THROW 52023,'La venta supera el plazo de devolucion.',1;
  INSERT INTO sales.SaleReversals(Id,SaleId,BranchId,LocationId,TillId,ActorId,Kind,SettlementKind,Reason,CreditMinor,CurrencyCode,Status,ApprovedBy,CreatedBy)
   VALUES(@ReversalId,@SaleId,@BranchId,@LocationId,@TillId,@ActorId,'return',@Outcome,@Reason,0,@currency,'approved',@ActorId,@ActorId);
  DECLARE @line uniqueidentifier,@qty int,@pool varchar(12),@item uniqueidentifier,@oldReturned int,@originalQty int,@lineTotal bigint,
   @unitCost bigint,@priorCredit bigint,@part bigint,@total bigint=0,@op uniqueidentifier,@mv uniqueidentifier;
  DECLARE outcomeCursor CURSOR LOCAL FAST_FORWARD FOR SELECT SaleLineId,Quantity,RestockPool FROM @Lines ORDER BY SaleLineId;
  OPEN outcomeCursor; FETCH NEXT FROM outcomeCursor INTO @line,@qty,@pool;
  WHILE @@FETCH_STATUS=0
  BEGIN
   SET @item=NULL; SET @priorCredit=0;
   SELECT @item=ItemId,@oldReturned=ReturnedQuantity,@originalQty=Quantity,@lineTotal=TotalMinor,@unitCost=CostUnitSnapshotMinor
    FROM sales.SaleLines WITH(UPDLOCK,HOLDLOCK) WHERE Id=@line AND SaleId=@SaleId;
   IF @item IS NULL OR @oldReturned+@qty>@originalQty THROW 51532,'Intento de devolver unidades ya devueltas.',1;
   SELECT @priorCredit=COALESCE(SUM(rl.CreditMinor),0) FROM sales.SaleReversalLines rl JOIN sales.SaleReversals r ON r.Id=rl.ReversalId
    WHERE rl.SaleLineId=@line AND r.Status='approved';
   SET @part=CASE WHEN @oldReturned+@qty=@originalQty THEN @lineTotal-@priorCredit
    ELSE CONVERT(bigint,ROUND(CONVERT(decimal(28,4),@lineTotal)*@qty/@originalQty,0)) END;
   IF @part<0 OR @priorCredit+@part>@lineTotal THROW 51533,'Reembolso supera importe original.',1;
   UPDATE sales.SaleLines SET ReturnedQuantity=ReturnedQuantity+@qty,ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@line;
   INSERT INTO sales.SaleReversalLines(ReversalId,SaleLineId,Quantity,CreditMinor,COGSReversedMinor,RestockPool,CreatedBy)
    VALUES(@ReversalId,@line,@qty,@part,CASE WHEN @unitCost IS NULL THEN NULL ELSE @unitCost*CONVERT(bigint,@qty) END,@pool,@ActorId);
   SET @op=NEWID(); SET @mv=NULL;
   EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@LocationId,@Pool=@pool,@Kind='return',@OnHandDelta=@qty,
    @SourceType='sale_reversal',@SourceId=@ReversalId,@ActorId=@ActorId,@MovementId=@mv OUTPUT;
   SET @total+=@part;
   FETCH NEXT FROM outcomeCursor INTO @line,@qty,@pool;
  END;
  CLOSE outcomeCursor; DEALLOCATE outcomeCursor;
  IF @total<=0 THROW 51534,'La devolucion debe tener valor mayor a cero.',1;
  UPDATE sales.SaleReversals SET CreditMinor=@total WHERE Id=@ReversalId;
  UPDATE sales.Sales SET Status=CASE WHEN NOT EXISTS(SELECT 1 FROM sales.SaleLines WHERE SaleId=@SaleId AND ReturnedQuantity<Quantity)
   THEN 'returned' ELSE 'partially_returned' END,ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@SaleId;
  DECLARE @cashOut bigint=0,@transferOut bigint=0,@transferRef nvarchar(120)=NULL,@applied bigint=0;
  IF @Outcome='cash' SET @cashOut=@total;
  IF @Outcome='transfer' BEGIN SET @transferOut=@total; SET @transferRef=@Reference; END;
  IF @Outcome='exchange'
  BEGIN
   DECLARE @newTotal bigint=(SELECT SUM(CAST(l.UnitPriceMinor AS bigint)*l.Quantity-l.DiscountMinor+
    CAST(ROUND((CAST(l.UnitPriceMinor AS decimal(28,0))*l.Quantity-l.DiscountMinor)*i.TaxRateBps/10000.0,0) AS bigint))
    FROM @NewLines l JOIN catalog.Items i ON i.Id=l.ItemId);
   IF @newTotal IS NULL OR (SELECT COUNT(*) FROM @NewLines)<>(SELECT COUNT(*) FROM @NewLines l JOIN catalog.Items i ON i.Id=l.ItemId)
    THROW 51513,'Producto, moneda o precio desactualizado.',1;
   SET @applied=CASE WHEN @newTotal<@total THEN @newTotal ELSE @total END;
   DECLARE @extra bigint=(SELECT COALESCE(SUM(AmountMinor),0) FROM @NewTenders);
   IF @extra<>CASE WHEN @newTotal>@total THEN @newTotal-@total ELSE 0 END THROW 51517,'Pagos de la diferencia no coinciden.',1;
   IF @newTotal<@total
   BEGIN
    IF @DifferenceKind IS NULL THROW 52025,'Indique como se devuelve la diferencia.',1;
    IF @DifferenceKind='cash' SET @cashOut=@total-@newTotal;
    ELSE BEGIN SET @transferOut=@total-@newTotal; SET @transferRef=@DifferenceReference; END;
   END;
   DECLARE @tenders sales.SaleTenderRequest;
   IF @applied>0 INSERT @tenders(TenderNumber,TenderKind,AmountMinor,CreditId,ReceivedMinor,ChangeMinor,Reference)
    VALUES(1,'other',@applied,NULL,NULL,NULL,CONCAT(N'CAMBIO ',CONVERT(nvarchar(36),@ReversalId)));
   INSERT @tenders(TenderNumber,TenderKind,AmountMinor,CreditId,ReceivedMinor,ChangeMinor,Reference)
    SELECT 1+ROW_NUMBER() OVER(ORDER BY TenderNumber),TenderKind,AmountMinor,CreditId,ReceivedMinor,ChangeMinor,Reference FROM @NewTenders;
   DECLARE @tillCashier uniqueidentifier=(SELECT CashierId FROM sales.CashTills WHERE Id=@TillId);
   EXEC sales.usp_PostSale @SaleId=@ExchangeSaleId,@BranchId=@BranchId,@LocationId=@LocationId,@CashierId=@tillCashier,@CurrencyCode=@currency,
    @OriginNodeId=@OriginNodeId,@Lines=@NewLines,@Tenders=@tenders,@TillId=@TillId,@SellersJson=@SellersJson;
   IF @applied>0 INSERT sales.ReturnSettlements(ReversalId,Kind,AmountMinor,ExchangeSaleId,CreatedAt) VALUES(@ReversalId,'exchange',@applied,@ExchangeSaleId,core.ufn_BusinessNow());
  END;
  IF @cashOut>0
  BEGIN
   DECLARE @cashAvailable bigint;
   SELECT @cashAvailable=COALESCE(SUM(e.DeltaMinor),0) FROM sales.CashTills t WITH(UPDLOCK,HOLDLOCK) LEFT JOIN sales.CashEntries e ON e.TillId=t.Id WHERE t.Id=@TillId;
   IF @cashAvailable<@cashOut THROW 52024,'La caja no tiene efectivo suficiente para el reembolso.',1;
   INSERT INTO sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,ReversalId,ActorId,Reason,CreatedBy)
    VALUES(NEWID(),@TillId,@currency,'refund',-@cashOut,@ReversalId,@ActorId,@Reason,@ActorId);
   INSERT sales.ReturnSettlements(ReversalId,Kind,AmountMinor,CreatedAt) VALUES(@ReversalId,'cash',@cashOut,core.ufn_BusinessNow());
  END;
  IF @transferOut>0 INSERT sales.ReturnSettlements(ReversalId,Kind,AmountMinor,Reference,CreatedAt) VALUES(@ReversalId,'transfer',@transferOut,@transferRef,core.ufn_BusinessNow());
  DECLARE @evt uniqueidentifier=NEWID(),@payload nvarchar(max)=(SELECT @ReversalId AS returnId,@SaleId AS saleId,@BranchId AS branchId,@Outcome AS outcome,
   @total AS valueMinor,@ExchangeSaleId AS exchangeSaleId,
   JSON_QUERY((SELECT Kind AS kind,AmountMinor AS amountMinor,Reference AS reference FROM sales.ReturnSettlements WHERE ReversalId=@ReversalId FOR JSON PATH)) AS settlements,
   JSON_QUERY((SELECT SaleLineId,Quantity,CreditMinor,RestockPool FROM sales.SaleReversalLines WHERE ReversalId=@ReversalId FOR JSON PATH)) AS lines
   FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  EXEC sync.usp_EnqueueEvent @evt,@OriginNodeId,'sale_return',@ReversalId,'sales.return_posted',@payload;
  COMMIT;
 END TRY
 BEGIN CATCH
  IF CURSOR_STATUS('local','outcomeCursor')>=0 BEGIN CLOSE outcomeCursor; DEALLOCATE outcomeCursor; END;
  IF @@TRANCOUNT>0 ROLLBACK; THROW;
 END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [sales].[usp_PostCreditReturn]
 @ReversalId uniqueidentifier,@CreditId uniqueidentifier,@SaleId uniqueidentifier,
 @BranchId uniqueidentifier,@ReturnLocationId uniqueidentifier,@TillId uniqueidentifier,
 @ActorId uniqueidentifier,@ApprovedBy uniqueidentifier,@CustomerId uniqueidentifier,
 @Reason nvarchar(500),@OriginNodeId uniqueidentifier,
 @Lines [sales].[ReturnLineRequest] READONLY
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId AND (ParentTillId IS NOT NULL OR CurrencyCode<>'NIO')) THROW 52106,'Use el turno padre NIO.',1;
 IF NOT EXISTS(SELECT 1 FROM @Lines) OR LEN(LTRIM(RTRIM(@Reason)))=0
    THROW 51525,'Devolucion sin prendas o motivo.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
  DECLARE @lockedTill uniqueidentifier;
  SELECT @lockedTill=Id FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TillId;
  SELECT @lockedTill=Id FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE ParentTillId=@TillId;
  IF EXISTS(SELECT 1 FROM sales.SaleReversals WHERE Id=@ReversalId)
  BEGIN
    IF NOT EXISTS(SELECT 1 FROM credits.Credits WHERE Id=@CreditId AND SourceReversalId=@ReversalId)
      THROW 51526,'Devolucion ya existe sin ese anticipo.',1;
    -- D-B-03: only an identical retry returns success.
    IF NOT EXISTS(SELECT 1 FROM sales.SaleReversals WHERE Id=@ReversalId AND SaleId=@SaleId)
       OR EXISTS(SELECT SaleLineId,Quantity FROM @Lines
                 EXCEPT SELECT SaleLineId,Quantity FROM sales.SaleReversalLines WHERE ReversalId=@ReversalId)
       OR EXISTS(SELECT SaleLineId,Quantity FROM sales.SaleReversalLines WHERE ReversalId=@ReversalId
                 EXCEPT SELECT SaleLineId,Quantity FROM @Lines)
      THROW 51538,'ReversalId reutilizado con otro contenido.',1;
    COMMIT; RETURN;
  END;
  IF NOT EXISTS(SELECT 1 FROM core.Locations WHERE Id=@ReturnLocationId AND BranchId=@BranchId)
    THROW 51527,'Ubicacion de devolucion no pertenece a sucursal.',1;
  IF NOT EXISTS(SELECT 1 FROM sales.CashTills t JOIN sales.CashRegisters r ON r.Id=t.RegisterId
     WHERE t.Id=@TillId AND t.Status='open' AND r.BranchId=@BranchId AND r.LocationId=@ReturnLocationId)
    THROW 51528,'Turno de devolucion no abierto.',1;
  IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a WHERE a.StaffId=@ApprovedBy
      AND a.BranchId=@BranchId AND a.CanApproveReturns=1 AND a.IsActive=1)
    THROW 51529,'Supervisor sin permiso para devoluciones.',1;
  DECLARE @currency varchar(3),@saleCustomer uniqueidentifier,@saleStatus varchar(24),@saleBranch uniqueidentifier;
  SELECT @currency=CurrencyCode,@saleCustomer=CustomerId,@saleStatus=Status,@saleBranch=BranchId
     FROM sales.Sales WITH(UPDLOCK,HOLDLOCK) WHERE Id=@SaleId;
  -- A branch only changes its own rows (ADR-001 D5, D7). A return of another branch's sale is
  -- rejected until the business defines cross-branch returns as rows owned by the returning branch.
  IF @saleBranch IS NOT NULL AND @saleBranch<>@BranchId
    THROW 51535,'La venta pertenece a otra sucursal.',1;
  IF EXISTS(SELECT 1 FROM sales.Sales WHERE Id=@SaleId AND CreatedAt<DATEADD(day,-sales.ufn_ReturnWindowDays(@BranchId),core.ufn_BusinessNow())) THROW 52023,'La venta supera el plazo de devolucion.',1;
  IF @saleStatus IS NULL OR @saleStatus IN ('cancelled','returned') OR
       (@saleCustomer IS NOT NULL AND @saleCustomer<>@CustomerId) OR @CustomerId IS NULL OR NOT EXISTS(SELECT 1 FROM crm.Customers WHERE Id=@CustomerId AND IsActive=1)
    THROW 51530,'Venta original o cliente no verificado.',1;
  IF EXISTS(SELECT 1 FROM @Lines WHERE Quantity<=0 OR RestockPool NOT IN ('store','quarantine'))
    THROW 51531,'Cantidad o condicion no valida.',1;
  DECLARE @line uniqueidentifier,@qty int,@pool varchar(12),@item uniqueidentifier,
    @oldReturned int,@originalQty int,@lineTotal bigint,@unitCost bigint,@priorCredit bigint,@part bigint,
    @total bigint=0,@op uniqueidentifier,@mv uniqueidentifier;
  -- Validacion y registro del documento antes de la emision del credito.
  INSERT INTO sales.SaleReversals(Id,SaleId,BranchId,LocationId,TillId,ActorId,Kind,
    SettlementKind,Reason,CreditMinor,CurrencyCode,Status,ApprovedBy,CreatedBy)
    VALUES(@ReversalId,@SaleId,@BranchId,@ReturnLocationId,@TillId,@ActorId,'return',
      'credit',@Reason,0,@currency,'approved',@ApprovedBy,@ActorId);
  DECLARE returnCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT SaleLineId,Quantity,RestockPool FROM @Lines ORDER BY SaleLineId;
  OPEN returnCursor; FETCH NEXT FROM returnCursor INTO @line,@qty,@pool;
  WHILE @@FETCH_STATUS=0
  BEGIN
     SET @item=NULL; SET @priorCredit=0;
     SELECT @item=ItemId,@oldReturned=ReturnedQuantity,@originalQty=Quantity,@lineTotal=TotalMinor,@unitCost=CostUnitSnapshotMinor
        FROM sales.SaleLines WITH(UPDLOCK,HOLDLOCK) WHERE Id=@line AND SaleId=@SaleId;
     IF @item IS NULL OR @oldReturned+@qty>@originalQty
        THROW 51532,'Intento de devolver unidades ya devueltas.',1;
     SELECT @priorCredit=COALESCE(SUM(rl.CreditMinor),0)
       FROM sales.SaleReversalLines rl JOIN sales.SaleReversals r ON r.Id=rl.ReversalId
       WHERE rl.SaleLineId=@line AND r.Status='approved';
     SET @part=CASE WHEN @oldReturned+@qty=@originalQty THEN @lineTotal-@priorCredit
       ELSE CONVERT(bigint,ROUND(CONVERT(decimal(28,4),@lineTotal)*@qty/@originalQty,0)) END;
     IF @part<0 OR @priorCredit+@part>@lineTotal THROW 51533,'Credito supera importe original.',1;
     UPDATE sales.SaleLines SET ReturnedQuantity=ReturnedQuantity+@qty,
       ModifiedBy=@ActorId,ModifiedAt=core.ufn_BusinessNow() WHERE Id=@line;
     INSERT INTO sales.SaleReversalLines(ReversalId,SaleLineId,Quantity,CreditMinor,COGSReversedMinor,RestockPool,CreatedBy)
       VALUES(@ReversalId,@line,@qty,@part,CASE WHEN @unitCost IS NULL THEN NULL ELSE @unitCost*CONVERT(bigint,@qty) END,@pool,@ActorId);
     SET @op=NEWID(); SET @mv=NULL;
     EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@ReturnLocationId,
       @Pool=@pool,@Kind='return',@OnHandDelta=@qty,@SourceType='sale_reversal',
       @SourceId=@ReversalId,@ActorId=@ActorId,@MovementId=@mv OUTPUT;
     SET @total+=@part;
     FETCH NEXT FROM returnCursor INTO @line,@qty,@pool;
  END;
  CLOSE returnCursor; DEALLOCATE returnCursor;
  IF @total<=0 THROW 51534,'Anticipo debe tener valor mayor a cero.',1;
  UPDATE sales.SaleReversals SET CreditMinor=@total WHERE Id=@ReversalId;
  UPDATE sales.Sales SET Status=CASE WHEN NOT EXISTS(SELECT 1 FROM sales.SaleLines WHERE SaleId=@SaleId AND ReturnedQuantity<Quantity)
     THEN 'returned' ELSE 'partially_returned' END,
     ModifiedBy=@ActorId,ModifiedAt=core.ufn_BusinessNow() WHERE Id=@SaleId;
  EXEC credits.usp_IssueFromReturn @CreditId,@ReversalId,@ActorId,@CustomerId;
  DECLARE @evt uniqueidentifier=NEWID(),@payload nvarchar(max)=(SELECT @ReversalId AS returnId,
     @CreditId AS creditId,@SaleId AS saleId,@BranchId AS branchId,@total AS creditMinor,
     JSON_QUERY((SELECT SaleLineId,Quantity,CreditMinor,RestockPool
        FROM sales.SaleReversalLines WHERE ReversalId=@ReversalId FOR JSON PATH)) AS lines
     FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  EXEC sync.usp_EnqueueEvent @evt,@OriginNodeId,'sale_return',@ReversalId,'sales.credit_return_posted',@payload;
  COMMIT;
 END TRY
 BEGIN CATCH
  IF CURSOR_STATUS('local','returnCursor')>=0 BEGIN CLOSE returnCursor; DEALLOCATE returnCursor; END;
  IF @@TRANCOUNT>0 ROLLBACK; THROW;
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
     t.ChangeMinor AS changeMinor,t.ForeignCurrencyCode AS foreignCurrencyCode,t.ForeignReceivedMinor AS foreignReceivedMinor,t.ExchangeRateId AS exchangeRateId,t.ExchangeRate AS exchangeRate,t.RoundingMinor AS roundingMinor,t.Reference AS reference,t.CreditId AS creditId,t.Status AS status
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
 OR (SELECT COUNT(*) FROM sales.CashEntries x WHERE x.SaleTenderId=t.Id AND x.Kind='change')<>CASE WHEN t.ChangeMinor=0 THEN 0 ELSE 1 END);
 INSERT INTO @v
 SELECT 'sale.fx_conversion',CONVERT(nvarchar(36),t.Id),t.ReceivedMinor,CONVERT(bigint,ROUND(t.ForeignReceivedMinor*r.Rate,0))
 FROM sales.SaleTenders t LEFT JOIN core.ExchangeRates r ON r.Id=t.ExchangeRateId
 WHERE t.ForeignCurrencyCode IS NOT NULL AND (r.Id IS NULL OR r.Rate<>t.ExchangeRate OR t.ReceivedMinor<>ROUND(t.ForeignReceivedMinor*t.ExchangeRate,0)
 OR t.ReceivedMinor-t.ChangeMinor-t.RoundingMinor<>t.AmountMinor OR t.RoundingMinor NOT BETWEEN -99 AND 99 OR t.ChangeMinor%100<>0);
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
    WHERE t.ParentTillId IS NULL AND t.CurrencyCode='NIO' AND reg.BranchId=@BranchId AND cl.ClosedAt>=@start AND cl.ClosedAt<@end) AS tillClosures,
  (SELECT COUNT(*) FROM sales.CashClosures cl JOIN sales.CashTills t ON t.Id=cl.TillId JOIN sales.CashRegisters reg ON reg.Id=t.RegisterId
    WHERE t.ParentTillId IS NULL AND t.CurrencyCode='NIO' AND reg.BranchId=@BranchId AND cl.ClosedAt>=@start AND cl.ClosedAt<@end AND cl.DifferenceMinor<>0) AS tillClosuresWithDifference,
  (SELECT COALESCE(SUM(cl.DifferenceMinor),0) FROM sales.CashClosures cl JOIN sales.CashTills t ON t.Id=cl.TillId JOIN sales.CashRegisters reg ON reg.Id=t.RegisterId
    WHERE t.ParentTillId IS NULL AND t.CurrencyCode='NIO' AND reg.BranchId=@BranchId AND cl.ClosedAt>=@start AND cl.ClosedAt<@end) AS tillDifferenceMinor,
  (SELECT COALESCE(SUM(cl.DifferenceMinor),0) FROM sales.CashClosures cl JOIN sales.CashTills t ON t.Id=cl.TillId JOIN sales.CashRegisters reg ON reg.Id=t.RegisterId
    WHERE t.CurrencyCode='USD' AND t.ParentTillId IS NOT NULL AND reg.BranchId=@BranchId AND cl.ClosedAt>=@start AND cl.ClosedAt<@end) AS usdTillDifferenceMinor,
  JSON_QUERY(COALESCE((SELECT DATEPART(hour,DATEADD(hour,-6,CreatedAt)) AS hour,COUNT(*) AS salesCount,SUM(TotalMinor) AS totalMinor
   FROM #s GROUP BY DATEPART(hour,DATEADD(hour,-6,CreatedAt)) ORDER BY hour FOR JSON PATH),N'[]')) AS salesByHour
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS Json;
END;
GO

CREATE OR ALTER PROCEDURE sales.usp_KpiTeam @BranchId uniqueidentifier,@ActorId uniqueidentifier,@Period varchar(8),@Date date
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @all bit=0;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffBranchAccess a ON a.StaffId=s.Id JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId
  WHERE s.Id=@ActorId AND s.IsEnabled=1 AND a.BranchId=@BranchId AND a.IsActive=1 AND r.IsActive=1 AND r.Code IN ('SELLER','MANAGER','OWNER')) THROW 52001,'Sin acceso a indicadores del equipo.',1;
 IF EXISTS(SELECT 1 FROM security.StaffRoles sr JOIN security.Roles r ON r.Id=sr.RoleId WHERE sr.StaffId=@ActorId AND r.Code IN ('MANAGER','OWNER') AND r.IsActive=1) SET @all=1;
 IF @Period NOT IN ('day','week','month','year') OR @Date IS NULL OR @Date<'19000101' OR @Date>='99990101' THROW 51900,'Periodo o fecha invalida.',1;
 DECLARE @from date=CASE @Period WHEN 'week' THEN DATEADD(day,-DATEDIFF(day,'19000101',@Date)%7,@Date) WHEN 'month' THEN DATEFROMPARTS(YEAR(@Date),MONTH(@Date),1) WHEN 'year' THEN DATEFROMPARTS(YEAR(@Date),1,1) ELSE @Date END;
 DECLARE @until date=CASE @Period WHEN 'week' THEN DATEADD(day,7,@from) WHEN 'month' THEN DATEADD(month,1,@from) WHEN 'year' THEN DATEADD(year,1,@from) ELSE DATEADD(day,1,@from) END;
 DECLARE @start datetime2=DATEADD(hour,6,CONVERT(datetime2,@from)),@end datetime2=DATEADD(hour,6,CONVERT(datetime2,@until));
 SELECT st.Id,st.DisplayName INTO #staff FROM security.Staff st WHERE EXISTS(SELECT 1 FROM security.StaffBranchAccess a WHERE a.StaffId=st.Id AND a.BranchId=@BranchId AND a.IsActive=1);
 SELECT (SELECT @Period AS period,@Date AS date,@from AS startDate,DATEADD(day,-1,@until) AS endDate,'NIO' AS currencyCode,
  JSON_QUERY(COALESCE((SELECT st.Id AS sellerId,st.DisplayName AS name,COALESCE(s.net,0) AS netSalesMinor,COALESCE(s.units,0) AS units,COALESCE(s.tickets,0) AS tickets,
    CASE WHEN COALESCE(s.tickets,0)=0 THEN 0 ELSE s.net/s.tickets END AS averageTicketMinor,
    CASE WHEN COALESCE(s.tickets,0)=0 THEN 0 ELSE s.units*100/s.tickets END AS unitsPerTicketX100,
    COALESCE(ret.net,0) AS returnsMinor,CASE WHEN COALESCE(s.net,0)<=0 THEN 0 ELSE COALESCE(ret.net,0)*10000/s.net END AS returnsBps,
    COALESCE(s.discount,0) AS discountsMinor,
    COALESCE(s.earned,0)-COALESCE(ret.reversed,0) AS commissionPayableMinor
   FROM #staff st
   OUTER APPLY(SELECT SUM(CONVERT(bigint,l.Quantity)) AS units,SUM(l.UnitPriceMinor*l.Quantity-l.DiscountMinor) AS net,SUM(l.DiscountMinor) AS discount,
     COUNT(DISTINCT l.SaleId) AS tickets,SUM(l.CommissionMinor) AS earned
    FROM sales.SaleLines l JOIN sales.Sales v ON v.Id=l.SaleId WHERE l.SellerId=st.Id AND v.BranchId=@BranchId AND v.CreatedAt>=@start AND v.CreatedAt<@end) s
   OUTER APPLY(SELECT SUM(q.CreditMinor) AS net,
     SUM(CONVERT(bigint,FLOOR(CONVERT(decimal(28,4),q.CommissionMinor)*q.cumulative/q.sold))-CONVERT(bigint,FLOOR(CONVERT(decimal(28,4),q.CommissionMinor)*(q.cumulative-q.Quantity)/q.sold))) AS reversed
    FROM (SELECT rl.Quantity,rl.CreditMinor,l.CommissionMinor,l.Quantity AS sold,r.CreatedAt,r.BranchId,
     SUM(rl.Quantity) OVER(PARTITION BY l.Id ORDER BY r.CreatedAt,r.Id ROWS UNBOUNDED PRECEDING) AS cumulative
     FROM sales.SaleReversalLines rl JOIN sales.SaleReversals r ON r.Id=rl.ReversalId JOIN sales.SaleLines l ON l.Id=rl.SaleLineId
     WHERE l.SellerId=st.Id AND r.Status='approved') q WHERE q.BranchId=@BranchId AND q.CreatedAt>=@start AND q.CreatedAt<@end) ret
   WHERE (@all=1 OR st.Id=@ActorId) AND EXISTS(SELECT 1 FROM security.StaffRoles sr JOIN security.Roles r ON r.Id=sr.RoleId WHERE sr.StaffId=st.Id AND r.Code='SELLER')
   ORDER BY st.DisplayName,st.Id FOR JSON PATH),N'[]')) AS sellers,
  JSON_QUERY(COALESCE((SELECT st.Id AS staffId,st.DisplayName AS name,
    (SELECT COUNT(*) FROM sales.CashClosures cl JOIN sales.CashTills t ON t.Id=cl.TillId JOIN sales.CashRegisters reg ON reg.Id=t.RegisterId WHERE reg.BranchId=@BranchId AND t.ParentTillId IS NULL AND t.CurrencyCode='NIO' AND cl.ClosedBy=st.Id AND cl.ClosedAt>=@start AND cl.ClosedAt<@end) AS tillClosures,
    (SELECT COALESCE(SUM(cl.DifferenceMinor),0) FROM sales.CashClosures cl JOIN sales.CashTills t ON t.Id=cl.TillId JOIN sales.CashRegisters reg ON reg.Id=t.RegisterId WHERE reg.BranchId=@BranchId AND t.ParentTillId IS NULL AND t.CurrencyCode='NIO' AND cl.ClosedBy=st.Id AND cl.ClosedAt>=@start AND cl.ClosedAt<@end) AS tillDifferenceMinor,
    (SELECT COALESCE(SUM(cl.DifferenceMinor),0) FROM sales.CashClosures cl JOIN sales.CashTills t ON t.Id=cl.TillId JOIN sales.CashRegisters reg ON reg.Id=t.RegisterId WHERE reg.BranchId=@BranchId AND t.ParentTillId IS NOT NULL AND t.CurrencyCode='USD' AND cl.ClosedBy=st.Id AND cl.ClosedAt>=@start AND cl.ClosedAt<@end) AS usdTillDifferenceMinor,
    (SELECT COUNT(*) FROM sales.Sales v WHERE v.BranchId=@BranchId AND v.DiscountApprovedBy=st.Id AND v.CreatedAt>=@start AND v.CreatedAt<@end)
     +(SELECT COUNT(*) FROM sales.SaleReversals r WHERE r.BranchId=@BranchId AND r.ApprovedBy=st.Id AND r.Status='approved' AND r.CreatedAt>=@start AND r.CreatedAt<@end) AS approvalsCount,
    (SELECT COALESCE(SUM(v.DiscountMinor),0) FROM sales.Sales v WHERE v.BranchId=@BranchId AND v.DiscountApprovedBy=st.Id AND v.CreatedAt>=@start AND v.CreatedAt<@end)
     +(SELECT COALESCE(SUM(r.CreditMinor),0) FROM sales.SaleReversals r WHERE r.BranchId=@BranchId AND r.ApprovedBy=st.Id AND r.Status='approved' AND r.CreatedAt>=@start AND r.CreatedAt<@end) AS approvalsMinor
   FROM #staff st WHERE @all=1 AND EXISTS(SELECT 1 FROM security.StaffRoles sr JOIN security.Roles r ON r.Id=sr.RoleId WHERE sr.StaffId=st.Id AND r.Code IN ('MANAGER','OWNER'))
   ORDER BY st.DisplayName,st.Id FOR JSON PATH),N'[]')) AS managers,
  JSON_QUERY(COALESCE((SELECT st.Id AS staffId,st.DisplayName AS name,
    (SELECT COALESCE(SUM(CONVERT(bigint,e.Quantity)),0) FROM receiving.ScanEvents e WHERE e.CreatedBy=st.Id AND e.MatchStatus='matched' AND e.CreatedAt>=@start AND e.CreatedAt<@end) AS garmentsReceived,
    (SELECT COALESCE(SUM(CONVERT(bigint,q.Damaged+q.Stained+q.Odor+q.Missing)),0) FROM receiving.vw_CurrentQuality q WHERE q.ActorId=st.Id AND q.CreatedAt>=@start AND q.CreatedAt<@end) AS qualityRejects,
    (SELECT AVG(CONVERT(bigint,DATEDIFF(minute,ss.CreatedAt,ss.ClosedAt))) FROM receiving.ScanSessions ss WHERE ss.CreatedBy=st.Id AND ss.ClosedAt IS NOT NULL AND ss.ClosedAt>=@start AND ss.ClosedAt<@end) AS receptionMinutesAverage
   FROM #staff st WHERE @all=1 AND EXISTS(SELECT 1 FROM security.StaffRoles sr JOIN security.Roles r ON r.Id=sr.RoleId WHERE sr.StaffId=st.Id AND r.Code='INVENTORY')
   ORDER BY st.DisplayName,st.Id FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS stockWorkers
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS Json;
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
     d.SaleGrossMinor AS saleGrossMinor,d.ReturnGrossMinor AS returnGrossMinor,d.NetSalesMinor AS netSalesMinor,
     (SELECT COALESCE(cl2.ExpectedMinor,(SELECT SUM(DeltaMinor) FROM sales.CashEntries WHERE TillId=child.Id),0) FROM sales.CashTills child LEFT JOIN sales.CashClosures cl2 ON cl2.TillId=child.Id WHERE child.ParentTillId=t.Id) AS usdExpectedMinor,
     (SELECT cl2.CountedMinor FROM sales.CashTills child JOIN sales.CashClosures cl2 ON cl2.TillId=child.Id WHERE child.ParentTillId=t.Id) AS usdCountedMinor,
     (SELECT cl2.DifferenceMinor FROM sales.CashTills child JOIN sales.CashClosures cl2 ON cl2.TillId=child.Id WHERE child.ParentTillId=t.Id) AS usdDifferenceMinor
     FROM sales.CashTills t JOIN sales.CashRegisters reg ON reg.Id=t.RegisterId JOIN security.Staff st ON st.Id=t.CashierId
     LEFT JOIN sales.CashClosures cl ON cl.TillId=t.Id LEFT JOIN accounting.CloseDocuments d ON d.ClosureId=cl.Id
     OUTER APPLY(SELECT SUM(DeltaMinor) AS ExpectedMinor FROM sales.CashEntries WHERE TillId=t.Id) e
     WHERE t.ParentTillId IS NULL AND reg.BranchId=@BranchId AND ((t.OpenedAt>=@start AND t.OpenedAt<@end) OR (t.ClosedAt>=@start AND t.ClosedAt<@end))
     ORDER BY t.OpenedAt,t.Id FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS tills,
   JSON_QUERY(COALESCE((SELECT TOP (5) l.ItemId AS itemId,MAX(l.SkuSnapshot) AS sku,MAX(l.NameSnapshot) AS name,SUM(CONVERT(bigint,l.Quantity)) AS unitsSold
     FROM sales.Sales s JOIN sales.SaleLines l ON l.SaleId=s.Id
     WHERE s.BranchId=@BranchId AND s.CreatedAt>=@start AND s.CreatedAt<@end AND s.Status<>'cancelled'
     GROUP BY l.ItemId ORDER BY SUM(CONVERT(bigint,l.Quantity)) DESC,l.ItemId FOR JSON PATH),N'[]')) AS topItems
   FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS Json;
END;

GO

-- Rate history is append-only even for direct SQL writes.
CREATE OR ALTER TRIGGER core.tr_ExchangeRates_Immutable ON core.ExchangeRates INSTEAD OF UPDATE,DELETE
AS
BEGIN
 THROW 52107,'Las tasas son inmutables; cree una nueva fecha.',1;
END;
GO

-- Legacy openings remain NIO-only; counted openings create the internal USD drawer.
CREATE OR ALTER PROCEDURE [sales].[usp_OpenTill]
 @TillId uniqueidentifier,@RegisterId uniqueidentifier,@CashierId uniqueidentifier,
 @CurrencyCode varchar(3),@OpeningMinor bigint,@OriginNodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId AND ParentTillId IS NOT NULL)
 THROW 52106,'Use el turno padre NIO.',1;
 IF @OpeningMinor<0 THROW 51501,'Fondo inicial invalido.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId)
   BEGIN
     IF EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId AND
        (RegisterId<>@RegisterId OR CashierId<>@CashierId OR CurrencyCode<>@CurrencyCode))
        -- D-B-01: the opening amount is part of the request; a different amount is another till.
        OR NOT EXISTS(SELECT 1 FROM sales.CashEntries WHERE TillId=@TillId AND Kind='opening' AND DeltaMinor=@OpeningMinor)
       THROW 51502,'TillId reutilizado incorrectamente.',1;
     COMMIT; RETURN;
   END;
   IF @CurrencyCode IS NULL OR @CurrencyCode<>'NIO' THROW 52106,'Use el turno padre NIO.',1;
   DECLARE @branch uniqueidentifier;
   SELECT @branch=BranchId FROM sales.CashRegisters WHERE Id=@RegisterId AND IsActive=1;
   IF @branch IS NULL THROW 51503,'Caja registradora inexistente o inactiva.',1;
   IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId
      WHERE a.StaffId=@CashierId AND a.BranchId=@branch AND a.IsActive=1 AND s.IsEnabled=1)
      THROW 51504,'Cajero no autorizado en sucursal.',1;
   INSERT INTO sales.CashTills(Id,RegisterId,CashierId,CurrencyCode,CreatedBy)
     VALUES(@TillId,@RegisterId,@CashierId,@CurrencyCode,@CashierId);
   INSERT INTO sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,ActorId,CreatedBy)
     VALUES(NEWID(),@TillId,@CurrencyCode,'opening',@OpeningMinor,@CashierId,@CashierId);
   DECLARE @evt uniqueidentifier=NEWID(),@payload nvarchar(max)=(SELECT @TillId AS tillId,
      @RegisterId AS registerId,@OpeningMinor AS openingMinor,@CurrencyCode AS currency
      FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @evt,@OriginNodeId,'cash_till',@TillId,'cash.till_opened',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

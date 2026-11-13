-- Owner decisions 2026-11-12. Domain rules remain in SQL; V001 is untouched.
CREATE TABLE sales.CashDenominations(DenominationMinor bigint NOT NULL PRIMARY KEY);
INSERT INTO sales.CashDenominations VALUES(100000),(50000),(20000),(10000),(5000),(2000),(1000),(500),(100),(50),(25),(10);
ALTER TABLE sales.CashCounts ADD CountKind varchar(12) NOT NULL CONSTRAINT DF_CashCountKind DEFAULT('closing')
 CONSTRAINT CK_CashCountKind CHECK(CountKind IN ('opening','closing'));
GO
DROP INDEX UX_CashCounts_TillSubmitted ON sales.CashCounts;
CREATE UNIQUE INDEX UX_CashCounts_TillSubmitted ON sales.CashCounts(TillId,CountKind) WHERE Status='submitted';
CREATE UNIQUE INDEX UX_CashCounts_Opening ON sales.CashCounts(TillId) WHERE CountKind='opening';
ALTER TABLE sales.Sales ADD DiscountReason nvarchar(250) NULL, ReceiptSequence bigint NULL;
GO
WITH numbered AS(SELECT Id,ROW_NUMBER() OVER(PARTITION BY BranchId ORDER BY CreatedAt,Id) AS n FROM sales.Sales)
UPDATE s SET ReceiptSequence=n.n FROM sales.Sales s JOIN numbered n ON n.Id=s.Id;
CREATE UNIQUE INDEX UX_Sales_ReceiptSequence ON sales.Sales(BranchId,ReceiptSequence) WHERE ReceiptSequence IS NOT NULL;
CREATE TABLE sales.StockExceptions(
 Id uniqueidentifier NOT NULL PRIMARY KEY, SaleLineId uniqueidentifier NOT NULL UNIQUE REFERENCES sales.SaleLines(Id),
 ItemId uniqueidentifier NOT NULL REFERENCES catalog.Items(Id), QuantityShort int NOT NULL CHECK(QuantityShort>0),
 CashierId uniqueidentifier NOT NULL REFERENCES security.Staff(Id), Note nvarchar(500) NOT NULL,
 CreatedAt datetime2(3) NOT NULL DEFAULT(SYSUTCDATETIME()),
 ReviewedBy uniqueidentifier NULL REFERENCES security.Staff(Id), ReviewedAt datetime2(3) NULL, ReviewNote nvarchar(500) NULL,
 CONSTRAINT CK_StockExceptions_Review CHECK((ReviewedBy IS NULL AND ReviewedAt IS NULL AND ReviewNote IS NULL) OR
 (ReviewedBy IS NOT NULL AND ReviewedAt IS NOT NULL AND LEN(LTRIM(RTRIM(ReviewNote)))>0)));
GO
CREATE OR ALTER PROCEDURE sales.usp_OpenTillCounted
 @TillId uniqueidentifier,@RegisterId uniqueidentifier,@CashierId uniqueidentifier,
 @CurrencyCode varchar(3),@OpeningMinor bigint,@OriginNodeId uniqueidentifier,@LinesJson nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF ISJSON(@LinesJson)<>1 OR @LinesJson IS NULL THROW 51545,'Cuente el efectivo inicial por denominacion.',1;
 DECLARE @lines TABLE(DenominationMinor bigint,Quantity int);
 INSERT INTO @lines SELECT denominationMinor,quantity FROM OPENJSON(@LinesJson)
 WITH(denominationMinor bigint,quantity int);
 IF NOT EXISTS(SELECT 1 FROM @lines) OR EXISTS(SELECT 1 FROM @lines l WHERE Quantity IS NULL OR Quantity NOT BETWEEN 0 AND 1000000 OR
 NOT EXISTS(SELECT 1 FROM sales.CashDenominations d WHERE d.DenominationMinor=l.DenominationMinor)) OR
 EXISTS(SELECT DenominationMinor FROM @lines GROUP BY DenominationMinor HAVING COUNT(*)>1) OR
 @OpeningMinor<>(SELECT SUM(DenominationMinor*CONVERT(bigint,Quantity)) FROM @lines) OR @CurrencyCode<>'NIO'
 THROW 51545,'El fondo inicial debe coincidir con el desglose de billetes y monedas.',1;
 BEGIN TRAN;
 BEGIN TRY
  IF EXISTS(SELECT 1 FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TillId)
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId AND RegisterId=@RegisterId AND CashierId=@CashierId AND CurrencyCode=@CurrencyCode)
    OR EXISTS(SELECT DenominationMinor,Quantity FROM @lines EXCEPT SELECT l.DenominationMinor,l.Quantity FROM sales.CashCounts c JOIN sales.CashCountLines l ON l.CashCountId=c.Id WHERE c.TillId=@TillId AND c.CountKind='opening')
    OR EXISTS(SELECT l.DenominationMinor,l.Quantity FROM sales.CashCounts c JOIN sales.CashCountLines l ON l.CashCountId=c.Id WHERE c.TillId=@TillId AND c.CountKind='opening' EXCEPT SELECT DenominationMinor,Quantity FROM @lines)
    THROW 51502,'TillId reutilizado con otro desglose.',1;
   COMMIT; RETURN;
  END;
  EXEC sales.usp_OpenTill @TillId,@RegisterId,@CashierId,@CurrencyCode,@OpeningMinor,@OriginNodeId;
  EXEC sales.usp_RecordCashCount @TillId,@TillId,@CashierId,@LinesJson;
  UPDATE sales.CashCounts SET CountKind='opening' WHERE Id=@TillId;
  COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE [sales].[usp_PostSale]
 @SaleId uniqueidentifier,@BranchId uniqueidentifier,@LocationId uniqueidentifier,
 @CashierId uniqueidentifier,@CurrencyCode varchar(3),@OriginNodeId uniqueidentifier,
 @Lines [sales].[SaleLineRequest] READONLY,
 @Tenders [sales].[SaleTenderRequest] READONLY,
 @CustomerId uniqueidentifier=NULL,@TillId uniqueidentifier=NULL,
 @DiscountApproverId uniqueidentifier=NULL,@DiscountReason nvarchar(250)=NULL,@StockExceptionNote nvarchar(500)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
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
   (TenderKind IN ('card','transfer') AND (Reference IS NULL OR LEN(LTRIM(RTRIM(Reference)))=0)))
   THROW 51509,'Formas de pago invalidas o sin autorizacion de referencia.',1;
 DECLARE @input nvarchar(max)=(SELECT @BranchId AS branchId,@LocationId AS locationId,
   @CashierId AS cashierId,@DiscountReason AS discountReason,@StockExceptionNote AS stockExceptionNote,@CurrencyCode AS currency,@CustomerId AS customerId,@TillId AS tillId,
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
     Quantity,UnitPriceMinor,CostUnitSnapshotMinor,COGSMinor,DiscountMinor,TaxMinor,TotalMinor,CreatedBy)
   SELECT @SaleId,c.LineNumber,c.ItemId,i.Sku,i.VariantName,c.Quantity,c.UnitPriceMinor,
     i.UnitCostMinor,i.UnitCostMinor*CONVERT(bigint,c.Quantity),
     c.DiscountMinor,c.TaxMinor,c.TotalMinor,@CashierId
   FROM @calc c JOIN catalog.Items i ON i.Id=c.ItemId;
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

CREATE OR ALTER PROCEDURE sales.usp_GetSaleDetail @BranchId uniqueidentifier,@SaleId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON;
 SELECT (SELECT s.Id AS saleId,CONCAT((SELECT Code FROM core.Branches WHERE Id=s.BranchId),'-',RIGHT(CONCAT('000000',s.ReceiptSequence),CASE WHEN LEN(CONVERT(varchar(20),s.ReceiptSequence))>6 THEN LEN(CONVERT(varchar(20),s.ReceiptSequence)) ELSE 6 END)) AS receiptNumber,s.DiscountApprovedBy AS discountApprovedBy,s.DiscountReason AS discountReason,s.SubtotalMinor AS subtotalMinor,s.DiscountMinor AS discountMinor,
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

CREATE OR ALTER PROCEDURE [sales].[usp_CloseTill]
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
   UPDATE sales.CashTills SET Status='closed',ClosedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId,
     ModifiedAt=SYSUTCDATETIME() WHERE Id=@TillId;
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
       @opened,SYSUTCDATETIME(),@ActorId);
   INSERT INTO accounting.CloseDocumentLines(CloseDocumentId,[LineNo],ConceptCode,ConceptName,AmountMinor)
      VALUES(@doc,1,'EXPECTED_CASH',N'Efectivo esperado',@expected),
            (@doc,2,'COUNTED_CASH',N'Efectivo contado',@counted),
            (@doc,3,'CASH_DIFFERENCE',N'Diferencia de caja',@counted-@expected),
            (@doc,4,'SALE_GROSS',N'Ventas del turno (todos los medios)',@gross),
            (@doc,5,'RETURN_GROSS',N'Devoluciones del turno',-@returns),
            (@doc,6,'NET_SALES',N'Venta neta del turno',@gross-@returns),
            (@doc,7,'CARD_TENDERS',N'Pagos con tarjeta registrados',@card),
            (@doc,8,'CREDIT_REDEMPTIONS',N'Anticipos canjeados',@credit),
            (@doc,9,'COGS_GROSS',N'Costo de venta del turno (costo snapshot)',@saleCOGS),
            (@doc,10,'COGS_RETURNED',N'Costo revertido por devoluciones',-@returnCOGS),
            (@doc,11,'COGS_NET',N'Costo de venta neto',@saleCOGS-@returnCOGS);
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


CREATE OR ALTER PROCEDURE [sales].[usp_RecordCashCount]
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
      WHERE DenominationMinor IS NULL OR Quantity IS NULL OR DenominationMinor<=0 OR Quantity<0 OR Quantity>1000000 OR NOT EXISTS(SELECT 1 FROM sales.CashDenominations d WHERE d.DenominationMinor=l.DenominationMinor))
   THROW 51541,'Arqueo: cada linea necesita denominacion mayor a cero y cantidad no negativa.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM sales.CashCounts WITH(UPDLOCK,HOLDLOCK) WHERE Id=@CashCountId)
   BEGIN
     IF NOT EXISTS(SELECT 1 FROM sales.CashCounts WHERE Id=@CashCountId AND TillId=@TillId)
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

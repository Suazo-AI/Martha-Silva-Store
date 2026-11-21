-- savia:transactional
-- V029: canonical request identity v1. Legacy NULL identities remain lookup-only.
-- No policy/price reconstruction or retry backfill. Execute through saviadb migration envelope.
ALTER TABLE sales.SaleReversals ADD RequestIdentityVersion smallint NULL, RequestIdentityHash varbinary(32) NULL;
GO
ALTER TABLE sales.SaleReversals ADD CONSTRAINT CK_Reversals_RequestIdentity CHECK(
 (RequestIdentityVersion IS NULL AND RequestIdentityHash IS NULL) OR
 (RequestIdentityVersion IS NOT NULL AND RequestIdentityVersion=1 AND RequestIdentityHash IS NOT NULL AND DATALENGTH(RequestIdentityHash)=32));
GO
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
 -- Normalize seller JSON whitespace/key/row ordering through the actual typed contract.
 -- Missing seller payload is distinct from an explicit mapping (historical CASHIER contract).
 DECLARE @identitySellers TABLE(LineNumber int PRIMARY KEY,SellerId uniqueidentifier);
 IF @SellersJson IS NOT NULL
 BEGIN
  IF ISJSON(@SellersJson)<>1 THROW 52002,'Indique la vendedora de cada linea.',1;
  INSERT @identitySellers SELECT lineNumber,sellerId FROM OPENJSON(@SellersJson) WITH(lineNumber int,sellerId uniqueidentifier);
 END;
 -- v1 uses UTF-16 SQL JSON bytes; no locale-dependent concatenation or total approximation.
 DECLARE @identityJson nvarchar(max)=(SELECT 1 AS version,N'outcome' AS endpoint,@SaleId AS saleId,@BranchId AS branchId,@LocationId AS locationId,
   @OriginNodeId AS originNodeId,@TillId AS tillId,@Reason AS reason,@Outcome AS outcome,@Reference AS reference,@ExchangeSaleId AS exchangeSaleId,
   @DifferenceKind AS differenceKind,@DifferenceReference AS differenceReference,
   JSON_QUERY((SELECT SaleLineId,Quantity,RestockPool FROM @Lines ORDER BY SaleLineId FOR JSON PATH,INCLUDE_NULL_VALUES)) AS returnLines,
   JSON_QUERY((SELECT LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor FROM @NewLines ORDER BY LineNumber FOR JSON PATH,INCLUDE_NULL_VALUES)) AS newLines,
   JSON_QUERY((SELECT TenderNumber,TenderKind,AmountMinor,CreditId,ReceivedMinor,ChangeMinor,Reference FROM @NewTenders ORDER BY TenderNumber FOR JSON PATH,INCLUDE_NULL_VALUES)) AS newTenders,
   JSON_QUERY((SELECT LineNumber,SellerId FROM @identitySellers ORDER BY LineNumber FOR JSON PATH,INCLUDE_NULL_VALUES)) AS sellers,CASE WHEN @SellersJson IS NULL THEN 0 ELSE 1 END AS sellersProvided
   FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER);
 DECLARE @identityHash varbinary(32)=HASHBYTES('SHA2_256',CONVERT(varbinary(max),@identityJson));
 BEGIN TRANSACTION;
 BEGIN TRY
  DECLARE @identityLock int,@identityResource nvarchar(255)=CONCAT(N'savia.return.',CONVERT(nvarchar(36),@ReversalId));
  EXEC @identityLock=sys.sp_getapplock @Resource=@identityResource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @identityLock<0 THROW 51538,'No se pudo verificar ReversalId; consulte el comprobante.',1;
  IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId
    WHERE a.StaffId=@ActorId AND s.IsEnabled=1 AND a.BranchId=@BranchId AND a.IsActive=1)
    THROW 51529,'Actor sin acceso vigente a la sucursal.',1;
  IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId
    WHERE a.StaffId=@ActorId AND s.IsEnabled=1 AND a.BranchId=@BranchId AND a.CanApproveReturns=1 AND a.IsActive=1)
    THROW 51529,'Supervisor sin permiso para devoluciones.',1;
  DECLARE @lockedTill uniqueidentifier;
  SELECT @lockedTill=Id FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TillId;
  SELECT @lockedTill=Id FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE ParentTillId=@TillId;
  IF EXISTS(SELECT 1 FROM sales.SaleReversals WITH(UPDLOCK,HOLDLOCK) WHERE Id=@ReversalId)
  BEGIN
   -- NULL legacy identity must never be completed from the retry request.
   IF NOT EXISTS(SELECT 1 FROM sales.SaleReversals WHERE Id=@ReversalId
      AND RequestIdentityVersion=1 AND RequestIdentityHash=@identityHash)
    THROW 51538,'ReversalId reutilizado o identidad historica no verificable; consulte el comprobante.',1;
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
  INSERT INTO sales.SaleReversals(Id,SaleId,BranchId,LocationId,TillId,ActorId,Kind,SettlementKind,Reason,CreditMinor,CurrencyCode,Status,ApprovedBy,CreatedBy,RequestIdentityVersion,RequestIdentityHash)
   VALUES(@ReversalId,@SaleId,@BranchId,@LocationId,@TillId,@ActorId,'return',@Outcome,@Reason,0,@currency,'approved',@ActorId,@ActorId,1,@identityHash);
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
 -- v1 uses UTF-16 SQL JSON bytes; no locale-dependent concatenation or total approximation.
 DECLARE @identityJson nvarchar(max)=(SELECT 1 AS version,N'credit' AS endpoint,@SaleId AS saleId,@BranchId AS branchId,@ReturnLocationId AS locationId,
   @OriginNodeId AS originNodeId,@TillId AS tillId,@Reason AS reason,N'credit' AS outcome,@CreditId AS creditId,@CustomerId AS customerId,
   JSON_QUERY((SELECT SaleLineId,Quantity,RestockPool FROM @Lines ORDER BY SaleLineId FOR JSON PATH,INCLUDE_NULL_VALUES)) AS returnLines
   FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER);
 DECLARE @identityHash varbinary(32)=HASHBYTES('SHA2_256',CONVERT(varbinary(max),@identityJson));
 BEGIN TRANSACTION;
 BEGIN TRY
  DECLARE @identityLock int,@identityResource nvarchar(255)=CONCAT(N'savia.return.',CONVERT(nvarchar(36),@ReversalId));
  EXEC @identityLock=sys.sp_getapplock @Resource=@identityResource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @identityLock<0 THROW 51538,'No se pudo verificar ReversalId; consulte el comprobante.',1;
  IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId
    WHERE a.StaffId=@ActorId AND s.IsEnabled=1 AND a.BranchId=@BranchId AND a.IsActive=1)
    THROW 51529,'Actor sin acceso vigente a la sucursal.',1;
  IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId
    WHERE a.StaffId=@ApprovedBy AND s.IsEnabled=1 AND a.BranchId=@BranchId AND a.CanApproveReturns=1 AND a.IsActive=1)
    THROW 51529,'Supervisor sin permiso para devoluciones.',1;
  DECLARE @lockedTill uniqueidentifier;
  SELECT @lockedTill=Id FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TillId;
  SELECT @lockedTill=Id FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE ParentTillId=@TillId;
  IF EXISTS(SELECT 1 FROM sales.SaleReversals WITH(UPDLOCK,HOLDLOCK) WHERE Id=@ReversalId)
  BEGIN
   -- NULL legacy identity must never be completed from the retry request.
   IF NOT EXISTS(SELECT 1 FROM sales.SaleReversals WHERE Id=@ReversalId
      AND RequestIdentityVersion=1 AND RequestIdentityHash=@identityHash)
    THROW 51538,'ReversalId reutilizado o identidad historica no verificable; consulte el comprobante.',1;
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
    SettlementKind,Reason,CreditMinor,CurrencyCode,Status,ApprovedBy,CreatedBy,RequestIdentityVersion,RequestIdentityHash)
    VALUES(@ReversalId,@SaleId,@BranchId,@ReturnLocationId,@TillId,@ActorId,'return',
      'credit',@Reason,0,@currency,'approved',@ApprovedBy,@ActorId,1,@identityHash);
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

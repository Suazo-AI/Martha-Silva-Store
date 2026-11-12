-- V007: CP1-B procedure fixes (D-B-01 to D-B-05), found by the CP1-B audit tests.
-- Each procedure body is the latest version (V001, V004 or V006) plus the marked guard.
-- 51536 cash entry id reused with other content; 51537 actor without access to the till branch;
-- 51538 reversal id reused with other content. 51502 now also covers another opening amount.

CREATE OR ALTER PROCEDURE [sales].[usp_OpenTill]
 @TillId uniqueidentifier,@RegisterId uniqueidentifier,@CashierId uniqueidentifier,
 @CurrencyCode varchar(3),@OpeningMinor bigint,@OriginNodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
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

CREATE OR ALTER PROCEDURE [sales].[usp_RecordCashEntry]
 @EntryId uniqueidentifier,@TillId uniqueidentifier,@ActorId uniqueidentifier,
 @Kind varchar(16),@DeltaMinor bigint,@Reason nvarchar(400),@OriginNodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Kind NOT IN ('payout','deposit','adjustment') OR LEN(LTRIM(RTRIM(@Reason)))=0
   THROW 51505,'Solo operaciones manuales justificadas.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
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
       WHERE Id=@CashCountId AND TillId=@TillId AND Status='submitted')
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

CREATE OR ALTER PROCEDURE [sales].[usp_PostCreditReturn]
 @ReversalId uniqueidentifier,@CreditId uniqueidentifier,@SaleId uniqueidentifier,
 @BranchId uniqueidentifier,@ReturnLocationId uniqueidentifier,@TillId uniqueidentifier,
 @ActorId uniqueidentifier,@ApprovedBy uniqueidentifier,@CustomerId uniqueidentifier,
 @Reason nvarchar(500),@OriginNodeId uniqueidentifier,
 @Lines [sales].[ReturnLineRequest] READONLY
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM @Lines) OR LEN(LTRIM(RTRIM(@Reason)))=0
    THROW 51525,'Devolucion sin prendas o motivo.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
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
  IF @saleStatus IS NULL OR @saleStatus IN ('cancelled','returned') OR
       @saleCustomer IS NULL OR @saleCustomer<>@CustomerId
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
       ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@line;
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
     ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@SaleId;
  EXEC credits.usp_IssueFromReturn @CreditId,@ReversalId,@ActorId;
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

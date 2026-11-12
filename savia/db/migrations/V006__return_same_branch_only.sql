/* V006: a branch cannot return a sale of another branch (BUG-010, ADR-001 critique F3).
   Same body as V001 sales.usp_PostCreditReturn plus one guard after the sale is read.
   Evidence: savia/docs/bugs/BUG-010-devolucion-otra-sucursal.md */

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

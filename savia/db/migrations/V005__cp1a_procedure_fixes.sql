/* V005: fixes for the defects found by the CP1-A procedure audit.
   Each defect has a test that failed before this migration (XFAIL) and passes after it.
   Evidence: savia/docs/bugs/BUG-003-009-cp1a.md

   D-A-01 receiving.usp_ResolveScan        a retry with the same ids returns the resolution.
   D-A-02 receiving.usp_ApproveScanSession a retry by the same reviewer returns the approval.
   D-A-03 inventory.usp_PostAdjustment     the approver needs access to the branch (51107).
   D-A-04 catalog.usp_RegisterItem         a repeated internal SKU is a domain error (51212).
   D-A-05 catalog.usp_ActivateItem         a price change on an active variant writes PriceHistory.
   D-A-06 receiving.usp_PostScanSession    closes the container when no other session is open.
   D-A-07 receiving.usp_RecordScan         leaves the caller's transaction to the caller, so the
                                           domain error survives INSERT ... EXEC (no Msg 3915).
                                           The retry path now also returns the column ScanId. */

CREATE OR ALTER PROCEDURE [receiving].[usp_RecordScan]
 @ScanId uniqueidentifier,@ScanSessionId uniqueidentifier,@RawCode nvarchar(128),
 @Quantity int=1,@DeviceCode nvarchar(80)=NULL,@ActorId uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Quantity NOT BETWEEN 1 AND 10000 OR LEN(LTRIM(RTRIM(@RawCode)))=0
   THROW 51301,'Lectura invalida.',1;
 DECLARE @ownTran bit=0;
 IF @@TRANCOUNT=0 BEGIN SET @ownTran=1; BEGIN TRANSACTION; END;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM receiving.ScanEvents WITH(UPDLOCK,HOLDLOCK) WHERE Id=@ScanId)
   BEGIN
     IF EXISTS(SELECT 1 FROM receiving.ScanEvents WHERE Id=@ScanId AND
         (ScanSessionId<>@ScanSessionId OR RawCode<>@RawCode OR Quantity<>@Quantity))
       THROW 51302,'ScanId repetido con contenido distinto.',1;
     SELECT Id AS ScanId,ItemId,MatchStatus,Quantity FROM receiving.ScanEvents WHERE Id=@ScanId;
     IF @ownTran=1 COMMIT;
     RETURN;
   END;
   DECLARE @supplier uniqueidentifier,@status varchar(16),@matched uniqueidentifier=NULL,@matches int;
   SELECT @supplier=c.SupplierId,@status=s.Status FROM receiving.ScanSessions s WITH(UPDLOCK,HOLDLOCK)
     JOIN receiving.ImportContainers c ON c.Id=s.ContainerId WHERE s.Id=@ScanSessionId;
   IF @status IS NULL OR @status<>'counting' THROW 51303,'Sesion de escaneo no abierta.',1;
   DECLARE @candidates TABLE(ItemId uniqueidentifier PRIMARY KEY);
   INSERT INTO @candidates(ItemId)
    SELECT DISTINCT ItemId FROM catalog.ItemIdentifiers
      WHERE RawCode=@RawCode AND IsActive=1 AND
         ((Kind='barcode' AND SupplierId IS NULL)
          OR (SupplierId=@supplier AND Kind IN ('supplier_sku','barcode','alias'))
          OR (Kind='alias' AND SupplierId IS NULL));
   SELECT @matches=COUNT(*),@matched=MIN(ItemId) FROM @candidates;
   SET @status=CASE WHEN @matches=0 THEN 'unknown' WHEN @matches=1 THEN 'matched' ELSE 'ambiguous' END;
   INSERT INTO receiving.ScanEvents(Id,ScanSessionId,ItemId,RawCode,Quantity,MatchStatus,DeviceCode,CreatedBy)
     VALUES(@ScanId,@ScanSessionId,CASE WHEN @matches=1 THEN @matched ELSE NULL END,
            @RawCode,@Quantity,@status,@DeviceCode,@ActorId);
   SELECT @ScanId AS ScanId,CASE WHEN @matches=1 THEN @matched ELSE NULL END AS ItemId,@status AS MatchStatus,@Quantity AS Quantity;
   IF @ownTran=1 COMMIT;
 END TRY
 BEGIN CATCH IF @ownTran=1 AND @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [receiving].[usp_ResolveScan]
 @ScanId uniqueidentifier,@ItemId uniqueidentifier,@ReviewerId uniqueidentifier,@Reason nvarchar(250)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF LEN(LTRIM(RTRIM(@Reason)))=0 THROW 51304,'Motivo obligatorio.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   -- Retry of a resolution already stored: same item, resolved by a reviewer (not an automatic match).
   IF EXISTS(SELECT 1 FROM receiving.ScanEvents WITH(UPDLOCK,HOLDLOCK)
       WHERE Id=@ScanId AND MatchStatus='matched' AND ItemId=@ItemId AND ResolutionReason IS NOT NULL)
   BEGIN COMMIT; RETURN; END;
   DECLARE @code nvarchar(128),@supplier uniqueidentifier,@sessionStatus varchar(16);
   SELECT @code=e.RawCode,@supplier=c.SupplierId,@sessionStatus=s.Status
   FROM receiving.ScanEvents e WITH(UPDLOCK,HOLDLOCK)
     JOIN receiving.ScanSessions s ON s.Id=e.ScanSessionId
     JOIN receiving.ImportContainers c ON c.Id=s.ContainerId
   WHERE e.Id=@ScanId AND e.MatchStatus IN ('unknown','ambiguous');
   IF @code IS NULL OR @sessionStatus NOT IN ('counting','review')
     THROW 51305,'Escaneo no resoluble en su estado actual.',1;
   IF NOT EXISTS(SELECT 1 FROM catalog.ItemIdentifiers WHERE ItemId=@ItemId AND RawCode=@code
       AND IsActive=1 AND (SupplierId IS NULL OR SupplierId=@supplier))
     THROW 51306,'Primero registrar el codigo original para esta variante.',1;
   UPDATE receiving.ScanEvents SET ItemId=@ItemId,MatchStatus='matched',ResolutionReason=@Reason,
     ModifiedBy=@ReviewerId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@ScanId;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [receiving].[usp_ApproveScanSession]
 @ScanSessionId uniqueidentifier,@ReviewerId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
   DECLARE @status varchar(16),@reviewedBy uniqueidentifier;
   SELECT @status=Status,@reviewedBy=ReviewedBy FROM receiving.ScanSessions WITH(UPDLOCK,HOLDLOCK) WHERE Id=@ScanSessionId;
   -- Retry by the same reviewer after the approval (or after the posting) returns the approval.
   IF @status IN ('approved','posted') AND @reviewedBy=@ReviewerId
   BEGIN COMMIT; RETURN; END;
   IF @status NOT IN ('counting','review') OR @status IS NULL
     THROW 51307,'La sesion no puede aprobarse.',1;
   IF NOT EXISTS(SELECT 1 FROM receiving.ScanEvents WHERE ScanSessionId=@ScanSessionId)
     THROW 51308,'Sesion sin lecturas.',1;
   IF EXISTS(SELECT 1 FROM receiving.ScanEvents WHERE ScanSessionId=@ScanSessionId AND MatchStatus<>'matched')
     THROW 51309,'Hay codigos pendientes, ambiguos o rechazados.',1;
   IF EXISTS(SELECT 1 FROM receiving.ScanEvents e JOIN catalog.Items i ON i.Id=e.ItemId
     WHERE e.ScanSessionId=@ScanSessionId AND i.Status NOT IN ('active','draft'))
     THROW 51310,'Variante no habilitada para ingreso.',1;
   UPDATE receiving.ScanSessions SET Status='approved',ReviewedBy=@ReviewerId,ReviewedAt=SYSUTCDATETIME(),
     ClosedAt=SYSUTCDATETIME(),ModifiedBy=@ReviewerId,ModifiedAt=SYSUTCDATETIME()
     WHERE Id=@ScanSessionId;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [inventory].[usp_PostAdjustment]
 @AdjustmentId uniqueidentifier,@ItemId uniqueidentifier,@LocationId uniqueidentifier,
 @Pool varchar(12),@Delta int,@ActorId uniqueidentifier,@ApproverId uniqueidentifier,
 @Reason nvarchar(500),@OriginNodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Delta=0 OR LEN(LTRIM(RTRIM(@Reason)))=0 THROW 51105,'Ajuste invalido.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
  IF EXISTS(SELECT 1 FROM inventory.StockAdjustments WHERE Id=@AdjustmentId)
    BEGIN COMMIT; RETURN; END;
  IF @ActorId=@ApproverId THROW 51106,'Aprobador debe ser distinto del solicitante.',1;
  IF NOT EXISTS(SELECT 1 FROM core.Locations l JOIN security.StaffBranchAccess a ON a.BranchId=l.BranchId
      WHERE l.Id=@LocationId AND a.StaffId=@ApproverId AND a.IsActive=1)
    THROW 51107,'Aprobador no pertenece a la sucursal del ajuste.',1;
  DECLARE @op uniqueidentifier=NEWID(),@mv uniqueidentifier=NULL;
  INSERT INTO inventory.StockAdjustments(Id,ItemId,LocationId,Pool,QuantityDelta,Reason,
    ApprovedBy,MovementOperationId,CreatedBy)
    VALUES(@AdjustmentId,@ItemId,@LocationId,@Pool,@Delta,@Reason,@ApproverId,@op,@ActorId);
  EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@ItemId,@LocationId=@LocationId,
    @Pool=@Pool,@Kind='adjust',@OnHandDelta=@Delta,
    @SourceType='stock_adjustment',@SourceId=@AdjustmentId,@ActorId=@ActorId,@MovementId=@mv OUTPUT;
  DECLARE @event uniqueidentifier=NEWID(),@payload nvarchar(max)=(
   SELECT @AdjustmentId AS adjustmentId,@ItemId AS itemId,@LocationId AS locationId,
     @Pool AS pool,@Delta AS quantityDelta,@Reason AS reason FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  EXEC sync.usp_EnqueueEvent @event,@OriginNodeId,'stock_adjustment',@AdjustmentId,
    'inventory.adjusted',@payload;
  COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [catalog].[usp_RegisterItem]
 @ProductId uniqueidentifier,@Sku nvarchar(100),@VariantName nvarchar(200),
 @CurrencyCode varchar(3),@UnitPriceMinor bigint,@ItemId uniqueidentifier,
 @OriginNodeId uniqueidentifier,@EventId uniqueidentifier,
 @SizeId uniqueidentifier=NULL,@ColorId uniqueidentifier=NULL,@Barcode nvarchar(128)=NULL,
 @SupplierId uniqueidentifier=NULL,@SupplierSku nvarchar(128)=NULL,
 @UnitCostMinor bigint=NULL,@ActorId uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Barcode IS NULL AND @SupplierSku IS NULL
   THROW 51201,'Registrar codigo del proveedor o barcode antes de habilitar el escaneo.',1;
 IF @SupplierSku IS NOT NULL AND @SupplierId IS NULL
   THROW 51202,'SupplierSku necesita proveedor.',1;
 IF @UnitPriceMinor<0 THROW 51203,'Precio negativo.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM catalog.Items WITH(UPDLOCK,HOLDLOCK) WHERE Id=@ItemId)
   BEGIN
     IF NOT EXISTS(SELECT 1 FROM catalog.Items WHERE Id=@ItemId AND Sku=@Sku AND ProductId=@ProductId)
        THROW 51211,'ItemId reutilizado con otra variante.',1;
     COMMIT; RETURN;
   END;
   IF EXISTS(SELECT 1 FROM catalog.Items WITH(UPDLOCK,HOLDLOCK) WHERE Sku=@Sku)
     THROW 51212,'SKU interno ya usado por otra variante.',1;
   IF @Barcode IS NOT NULL AND EXISTS(SELECT 1 FROM catalog.ItemIdentifiers WITH(UPDLOCK,HOLDLOCK)
        WHERE RawCode=@Barcode AND Kind='barcode' AND SupplierId IS NULL AND IsActive=1)
     THROW 51204,'Barcode ya asociado a una variante. Buscar producto antes de crear.',1;
   IF @SupplierSku IS NOT NULL AND EXISTS(SELECT 1 FROM catalog.ItemIdentifiers WITH(UPDLOCK,HOLDLOCK)
        WHERE RawCode=@SupplierSku AND Kind='supplier_sku' AND SupplierId=@SupplierId AND IsActive=1)
     THROW 51205,'SKU del proveedor ya asociado. Revisar variante.',1;
   INSERT INTO catalog.Items(Id,ProductId,SizeId,ColorId,Sku,VariantName,CurrencyCode,
     UnitPriceMinor,UnitCostMinor,Status,CreatedBy)
     VALUES(@ItemId,@ProductId,@SizeId,@ColorId,@Sku,@VariantName,@CurrencyCode,
     @UnitPriceMinor,@UnitCostMinor,CASE WHEN @UnitPriceMinor=0 OR @UnitCostMinor IS NULL THEN 'draft' ELSE 'active' END,@ActorId);
   IF @Barcode IS NOT NULL
     INSERT INTO catalog.ItemIdentifiers(ItemId,Kind,RawCode,IsPrimary,CreatedBy)
       VALUES(@ItemId,'barcode',@Barcode,1,@ActorId);
   IF @SupplierSku IS NOT NULL
     INSERT INTO catalog.ItemIdentifiers(ItemId,SupplierId,Kind,RawCode,CreatedBy)
       VALUES(@ItemId,@SupplierId,'supplier_sku',@SupplierSku,@ActorId);
   DECLARE @payload nvarchar(max)=(SELECT @ItemId AS itemId,@ProductId AS productId,
       @Sku AS sku,@VariantName AS variantName,@SizeId AS sizeId,@ColorId AS colorId,
       @CurrencyCode AS currency,@UnitPriceMinor AS priceMinor,@UnitCostMinor AS costMinor,
       @Barcode AS barcode,@SupplierId AS supplierId,@SupplierSku AS supplierSku
       FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'item',@ItemId,
      'catalog.item_registered',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [catalog].[usp_ActivateItem]
 @ItemId uniqueidentifier,@UnitPriceMinor bigint,@UnitCostMinor bigint,
 @ActorId uniqueidentifier,@OriginNodeId uniqueidentifier,@EventId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @UnitPriceMinor<=0 OR @UnitCostMinor<0 THROW 51220,'Precio y costo deben estar aprobados.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   DECLARE @status varchar(16),@old bigint,@currency varchar(3);
   SELECT @status=Status,@old=UnitPriceMinor,@currency=CurrencyCode FROM catalog.Items WITH(UPDLOCK,HOLDLOCK)
      WHERE Id=@ItemId AND Status IN ('draft','active');
   IF @status IS NULL THROW 51221,'Variante no existe o inactiva.',1;
   UPDATE catalog.Items SET Status='active',UnitPriceMinor=@UnitPriceMinor,
      UnitCostMinor=@UnitCostMinor,ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId WHERE Id=@ItemId;
   -- A price already offered to customers changed: keep the trace, same as usp_ChangePrice.
   IF @status='active' AND @old<>@UnitPriceMinor
     INSERT INTO catalog.PriceHistory(ItemId,OldPriceMinor,NewPriceMinor,CurrencyCode,EffectiveAt,Reason,CreatedBy)
       VALUES(@ItemId,@old,@UnitPriceMinor,@currency,SYSUTCDATETIME(),N'Reactivacion con precio nuevo',@ActorId);
   DECLARE @payload nvarchar(max)=(SELECT @ItemId AS itemId,@UnitPriceMinor AS priceMinor,
        @UnitCostMinor AS costMinor,N'active' AS status FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'item',@ItemId,'catalog.item_activated',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [receiving].[usp_PostScanSession]
 @ScanSessionId uniqueidentifier,@ActorId uniqueidentifier,@OriginNodeId uniqueidentifier,
 @ReceiptId uniqueidentifier OUTPUT,@CurrencyCode varchar(3)='NIO'
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
  DECLARE @status varchar(16),@location uniqueidentifier,@container uniqueidentifier,@po uniqueidentifier;
  SELECT @status=s.Status,@location=c.LocationId,@container=c.Id,@po=c.PurchaseOrderId
    FROM receiving.ScanSessions s WITH(UPDLOCK,HOLDLOCK)
    JOIN receiving.ImportContainers c ON c.Id=s.ContainerId WHERE s.Id=@ScanSessionId;
  IF @status='posted'
  BEGIN
    SELECT @ReceiptId=Id FROM purchasing.GoodsReceipts WHERE ScanSessionId=@ScanSessionId;
    IF @ReceiptId IS NULL THROW 51311,'Sesion marcada posted sin comprobante.',1;
    COMMIT; RETURN;
  END;
  IF @status IS NULL OR @status<>'approved' THROW 51312,'Sesion requiere aprobacion previa.',1;
  IF NOT EXISTS(SELECT 1 FROM receiving.ScanEvents WHERE ScanSessionId=@ScanSessionId)
    THROW 51313,'No hay lecturas.',1;
  IF EXISTS(SELECT 1 FROM receiving.ScanEvents WHERE ScanSessionId=@ScanSessionId AND MatchStatus<>'matched')
    THROW 51314,'Hay codigos no resueltos.',1;
  IF EXISTS(SELECT 1 FROM receiving.ScanEvents e JOIN catalog.Items i ON i.Id=e.ItemId
    WHERE e.ScanSessionId=@ScanSessionId AND (i.Status NOT IN ('active','draft') OR i.CurrencyCode<>@CurrencyCode))
    THROW 51315,'Variante no activa o moneda distinta a la recepcion.',1;
  DECLARE @rows TABLE(RowNo int IDENTITY(1,1) PRIMARY KEY, ItemId uniqueidentifier,Qty int,Cost bigint NULL,Pool varchar(12));
  INSERT INTO @rows(ItemId,Qty,Cost,Pool)
   SELECT e.ItemId,SUM(e.Quantity),i.UnitCostMinor,
     CASE WHEN i.UnitCostMinor IS NULL OR i.Status<>'active' THEN 'quarantine' ELSE 'store' END
   FROM receiving.ScanEvents e JOIN catalog.Items i ON i.Id=e.ItemId
   WHERE e.ScanSessionId=@ScanSessionId GROUP BY e.ItemId,i.UnitCostMinor,i.Status;
  IF EXISTS(SELECT 1 FROM @rows WHERE Qty NOT BETWEEN 1 AND 1000000)
    THROW 51316,'Cantidad agrupada fuera de rango.',1;
  SET @ReceiptId=NEWID();
  INSERT INTO purchasing.GoodsReceipts(Id,ScanSessionId,PurchaseOrderId,ContainerId,LocationId,CurrencyCode,TotalCostMinor,CreatedBy)
     SELECT @ReceiptId,@ScanSessionId,@po,@container,@location,@CurrencyCode,
      CASE WHEN EXISTS(SELECT 1 FROM @rows WHERE Cost IS NULL) THEN NULL
      ELSE (SELECT SUM(CAST(Qty AS bigint)*Cost) FROM @rows) END,@ActorId;
  DECLARE @n int=1,@max int=(SELECT MAX(RowNo) FROM @rows),@item uniqueidentifier,
      @qty int,@cost bigint,@pool varchar(12),@line uniqueidentifier,@op uniqueidentifier,@movement uniqueidentifier;
  WHILE @n<=@max
  BEGIN
    SELECT @item=ItemId,@qty=Qty,@cost=Cost,@pool=Pool FROM @rows WHERE RowNo=@n;
    SET @line=NEWID(); SET @op=NEWID(); SET @movement=NULL;
    INSERT INTO purchasing.GoodsReceiptLines(Id,GoodsReceiptId,LineNumber,ItemId,Quantity,UnitCostMinor,Pool,CreatedBy)
      VALUES(@line,@ReceiptId,@n,@item,@qty,@cost,@pool,@ActorId);
    EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@location,@Pool=@pool,
      @Kind='receive',@OnHandDelta=@qty,@SourceType='goods_receipt_line',@SourceId=@line,
      @ActorId=@ActorId,@UnitCostMinor=@cost,@MovementId=@movement OUTPUT;
    SET @n+=1;
  END;
  UPDATE receiving.ScanSessions SET Status='posted',ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME()
    WHERE Id=@ScanSessionId;
  -- The container is done when none of its sessions is still in progress. usp_OpenScanSession
  -- then rejects a new session on it (51324), so the same container cannot be received twice.
  IF NOT EXISTS(SELECT 1 FROM receiving.ScanSessions WITH(UPDLOCK,HOLDLOCK)
      WHERE ContainerId=@container AND Status IN ('counting','review','approved'))
    UPDATE receiving.ImportContainers SET Status='closed',ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME()
      WHERE Id=@container AND Status<>'closed';
  EXEC labels.usp_QueueReceiptLabels @ReceiptId,@ActorId;
  DECLARE @event uniqueidentifier=NEWID(),@payload nvarchar(max)=(
    SELECT @ReceiptId AS receiptId,@ScanSessionId AS scanSessionId,@container AS containerId,
       @location AS locationId,@OriginNodeId AS originNodeId,
       JSON_QUERY((SELECT ItemId,Quantity,Pool,UnitCostMinor FROM purchasing.GoodsReceiptLines
         WHERE GoodsReceiptId=@ReceiptId ORDER BY LineNumber FOR JSON PATH)) AS lines
       FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  EXEC sync.usp_EnqueueEvent @event,@OriginNodeId,'goods_receipt',@ReceiptId,'inventory.receipt_posted',@payload;
  COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

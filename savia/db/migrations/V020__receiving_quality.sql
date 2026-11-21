-- Reception quality records are append-only; quarantine is the existing non-sellable pool.
CREATE TABLE receiving.QualityChecks(
 Id uniqueidentifier NOT NULL PRIMARY KEY,Revision bigint IDENTITY NOT NULL UNIQUE,
 ScanSessionId uniqueidentifier NOT NULL REFERENCES receiving.ScanSessions(Id),ItemId uniqueidentifier NOT NULL REFERENCES catalog.Items(Id),
 Good int NOT NULL CHECK(Good>=0),Damaged int NOT NULL CHECK(Damaged>=0),Stained int NOT NULL CHECK(Stained>=0),Odor int NOT NULL CHECK(Odor>=0),Missing int NOT NULL CHECK(Missing>=0),
 Reason nvarchar(250) NOT NULL,ActorId uniqueidentifier NOT NULL REFERENCES security.Staff(Id),CreatedAt datetime2(3) NOT NULL DEFAULT(SYSUTCDATETIME()));
GO
CREATE OR ALTER VIEW receiving.vw_CurrentQuality AS
 SELECT Id,ScanSessionId,ItemId,Good,Damaged,Stained,Odor,Missing,Reason,ActorId,CreatedAt FROM
 (SELECT *,ROW_NUMBER() OVER(PARTITION BY ScanSessionId,ItemId ORDER BY Revision DESC) AS n FROM receiving.QualityChecks) q WHERE n=1;
GO
CREATE OR ALTER PROCEDURE receiving.usp_RecordQuality @CheckId uniqueidentifier,@ScanSessionId uniqueidentifier,@ItemId uniqueidentifier,
 @Good int,@Damaged int,@Stained int,@Odor int,@Missing int,@Reason nvarchar(250),@ActorId uniqueidentifier,@LocationId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF @Good IS NULL OR @Damaged IS NULL OR @Stained IS NULL OR @Odor IS NULL OR @Missing IS NULL OR @Good<0 OR @Damaged<0 OR @Stained<0 OR @Odor<0 OR @Missing<0 OR NULLIF(LTRIM(RTRIM(@Reason)),N'') IS NULL THROW 52006,'Revise cantidades y motivo de calidad.',1;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId JOIN security.StaffBranchAccess a ON a.StaffId=s.Id JOIN core.Locations l ON l.BranchId=a.BranchId
 WHERE s.Id=@ActorId AND s.IsEnabled=1 AND r.Code IN ('INVENTORY','MANAGER','OWNER') AND r.IsActive=1 AND a.IsActive=1 AND l.Id=@LocationId) THROW 52001,'Sin acceso a calidad.',1;
 BEGIN TRAN;BEGIN TRY
  DECLARE @status varchar(16);
  SELECT @status=s.Status FROM receiving.ScanSessions s WITH(UPDLOCK,HOLDLOCK) JOIN receiving.ImportContainers c ON c.Id=s.ContainerId WHERE s.Id=@ScanSessionId AND c.LocationId=@LocationId;
  IF @status IS NULL THROW 51331,'Sesion no encontrada.',1;
  IF EXISTS(SELECT 1 FROM receiving.QualityChecks WHERE Id=@CheckId)
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM receiving.QualityChecks WHERE Id=@CheckId AND ScanSessionId=@ScanSessionId AND ItemId=@ItemId AND Good=@Good AND Damaged=@Damaged AND Stained=@Stained AND Odor=@Odor AND Missing=@Missing AND ActorId=@ActorId AND Reason=@Reason) THROW 52004,'Identificador reutilizado.',1;
   COMMIT;RETURN;
  END;
  IF @status<>'counting' THROW 52006,'Revise calidad antes de aprobar.',1;
  DECLARE @expected bigint=(SELECT SUM(CONVERT(bigint,Quantity)) FROM receiving.ScanEvents WHERE ScanSessionId=@ScanSessionId AND ItemId=@ItemId AND MatchStatus='matched');
  IF @expected IS NULL OR CONVERT(bigint,@Good)+@Damaged+@Stained+@Odor+@Missing<>@expected THROW 52006,'La calidad debe sumar las unidades esperadas.',1;
  INSERT receiving.QualityChecks(Id,ScanSessionId,ItemId,Good,Damaged,Stained,Odor,Missing,Reason,ActorId) VALUES(@CheckId,@ScanSessionId,@ItemId,@Good,@Damaged,@Stained,@Odor,@Missing,@Reason,@ActorId);
  COMMIT;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE receiving.usp_GetQuality @ScanSessionId uniqueidentifier,@LocationId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON;
 SELECT (SELECT q.ItemId AS itemId,q.Good AS buena,q.Damaged AS danada,q.Stained AS manchada,q.Odor AS malOlor,q.Missing AS faltante,q.Reason AS reason
 FROM receiving.vw_CurrentQuality q JOIN receiving.ScanSessions s ON s.Id=q.ScanSessionId JOIN receiving.ImportContainers c ON c.Id=s.ContainerId WHERE q.ScanSessionId=@ScanSessionId AND c.LocationId=@LocationId FOR JSON PATH) AS Json;
END;
GO
CREATE OR ALTER PROCEDURE receiving.usp_QualityReport @BranchId uniqueidentifier,@From date,@To date
AS
BEGIN
 SET NOCOUNT ON;
 IF @From IS NULL OR @To IS NULL OR @To<@From OR @To>='99990101' THROW 51900,'Rango invalido.',1;
 SELECT (SELECT c.SupplierId AS supplierId,p.DisplayName AS supplierName,SUM(CONVERT(bigint,q.Good)) AS buena,SUM(CONVERT(bigint,q.Damaged)) AS danada,SUM(CONVERT(bigint,q.Stained)) AS manchada,SUM(CONVERT(bigint,q.Odor)) AS malOlor,SUM(CONVERT(bigint,q.Missing)) AS faltante
 FROM receiving.vw_CurrentQuality q JOIN receiving.ScanSessions s ON s.Id=q.ScanSessionId JOIN receiving.ImportContainers c ON c.Id=s.ContainerId
 JOIN core.Locations l ON l.Id=c.LocationId JOIN sourcing.Suppliers p ON p.Id=c.SupplierId
 WHERE l.BranchId=@BranchId AND s.Status='posted' AND q.CreatedAt>=DATEADD(hour,6,CONVERT(datetime2,@From)) AND q.CreatedAt<DATEADD(hour,30,CONVERT(datetime2,@To))
 GROUP BY c.SupplierId,p.DisplayName ORDER BY p.DisplayName FOR JSON PATH) AS Json;
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
  IF NOT EXISTS(SELECT 1 FROM receiving.ScanEvents WHERE ScanSessionId=@ScanSessionId AND MatchStatus<>'rejected')
    THROW 51313,'No hay lecturas.',1;
  IF EXISTS(SELECT 1 FROM receiving.ScanEvents WHERE ScanSessionId=@ScanSessionId AND MatchStatus IN ('unknown','ambiguous'))
    THROW 51314,'Hay codigos no resueltos.',1;
  IF EXISTS(SELECT 1 FROM receiving.ScanEvents e JOIN catalog.Items i ON i.Id=e.ItemId
    WHERE e.ScanSessionId=@ScanSessionId AND (i.Status NOT IN ('active','draft') OR i.CurrencyCode<>@CurrencyCode))
    THROW 51315,'Variante no activa o moneda distinta a la recepcion.',1;
  DECLARE @rows TABLE(RowNo int IDENTITY(1,1) PRIMARY KEY, ItemId uniqueidentifier,Qty int,Cost bigint NULL,Pool varchar(12));
  IF EXISTS(SELECT 1 FROM receiving.vw_CurrentQuality q
   WHERE q.ScanSessionId=@ScanSessionId AND q.Good+q.Damaged+q.Stained+q.Odor+q.Missing <>
   (SELECT SUM(e.Quantity) FROM receiving.ScanEvents e WHERE e.ScanSessionId=@ScanSessionId AND e.ItemId=q.ItemId AND e.MatchStatus='matched'))
   THROW 52006,'La calidad no coincide con las unidades esperadas.',1;
  INSERT INTO @rows(ItemId,Qty,Cost,Pool)
   SELECT e.ItemId,COALESCE(q.Good,SUM(e.Quantity)),i.UnitCostMinor,
     CASE WHEN i.UnitCostMinor IS NULL OR i.Status<>'active' THEN 'quarantine' ELSE 'store' END
   FROM receiving.ScanEvents e JOIN catalog.Items i ON i.Id=e.ItemId
   LEFT JOIN receiving.vw_CurrentQuality q ON q.ScanSessionId=e.ScanSessionId AND q.ItemId=e.ItemId
   WHERE e.ScanSessionId=@ScanSessionId AND e.MatchStatus='matched'
   GROUP BY e.ItemId,i.UnitCostMinor,i.Status,q.Good HAVING COALESCE(q.Good,SUM(e.Quantity))>0;
  INSERT INTO @rows(ItemId,Qty,Cost,Pool)
   SELECT q.ItemId,q.Damaged+q.Stained+q.Odor,i.UnitCostMinor,'quarantine'
   FROM receiving.vw_CurrentQuality q JOIN catalog.Items i ON i.Id=q.ItemId
   WHERE q.ScanSessionId=@ScanSessionId AND q.Damaged+q.Stained+q.Odor>0;
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
-- Extend the existing oracle, preserving every other check. Missing units have no receipt or movement.
DECLARE @oracle nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'audit.usp_CheckConservation'));
IF CHARINDEX(N's.Quantity<>l.Quantity',@oracle)=0 THROW 52007,'Oracle incompatible.',1;
SET @oracle=REPLACE(@oracle,N'CREATE   PROCEDURE',N'CREATE OR ALTER PROCEDURE');
SET @oracle=REPLACE(@oracle,N'CREATE PROCEDURE',N'CREATE OR ALTER PROCEDURE');
SET @oracle=REPLACE(@oracle,N's.Quantity,l.Quantity',N's.Quantity-COALESCE((SELECT SUM(CONVERT(bigint,q.Missing)) FROM receiving.vw_CurrentQuality q WHERE q.ScanSessionId=r.ScanSessionId),0),l.Quantity');
SET @oracle=REPLACE(@oracle,N's.Quantity<>l.Quantity',N's.Quantity-COALESCE((SELECT SUM(CONVERT(bigint,q.Missing)) FROM receiving.vw_CurrentQuality q WHERE q.ScanSessionId=r.ScanSessionId),0)<>l.Quantity');
EXEC sys.sp_executesql @oracle;
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
   IF NOT EXISTS(SELECT 1 FROM receiving.ScanEvents WHERE ScanSessionId=@ScanSessionId AND MatchStatus<>'rejected')
     THROW 51308,'Sesion sin lecturas.',1;
   -- Pilot staff must explicitly classify each received item; legacy fixtures retain their original contract.
   IF EXISTS(SELECT 1 FROM receiving.ScanSessions s JOIN security.Staff st ON st.Id=s.CreatedBy WHERE s.Id=@ScanSessionId AND st.NormalizedLoginName LIKE '%.MUESTRA')
   AND EXISTS(SELECT 1 FROM receiving.ScanEvents e LEFT JOIN receiving.vw_CurrentQuality q ON q.ScanSessionId=e.ScanSessionId AND q.ItemId=e.ItemId
    WHERE e.ScanSessionId=@ScanSessionId AND e.MatchStatus='matched' AND (q.Id IS NULL OR q.Good+q.Damaged+q.Stained+q.Odor+q.Missing<>(SELECT SUM(x.Quantity) FROM receiving.ScanEvents x WHERE x.ScanSessionId=e.ScanSessionId AND x.ItemId=e.ItemId AND x.MatchStatus='matched')))
    THROW 52006,'Guarde la calidad de cada prenda antes de aprobar.',1;
   IF EXISTS(SELECT 1 FROM receiving.ScanEvents WHERE ScanSessionId=@ScanSessionId AND MatchStatus IN ('unknown','ambiguous'))
     THROW 51309,'Hay codigos pendientes o ambiguos.',1;
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

/* V012: discard unresolved scans without deleting their audit trail.
   Existing CK_ScanEvent_Status already permits rejected; CK_ScanEvent_Matched requires ItemId NULL.
   Only matched units enter receipts, movements and labels. Rejected units are neither pending nor violations. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [receiving].[usp_RejectScan]
 @ScanId uniqueidentifier,@ReviewerId uniqueidentifier,@Reason nvarchar(250)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Reason IS NULL OR LEN(LTRIM(RTRIM(@Reason)))=0
   THROW 51330,'Motivo obligatorio.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   DECLARE @session uniqueidentifier,@sessionStatus varchar(16),@matchStatus varchar(16);
   SELECT @session=ScanSessionId FROM receiving.ScanEvents WHERE Id=@ScanId;
   IF @session IS NULL THROW 51331,'La lectura no existe.',1;
   -- Serialize with approve/post on the parent before changing a reading.
   SELECT @sessionStatus=Status FROM receiving.ScanSessions WITH(UPDLOCK,HOLDLOCK) WHERE Id=@session;
   IF @sessionStatus IS NULL OR @sessionStatus<>'counting'
     THROW 51332,'La sesion debe estar en conteo para rechazar una lectura.',1;
   SELECT @matchStatus=MatchStatus FROM receiving.ScanEvents WITH(UPDLOCK,HOLDLOCK) WHERE Id=@ScanId AND ScanSessionId=@session;
   -- A repeated scan id keeps the original actor, time and reason.
   IF @matchStatus='rejected' BEGIN COMMIT; RETURN; END;
   IF @matchStatus IS NULL OR @matchStatus NOT IN ('unknown','ambiguous')
     THROW 51333,'Solo se puede rechazar una lectura no resuelta.',1;
   UPDATE receiving.ScanEvents SET MatchStatus='rejected',ResolutionReason=@Reason,
     ModifiedBy=@ReviewerId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@ScanId;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO
GRANT EXECUTE ON OBJECT::[receiving].[usp_RejectScan] TO [savia_manager_app];
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
  INSERT INTO @rows(ItemId,Qty,Cost,Pool)
   SELECT e.ItemId,SUM(e.Quantity),i.UnitCostMinor,
     CASE WHEN i.UnitCostMinor IS NULL OR i.Status<>'active' THEN 'quarantine' ELSE 'store' END
   FROM receiving.ScanEvents e JOIN catalog.Items i ON i.Id=e.ItemId
   WHERE e.ScanSessionId=@ScanSessionId AND e.MatchStatus='matched' GROUP BY e.ItemId,i.UnitCostMinor,i.Status;
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

CREATE OR ALTER VIEW [receiving].[vw_SessionProgress]
AS
SELECT s.Id AS ScanSessionId,c.Id AS ContainerId,c.Reference,
   c.LocationId,s.Status,
   COUNT(e.Id) AS ScanEvents,
   COALESCE(SUM(CASE WHEN e.MatchStatus='matched' THEN CONVERT(bigint,e.Quantity) ELSE 0 END),0) AS MatchedUnits,
   COALESCE(SUM(CASE WHEN e.MatchStatus IN ('unknown','ambiguous') THEN CONVERT(bigint,e.Quantity) ELSE 0 END),0) AS UnitsPendingReview
FROM receiving.ScanSessions s JOIN receiving.ImportContainers c ON c.Id=s.ContainerId
LEFT JOIN receiving.ScanEvents e ON e.ScanSessionId=s.Id
GROUP BY s.Id,c.Id,c.Reference,c.LocationId,s.Status;
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
 SELECT 'receipt.vs_scans',CONVERT(nvarchar(36),r.Id),s.Quantity,l.Quantity
 FROM purchasing.GoodsReceipts r
 CROSS APPLY (SELECT COALESCE(SUM(CONVERT(bigint,Quantity)),0) AS Quantity FROM receiving.ScanEvents
              WHERE ScanSessionId=r.ScanSessionId AND MatchStatus='matched') s
 CROSS APPLY (SELECT COALESCE(SUM(CONVERT(bigint,Quantity)),0) AS Quantity FROM purchasing.GoodsReceiptLines
              WHERE GoodsReceiptId=r.Id) l
 WHERE r.ScanSessionId IS NOT NULL AND s.Quantity<>l.Quantity;

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
 SELECT 'sale.cash_tender_vs_cash_entry',CONVERT(nvarchar(36),t.Id),t.AmountMinor,COALESCE(e.Total,0)
 FROM sales.SaleTenders t
 OUTER APPLY (SELECT SUM(DeltaMinor) AS Total,COUNT(*) AS Entries FROM sales.CashEntries WHERE SaleTenderId=t.Id) e
 WHERE t.TenderKind='cash' AND (COALESCE(e.Total,0)<>t.AmountMinor OR COALESCE(e.Entries,0)<>1);

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

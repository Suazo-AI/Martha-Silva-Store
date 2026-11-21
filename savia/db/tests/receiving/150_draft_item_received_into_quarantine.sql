-- TEST: a variant without approved cost is received into the quarantine pool and never into the store pool.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@draft uniqueidentifier=test.Id('itemDraft'),
  @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),@scan uniqueidentifier=NEWID(),
  @receipt uniqueidentifier,@n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id=@draft AND Status='draft' AND UnitCostMinor IS NULL);
EXEC test.AssertEq N'the variant starts as draft without approved cost',1,@n;

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-150',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000555000111',4,NULL,@actor;
EXEC receiving.usp_ApproveScanSession @session,@reviewer;
EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@actor,@OriginNodeId=@node,
  @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;

SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceiptLines WHERE GoodsReceiptId=@receipt AND ItemId=@draft
        AND Quantity=4 AND Pool='quarantine' AND UnitCostMinor IS NULL);
EXEC test.AssertEq N'the receipt line goes to quarantine',1,@n;
SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceipts WHERE Id=@receipt AND TotalCostMinor IS NULL);
EXEC test.AssertEq N'the receipt has no approved cost yet',1,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@draft AND LocationId=@loc AND Pool='quarantine');
EXEC test.AssertEq N'quarantine stock',4,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances WHERE ItemId=@draft AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'store stock of the variant without cost',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE ItemId=@draft AND LocationId=@loc
        AND Pool='quarantine' AND OnHandDelta=4);
EXEC test.AssertEq N'quarantine movements',1,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE ItemId=@draft AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'store movements of the variant without cost',0,@n;
-- The balance is the sum of the movements.
SET @n=(SELECT COUNT(*) FROM inventory.StockBalances b
        LEFT JOIN (SELECT ItemId,LocationId,Pool,SUM(OnHandDelta) OnHandSum,SUM(ReservedDelta) ReservedSum
                   FROM inventory.StockMovements GROUP BY ItemId,LocationId,Pool) m
          ON m.ItemId=b.ItemId AND m.LocationId=b.LocationId AND m.Pool=b.Pool
        WHERE b.OnHand<>ISNULL(m.OnHandSum,0) OR b.Reserved<>ISNULL(m.ReservedSum,0));
EXEC test.AssertEq N'balances that disagree with the movements',0,@n;
-- The label keeps the leading zeros of the barcode.
SET @n=(SELECT COUNT(*) FROM labels.PrintJobs WHERE ItemId=@draft AND CopiesRequested=4
        AND BarcodeSnapshot=N'0000555000111');
EXEC test.AssertEq N'label job with the leading zeros',1,@n;
PRINT 'PASS';

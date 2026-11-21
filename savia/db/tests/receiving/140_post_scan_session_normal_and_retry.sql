-- TEST: usp_PostScanSession receives the counted quantities in one receipt line, moves the stock once, queues the labels and writes one event; a retry returns the same receipt.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@branch uniqueidentifier=test.Id('branchA'),
  @supplier uniqueidentifier=test.Id('supplier'),@actor uniqueidentifier=test.Id('cashierA'),
  @reviewer uniqueidentifier=test.Id('supervisorA'),@node uniqueidentifier=test.Id('nodeA'),
  @item uniqueidentifier=test.Id('item'),@container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),
  @scan uniqueidentifier=NEWID(),@scan2 uniqueidentifier=NEWID(),@receipt uniqueidentifier,
  @receipt2 uniqueidentifier,@n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-140',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',2,NULL,@actor;
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan2,@session,N'0000123456789',3,NULL,@actor;
EXEC receiving.usp_ApproveScanSession @session,@reviewer;

EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@actor,@OriginNodeId=@node,
  @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;

SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceipts WHERE Id=@receipt AND ScanSessionId=@session
        AND LocationId=@loc AND CurrencyCode='NIO' AND TotalCostMinor=300000);
EXEC test.AssertEq N'the receipt with the total cost',1,@n;
SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceiptLines WHERE GoodsReceiptId=@receipt AND ItemId=@item
        AND Quantity=5 AND UnitCostMinor=60000 AND Pool='store');
EXEC test.AssertEq N'one receipt line with the summed quantity',1,@n;
SET @n=(SELECT COUNT(*) FROM receiving.ScanSessions WHERE Id=@session AND Status='posted');
EXEC test.AssertEq N'session posted',1,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE ItemId=@item AND LocationId=@loc AND Pool='store'
        AND Kind='receive' AND OnHandDelta=5);
EXEC test.AssertEq N'receive movements',1,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'store stock',5,@n;
SET @n=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'reserved stock',0,@n;
-- The balance is the sum of the movements.
SET @n=(SELECT COUNT(*) FROM inventory.StockBalances b
        LEFT JOIN (SELECT ItemId,LocationId,Pool,SUM(OnHandDelta) OnHandSum,SUM(ReservedDelta) ReservedSum
                   FROM inventory.StockMovements GROUP BY ItemId,LocationId,Pool) m
          ON m.ItemId=b.ItemId AND m.LocationId=b.LocationId AND m.Pool=b.Pool
        WHERE b.OnHand<>ISNULL(m.OnHandSum,0) OR b.Reserved<>ISNULL(m.ReservedSum,0));
EXEC test.AssertEq N'balances that disagree with the movements',0,@n;
-- The label carries the original code and the leading zeros.
SET @n=(SELECT COUNT(*) FROM labels.PrintJobs WHERE ItemId=@item AND BranchId=@branch
        AND CopiesRequested=5 AND SkuSnapshot=N'PROV-0001' AND BarcodeSnapshot=N'0000123456789'
        AND StoreNameSnapshot=N'SAVIA Test');
EXEC test.AssertEq N'label job with the original code and the leading zeros',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@receipt AND AggregateType='goods_receipt'
        AND EventType='inventory.receipt_posted');
EXEC test.AssertEq N'receipt posted event in outbox',1,@n;

-- Retry with the same ids: the client never got the reply.
EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@actor,@OriginNodeId=@node,
  @CurrencyCode='NIO',@ReceiptId=@receipt2 OUTPUT;

SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceipts WHERE ScanSessionId=@session);
EXEC test.AssertEq N'receipts after the retry',1,@n;
SET @n=(SELECT CASE WHEN @receipt2=@receipt THEN 1 ELSE 0 END);
EXEC test.AssertEq N'the retry returns the same receipt',1,@n;
SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceiptLines WHERE GoodsReceiptId=@receipt);
EXEC test.AssertEq N'receipt lines after the retry',1,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE ItemId=@item AND LocationId=@loc);
EXEC test.AssertEq N'stock movements after the retry',1,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'store stock after the retry',5,@n;
SET @n=(SELECT COUNT(*) FROM labels.PrintJobs WHERE ItemId=@item);
EXEC test.AssertEq N'label jobs after the retry',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@receipt AND EventType='inventory.receipt_posted');
EXEC test.AssertEq N'receipt events after the retry',1,@n;
PRINT 'PASS';

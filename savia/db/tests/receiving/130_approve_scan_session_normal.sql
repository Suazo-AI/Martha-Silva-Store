-- TEST: usp_ApproveScanSession approves a session whose reads are all matched and records who reviewed it.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@item uniqueidentifier=test.Id('item'),
  @item2 uniqueidentifier=test.Id('item2'),@container uniqueidentifier=NEWID(),
  @session uniqueidentifier=NEWID(),@scan uniqueidentifier=NEWID(),@scan2 uniqueidentifier=NEWID(),
  @receipt uniqueidentifier,@n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-130',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',2,NULL,@actor;
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan2,@session,N'0000987654321',1,NULL,@actor;

EXEC receiving.usp_ApproveScanSession @session,@reviewer;

SET @n=(SELECT COUNT(*) FROM receiving.ScanSessions WHERE Id=@session AND Status='approved' AND ReviewedBy=@reviewer);
EXEC test.AssertEq N'session approved by the reviewer',1,@n;
SET @n=(SELECT COUNT(*) FROM receiving.ScanSessions WHERE Id=@session AND ReviewedAt IS NOT NULL AND ClosedAt IS NOT NULL);
EXEC test.AssertEq N'review and close stamps written',1,@n;

-- Approving does not move stock: only the posting does.
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances);
EXEC test.AssertEq N'stock after the approval',0,@n;
SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceipts);
EXEC test.AssertEq N'receipts after the approval',0,@n;

-- The approved session can be posted and gives the expected stock.
EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@actor,@OriginNodeId=@node,
  @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;
SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceiptLines WHERE GoodsReceiptId=@receipt);
EXEC test.AssertEq N'receipt lines',2,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc);
EXEC test.AssertEq N'stock of the first variant',2,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances WHERE ItemId=@item2 AND LocationId=@loc);
EXEC test.AssertEq N'stock of the second variant',1,@n;
PRINT 'PASS';

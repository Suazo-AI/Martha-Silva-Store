-- TEST: usp_PostScanSession rejects a session marked posted without a receipt (51311) and a counted quantity out of range (51316).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@container uniqueidentifier=NEWID(),
  @sessionPosted uniqueidentifier=NEWID(),@sessionBig uniqueidentifier=NEWID(),
  @scan uniqueidentifier=NEWID(),@scan2 uniqueidentifier=NEWID(),@receipt uniqueidentifier,
  @i int=0,@n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-142',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@sessionPosted,@container,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@sessionBig,@container,'counting',@actor);

-- 51311: the session says posted but there is no receipt.
UPDATE receiving.ScanSessions SET Status='posted' WHERE Id=@sessionPosted;
BEGIN TRY
  EXEC receiving.usp_PostScanSession @ScanSessionId=@sessionPosted,@ActorId=@actor,@OriginNodeId=@node,
    @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;
  THROW 59002,'ASSERT FAIL: a session posted without receipt was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51311 THROW; END CATCH;

-- 51316: the counted quantity grouped by variant is out of range (101 reads of 10000 units).
WHILE @i<101
BEGIN
  SET @scan2=NEWID();
  INSERT INTO @sink EXEC receiving.usp_RecordScan @scan2,@sessionBig,N'0000123456789',10000,NULL,@actor;
  SET @i+=1;
END;
UPDATE receiving.ScanSessions SET Status='approved' WHERE Id=@sessionBig;
BEGIN TRY
  EXEC receiving.usp_PostScanSession @ScanSessionId=@sessionBig,@ActorId=@actor,@OriginNodeId=@node,
    @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;
  THROW 59002,'ASSERT FAIL: a session with an out of range quantity was posted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51316 THROW; END CATCH;

-- Nothing was received.
SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceipts);
EXEC test.AssertEq N'receipts after the rejections',0,@n;
SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceiptLines);
EXEC test.AssertEq N'receipt lines after the rejections',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements);
EXEC test.AssertEq N'stock movements after the rejections',0,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances);
EXEC test.AssertEq N'stock after the rejections',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventType='inventory.receipt_posted');
EXEC test.AssertEq N'receipt events after the rejections',0,@n;
PRINT 'PASS';

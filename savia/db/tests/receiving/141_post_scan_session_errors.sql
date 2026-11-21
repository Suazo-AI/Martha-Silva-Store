-- TEST: usp_PostScanSession rejects a session that is not approved (51312), without reads (51313), with pending codes (51314) and with a variant that is not active or in another currency (51315).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@item uniqueidentifier=test.Id('item'),
  @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),
  @sessionEmpty uniqueidentifier=NEWID(),@sessionPending uniqueidentifier=NEWID(),
  @sessionBlocked uniqueidentifier=NEWID(),@sessionCurrency uniqueidentifier=NEWID(),
  @scan uniqueidentifier=NEWID(),@scanPending uniqueidentifier=NEWID(),
  @scanBlocked uniqueidentifier=NEWID(),@scanCurrency uniqueidentifier=NEWID(),
  @receipt uniqueidentifier,@n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-141',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@sessionEmpty,@container,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@sessionPending,@container,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@sessionBlocked,@container,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@sessionCurrency,@container,'counting',@actor);

-- The reads are taken while the sessions are open; the approval is then forced
-- to reach the states the normal flow would never leave behind.
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',2,NULL,@actor;
INSERT INTO @sink EXEC receiving.usp_RecordScan @scanPending,@sessionPending,N'NO-EXISTE-9999',1,NULL,@actor;
INSERT INTO @sink EXEC receiving.usp_RecordScan @scanBlocked,@sessionBlocked,N'0000123456789',1,NULL,@actor;
INSERT INTO @sink EXEC receiving.usp_RecordScan @scanCurrency,@sessionCurrency,N'0000123456789',1,NULL,@actor;
UPDATE receiving.ScanSessions SET Status='approved'
  WHERE Id IN (@sessionEmpty,@sessionPending,@sessionBlocked,@sessionCurrency);

-- 51312: the session was never approved.
BEGIN TRY
  EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@actor,@OriginNodeId=@node,
    @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;
  THROW 59002,'ASSERT FAIL: a session without approval was posted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51312 THROW; END CATCH;

-- 51313: the session has no reads.
BEGIN TRY
  EXEC receiving.usp_PostScanSession @ScanSessionId=@sessionEmpty,@ActorId=@actor,@OriginNodeId=@node,
    @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;
  THROW 59002,'ASSERT FAIL: a session without reads was posted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51313 THROW; END CATCH;

-- 51314: the session has a code that is not matched.
BEGIN TRY
  EXEC receiving.usp_PostScanSession @ScanSessionId=@sessionPending,@ActorId=@actor,@OriginNodeId=@node,
    @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;
  THROW 59002,'ASSERT FAIL: a session with pending codes was posted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51314 THROW; END CATCH;

-- 51315: the variant is not active.
UPDATE catalog.Items SET Status='inactive' WHERE Id=@item;
BEGIN TRY
  EXEC receiving.usp_PostScanSession @ScanSessionId=@sessionBlocked,@ActorId=@actor,@OriginNodeId=@node,
    @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;
  THROW 59002,'ASSERT FAIL: a session with a disabled variant was posted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51315 THROW; END CATCH;
UPDATE catalog.Items SET Status='active' WHERE Id=@item;

-- 51315: the variant is in another currency than the reception.
UPDATE catalog.Items SET CurrencyCode='USD' WHERE Id=@item;
BEGIN TRY
  EXEC receiving.usp_PostScanSession @ScanSessionId=@sessionCurrency,@ActorId=@actor,@OriginNodeId=@node,
    @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;
  THROW 59002,'ASSERT FAIL: a session in another currency was posted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51315 THROW; END CATCH;
UPDATE catalog.Items SET CurrencyCode='NIO' WHERE Id=@item;

-- Nothing was received: no receipt, no movement, no label and no event.
SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceipts);
EXEC test.AssertEq N'receipts after the rejections',0,@n;
SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceiptLines);
EXEC test.AssertEq N'receipt lines after the rejections',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements);
EXEC test.AssertEq N'stock movements after the rejections',0,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances);
EXEC test.AssertEq N'stock after the rejections',0,@n;
SET @n=(SELECT COUNT(*) FROM labels.PrintJobs);
EXEC test.AssertEq N'label jobs after the rejections',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventType='inventory.receipt_posted');
EXEC test.AssertEq N'receipt events after the rejections',0,@n;
PRINT 'PASS';

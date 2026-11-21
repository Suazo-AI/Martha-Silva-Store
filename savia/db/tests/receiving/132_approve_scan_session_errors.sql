-- TEST: usp_ApproveScanSession rejects a session that is not open (51307), a session without reads (51308), a session with pending codes (51309) and a variant that is not enabled for ingress (51310).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),
  @item uniqueidentifier=test.Id('item'),@container uniqueidentifier=NEWID(),
  @session uniqueidentifier=NEWID(),@sessionEmpty uniqueidentifier=NEWID(),
  @sessionPending uniqueidentifier=NEWID(),@sessionBlocked uniqueidentifier=NEWID(),
  @scan uniqueidentifier=NEWID(),@scanPending uniqueidentifier=NEWID(),@scanBlocked uniqueidentifier=NEWID(),
  @missing uniqueidentifier=NEWID(),@n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-132',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@sessionEmpty,@container,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@sessionPending,@container,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@sessionBlocked,@container,'counting',@actor);

-- 51307: the session does not exist.
BEGIN TRY
  EXEC receiving.usp_ApproveScanSession @missing,@reviewer;
  THROW 59002,'ASSERT FAIL: a missing session was approved',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51307 THROW; END CATCH;

-- 51308: the session has no reads.
BEGIN TRY
  EXEC receiving.usp_ApproveScanSession @sessionEmpty,@reviewer;
  THROW 59002,'ASSERT FAIL: a session without reads was approved',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51308 THROW; END CATCH;

-- 51309: the session has a code that is not matched.
INSERT INTO @sink EXEC receiving.usp_RecordScan @scanPending,@sessionPending,N'NO-EXISTE-9999',1,NULL,@actor;
BEGIN TRY
  EXEC receiving.usp_ApproveScanSession @sessionPending,@reviewer;
  THROW 59002,'ASSERT FAIL: a session with a pending code was approved',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51309 THROW; END CATCH;

-- 51310: the variant is not enabled for ingress.
UPDATE catalog.Items SET Status='inactive' WHERE Id=@item;
INSERT INTO @sink EXEC receiving.usp_RecordScan @scanBlocked,@sessionBlocked,N'0000123456789',1,NULL,@actor;
BEGIN TRY
  EXEC receiving.usp_ApproveScanSession @sessionBlocked,@reviewer;
  THROW 59002,'ASSERT FAIL: a session with a disabled variant was approved',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51310 THROW; END CATCH;

-- No session was approved and nothing was received.
SET @n=(SELECT COUNT(*) FROM receiving.ScanSessions WHERE Id IN (@session,@sessionEmpty,@sessionPending,@sessionBlocked)
        AND Status='approved');
EXEC test.AssertEq N'approved sessions after the rejections',0,@n;
SET @n=(SELECT COUNT(*) FROM receiving.ScanSessions WHERE Id IN (@session,@sessionEmpty,@sessionPending,@sessionBlocked)
        AND ReviewedBy IS NOT NULL);
EXEC test.AssertEq N'sessions with a reviewer after the rejections',0,@n;
SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceipts);
EXEC test.AssertEq N'receipts after the rejections',0,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances);
EXEC test.AssertEq N'stock after the rejections',0,@n;
PRINT 'PASS';

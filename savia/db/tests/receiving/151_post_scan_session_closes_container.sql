-- TEST: a container whose reception was posted is closed, so the same container cannot be received again.
-- FIXED (V005): D-A-06 was: usp_PostScanSession never closes the ImportContainer: its status stays 'counting' after the receipt is posted.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@item uniqueidentifier=test.Id('item'),
  @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),@scan uniqueidentifier=NEWID(),
  @receipt uniqueidentifier,@n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-151',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',2,NULL,@actor;
EXEC receiving.usp_ApproveScanSession @session,@reviewer;
EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@actor,@OriginNodeId=@node,
  @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;

SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceipts WHERE Id=@receipt);
EXEC test.AssertEq N'the receipt was posted',1,@n;
-- The container of a posted reception has to be closed.
SET @n=(SELECT COUNT(*) FROM receiving.ImportContainers WHERE Id=@container AND Status='closed');
EXEC test.AssertEq N'the container is closed after the posting',1,@n;
PRINT 'PASS';

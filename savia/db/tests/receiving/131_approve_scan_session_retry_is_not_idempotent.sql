-- TEST: approving the same session again with the same ids keeps it approved and does not duplicate anything.
-- XFAIL: D-A-02 usp_ApproveScanSession is not idempotent: a retry with the same session id fails with 51307 instead of returning the approval.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),
  @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),
  @scan uniqueidentifier=NEWID(),@n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-131',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',2,NULL,@actor;

EXEC receiving.usp_ApproveScanSession @session,@reviewer;

-- Retry with the same ids: the client never got the reply.
EXEC receiving.usp_ApproveScanSession @session,@reviewer;

SET @n=(SELECT COUNT(*) FROM receiving.ScanSessions WHERE Id=@session AND Status='approved' AND ReviewedBy=@reviewer);
EXEC test.AssertEq N'the session stays approved by the same reviewer',1,@n;
SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE ScanSessionId=@session);
EXEC test.AssertEq N'reads of the session',1,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances);
EXEC test.AssertEq N'stock after the retry',0,@n;
PRINT 'PASS';

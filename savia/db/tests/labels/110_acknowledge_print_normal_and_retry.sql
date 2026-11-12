-- TEST: usp_AcknowledgePrint marks the job as printed with its copies acknowledged and writes one attempt; a retry with the same attempt id adds nothing.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@item uniqueidentifier=test.Id('item'),
  @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),@scan uniqueidentifier=NEWID(),
  @receipt uniqueidentifier,@job uniqueidentifier,@attempt uniqueidentifier=NEWID(),@n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-L110',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',3,NULL,@actor;
EXEC receiving.usp_ApproveScanSession @session,@reviewer;
EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@actor,@OriginNodeId=@node,
  @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;

SET @job=(SELECT Id FROM labels.PrintJobs WHERE ItemId=@item);
SET @n=(SELECT COUNT(*) FROM labels.PrintJobs WHERE Id=@job AND CopiesRequested=3 AND Status='waiting_config');
EXEC test.AssertEq N'the queued label job',1,@n;

EXEC labels.usp_AcknowledgePrint @PrintJobId=@job,@AttemptId=@attempt,@AttemptNo=1,@Successful=1,
  @PrinterResponse=N'OK';

SET @n=(SELECT COUNT(*) FROM labels.PrintJobs WHERE Id=@job AND Status='printed' AND CopiesAcknowledged=3);
EXEC test.AssertEq N'the job is printed with its copies acknowledged',1,@n;
SET @n=(SELECT COUNT(*) FROM labels.PrintAttempts WHERE Id=@attempt AND PrintJobId=@job AND AttemptNo=1
        AND Status='acknowledged' AND AcknowledgedAt IS NOT NULL);
EXEC test.AssertEq N'the acknowledged attempt',1,@n;

-- Retry with the same ids: the printer worker never got the reply.
EXEC labels.usp_AcknowledgePrint @PrintJobId=@job,@AttemptId=@attempt,@AttemptNo=1,@Successful=1,
  @PrinterResponse=N'OK';

SET @n=(SELECT COUNT(*) FROM labels.PrintAttempts WHERE PrintJobId=@job);
EXEC test.AssertEq N'print attempts after the retry',1,@n;
SET @n=(SELECT COUNT(*) FROM labels.PrintJobs WHERE Id=@job AND Status='printed' AND CopiesAcknowledged=3);
EXEC test.AssertEq N'the job after the retry',1,@n;
PRINT 'PASS';

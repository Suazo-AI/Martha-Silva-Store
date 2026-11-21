-- TEST: usp_AcknowledgePrint rejects a job that does not exist (51402) and a job that is already printed (51403), and a failed print keeps the error and the copies pending.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@item uniqueidentifier=test.Id('item'),
  @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),@scan uniqueidentifier=NEWID(),
  @receipt uniqueidentifier,@job uniqueidentifier,@missing uniqueidentifier=NEWID(),
  @attempt1 uniqueidentifier=NEWID(),@attempt2 uniqueidentifier=NEWID(),@attempt3 uniqueidentifier=NEWID(),
  @n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-L111',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',3,NULL,@actor;
EXEC receiving.usp_ApproveScanSession @session,@reviewer;
EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@actor,@OriginNodeId=@node,
  @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;
SET @job=(SELECT Id FROM labels.PrintJobs WHERE ItemId=@item);

-- 51402: the job does not exist.
BEGIN TRY
  EXEC labels.usp_AcknowledgePrint @PrintJobId=@missing,@AttemptId=@attempt1,@AttemptNo=1,@Successful=1;
  THROW 59002,'ASSERT FAIL: a print job that does not exist was acknowledged',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51402 THROW; END CATCH;

-- A failed print keeps the error and leaves the copies pending.
EXEC labels.usp_AcknowledgePrint @PrintJobId=@job,@AttemptId=@attempt1,@AttemptNo=1,@Successful=0,
  @PrinterResponse=N'Impresora sin papel';
SET @n=(SELECT COUNT(*) FROM labels.PrintJobs WHERE Id=@job AND Status='failed'
        AND CopiesAcknowledged=0 AND LastError=N'Impresora sin papel');
EXEC test.AssertEq N'the failed job keeps the printer error',1,@n;
SET @n=(SELECT COUNT(*) FROM labels.PrintAttempts WHERE Id=@attempt1 AND Status='failed'
        AND AcknowledgedAt IS NULL);
EXEC test.AssertEq N'the failed attempt',1,@n;

-- The worker prints again and succeeds.
EXEC labels.usp_AcknowledgePrint @PrintJobId=@job,@AttemptId=@attempt2,@AttemptNo=2,@Successful=1,
  @PrinterResponse=N'OK';
SET @n=(SELECT COUNT(*) FROM labels.PrintJobs WHERE Id=@job AND Status='printed' AND CopiesAcknowledged=3
        AND LastError IS NULL);
EXEC test.AssertEq N'the job printed after the second attempt',1,@n;
SET @n=(SELECT COUNT(*) FROM labels.PrintAttempts WHERE PrintJobId=@job);
EXEC test.AssertEq N'print attempts',2,@n;

-- 51403: a printed job does not take more attempts.
BEGIN TRY
  EXEC labels.usp_AcknowledgePrint @PrintJobId=@job,@AttemptId=@attempt3,@AttemptNo=3,@Successful=1;
  THROW 59002,'ASSERT FAIL: a printed job took another attempt',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51403 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM labels.PrintAttempts WHERE PrintJobId=@job);
EXEC test.AssertEq N'print attempts after the rejection',2,@n;
SET @n=(SELECT COUNT(*) FROM labels.PrintJobs WHERE Id=@job AND Status='printed' AND CopiesAcknowledged=3);
EXEC test.AssertEq N'the job after the rejection',1,@n;
PRINT 'PASS';

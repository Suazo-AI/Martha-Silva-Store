-- TEST: a read rejected inside the procedure reports the domain error 51303 even when the read is captured with INSERT ... EXEC, the pattern the test guide prescribes.
-- XFAIL: D-A-07 usp_RecordScan replaces its own validation error with Msg 3915 when the read is captured with INSERT ... EXEC.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@container uniqueidentifier=NEWID(),
  @session uniqueidentifier=NEWID(),@sessionClosed uniqueidentifier=NEWID(),
  @scan uniqueidentifier=NEWID(),@n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-103',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@sessionClosed,@container,'approved',@actor);

BEGIN TRY
  INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@sessionClosed,N'0000123456789',1,NULL,@actor;
  THROW 59002,'ASSERT FAIL: a read in a session that is not counting was accepted',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()=59002 THROW;
  IF ERROR_NUMBER()<>51303
    THROW 59003,'ASSERT FAIL: the rejected read reported a raw SQL error instead of the domain error 51303',1;
END CATCH;

SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE Id=@scan);
EXEC test.AssertEq N'reads recorded',0,@n;
PRINT 'PASS';

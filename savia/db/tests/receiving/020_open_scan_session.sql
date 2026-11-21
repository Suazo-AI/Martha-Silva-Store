-- TEST: opening a scan session creates the container once, is idempotent, and rejects a reused session id, a bad location and a closed container.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @supplier2 uniqueidentifier=test.Id('supplier2'),@actor uniqueidentifier=test.Id('cashierA'),
  @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),@session2 uniqueidentifier=NEWID(),
  @other uniqueidentifier=NEWID(),@missing uniqueidentifier=NEWID(),@n bigint;

EXEC receiving.usp_OpenScanSession @ContainerId=@container,@ScanSessionId=@session,@Reference=N'T-CONT-OPEN',
     @SupplierId=@supplier,@LocationId=@loc,@ActorId=@actor,@DeviceCode=N'SCAN-01';
EXEC receiving.usp_OpenScanSession @ContainerId=@container,@ScanSessionId=@session,@Reference=N'T-CONT-OPEN',
     @SupplierId=@supplier,@LocationId=@loc,@ActorId=@actor,@DeviceCode=N'SCAN-01';
SET @n=(SELECT COUNT(*) FROM receiving.ImportContainers WHERE Id=@container AND Status='counting');
EXEC test.AssertEq N'containers created',1,@n;
SET @n=(SELECT COUNT(*) FROM receiving.ScanSessions WHERE ContainerId=@container AND Status='counting');
EXEC test.AssertEq N'sessions after a retry',1,@n;

-- A second device may open another session on the same container.
EXEC receiving.usp_OpenScanSession @ContainerId=@container,@ScanSessionId=@session2,@Reference=N'T-CONT-OPEN',
     @SupplierId=@supplier,@LocationId=@loc,@ActorId=@actor;
SET @n=(SELECT COUNT(*) FROM receiving.ScanSessions WHERE ContainerId=@container);
EXEC test.AssertEq N'sessions on one container',2,@n;

BEGIN TRY  -- same session id, different container
  EXEC receiving.usp_OpenScanSession @ContainerId=@other,@ScanSessionId=@session,@Reference=N'T-OTHER',
       @SupplierId=@supplier,@LocationId=@loc,@ActorId=@actor;
  THROW 59002,'ASSERT FAIL: session id reused with another container was accepted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51321 THROW; END CATCH;

BEGIN TRY  -- unknown location
  DECLARE @s3 uniqueidentifier=NEWID();
  EXEC receiving.usp_OpenScanSession @ContainerId=@other,@ScanSessionId=@s3,@Reference=N'T-OTHER',
       @SupplierId=@supplier,@LocationId=@missing,@ActorId=@actor;
  THROW 59002,'ASSERT FAIL: unknown location was accepted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51322 THROW; END CATCH;

BEGIN TRY  -- container belongs to another supplier
  DECLARE @s4 uniqueidentifier=NEWID();
  EXEC receiving.usp_OpenScanSession @ContainerId=@container,@ScanSessionId=@s4,@Reference=N'T-CONT-OPEN',
       @SupplierId=@supplier2,@LocationId=@loc,@ActorId=@actor;
  THROW 59002,'ASSERT FAIL: container with another supplier was accepted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51324 THROW; END CATCH;

BEGIN TRY  -- empty reference
  DECLARE @s5 uniqueidentifier=NEWID(),@c5 uniqueidentifier=NEWID();
  EXEC receiving.usp_OpenScanSession @ContainerId=@c5,@ScanSessionId=@s5,@Reference=N'   ',
       @SupplierId=@supplier,@LocationId=@loc,@ActorId=@actor;
  THROW 59002,'ASSERT FAIL: empty reference was accepted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51320 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM receiving.ImportContainers);
EXEC test.AssertEq N'containers after rejected calls',1,@n;
PRINT 'PASS';

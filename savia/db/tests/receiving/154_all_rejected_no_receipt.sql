-- TEST: a session with only rejected scans cannot be approved or posted and creates no receipt or stock.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
 @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),
 @node uniqueidentifier=test.Id('nodeA'),@container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),
 @scan uniqueidentifier=NEWID(),@receipt uniqueidentifier,@n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);
EXEC receiving.usp_OpenScanSession @container,@session,N'T-REJECT-154',@supplier,@loc,@actor;
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'UNKNOWN-154',1,NULL,@actor;
EXEC receiving.usp_RejectScan @scan,@reviewer,N'Not received';
BEGIN TRY
 EXEC receiving.usp_ApproveScanSession @session,@reviewer;
 THROW 59002,'ASSERT FAIL: empty receipt approved',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51308 THROW; END CATCH;
BEGIN TRY
 EXEC receiving.usp_PostScanSession @session,@reviewer,@node,@receipt OUTPUT;
 THROW 59002,'ASSERT FAIL: empty receipt posted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51312 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceipts WHERE ScanSessionId=@session);
EXEC test.AssertEq N'no receipt',0,@n;
SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE Id=@scan AND MatchStatus='rejected');
EXEC test.AssertEq N'rejected event remains',1,@n;
UPDATE receiving.ScanSessions SET Status='cancelled' WHERE Id=@session;
BEGIN TRY
 EXEC receiving.usp_RejectScan @scan,@reviewer,N'cancelled';
 THROW 59002,'ASSERT FAIL: cancelled session changed',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51332 THROW; END CATCH;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';

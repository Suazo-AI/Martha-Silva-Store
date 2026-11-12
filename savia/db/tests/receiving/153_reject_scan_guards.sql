-- TEST: rejection requires a reason, an existing unresolved scan and a counting session; it cannot change matched scans or closed sessions.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
 @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),
 @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),@scan uniqueidentifier=NEWID(),
 @unknown uniqueidentifier=NEWID(),@missing uniqueidentifier=NEWID(),@n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);
EXEC receiving.usp_OpenScanSession @container,@session,N'T-REJECT-153',@supplier,@loc,@actor;
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',1,NULL,@actor;
INSERT INTO @sink EXEC receiving.usp_RecordScan @unknown,@session,N'UNKNOWN-153',1,NULL,@actor;
BEGIN TRY
 EXEC receiving.usp_RejectScan @unknown,@reviewer,N' ';
 THROW 59002,'ASSERT FAIL: blank reason accepted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51330 THROW; END CATCH;
BEGIN TRY
 EXEC receiving.usp_RejectScan @unknown,@reviewer,NULL;
 THROW 59002,'ASSERT FAIL: null reason accepted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51330 THROW; END CATCH;
BEGIN TRY
 EXEC receiving.usp_RejectScan @missing,@reviewer,N'bad code';
 THROW 59002,'ASSERT FAIL: missing scan accepted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51331 THROW; END CATCH;
BEGIN TRY
 EXEC receiving.usp_RejectScan @scan,@reviewer,N'bad code';
 THROW 59002,'ASSERT FAIL: matched scan rejected',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51333 THROW; END CATCH;
UPDATE receiving.ScanSessions SET Status='review' WHERE Id=@session;
BEGIN TRY
 EXEC receiving.usp_RejectScan @unknown,@reviewer,N'bad code';
 THROW 59002,'ASSERT FAIL: review session changed',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51332 THROW; END CATCH;
UPDATE receiving.ScanSessions SET Status='counting' WHERE Id=@session;
-- Ambiguous readings may also be rejected; the CHECK requires ItemId to remain NULL.
UPDATE receiving.ScanEvents SET MatchStatus='ambiguous' WHERE Id=@unknown;
EXEC receiving.usp_RejectScan @unknown,@reviewer,N'ambiguous label';
EXEC receiving.usp_ApproveScanSession @session,@reviewer;
BEGIN TRY
 EXEC receiving.usp_RejectScan @unknown,@reviewer,N'retry after approval';
 THROW 59002,'ASSERT FAIL: approved session accepted rejection',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51332 THROW; END CATCH;
BEGIN TRY
 DECLARE @item uniqueidentifier=test.Id('item');
 EXEC receiving.usp_ResolveScan @unknown,@item,@reviewer,N'cannot undo rejection';
 THROW 59002,'ASSERT FAIL: rejected scan resolved',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51305 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE Id=@unknown AND MatchStatus='rejected' AND ResolutionReason=N'ambiguous label');
EXEC test.AssertEq N'failed changes preserve rejection',1,@n;
PRINT 'PASS';

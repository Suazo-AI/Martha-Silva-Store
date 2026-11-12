-- TEST: rejecting an unresolved reading preserves its audit fields, is idempotent and excludes it from receipt, stock, labels and conservation violations.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
 @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),
 @node uniqueidentifier=test.Id('nodeA'),@item uniqueidentifier=test.Id('item'),
 @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),@scan uniqueidentifier=NEWID(),
 @unknown uniqueidentifier=NEWID(),@receipt uniqueidentifier,@n bigint,@at datetime2(3);
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);
EXEC receiving.usp_OpenScanSession @container,@session,N'T-REJECT-152',@supplier,@loc,@actor;
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',3,NULL,@actor;
INSERT INTO @sink EXEC receiving.usp_RecordScan @unknown,@session,N'UNKNOWN-152',8,NULL,@actor;
EXEC receiving.usp_RejectScan @unknown,@reviewer,N'Damaged label';
SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE Id=@unknown AND MatchStatus='rejected'
 AND ItemId IS NULL AND Quantity=8 AND RawCode=N'UNKNOWN-152' AND CreatedBy=@actor
 AND ResolutionReason=N'Damaged label' AND ModifiedBy=@reviewer AND ModifiedAt IS NOT NULL);
EXEC test.AssertEq N'rejected event retained with actor, time and reason',1,@n;
SET @at=(SELECT ModifiedAt FROM receiving.ScanEvents WHERE Id=@unknown);
EXEC receiving.usp_RejectScan @unknown,@actor,N'Retry does not replace audit';
SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE Id=@unknown AND ModifiedAt=@at
 AND ModifiedBy=@reviewer AND ResolutionReason=N'Damaged label');
EXEC test.AssertEq N'retry preserves first audit',1,@n;
SET @n=(SELECT UnitsPendingReview FROM receiving.vw_SessionProgress WHERE ScanSessionId=@session);
EXEC test.AssertEq N'rejected quantity is not pending',0,@n;
EXEC receiving.usp_ApproveScanSession @session,@reviewer;
EXEC receiving.usp_PostScanSession @session,@reviewer,@node,@receipt OUTPUT;
SET @n=(SELECT SUM(Quantity) FROM purchasing.GoodsReceiptLines WHERE GoodsReceiptId=@receipt);
EXEC test.AssertEq N'only matched units received',3,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'only matched stock',3,@n;
SET @n=(SELECT SUM(j.CopiesRequested) FROM labels.PrintJobs j JOIN purchasing.GoodsReceiptLines l ON l.Id=j.ReceiptLineId WHERE l.GoodsReceiptId=@receipt);
EXEC test.AssertEq N'only matched labels',3,@n;
EXEC audit.usp_CheckConservation @Throw=1;
-- The exception is only for rejected scans: an unknown in a posted session is still a violation.
UPDATE receiving.ScanEvents SET MatchStatus='unknown' WHERE Id=@unknown;
BEGIN TRY
 EXEC audit.usp_CheckConservation @Throw=1;
 THROW 59002,'ASSERT FAIL: audit ignored unresolved scan in posted session',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>59100 THROW; END CATCH;
UPDATE receiving.ScanEvents SET MatchStatus='rejected' WHERE Id=@unknown;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';

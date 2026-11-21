-- TEST: an unknown scanned code is stored as unknown with no variant and never adds stock; the session cannot be approved.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),
  @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),@scan uniqueidentifier=NEWID(),
  @n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-100B',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);

INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'NO-EXISTE-9999',2,NULL,@actor;

SET @n=(SELECT COUNT(*) FROM @sink WHERE c='unknown' AND b IS NULL AND d=2);
EXEC test.AssertEq N'the read is unknown and has no variant',1,@n;
SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE Id=@scan AND MatchStatus='unknown' AND ItemId IS NULL
        AND RawCode=N'NO-EXISTE-9999' AND Quantity=2);
EXEC test.AssertEq N'scan event of the unknown code',1,@n;

-- Unknown codes never become stock.
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances);
EXEC test.AssertEq N'stock after the unknown read',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements);
EXEC test.AssertEq N'stock movements after the unknown read',0,@n;

-- A session with an unknown code cannot be approved.
BEGIN TRY
  EXEC receiving.usp_ApproveScanSession @session,@reviewer;
  THROW 59002,'ASSERT FAIL: a session with an unknown code was approved',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51309 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM receiving.ScanSessions WHERE Id=@session AND Status='counting');
EXEC test.AssertEq N'the session is still counting',1,@n;
SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceipts);
EXEC test.AssertEq N'receipts after the rejected approval',0,@n;
PRINT 'PASS';

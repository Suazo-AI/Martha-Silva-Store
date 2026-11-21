-- TEST: usp_RecordScan rejects a quantity outside 1..10000 and an empty code (51301), a reused scan id with other content (51302) and a closed session (51303) without recording a read.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@item uniqueidentifier=test.Id('item'),
  @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),@session2 uniqueidentifier=NEWID(),
  @scan uniqueidentifier=NEWID(),@scan2 uniqueidentifier=NEWID(),@scan3 uniqueidentifier=NEWID(),
  @n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-100C',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session2,@container,'approved',@actor);

-- 51301: quantity zero.
BEGIN TRY
  EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',0,NULL,@actor;
  THROW 59002,'ASSERT FAIL: a read with quantity zero was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51301 THROW; END CATCH;

-- 51301: quantity above the allowed maximum.
BEGIN TRY
  EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',10001,NULL,@actor;
  THROW 59002,'ASSERT FAIL: a read with quantity 10001 was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51301 THROW; END CATCH;

-- 51301: empty code.
BEGIN TRY
  EXEC receiving.usp_RecordScan @scan,@session,N'   ',1,NULL,@actor;
  THROW 59002,'ASSERT FAIL: a read with an empty code was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51301 THROW; END CATCH;

-- 51303: the session is not counting.
BEGIN TRY
  EXEC receiving.usp_RecordScan @scan3,@session2,N'0000123456789',1,NULL,@actor;
  THROW 59002,'ASSERT FAIL: a read in a session that is not counting was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51303 THROW; END CATCH;

-- A valid read, then the same scan id with another content.
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',2,NULL,@actor;
BEGIN TRY
  EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',5,NULL,@actor;
  THROW 59002,'ASSERT FAIL: a reused scan id with another quantity was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51302 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE ScanSessionId=@session);
EXEC test.AssertEq N'reads recorded in the session',1,@n;
SET @n=(SELECT Quantity FROM receiving.ScanEvents WHERE Id=@scan);
EXEC test.AssertEq N'quantity of the recorded read',2,@n;
SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE ScanSessionId=@session2);
EXEC test.AssertEq N'reads recorded in the closed session',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements);
EXEC test.AssertEq N'stock movements after the rejected reads',0,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances);
EXEC test.AssertEq N'stock after the rejected reads',0,@n;
PRINT 'PASS';

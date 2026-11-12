-- TEST: usp_RecordScan matches a known barcode to its variant and keeps the leading zeros; a retry with the same scan id records one single read.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@item uniqueidentifier=test.Id('item'),
  @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),@scan uniqueidentifier=NEWID(),
  @n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-100A',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);

INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',3,NULL,@actor;

SET @n=(SELECT COUNT(*) FROM @sink WHERE c='matched' AND b=@item AND d=3);
EXEC test.AssertEq N'the read matched the variant',1,@n;
SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE Id=@scan AND ScanSessionId=@session
        AND ItemId=@item AND MatchStatus='matched' AND Quantity=3);
EXEC test.AssertEq N'scan event rows',1,@n;
-- The barcode keeps its leading zeros in the read.
SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE Id=@scan AND RawCode=N'0000123456789');
EXEC test.AssertEq N'scan event keeps the leading zeros',1,@n;

-- Retry with the same ids: the scanner never got the reply.
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',3,NULL,@actor;

SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE Id=@scan);
EXEC test.AssertEq N'scan events after the retry',1,@n;
SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE ScanSessionId=@session);
EXEC test.AssertEq N'scan events of the session after the retry',1,@n;
SET @n=(SELECT SUM(Quantity) FROM receiving.ScanEvents WHERE ScanSessionId=@session);
EXEC test.AssertEq N'quantity counted after the retry',3,@n;

-- A read never adds stock by itself.
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc);
EXEC test.AssertEq N'stock after the read',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements);
EXEC test.AssertEq N'stock movements after the read',0,@n;
PRINT 'PASS';

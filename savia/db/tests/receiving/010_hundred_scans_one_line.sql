-- TEST: 100 scans of one barcode add 100 units to one receipt line; no new SKU and no stock before approval and posting.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@item uniqueidentifier=test.Id('item'),
  @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),@scan uniqueidentifier,
  @receipt uniqueidentifier,@i int=0,@n bigint,@itemsBefore bigint=(SELECT COUNT(*) FROM catalog.Items);
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-100',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);

WHILE @i<100
BEGIN
  SET @scan=NEWID();
  INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',1,NULL,@actor;
  -- A retry of the same scan (lost reply from the scanner client) must not count twice.
  IF @i%10=0 INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',1,NULL,@actor;
  SET @i+=1;
END;

SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE ScanSessionId=@session);
EXEC test.AssertEq N'scan events recorded',100,@n;
SET @n=(SELECT COUNT(*) FROM @sink WHERE c<>'matched');
EXEC test.AssertEq N'scans not matched to the variant',0,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc);
EXEC test.AssertEq N'stock before approval',0,@n;

-- Posting without approval must fail and must not move stock.
BEGIN TRY
  EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@actor,@OriginNodeId=@node,
       @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;
  THROW 59002,'ASSERT FAIL: posting an unapproved session succeeded',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51312 THROW; END CATCH;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc);
EXEC test.AssertEq N'stock after rejected posting',0,@n;

EXEC receiving.usp_ApproveScanSession @session,@reviewer;
EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@actor,@OriginNodeId=@node,
     @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;
-- Retry of the posting (lost reply): same receipt, no second stock entry.
EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@actor,@OriginNodeId=@node,
     @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;

SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceiptLines WHERE GoodsReceiptId=@receipt);
EXEC test.AssertEq N'receipt lines',1,@n;
SET @n=(SELECT Quantity FROM purchasing.GoodsReceiptLines WHERE GoodsReceiptId=@receipt);
EXEC test.AssertEq N'receipt line quantity',100,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'store stock after posting',100,@n;
SET @n=(SELECT COUNT(*) FROM catalog.Items);
EXEC test.AssertEq N'variants (no SKU created by scanning)',@itemsBefore,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE ItemId=@item AND LocationId=@loc AND Kind='receive');
EXEC test.AssertEq N'receive movements',1,@n;
-- Label: original supplier code, barcode with its leading zeros, store name, one copy per unit.
SET @n=(SELECT COUNT(*) FROM labels.PrintJobs WHERE ItemId=@item AND CopiesRequested=100
        AND SkuSnapshot=N'PROV-0001' AND BarcodeSnapshot=N'0000123456789' AND StoreNameSnapshot=N'SAVIA Test');
EXEC test.AssertEq N'label job with original code and leading zeros',1,@n;
PRINT 'PASS';

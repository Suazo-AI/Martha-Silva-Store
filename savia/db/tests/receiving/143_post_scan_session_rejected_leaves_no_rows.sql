-- TEST: a reception that fails while moving the stock leaves no receipt, no movement, no label and no event.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@item uniqueidentifier=test.Id('item'),
  @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),@scan uniqueidentifier=NEWID(),
  @receipt uniqueidentifier,@receipts bigint,@lines bigint,@moves bigint,@jobs bigint,@events bigint,
  @onHand bigint,@n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

-- There is already stock of this item in the store pool.
EXEC test.SeedStock @item,@loc,5;

SET @receipts=(SELECT COUNT(*) FROM purchasing.GoodsReceipts);
SET @lines=(SELECT COUNT(*) FROM purchasing.GoodsReceiptLines);
SET @moves=(SELECT COUNT(*) FROM inventory.StockMovements);
SET @jobs=(SELECT COUNT(*) FROM labels.PrintJobs);
SET @events=(SELECT COUNT(*) FROM sync.Outbox);
SET @onHand=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');

-- The store pool is frozen: the reception cannot move the stock.
UPDATE inventory.StockBalances SET Status='frozen'
  WHERE ItemId=@item AND LocationId=@loc AND Pool='store';

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-143',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',4,NULL,@actor;
EXEC receiving.usp_ApproveScanSession @session,@reviewer;

BEGIN TRY
  EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@actor,@OriginNodeId=@node,
    @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;
  THROW 59002,'ASSERT FAIL: a reception into a frozen pool was posted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51103 THROW; END CATCH;

-- Nothing was left half written.
SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceipts);
EXEC test.AssertEq N'receipts after the rejected reception',@receipts,@n;
SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceiptLines);
EXEC test.AssertEq N'receipt lines after the rejected reception',@lines,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements);
EXEC test.AssertEq N'stock movements after the rejected reception',@moves,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock after the rejected reception',@onHand,@n;
SET @n=(SELECT COUNT(*) FROM labels.PrintJobs);
EXEC test.AssertEq N'label jobs after the rejected reception',@jobs,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox);
EXEC test.AssertEq N'outbox rows after the rejected reception',@events,@n;
SET @n=(SELECT COUNT(*) FROM receiving.ScanSessions WHERE Id=@session AND Status='approved');
EXEC test.AssertEq N'the session stays approved and ready to post',1,@n;
PRINT 'PASS';

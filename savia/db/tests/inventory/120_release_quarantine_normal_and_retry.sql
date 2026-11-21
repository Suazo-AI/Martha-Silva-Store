-- TEST: usp_ReleaseQuarantine moves the units from the quarantine pool to the store pool without changing the total; a retry with the same ids changes nothing.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@approver uniqueidentifier=test.Id('supervisorA'),
  @manager uniqueidentifier=test.Id('manager'),@node uniqueidentifier=test.Id('nodeA'),
  @draft uniqueidentifier=test.Id('itemDraft'),@container uniqueidentifier=NEWID(),
  @session uniqueidentifier=NEWID(),@scan uniqueidentifier=NEWID(),@receipt uniqueidentifier,
  @release uniqueidentifier=NEWID(),@event uniqueidentifier=NEWID(),@n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

-- The variant without approved cost enters the quarantine pool.
INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-I120',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000555000111',4,NULL,@actor;
EXEC receiving.usp_ApproveScanSession @session,@approver;
EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@actor,@OriginNodeId=@node,
  @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@draft AND LocationId=@loc AND Pool='quarantine');
EXEC test.AssertEq N'quarantine stock before the release',4,@n;

-- The price and cost are approved, so the goods can leave the quarantine.
EXEC catalog.usp_ActivateItem @ItemId=@draft,@UnitPriceMinor=90000,@UnitCostMinor=60000,
  @ActorId=@manager,@OriginNodeId=@node,@EventId=@event;

EXEC inventory.usp_ReleaseQuarantine @ReleaseId=@release,@ItemId=@draft,@LocationId=@loc,@Quantity=2,
  @ActorId=@actor,@ApproverId=@approver,@OriginNodeId=@node,@Reason=N'Costo ya aprobado';

SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@draft AND LocationId=@loc AND Pool='quarantine');
EXEC test.AssertEq N'quarantine stock after the release',2,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@draft AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'store stock after the release',2,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances WHERE ItemId=@draft AND LocationId=@loc);
EXEC test.AssertEq N'the total did not change',4,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE SourceId=@release);
EXEC test.AssertEq N'the two movements of the release',2,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@release AND EventType='inventory.quarantine_released');
EXEC test.AssertEq N'the release event in outbox',1,@n;

-- Retry with the same ids: the client never got the reply.
EXEC inventory.usp_ReleaseQuarantine @ReleaseId=@release,@ItemId=@draft,@LocationId=@loc,@Quantity=2,
  @ActorId=@actor,@ApproverId=@approver,@OriginNodeId=@node,@Reason=N'Costo ya aprobado';

SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances WHERE ItemId=@draft AND LocationId=@loc);
EXEC test.AssertEq N'the total after the retry',4,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE SourceId=@release);
EXEC test.AssertEq N'movements after the retry',2,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@release AND EventType='inventory.quarantine_released');
EXEC test.AssertEq N'events after the retry',1,@n;
PRINT 'PASS';

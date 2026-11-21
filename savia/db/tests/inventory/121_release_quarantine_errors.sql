-- TEST: usp_ReleaseQuarantine rejects a release without quantity, reason or double approval (51120), a variant without approved price and cost (51121), an approver from another branch (51122) and a release above the quarantine stock (51102).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@approver uniqueidentifier=test.Id('supervisorA'),
  @otherBranch uniqueidentifier=test.Id('supervisorB'),@node uniqueidentifier=test.Id('nodeA'),
  @draft uniqueidentifier=test.Id('itemDraft'),@container uniqueidentifier=NEWID(),
  @session uniqueidentifier=NEWID(),@scan uniqueidentifier=NEWID(),@receipt uniqueidentifier,
  @release1 uniqueidentifier=NEWID(),@release2 uniqueidentifier=NEWID(),@release3 uniqueidentifier=NEWID(),
  @release4 uniqueidentifier=NEWID(),@release5 uniqueidentifier=NEWID(),@release6 uniqueidentifier=NEWID(),
  @n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

-- Four units of a variant without approved cost wait in the quarantine.
INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-I121',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000555000111',4,NULL,@actor;
EXEC receiving.usp_ApproveScanSession @session,@approver;
EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@actor,@OriginNodeId=@node,
  @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;

-- 51120: the approver is the actor.
BEGIN TRY
  EXEC inventory.usp_ReleaseQuarantine @ReleaseId=@release1,@ItemId=@draft,@LocationId=@loc,@Quantity=1,
    @ActorId=@actor,@ApproverId=@actor,@OriginNodeId=@node,@Reason=N'Liberar';
  THROW 59002,'ASSERT FAIL: a release approved by the actor was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51120 THROW; END CATCH;

-- 51120: a quantity of zero.
BEGIN TRY
  EXEC inventory.usp_ReleaseQuarantine @ReleaseId=@release2,@ItemId=@draft,@LocationId=@loc,@Quantity=0,
    @ActorId=@actor,@ApproverId=@approver,@OriginNodeId=@node,@Reason=N'Liberar';
  THROW 59002,'ASSERT FAIL: a release of zero units was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51120 THROW; END CATCH;

-- 51120: an empty reason.
BEGIN TRY
  EXEC inventory.usp_ReleaseQuarantine @ReleaseId=@release3,@ItemId=@draft,@LocationId=@loc,@Quantity=1,
    @ActorId=@actor,@ApproverId=@approver,@OriginNodeId=@node,@Reason=N'  ';
  THROW 59002,'ASSERT FAIL: a release without reason was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51120 THROW; END CATCH;

-- 51121: the variant has no approved price and cost yet.
BEGIN TRY
  EXEC inventory.usp_ReleaseQuarantine @ReleaseId=@release4,@ItemId=@draft,@LocationId=@loc,@Quantity=1,
    @ActorId=@actor,@ApproverId=@approver,@OriginNodeId=@node,@Reason=N'Liberar sin costo aprobado';
  THROW 59002,'ASSERT FAIL: a release of a variant without approved cost was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51121 THROW; END CATCH;

-- The goods are released now that the price and cost are approved.
DECLARE @manager uniqueidentifier=test.Id('manager'),@event uniqueidentifier=NEWID();
EXEC catalog.usp_ActivateItem @ItemId=@draft,@UnitPriceMinor=90000,@UnitCostMinor=60000,
  @ActorId=@manager,@OriginNodeId=@node,@EventId=@event;

-- 51122: the approver has no access to the branch of the location.
BEGIN TRY
  EXEC inventory.usp_ReleaseQuarantine @ReleaseId=@release5,@ItemId=@draft,@LocationId=@loc,@Quantity=1,
    @ActorId=@actor,@ApproverId=@otherBranch,@OriginNodeId=@node,@Reason=N'Liberar';
  THROW 59002,'ASSERT FAIL: a release approved from another branch was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51122 THROW; END CATCH;

-- 51102: more units than the quarantine holds.
BEGIN TRY
  EXEC inventory.usp_ReleaseQuarantine @ReleaseId=@release6,@ItemId=@draft,@LocationId=@loc,@Quantity=99,
    @ActorId=@actor,@ApproverId=@approver,@OriginNodeId=@node,@Reason=N'Liberar de mas';
  THROW 59002,'ASSERT FAIL: a release above the quarantine stock was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51102 THROW; END CATCH;

-- The rejected releases left nothing behind.
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE SourceId IN
        (@release1,@release2,@release3,@release4,@release5,@release6));
EXEC test.AssertEq N'movements of the rejected releases',0,@n;
SET @n=(SELECT COUNT(*) FROM audit.Operations WHERE Scope='inventory.quarantine_release');
EXEC test.AssertEq N'operations of the rejected releases',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventType='inventory.quarantine_released');
EXEC test.AssertEq N'release events after the rejections',0,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@draft AND LocationId=@loc AND Pool='quarantine');
EXEC test.AssertEq N'quarantine stock after the rejections',4,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances WHERE ItemId=@draft AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'store stock after the rejections',0,@n;
PRINT 'PASS';

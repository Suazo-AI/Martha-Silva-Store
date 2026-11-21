-- TEST: usp_PostAdjustment rejects a difference of zero or an empty reason (51105) and an approver that is the actor (51106) without leaving rows behind.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@item uniqueidentifier=test.Id('item'),
  @actor uniqueidentifier=test.Id('manager'),@approver uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@adjustment uniqueidentifier=NEWID(),
  @adjustment2 uniqueidentifier=NEWID(),@adjustment3 uniqueidentifier=NEWID(),
  @adjustment4 uniqueidentifier=NEWID(),@n bigint;

-- 51105: a difference of zero.
BEGIN TRY
  EXEC inventory.usp_PostAdjustment @AdjustmentId=@adjustment,@ItemId=@item,@LocationId=@loc,@Pool='store',
    @Delta=0,@ActorId=@actor,@ApproverId=@approver,@Reason=N'Ajuste sin diferencia',@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: an adjustment of zero was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51105 THROW; END CATCH;

-- 51105: an empty reason.
BEGIN TRY
  EXEC inventory.usp_PostAdjustment @AdjustmentId=@adjustment2,@ItemId=@item,@LocationId=@loc,@Pool='store',
    @Delta=1,@ActorId=@actor,@ApproverId=@approver,@Reason=N'  ',@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: an adjustment without reason was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51105 THROW; END CATCH;

-- 51106: the approver is the actor.
BEGIN TRY
  EXEC inventory.usp_PostAdjustment @AdjustmentId=@adjustment3,@ItemId=@item,@LocationId=@loc,@Pool='store',
    @Delta=1,@ActorId=@actor,@ApproverId=@actor,@Reason=N'Ajuste sin doble aprobacion',@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: an adjustment approved by the actor was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51106 THROW; END CATCH;

-- 51102: the adjustment would leave the stock below zero.
BEGIN TRY
  EXEC inventory.usp_PostAdjustment @AdjustmentId=@adjustment4,@ItemId=@item,@LocationId=@loc,@Pool='store',
    @Delta=-1,@ActorId=@actor,@ApproverId=@approver,@Reason=N'Merma sin existencias',@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: an adjustment below zero was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51102 THROW; END CATCH;

-- Nothing was left behind.
SET @n=(SELECT COUNT(*) FROM inventory.StockAdjustments);
EXEC test.AssertEq N'adjustments after the rejections',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements);
EXEC test.AssertEq N'stock movements after the rejections',0,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances);
EXEC test.AssertEq N'stock after the rejections',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventType='inventory.adjusted');
EXEC test.AssertEq N'adjustment events after the rejections',0,@n;
PRINT 'PASS';

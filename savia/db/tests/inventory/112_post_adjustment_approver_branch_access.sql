-- TEST: an adjustment of a branch needs an approver with access to that branch.
-- FIXED (V005): D-A-03 was: usp_PostAdjustment accepts an approver with no access to the branch, while usp_ReleaseQuarantine rejects the same case with 51122.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@item uniqueidentifier=test.Id('item'),
  @actor uniqueidentifier=test.Id('manager'),@approver uniqueidentifier=test.Id('supervisorB'),
  @node uniqueidentifier=test.Id('nodeA'),@adjustment uniqueidentifier=NEWID(),@n bigint;

-- supervisorB only has access to the branch B; this stock belongs to the branch A.
BEGIN TRY
  EXEC inventory.usp_PostAdjustment @AdjustmentId=@adjustment,@ItemId=@item,@LocationId=@loc,@Pool='store',
    @Delta=1,@ActorId=@actor,@ApproverId=@approver,@Reason=N'Ajuste con aprobador de otra sucursal',
    @OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: an approver without access to the branch was accepted',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()<>51107 THROW;
END CATCH;

SET @n=(SELECT COUNT(*) FROM inventory.StockAdjustments WHERE Id=@adjustment);
EXEC test.AssertEq N'the adjustment was rejected',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements);
EXEC test.AssertEq N'stock movements after the rejection',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventType='inventory.adjusted');
EXEC test.AssertEq N'adjustment events after the rejection',0,@n;
PRINT 'PASS';

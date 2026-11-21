-- TEST: usp_PostAdjustment adjusts the stock once with an approver that is not the actor and writes one event; a retry with the same ids changes nothing.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@item uniqueidentifier=test.Id('item'),
  @actor uniqueidentifier=test.Id('manager'),@approver uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@adjustment uniqueidentifier=NEWID(),
  @adjustment2 uniqueidentifier=NEWID(),@n bigint;

EXEC inventory.usp_PostAdjustment @AdjustmentId=@adjustment,@ItemId=@item,@LocationId=@loc,@Pool='store',
  @Delta=3,@ActorId=@actor,@ApproverId=@approver,@Reason=N'Merma contada',@OriginNodeId=@node;

SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'store stock after the adjustment',3,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockAdjustments WHERE Id=@adjustment AND ItemId=@item
        AND LocationId=@loc AND Pool='store' AND QuantityDelta=3 AND ApprovedBy=@approver
        AND CreatedBy=@actor AND Status='posted' AND MovementOperationId IS NOT NULL);
EXEC test.AssertEq N'the adjustment row',1,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE ItemId=@item AND LocationId=@loc AND Pool='store'
        AND Kind='adjust' AND OnHandDelta=3 AND SourceType='stock_adjustment' AND SourceId=@adjustment);
EXEC test.AssertEq N'the adjustment movement',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@adjustment AND AggregateType='stock_adjustment'
        AND EventType='inventory.adjusted');
EXEC test.AssertEq N'the adjustment event in outbox',1,@n;

-- Retry with the same ids: the client never got the reply.
EXEC inventory.usp_PostAdjustment @AdjustmentId=@adjustment,@ItemId=@item,@LocationId=@loc,@Pool='store',
  @Delta=3,@ActorId=@actor,@ApproverId=@approver,@Reason=N'Merma contada',@OriginNodeId=@node;

SET @n=(SELECT COUNT(*) FROM inventory.StockAdjustments WHERE Id=@adjustment);
EXEC test.AssertEq N'adjustments after the retry',1,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE SourceId=@adjustment);
EXEC test.AssertEq N'movements after the retry',1,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'store stock after the retry',3,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@adjustment AND EventType='inventory.adjusted');
EXEC test.AssertEq N'events after the retry',1,@n;

-- A second adjustment with another id moves the stock again.
EXEC inventory.usp_PostAdjustment @AdjustmentId=@adjustment2,@ItemId=@item,@LocationId=@loc,@Pool='store',
  @Delta=-1,@ActorId=@actor,@ApproverId=@approver,@Reason=N'Unit devuelta',@OriginNodeId=@node;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'store stock after the second adjustment',2,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockBalances WHERE OnHand<0 OR Reserved<0 OR Reserved>OnHand);
EXEC test.AssertEq N'balances out of the allowed bounds',0,@n;
PRINT 'PASS';

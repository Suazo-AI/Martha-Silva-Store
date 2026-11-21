-- TEST: usp_ApplyMovement moves the stock once, writes the movement and a retry with the same operation id changes nothing.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@item uniqueidentifier=test.Id('item'),
  @actor uniqueidentifier=test.Id('manager'),@operation uniqueidentifier=NEWID(),
  @source uniqueidentifier=NEWID(),@movement uniqueidentifier,@movement2 uniqueidentifier,@n bigint;

EXEC inventory.usp_ApplyMovement @OperationId=@operation,@ItemId=@item,@LocationId=@loc,@Pool='store',
  @Kind='receive',@OnHandDelta=5,@SourceType='test_receive',@SourceId=@source,@ActorId=@actor,
  @MovementId=@movement OUTPUT;

SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'store stock after the movement',5,@n;
SET @n=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'reserved stock after the movement',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE OperationId=@operation AND ItemId=@item
        AND LocationId=@loc AND Pool='store' AND Kind='receive' AND OnHandDelta=5 AND ReservedDelta=0
        AND OnHandAfter=5 AND ReservedAfter=0 AND SourceType='test_receive' AND SourceId=@source);
EXEC test.AssertEq N'the movement row',1,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE Id=@movement);
EXEC test.AssertEq N'the returned movement id exists',1,@n;

-- Retry with the same ids: the client never got the reply.
EXEC inventory.usp_ApplyMovement @OperationId=@operation,@ItemId=@item,@LocationId=@loc,@Pool='store',
  @Kind='receive',@OnHandDelta=5,@SourceType='test_receive',@SourceId=@source,@ActorId=@actor,
  @MovementId=@movement2 OUTPUT;

SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE OperationId=@operation);
EXEC test.AssertEq N'movements after the retry',1,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'store stock after the retry',5,@n;
SET @n=(SELECT CASE WHEN @movement2=@movement THEN 1 ELSE 0 END);
EXEC test.AssertEq N'the retry returns the same movement',1,@n;

-- The balance is the sum of the movements and never negative.
SET @n=(SELECT COUNT(*) FROM inventory.StockBalances b
        LEFT JOIN (SELECT ItemId,LocationId,Pool,SUM(OnHandDelta) OnHandSum,SUM(ReservedDelta) ReservedSum
                   FROM inventory.StockMovements GROUP BY ItemId,LocationId,Pool) m
          ON m.ItemId=b.ItemId AND m.LocationId=b.LocationId AND m.Pool=b.Pool
        WHERE b.OnHand<>ISNULL(m.OnHandSum,0) OR b.Reserved<>ISNULL(m.ReservedSum,0));
EXEC test.AssertEq N'balances that disagree with the movements',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockBalances WHERE OnHand<0 OR Reserved<0 OR Reserved>OnHand);
EXEC test.AssertEq N'balances out of the allowed bounds',0,@n;
PRINT 'PASS';

-- TEST: usp_AllocateToWeb moves units from the store pool to the web pool without changing the total; a retry with the same ids changes nothing.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@item uniqueidentifier=test.Id('item'),
  @actor uniqueidentifier=test.Id('manager'),@node uniqueidentifier=test.Id('nodeA'),
  @allocation uniqueidentifier=NEWID(),@n bigint;

EXEC test.SeedStock @item,@loc,5;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'store stock before the allocation',5,@n;

EXEC inventory.usp_AllocateToWeb @AllocationId=@allocation,@ItemId=@item,@LocationId=@loc,@Quantity=2,
  @ActorId=@actor,@OriginNodeId=@node;

SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'store stock after the allocation',3,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='web');
EXEC test.AssertEq N'web stock after the allocation',2,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc);
EXEC test.AssertEq N'the total did not change',5,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE SourceId=@allocation);
EXEC test.AssertEq N'the two movements of the allocation',2,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@allocation AND AggregateType='web_allocation'
        AND EventType='inventory.web_allocated');
EXEC test.AssertEq N'the allocation event in outbox',1,@n;
SET @n=(SELECT COUNT(*) FROM audit.Operations WHERE Id=@allocation AND Scope='inventory.web_allocation');
EXEC test.AssertEq N'the allocation operation record',1,@n;

-- Retry with the same ids: the client never got the reply.
EXEC inventory.usp_AllocateToWeb @AllocationId=@allocation,@ItemId=@item,@LocationId=@loc,@Quantity=2,
  @ActorId=@actor,@OriginNodeId=@node;

SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc);
EXEC test.AssertEq N'the total after the retry',5,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'store stock after the retry',3,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='web');
EXEC test.AssertEq N'web stock after the retry',2,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE SourceId=@allocation);
EXEC test.AssertEq N'movements after the retry',2,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@allocation AND EventType='inventory.web_allocated');
EXEC test.AssertEq N'events after the retry',1,@n;

-- The balance is the sum of the movements.
SET @n=(SELECT COUNT(*) FROM inventory.StockBalances b
        LEFT JOIN (SELECT ItemId,LocationId,Pool,SUM(OnHandDelta) OnHandSum,SUM(ReservedDelta) ReservedSum
                   FROM inventory.StockMovements GROUP BY ItemId,LocationId,Pool) m
          ON m.ItemId=b.ItemId AND m.LocationId=b.LocationId AND m.Pool=b.Pool
        WHERE b.OnHand<>ISNULL(m.OnHandSum,0) OR b.Reserved<>ISNULL(m.ReservedSum,0));
EXEC test.AssertEq N'balances that disagree with the movements',0,@n;
PRINT 'PASS';

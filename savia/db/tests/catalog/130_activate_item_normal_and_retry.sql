-- TEST: usp_ActivateItem approves price and cost, moves the variant to active and writes one event; a retry with the same ids changes nothing.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @draft uniqueidentifier=test.Id('itemDraft'),@actor uniqueidentifier=test.Id('manager'),
  @node uniqueidentifier=test.Id('nodeA'),@event uniqueidentifier=NEWID(),@n bigint;

SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id=@draft AND Status='draft' AND UnitCostMinor IS NULL);
EXEC test.AssertEq N'the variant starts as draft without cost',1,@n;

EXEC catalog.usp_ActivateItem @ItemId=@draft,@UnitPriceMinor=95000,@UnitCostMinor=61000,
  @ActorId=@actor,@OriginNodeId=@node,@EventId=@event;

SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id=@draft AND Status='active');
EXEC test.AssertEq N'variant active',1,@n;
SET @n=(SELECT UnitPriceMinor FROM catalog.Items WHERE Id=@draft);
EXEC test.AssertEq N'approved unit price',95000,@n;
SET @n=(SELECT UnitCostMinor FROM catalog.Items WHERE Id=@draft);
EXEC test.AssertEq N'approved unit cost',61000,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@event AND AggregateType='item'
        AND AggregateId=@draft AND EventType='catalog.item_activated');
EXEC test.AssertEq N'catalog.item_activated event in outbox',1,@n;

-- Retry with the same ids: the client never got the reply.
EXEC catalog.usp_ActivateItem @ItemId=@draft,@UnitPriceMinor=95000,@UnitCostMinor=61000,
  @ActorId=@actor,@OriginNodeId=@node,@EventId=@event;

SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id=@draft AND Status='active' AND UnitPriceMinor=95000
        AND UnitCostMinor=61000);
EXEC test.AssertEq N'variant after the retry',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@draft AND EventType='catalog.item_activated');
EXEC test.AssertEq N'events after the retry',1,@n;
PRINT 'PASS';

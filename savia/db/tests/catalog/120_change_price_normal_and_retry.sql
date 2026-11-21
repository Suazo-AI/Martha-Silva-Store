-- TEST: usp_ChangePrice moves the price once, writes the price history and one event; a retry with the same ids changes nothing.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @item uniqueidentifier=test.Id('item'),@actor uniqueidentifier=test.Id('manager'),
  @node uniqueidentifier=test.Id('nodeA'),@event uniqueidentifier=NEWID(),@n bigint;

EXEC catalog.usp_ChangePrice @ItemId=@item,@NewPriceMinor=135000,@ActorId=@actor,
  @OriginNodeId=@node,@EventId=@event,@Reason=N'Regla de fin de temporada';

SET @n=(SELECT UnitPriceMinor FROM catalog.Items WHERE Id=@item);
EXEC test.AssertEq N'new unit price',135000,@n;
SET @n=(SELECT COUNT(*) FROM catalog.PriceHistory WHERE ItemId=@item AND OldPriceMinor=120000
        AND NewPriceMinor=135000 AND CurrencyCode='NIO' AND Reason=N'Regla de fin de temporada');
EXEC test.AssertEq N'price history rows',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@event AND AggregateType='item'
        AND AggregateId=@item AND EventType='catalog.price_changed');
EXEC test.AssertEq N'catalog.price_changed event in outbox',1,@n;

-- Retry with the same ids: the client never got the reply.
EXEC catalog.usp_ChangePrice @ItemId=@item,@NewPriceMinor=135000,@ActorId=@actor,
  @OriginNodeId=@node,@EventId=@event,@Reason=N'Regla de fin de temporada';

SET @n=(SELECT UnitPriceMinor FROM catalog.Items WHERE Id=@item);
EXEC test.AssertEq N'unit price after the retry',135000,@n;
SET @n=(SELECT COUNT(*) FROM catalog.PriceHistory WHERE ItemId=@item);
EXEC test.AssertEq N'price history rows after the retry',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@item AND EventType='catalog.price_changed');
EXEC test.AssertEq N'events after the retry',1,@n;
PRINT 'PASS';

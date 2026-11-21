-- TEST: usp_RegisterProduct creates one product and one sync event; a retry with the same ids changes nothing.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @product uniqueidentifier=NEWID(),@actor uniqueidentifier=test.Id('manager'),
  @node uniqueidentifier=test.Id('nodeA'),@event uniqueidentifier=NEWID(),@n bigint;

EXEC catalog.usp_RegisterProduct @ProductId=@product,@Name=N'Blusa de Prueba',@ActorId=@actor,
  @OriginNodeId=@node,@EventId=@event;

SET @n=(SELECT COUNT(*) FROM catalog.Products WHERE Id=@product);
EXEC test.AssertEq N'product rows',1,@n;
SET @n=(SELECT COUNT(*) FROM catalog.Products WHERE Id=@product AND Name=N'Blusa de Prueba' AND Status='active');
EXEC test.AssertEq N'product active with the given name',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@event AND AggregateType='product'
        AND AggregateId=@product AND EventType='catalog.product_registered');
EXEC test.AssertEq N'catalog.product_registered event in outbox',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox);
EXEC test.AssertEq N'outbox rows after registering the product',5,@n;

-- Retry with the same ids: the client never got the reply.
EXEC catalog.usp_RegisterProduct @ProductId=@product,@Name=N'Blusa de Prueba',@ActorId=@actor,
  @OriginNodeId=@node,@EventId=@event;

SET @n=(SELECT COUNT(*) FROM catalog.Products WHERE Id=@product);
EXEC test.AssertEq N'product rows after the retry',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@product AND EventType='catalog.product_registered');
EXEC test.AssertEq N'events for the product after the retry',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox);
EXEC test.AssertEq N'outbox rows after the retry',5,@n;
PRINT 'PASS';

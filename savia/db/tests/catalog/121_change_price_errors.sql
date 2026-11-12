-- TEST: usp_ChangePrice rejects a negative price or an empty reason (51206) and a variant that is not active (51207) without touching the price.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @item uniqueidentifier=test.Id('item'),@draft uniqueidentifier=test.Id('itemDraft'),
  @actor uniqueidentifier=test.Id('manager'),@node uniqueidentifier=test.Id('nodeA'),
  @event uniqueidentifier=NEWID(),@event2 uniqueidentifier=NEWID(),@n bigint;

-- 51206: negative price.
BEGIN TRY
  EXEC catalog.usp_ChangePrice @ItemId=@item,@NewPriceMinor=-1,@ActorId=@actor,
    @OriginNodeId=@node,@EventId=@event,@Reason=N'Precio negativo';
  THROW 59002,'ASSERT FAIL: a negative price was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51206 THROW; END CATCH;

-- 51206: empty reason.
BEGIN TRY
  EXEC catalog.usp_ChangePrice @ItemId=@item,@NewPriceMinor=135000,@ActorId=@actor,
    @OriginNodeId=@node,@EventId=@event,@Reason=N'  ';
  THROW 59002,'ASSERT FAIL: an empty reason was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51206 THROW; END CATCH;

-- 51207: the variant is not active (draft), so its price is not a sale price yet.
BEGIN TRY
  EXEC catalog.usp_ChangePrice @ItemId=@draft,@NewPriceMinor=135000,@ActorId=@actor,
    @OriginNodeId=@node,@EventId=@event2,@Reason=N'Precio de borrador';
  THROW 59002,'ASSERT FAIL: the price of a draft variant was changed',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51207 THROW; END CATCH;

-- Nothing changed: price, history and outbox are untouched.
SET @n=(SELECT UnitPriceMinor FROM catalog.Items WHERE Id=@item);
EXEC test.AssertEq N'unit price after the rejections',120000,@n;
SET @n=(SELECT UnitPriceMinor FROM catalog.Items WHERE Id=@draft);
EXEC test.AssertEq N'unit price of the draft variant',90000,@n;
SET @n=(SELECT COUNT(*) FROM catalog.PriceHistory);
EXEC test.AssertEq N'price history rows after the rejections',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventType='catalog.price_changed');
EXEC test.AssertEq N'price events after the rejections',0,@n;
PRINT 'PASS';

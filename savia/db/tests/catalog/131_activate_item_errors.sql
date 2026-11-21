-- TEST: usp_ActivateItem rejects a price of zero or a negative cost (51220) and a variant that does not exist or is not active (51221).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @draft uniqueidentifier=test.Id('itemDraft'),@missing uniqueidentifier=NEWID(),
  @actor uniqueidentifier=test.Id('manager'),@node uniqueidentifier=test.Id('nodeA'),
  @event uniqueidentifier=NEWID(),@n bigint;

-- 51220: the price must be approved, zero is not a price.
BEGIN TRY
  EXEC catalog.usp_ActivateItem @ItemId=@draft,@UnitPriceMinor=0,@UnitCostMinor=61000,
    @ActorId=@actor,@OriginNodeId=@node,@EventId=@event;
  THROW 59002,'ASSERT FAIL: a variant was activated with a price of zero',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51220 THROW; END CATCH;

-- 51220: a negative cost is not a cost.
BEGIN TRY
  EXEC catalog.usp_ActivateItem @ItemId=@draft,@UnitPriceMinor=95000,@UnitCostMinor=-1,
    @ActorId=@actor,@OriginNodeId=@node,@EventId=@event;
  THROW 59002,'ASSERT FAIL: a variant was activated with a negative cost',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51220 THROW; END CATCH;

-- 51221: the variant does not exist.
BEGIN TRY
  EXEC catalog.usp_ActivateItem @ItemId=@missing,@UnitPriceMinor=95000,@UnitCostMinor=61000,
    @ActorId=@actor,@OriginNodeId=@node,@EventId=@event;
  THROW 59002,'ASSERT FAIL: a missing variant was activated',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51221 THROW; END CATCH;

-- The variant is still draft and nothing was published.
SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id=@draft AND Status='draft' AND UnitCostMinor IS NULL);
EXEC test.AssertEq N'the variant is still draft without cost',1,@n;
SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id=@missing);
EXEC test.AssertEq N'items created by the rejected activation',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventType='catalog.item_activated');
EXEC test.AssertEq N'activation events after the rejections',0,@n;
PRINT 'PASS';

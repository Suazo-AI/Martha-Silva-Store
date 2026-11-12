-- TEST: a price change applied to an already active variant leaves a trace in the price history.
-- XFAIL: D-A-05 usp_ActivateItem changes the price of an active variant without writing any catalog.PriceHistory row.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @item uniqueidentifier=test.Id('item'),@actor uniqueidentifier=test.Id('manager'),
  @node uniqueidentifier=test.Id('nodeA'),@event uniqueidentifier=NEWID(),@n bigint;

EXEC catalog.usp_ActivateItem @ItemId=@item,@UnitPriceMinor=130000,@UnitCostMinor=62000,
  @ActorId=@actor,@OriginNodeId=@node,@EventId=@event;

SET @n=(SELECT UnitPriceMinor FROM catalog.Items WHERE Id=@item);
EXEC test.AssertEq N'new unit price',130000,@n;
SET @n=(SELECT COUNT(*) FROM catalog.PriceHistory WHERE ItemId=@item
        AND OldPriceMinor=120000 AND NewPriceMinor=130000);
EXEC test.AssertEq N'price history rows for the price change',1,@n;
PRINT 'PASS';

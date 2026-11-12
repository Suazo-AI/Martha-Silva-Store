-- TEST: a reserved order is stored once with exact totals, reserves web stock only, and a retry with the same ids changes nothing while a retry with other content is rejected.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@locA uniqueidentifier=test.Id('locA'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @item uniqueidentifier=test.Id('item'),@item2 uniqueidentifier=test.Id('item2'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @allocation uniqueidentifier=NEWID(),@allocation2 uniqueidentifier=NEWID(),
  @order uniqueidentifier=NEWID(),@order2 uniqueidentifier=NEWID(),
  @orderEvent uniqueidentifier=NEWID(),@orderEvent2 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),
  @n bigint;
DECLARE @webLines webstore.OrderLineRequest;

EXEC test.SeedStock @item,@locA,5;
EXEC test.SeedStock @item2,@locA,5;
EXEC inventory.usp_AllocateToWeb @AllocationId=@allocation,@ItemId=@item,@LocationId=@locA,
  @Quantity=2,@ActorId=@manager,@OriginNodeId=@nodeA;
EXEC inventory.usp_AllocateToWeb @AllocationId=@allocation2,@ItemId=@item2,@LocationId=@locA,
  @Quantity=2,@ActorId=@manager,@OriginNodeId=@nodeA;

INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
  @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
  @OriginNodeId=@nodeCloud,@EventId=@orderEvent,@Lines=@webLines;

SET @n=(SELECT TotalMinor FROM webstore.Orders WHERE Id=@order);
EXEC test.AssertEq N'order total',120000,@n;
SET @n=(SELECT SubtotalMinor FROM webstore.Orders WHERE Id=@order);
EXEC test.AssertEq N'order subtotal',120000,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Orders WHERE Id=@order AND Status='reserved' AND CurrencyCode='NIO' AND CustomerId=@customer);
EXEC test.AssertEq N'order stored reserved once',1,@n;
SET @n=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='web');
EXEC test.AssertEq N'web reserved by the order',1,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='web');
EXEC test.AssertEq N'web on hand unchanged',2,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='store');
EXEC test.AssertEq N'store pool untouched by the order',3,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockReservations WHERE ReferenceType='web_order_line'
        AND Id IN (SELECT ReservationId FROM webstore.OrderLines WHERE OrderId=@order));
EXEC test.AssertEq N'one active reservation for the line',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Fulfillments WHERE OrderId=@order AND BranchId=@branchA AND LocationId=@locA AND Status='pending');
EXEC test.AssertEq N'pending fulfillment created',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@orderEvent AND EventType='web.order_reserved');
EXEC test.AssertEq N'order event in outbox',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.EventDeliveries WHERE EventId=@orderEvent AND DestinationNodeId=@nodeA);
EXEC test.AssertEq N'order event routed to the branch node',1,@n;

-- Retry with the same ids and content (the checkout did not get the reply): nothing changes.
EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
  @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
  @OriginNodeId=@nodeCloud,@EventId=@orderEvent,@Lines=@webLines;
SET @n=(SELECT COUNT(*) FROM webstore.Orders);
EXEC test.AssertEq N'no duplicate order after retry',1,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockReservations WHERE Pool='web' AND ReferenceType='web_order_line');
EXEC test.AssertEq N'no duplicate reservation after retry',1,@n;
SET @n=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='web');
EXEC test.AssertEq N'web reserved unchanged after retry',1,@n;

-- Same OrderId with different content is rejected.
DELETE FROM @webLines;
INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,2,120000,0);
BEGIN TRY
  EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
    @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
    @OriginNodeId=@nodeCloud,@EventId=@e2,@Lines=@webLines;
  THROW 59002,'ASSERT FAIL: order id reused with other content was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51710 THROW; END CATCH;

-- A second order on item2 charges 15% tax exactly: total 85000 + 12750 = 97750.
DELETE FROM @webLines;
INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item2,1,85000,0);
EXEC webstore.usp_CreateReservedOrder @OrderId=@order2,@CustomerId=@customer,
  @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
  @OriginNodeId=@nodeCloud,@EventId=@orderEvent2,@Lines=@webLines;
SET @n=(SELECT TaxMinor FROM webstore.Orders WHERE Id=@order2);
EXEC test.AssertEq N'order tax 15 percent',12750,@n;
SET @n=(SELECT TotalMinor FROM webstore.Orders WHERE Id=@order2);
EXEC test.AssertEq N'order total with tax',97750,@n;
PRINT 'PASS';

-- TEST: fulfilling a paid order lowers web OnHand and Reserved by the same quantity once; a retry changes nothing and an unpaid or unknown order is rejected.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @flag bigint; DECLARE @tmp uniqueidentifier=NEWID();
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@locA uniqueidentifier=test.Id('locA'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @item uniqueidentifier=test.Id('item'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @allocation uniqueidentifier=NEWID(),
  @order uniqueidentifier=NEWID(),@order2 uniqueidentifier=NEWID(),
  @payment uniqueidentifier=NEWID(),
  @orderEvent uniqueidentifier=NEWID(),@orderEvent2 uniqueidentifier=NEWID(),
  @paymentEvent uniqueidentifier=NEWID(),@fulfillEvent uniqueidentifier=NEWID(),
  @payment2 uniqueidentifier=NEWID(),@paymentEvent2 uniqueidentifier=NEWID(),
  @fulfillEvent2 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),
  @n bigint,@status varchar(24);
DECLARE @webLines webstore.OrderLineRequest;

EXEC test.SeedStock @item,@locA,5;
EXEC inventory.usp_AllocateToWeb @AllocationId=@allocation,@ItemId=@item,@LocationId=@locA,
  @Quantity=2,@ActorId=@manager,@OriginNodeId=@nodeA;

-- Fulfilling a merely reserved order is rejected.
INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
EXEC webstore.usp_CreateReservedOrder @OrderId=@order2,@CustomerId=@customer,
  @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
  @OriginNodeId=@nodeCloud,@EventId=@orderEvent2,@Lines=@webLines;
BEGIN TRY
  EXEC webstore.usp_FulfillPaidOrder @OrderId=@order2,@OriginNodeId=@nodeA,@EventId=@e2,@ActorId=@manager;
  THROW 59002,'ASSERT FAIL: fulfillment of an unpaid order was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51707 THROW; END CATCH;

-- Fulfilling an unknown order is rejected.
BEGIN TRY
  EXEC webstore.usp_FulfillPaidOrder @OrderId=@tmp,@OriginNodeId=@nodeA,@EventId=@e2,@ActorId=@manager;
  THROW 59002,'ASSERT FAIL: fulfillment of an unknown order was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51707 THROW; END CATCH;

-- Pay and fulfill.
EXEC webstore.usp_RecordVerifiedPayment @PaymentId=@payment,@OrderId=@order2,
  @Provider=N'stripe',@ExternalPaymentId=N'pi_fulfil',
  @AmountMinor=120000,@CurrencyCode='NIO',@VerifiedByTrustedService=1,
  @OriginNodeId=@nodeCloud,@EventId=@paymentEvent;
EXEC webstore.usp_FulfillPaidOrder @OrderId=@order2,@OriginNodeId=@nodeA,@EventId=@fulfillEvent,@ActorId=@manager;

SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='web');
EXEC test.AssertEq N'web on hand lowered by fulfillment',1,@n;
SET @n=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='web');
EXEC test.AssertEq N'web reserved cleared by fulfillment',0,@n;
SET @status=(SELECT Status FROM webstore.Orders WHERE Id=@order2);
SET @flag=CASE WHEN @status='fulfilled' THEN 1 ELSE 0 END;
EXEC test.AssertEq N'order fulfilled',1,@flag;
SET @n=(SELECT COUNT(*) FROM webstore.Fulfillments WHERE OrderId=@order2 AND Status='shipped' AND ShippedAt IS NOT NULL);
EXEC test.AssertEq N'fulfillment shipped once',1,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE ItemId=@item AND LocationId=@locA AND Pool='web' AND Kind='fulfill' AND OnHandDelta=-1 AND ReservedDelta=-1);
EXEC test.AssertEq N'fulfill movement recorded once',1,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockReservations WHERE ReferenceType='web_order_line' AND Status='fulfilled');
EXEC test.AssertEq N'reservation closed as fulfilled',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@fulfillEvent AND EventType='web.fulfilled');
EXEC test.AssertEq N'fulfill event in outbox',1,@n;

-- Retry of the fulfillment (lost reply): nothing changes.
EXEC webstore.usp_FulfillPaidOrder @OrderId=@order2,@OriginNodeId=@nodeA,@EventId=@e2,@ActorId=@manager;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='web');
EXEC test.AssertEq N'web on hand unchanged after retry',1,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE ItemId=@item AND Pool='web' AND Kind='fulfill');
EXEC test.AssertEq N'no duplicate fulfill movement after retry',1,@n;

-- Fulfilling an already fulfilled order again would be silent; a missing reservation on a paid order is rejected.
-- (Simulated by a second paid order whose reservation row is gone.)
DELETE FROM @webLines;
INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
  @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
  @OriginNodeId=@nodeCloud,@EventId=@orderEvent,@Lines=@webLines;
EXEC webstore.usp_RecordVerifiedPayment @PaymentId=@payment2,@OrderId=@order,
  @Provider=N'stripe',@ExternalPaymentId=N'pi_orphan',
  @AmountMinor=120000,@CurrencyCode='NIO',@VerifiedByTrustedService=1,
  @OriginNodeId=@nodeCloud,@EventId=@paymentEvent2;
UPDATE inventory.StockReservations SET Status='released' WHERE Id IN (SELECT ReservationId FROM webstore.OrderLines WHERE OrderId=@order);
BEGIN TRY
  EXEC webstore.usp_FulfillPaidOrder @OrderId=@order,@OriginNodeId=@nodeA,@EventId=@fulfillEvent2,@ActorId=@manager;
  THROW 59002,'ASSERT FAIL: fulfillment without reservation was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51709 THROW; END CATCH;
PRINT 'PASS';

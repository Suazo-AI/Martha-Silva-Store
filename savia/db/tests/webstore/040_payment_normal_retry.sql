-- TEST: a verified payment equal to the order total marks the order paid once; a retry of the same gateway payment changes nothing and a reused gateway id for another payment is rejected.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @flag bigint; DECLARE @tmp uniqueidentifier=NEWID();
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@locA uniqueidentifier=test.Id('locA'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @item uniqueidentifier=test.Id('item'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @allocation uniqueidentifier=NEWID(),
  @order uniqueidentifier=NEWID(),@order2 uniqueidentifier=NEWID(),
  @payment uniqueidentifier=NEWID(),@payment2 uniqueidentifier=NEWID(),
  @orderEvent uniqueidentifier=NEWID(),@orderEvent2 uniqueidentifier=NEWID(),
  @paymentEvent uniqueidentifier=NEWID(),@paymentEvent2 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),
  @n bigint,@status varchar(24);
DECLARE @webLines webstore.OrderLineRequest;

EXEC test.SeedStock @item,@locA,5;
EXEC inventory.usp_AllocateToWeb @AllocationId=@allocation,@ItemId=@item,@LocationId=@locA,
  @Quantity=2,@ActorId=@manager,@OriginNodeId=@nodeA;
INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
  @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
  @OriginNodeId=@nodeCloud,@EventId=@orderEvent,@Lines=@webLines;

EXEC webstore.usp_RecordVerifiedPayment @PaymentId=@payment,@OrderId=@order,
  @Provider=N'stripe',@ExternalPaymentId=N'pi_0001',
  @AmountMinor=120000,@CurrencyCode='NIO',@VerifiedByTrustedService=1,
  @OriginNodeId=@nodeCloud,@EventId=@paymentEvent;

SET @status=(SELECT Status FROM webstore.Orders WHERE Id=@order);
SET @flag=CASE WHEN @status='paid' THEN 1 ELSE 0 END;
EXEC test.AssertEq N'order paid after capture',1,@flag;
SET @n=(SELECT COUNT(*) FROM webstore.Payments WHERE Id=@payment AND OrderId=@order AND Provider=N'stripe'
        AND ExternalPaymentId=N'pi_0001' AND AmountMinor=120000 AND Status='captured');
EXEC test.AssertEq N'payment captured once',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Payments WHERE VerifiedAt IS NOT NULL);
EXEC test.AssertEq N'payment verified timestamp',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@paymentEvent AND EventType='web.payment_captured');
EXEC test.AssertEq N'payment event in outbox',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.EventDeliveries WHERE EventId=@paymentEvent AND DestinationNodeId=@nodeA);
EXEC test.AssertEq N'payment event routed to the branch node',1,@n;

-- Retry with the same gateway id and payment id: nothing changes.
EXEC webstore.usp_RecordVerifiedPayment @PaymentId=@payment,@OrderId=@order,
  @Provider=N'stripe',@ExternalPaymentId=N'pi_0001',
  @AmountMinor=120000,@CurrencyCode='NIO',@VerifiedByTrustedService=1,
  @OriginNodeId=@nodeCloud,@EventId=@paymentEvent;
SET @n=(SELECT COUNT(*) FROM webstore.Payments);
EXEC test.AssertEq N'no duplicate payment after retry',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventType='web.payment_captured');
EXEC test.AssertEq N'no duplicate payment event after retry',1,@n;

-- The same gateway id for a different payment is rejected.
DELETE FROM @webLines;
INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
EXEC webstore.usp_CreateReservedOrder @OrderId=@order2,@CustomerId=@customer,
  @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
  @OriginNodeId=@nodeCloud,@EventId=@orderEvent2,@Lines=@webLines;
BEGIN TRY
  EXEC webstore.usp_RecordVerifiedPayment @PaymentId=@payment2,@OrderId=@order2,
    @Provider=N'stripe',@ExternalPaymentId=N'pi_0001',
    @AmountMinor=120000,@CurrencyCode='NIO',@VerifiedByTrustedService=1,
    @OriginNodeId=@nodeCloud,@EventId=@e2;
  THROW 59002,'ASSERT FAIL: gateway id reused for another payment was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51705 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM webstore.Payments);
EXEC test.AssertEq N'still one payment after reuse rejection',1,@n;
SET @status=(SELECT Status FROM webstore.Orders WHERE Id=@order2);
SET @flag=CASE WHEN @status='reserved' THEN 1 ELSE 0 END;
EXEC test.AssertEq N'second order still reserved',1,@flag;
PRINT 'PASS';

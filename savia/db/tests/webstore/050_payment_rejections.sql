-- TEST: a payment is rejected with its exact error when not verified by the trusted service, when the amount or currency differs from the order, and when the order is not an unpaid reservation.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @flag bigint; DECLARE @tmp uniqueidentifier=NEWID();
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@locA uniqueidentifier=test.Id('locA'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @item uniqueidentifier=test.Id('item'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @allocation uniqueidentifier=NEWID(),
  @order uniqueidentifier=NEWID(),
  @payment uniqueidentifier=NEWID(),@payment2 uniqueidentifier=NEWID(),@payment3 uniqueidentifier=NEWID(),
  @payment4 uniqueidentifier=NEWID(),@payment5 uniqueidentifier=NEWID(),
  @orderEvent uniqueidentifier=NEWID(),@paymentEvent uniqueidentifier=NEWID(),
  @e1 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),
  @n bigint,@status varchar(24);
DECLARE @webLines webstore.OrderLineRequest;

EXEC test.SeedStock @item,@locA,5;
EXEC inventory.usp_AllocateToWeb @AllocationId=@allocation,@ItemId=@item,@LocationId=@locA,
  @Quantity=2,@ActorId=@manager,@OriginNodeId=@nodeA;
INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
  @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
  @OriginNodeId=@nodeCloud,@EventId=@orderEvent,@Lines=@webLines;

-- Not verified by the trusted backend service.
BEGIN TRY
  EXEC webstore.usp_RecordVerifiedPayment @PaymentId=@payment,@OrderId=@order,
    @Provider=N'stripe',@ExternalPaymentId=N'pi_noverif',
    @AmountMinor=120000,@CurrencyCode='NIO',@VerifiedByTrustedService=0,
    @OriginNodeId=@nodeCloud,@EventId=@e1;
  THROW 59002,'ASSERT FAIL: unverified payment was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51704 THROW; END CATCH;

-- Amount one cent below the order total.
BEGIN TRY
  EXEC webstore.usp_RecordVerifiedPayment @PaymentId=@payment2,@OrderId=@order,
    @Provider=N'stripe',@ExternalPaymentId=N'pi_short',
    @AmountMinor=119999,@CurrencyCode='NIO',@VerifiedByTrustedService=1,
    @OriginNodeId=@nodeCloud,@EventId=@paymentEvent;
  THROW 59002,'ASSERT FAIL: underpaid amount was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51706 THROW; END CATCH;

-- Wrong currency.
BEGIN TRY
  EXEC webstore.usp_RecordVerifiedPayment @PaymentId=@payment3,@OrderId=@order,
    @Provider=N'stripe',@ExternalPaymentId=N'pi_usd',
    @AmountMinor=120000,@CurrencyCode='USD',@VerifiedByTrustedService=1,
    @OriginNodeId=@nodeCloud,@EventId=@paymentEvent;
  THROW 59002,'ASSERT FAIL: wrong currency payment was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51706 THROW; END CATCH;

-- Unknown order.
BEGIN TRY
  EXEC webstore.usp_RecordVerifiedPayment @PaymentId=@tmp,@OrderId=@tmp,
    @Provider=N'stripe',@ExternalPaymentId=N'pi_ghost',
    @AmountMinor=120000,@CurrencyCode='NIO',@VerifiedByTrustedService=1,
    @OriginNodeId=@nodeCloud,@EventId=@paymentEvent;
  THROW 59002,'ASSERT FAIL: payment for an unknown order was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51706 THROW; END CATCH;

-- One real capture, then a second different payment against the now paid order.
EXEC webstore.usp_RecordVerifiedPayment @PaymentId=@payment,@OrderId=@order,
  @Provider=N'stripe',@ExternalPaymentId=N'pi_ok',
  @AmountMinor=120000,@CurrencyCode='NIO',@VerifiedByTrustedService=1,
  @OriginNodeId=@nodeCloud,@EventId=@paymentEvent;
BEGIN TRY
  EXEC webstore.usp_RecordVerifiedPayment @PaymentId=@payment4,@OrderId=@order,
    @Provider=N'stripe',@ExternalPaymentId=N'pi_second',
    @AmountMinor=120000,@CurrencyCode='NIO',@VerifiedByTrustedService=1,
    @OriginNodeId=@nodeCloud,@EventId=@e2;
  THROW 59002,'ASSERT FAIL: double payment of the same order was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51706 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM webstore.Payments);
EXEC test.AssertEq N'only the valid payment stored',1,@n;
SET @status=(SELECT Status FROM webstore.Orders WHERE Id=@order);
SET @flag=CASE WHEN @status='paid' THEN 1 ELSE 0 END;
EXEC test.AssertEq N'order paid exactly once',1,@flag;
PRINT 'PASS';

-- TEST: an order is rejected with its exact error for empty lines, negative shipping, a fulfillment branch that does not match, and invalid price/quantity; nothing is stored.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),
  @locA uniqueidentifier=test.Id('locA'),@locB uniqueidentifier=test.Id('locB'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @item uniqueidentifier=test.Id('item'),@itemDraft uniqueidentifier=test.Id('itemDraft'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @allocation uniqueidentifier=NEWID(),
  @order uniqueidentifier=NEWID(),@orderEvent uniqueidentifier=NEWID(),
  @n bigint;
DECLARE @webLines webstore.OrderLineRequest;

EXEC test.SeedStock @item,@locA,5;
EXEC inventory.usp_AllocateToWeb @AllocationId=@allocation,@ItemId=@item,@LocationId=@locA,
  @Quantity=2,@ActorId=@manager,@OriginNodeId=@nodeA;

-- Empty lines.
BEGIN TRY
  EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
    @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
    @OriginNodeId=@nodeCloud,@EventId=@orderEvent,@Lines=@webLines;
  THROW 59002,'ASSERT FAIL: empty order was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51701 THROW; END CATCH;

-- Negative shipping.
INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
BEGIN TRY
  EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
    @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=-1,
    @OriginNodeId=@nodeCloud,@EventId=@orderEvent,@Lines=@webLines;
  THROW 59002,'ASSERT FAIL: negative shipping was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51701 THROW; END CATCH;

-- Location does not belong to the branch.
BEGIN TRY
  EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
    @CurrencyCode='NIO',@LocationId=@locB,@BranchId=@branchA,@ShippingMinor=0,
    @OriginNodeId=@nodeCloud,@EventId=@orderEvent,@Lines=@webLines;
  THROW 59002,'ASSERT FAIL: mismatched branch and location was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51702 THROW; END CATCH;

-- Unit price different from the catalog price.
DELETE FROM @webLines;
INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,119000,0);
BEGIN TRY
  EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
    @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
    @OriginNodeId=@nodeCloud,@EventId=@orderEvent,@Lines=@webLines;
  THROW 59002,'ASSERT FAIL: wrong unit price was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51703 THROW; END CATCH;

-- Zero quantity.
DELETE FROM @webLines;
INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,0,120000,0);
BEGIN TRY
  EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
    @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
    @OriginNodeId=@nodeCloud,@EventId=@orderEvent,@Lines=@webLines;
  THROW 59002,'ASSERT FAIL: zero quantity was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51703 THROW; END CATCH;

-- Discount larger than the line value.
DELETE FROM @webLines;
INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,200000);
BEGIN TRY
  EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
    @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
    @OriginNodeId=@nodeCloud,@EventId=@orderEvent,@Lines=@webLines;
  THROW 59002,'ASSERT FAIL: discount above the line value was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51703 THROW; END CATCH;

-- Draft item (not active).
DELETE FROM @webLines;
INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@itemDraft,1,90000,0);
BEGIN TRY
  EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
    @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
    @OriginNodeId=@nodeCloud,@EventId=@orderEvent,@Lines=@webLines;
  THROW 59002,'ASSERT FAIL: draft item order was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51703 THROW; END CATCH;

-- Wrong currency.
DELETE FROM @webLines;
INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
BEGIN TRY
  EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
    @CurrencyCode='USD',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
    @OriginNodeId=@nodeCloud,@EventId=@orderEvent,@Lines=@webLines;
  THROW 59002,'ASSERT FAIL: wrong currency order was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51703 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM webstore.Orders);
EXEC test.AssertEq N'no order stored by rejections',0,@n;
SET @n=(SELECT COUNT(*) FROM webstore.OrderLines);
EXEC test.AssertEq N'no order lines stored by rejections',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockReservations WHERE ReferenceType='web_order_line');
EXEC test.AssertEq N'no reservation stored by rejections',0,@n;
SET @n=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='web');
EXEC test.AssertEq N'web stock untouched by rejections',0,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='web');
EXEC test.AssertEq N'web on hand untouched by rejections',2,@n;
PRINT 'PASS';

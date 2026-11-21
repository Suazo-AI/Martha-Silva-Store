-- TEST: an order reserves only the 'web' pool; it cannot reserve more than the available web stock and then nothing is stored.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@locA uniqueidentifier=test.Id('locA'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @item uniqueidentifier=test.Id('item'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @allocation uniqueidentifier=NEWID(),
  @order uniqueidentifier=NEWID(),@orderEvent uniqueidentifier=NEWID(),
  @n bigint;
DECLARE @webLines webstore.OrderLineRequest;

EXEC test.SeedStock @item,@locA,5;
INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);

-- The store pool has stock but the web pool is empty: the order must fail and store nothing.
BEGIN TRY
  EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
    @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
    @OriginNodeId=@nodeCloud,@EventId=@orderEvent,@Lines=@webLines;
  THROW 59002,'ASSERT FAIL: order reserved web stock that does not exist',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51102 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM webstore.Orders);
EXEC test.AssertEq N'no order stored without web stock',0,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='store');
EXEC test.AssertEq N'store stock untouched without web stock',5,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockReservations);
EXEC test.AssertEq N'no reservation without web stock',0,@n;

-- Two units in the web pool: an order of three fails and stores nothing.
EXEC inventory.usp_AllocateToWeb @AllocationId=@allocation,@ItemId=@item,@LocationId=@locA,
  @Quantity=2,@ActorId=@manager,@OriginNodeId=@nodeA;
DELETE FROM @webLines;
INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,3,120000,0);
BEGIN TRY
  EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
    @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
    @OriginNodeId=@nodeCloud,@EventId=@orderEvent,@Lines=@webLines;
  THROW 59002,'ASSERT FAIL: order above the web stock was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51102 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM webstore.Orders);
EXEC test.AssertEq N'no order stored above web stock',0,@n;
SET @n=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='web');
EXEC test.AssertEq N'web reserved still zero above web stock',0,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='web');
EXEC test.AssertEq N'web on hand still two above web stock',2,@n;

-- An order of exactly two is accepted and reserves only in the web pool.
DELETE FROM @webLines;
INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,2,120000,0);
EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
  @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
  @OriginNodeId=@nodeCloud,@EventId=@orderEvent,@Lines=@webLines;
SET @n=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='web');
EXEC test.AssertEq N'web reserved two',2,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='web');
EXEC test.AssertEq N'web on hand still two',2,@n;
SET @n=(SELECT COALESCE((SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='store'),0));
EXEC test.AssertEq N'store pool never reserved by orders',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE ItemId=@item AND Pool='store' AND SourceType='web_reservation');
EXEC test.AssertEq N'no store-pool movements for the order',0,@n;
PRINT 'PASS';

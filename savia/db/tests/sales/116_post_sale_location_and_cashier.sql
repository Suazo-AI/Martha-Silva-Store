-- TEST: usp_PostSale rejects a location from another branch (51511) and a cashier without access to the branch (51512).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),
  @loc uniqueidentifier=test.Id('locA'),@locB uniqueidentifier=test.Id('locB'),
  @cashier uniqueidentifier=test.Id('cashierA'),@cashierB uniqueidentifier=test.Id('cashierB'),
  @node uniqueidentifier=test.Id('nodeA'),@register uniqueidentifier=test.Id('registerA'),
  @item uniqueidentifier=test.Id('item'),@till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),
  @n bigint;
EXEC test.SeedStock @item,@loc,10;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',120000,120000,0);

-- 51511 la ubicacion de la sucursal B en una venta de la sucursal A
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@locB,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;
  THROW 59002,'ASSERT FAIL: ubicacion de otra sucursal aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51511 THROW; END CATCH;

-- 51512 cajera de la sucursal B vendiendo en la sucursal A
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashierB,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;
  THROW 59002,'ASSERT FAIL: cajera sin acceso a la sucursal aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51512 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM sales.Sales);
EXEC test.AssertEq N'ventas guardadas',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE TillId=@till AND Kind='sale');
EXEC test.AssertEq N'cobros en caja',0,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock intacto',10,@n;
PRINT 'PASS';

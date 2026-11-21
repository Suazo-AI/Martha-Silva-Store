-- TEST: usp_PostSale rejects a sale without lines (51507) and invalid lines (51508) without storing anything.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@item uniqueidentifier=test.Id('item'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@n bigint;
EXEC test.SeedStock @item,@loc,10;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;

-- 51507 venta sin articulos
DECLARE @emptyLines sales.SaleLineRequest,@t1 sales.SaleTenderRequest;
INSERT INTO @t1(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',120000,120000,0);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@emptyLines,@Tenders=@t1;
  THROW 59002,'ASSERT FAIL: venta sin articulos aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51507 THROW; END CATCH;

-- 51508 cantidad cero
DECLARE @bad sales.SaleLineRequest,@t2 sales.SaleTenderRequest;
INSERT INTO @bad(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,0,120000,0);
INSERT INTO @t2(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',120000,120000,0);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@bad,@Tenders=@t2;
  THROW 59002,'ASSERT FAIL: linea con cantidad cero aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51508 THROW; END CATCH;

-- 51508 descuento mayor que el importe de la linea
DECLARE @bad2 sales.SaleLineRequest;
INSERT INTO @bad2(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,120001);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@bad2,@Tenders=@t2;
  THROW 59002,'ASSERT FAIL: descuento mayor que la linea aceptado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51508 THROW; END CATCH;

-- Nada de lo rechazado quedo guardado.
SET @n=(SELECT COUNT(*) FROM sales.Sales);
EXEC test.AssertEq N'ventas guardadas',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleLines);
EXEC test.AssertEq N'lineas guardadas',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE TillId=@till AND Kind='sale');
EXEC test.AssertEq N'cobros en caja',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE Kind='sale');
EXEC test.AssertEq N'movimientos de inventario por venta',0,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock intacto',10,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventType='sales.sale_posted');
EXEC test.AssertEq N'eventos de venta',0,@n;
PRINT 'PASS';

-- TEST: sin stock suficiente usp_PostSale falla con 51102 y no guarda venta, lineas, pagos, caja, inventario ni evento.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@item uniqueidentifier=test.Id('item'),
  @item2 uniqueidentifier=test.Id('item2'),@till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),
  @sale2 uniqueidentifier=NEWID(),@n bigint;
EXEC test.SeedStock @item,@loc,1;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;

-- Se pide 2 y solo hay 1.
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,2,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',240000,240000,0);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;
  THROW 59002,'ASSERT FAIL: venta sin stock aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51102 THROW; END CATCH;

-- Dos lineas del mismo articulo sin stock: la primera linea no debe quedar aplicada.
DECLARE @lines2 sales.SaleLineRequest,@tenders2 sales.SaleTenderRequest;
INSERT INTO @lines2(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor)
  VALUES(1,@item2,1,85000,0),(2,@item2,1,85000,0);
INSERT INTO @tenders2(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',195500,195500,0);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale2,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines2,@Tenders=@tenders2;
  THROW 59002,'ASSERT FAIL: venta con dos lineas sin stock aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51102 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM sales.Sales WHERE Id IN (@sale,@sale2));
EXEC test.AssertEq N'ventas guardadas',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleLines WHERE SaleId IN (@sale,@sale2));
EXEC test.AssertEq N'lineas guardadas',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleTenders WHERE SaleId IN (@sale,@sale2));
EXEC test.AssertEq N'pagos guardados',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE TillId=@till AND Kind='sale');
EXEC test.AssertEq N'cobros en caja',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE SourceId IN (@sale,@sale2));
EXEC test.AssertEq N'movimientos de inventario de las ventas rechazadas',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE ItemId=@item2 AND Kind='sale');
EXEC test.AssertEq N'movimientos de la segunda venta rechazada',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId IN (@sale,@sale2));
EXEC test.AssertEq N'eventos de las ventas rechazadas',0,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock del primer articulo intacto',1,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances WHERE ItemId=@item2 AND LocationId=@loc);
EXEC test.AssertEq N'stock del segundo articulo intacto',0,@n;
PRINT 'PASS';

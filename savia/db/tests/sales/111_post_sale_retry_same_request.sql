-- TEST: reintentar usp_PostSale con los mismos ids no cambia stock, venta, lineas, pagos, caja ni eventos.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@item uniqueidentifier=test.Id('item'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@n bigint;
EXEC test.SeedStock @item,@loc,5;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;

DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,2,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',240000,300000,60000);
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
     @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;

-- Reintento identico: el POS no recibio la respuesta.
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
     @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;

SET @n=(SELECT COUNT(*) FROM sales.Sales WHERE Id=@sale);
EXEC test.AssertEq N'ventas guardadas',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleLines WHERE SaleId=@sale);
EXEC test.AssertEq N'lineas guardadas',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleTenders WHERE SaleId=@sale);
EXEC test.AssertEq N'pagos guardados',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE TillId=@till AND Kind='sale');
EXEC test.AssertEq N'movimientos de caja de la venta',1,@n;
SET @n=(SELECT COALESCE(SUM(DeltaMinor),0) FROM sales.CashEntries WHERE TillId=@till);
EXEC test.AssertEq N'efectivo esperado tras el reintento',240000,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE SourceId=@sale);
EXEC test.AssertEq N'movimientos de inventario',1,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock tras la venta y el reintento',3,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@sale AND EventType='sales.sale_posted');
EXEC test.AssertEq N'eventos de venta',1,@n;
PRINT 'PASS';

-- TEST: una venta descuenta stock una vez por linea, con un movimiento por linea y el saldo final exacto.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@item uniqueidentifier=test.Id('item'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@n bigint;
EXEC test.SeedStock @item,@loc,5;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;

DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor)
  VALUES(1,@item,2,120000,0),(2,@item,1,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',360000,360000,0);
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
     @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;

SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE SourceId=@sale AND Kind='sale');
EXEC test.AssertEq N'un movimiento por linea',2,@n;
SET @n=(SELECT COUNT(DISTINCT OperationId) FROM inventory.StockMovements WHERE SourceId=@sale);
EXEC test.AssertEq N'operaciones de inventario distintas',2,@n;
SET @n=(SELECT COALESCE(SUM(OnHandDelta),0) FROM inventory.StockMovements WHERE SourceId=@sale);
EXEC test.AssertEq N'unidades descontadas',-3,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE SourceId=@sale AND Pool='store' AND SourceType='sale');
EXEC test.AssertEq N'movimientos del pool de tienda',2,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock final 5-3',2,@n;
SET @n=(SELECT MAX(OnHandAfter) FROM inventory.StockMovements WHERE SourceId=@sale);
EXEC test.AssertEq N'saldo tras la primera linea',3,@n;
SET @n=(SELECT MIN(OnHandAfter) FROM inventory.StockMovements WHERE SourceId=@sale);
EXEC test.AssertEq N'saldo tras la segunda linea',2,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@sale AND EventType='sales.sale_posted');
EXEC test.AssertEq N'un solo evento de venta',1,@n;
PRINT 'PASS';

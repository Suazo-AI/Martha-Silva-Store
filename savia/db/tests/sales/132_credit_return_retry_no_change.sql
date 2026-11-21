-- TEST: reintentar usp_PostCreditReturn con los mismos ids deja un solo anticipo, una sola linea devuelta y el mismo stock.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@super uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@register uniqueidentifier=test.Id('registerA'),
  @item uniqueidentifier=test.Id('item'),@customer uniqueidentifier=test.Id('customer'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@rev uniqueidentifier=NEWID(),
  @credit uniqueidentifier=NEWID(),@line uniqueidentifier,@n bigint;
EXEC test.SeedStock @item,@loc,10;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,3,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',360000,360000,0);
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
     @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders,
     @CustomerId=@customer;
SET @line=(SELECT Id FROM sales.SaleLines WHERE SaleId=@sale AND LineNumber=1);

DECLARE @ret sales.ReturnLineRequest;
INSERT INTO @ret(SaleLineId,Quantity,RestockPool) VALUES(@line,1,'store');
EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,
  @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
  @Reason=N'reintento',@OriginNodeId=@node,@Lines=@ret;
-- Mismo reintento: el POS no recibio la respuesta.
EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,
  @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
  @Reason=N'reintento',@OriginNodeId=@node,@Lines=@ret;

SET @n=(SELECT COUNT(*) FROM sales.SaleReversals WHERE Id=@rev);
EXEC test.AssertEq N'devoluciones guardadas',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleReversalLines WHERE ReversalId=@rev);
EXEC test.AssertEq N'lineas devueltas',1,@n;
SET @n=(SELECT CreditMinor FROM sales.SaleReversals WHERE Id=@rev);
EXEC test.AssertEq N'importe de la devolucion',120000,@n;
SET @n=(SELECT COUNT(*) FROM credits.Credits WHERE Id=@credit AND SourceReversalId=@rev);
EXEC test.AssertEq N'anticipos emitidos',1,@n;
SET @n=(SELECT COUNT(*) FROM credits.CreditMovements WHERE CreditId=@credit);
EXEC test.AssertEq N'movimientos del anticipo',1,@n;
SET @n=(SELECT ReturnedQuantity FROM sales.SaleLines WHERE Id=@line);
EXEC test.AssertEq N'unidades devueltas',1,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE SourceId=@rev);
EXEC test.AssertEq N'movimientos de inventario',1,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock tras el reintento',8,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@rev);
EXEC test.AssertEq N'eventos de la devolucion',1,@n;
PRINT 'PASS';

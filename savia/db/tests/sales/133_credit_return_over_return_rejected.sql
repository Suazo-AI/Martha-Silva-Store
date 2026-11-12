-- TEST: devolver mas unidades de las vendidas se rechaza con 51532 y no deja devolucion, anticipo ni movimiento de stock.
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
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,2,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',240000,240000,0);
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
     @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders,
     @CustomerId=@customer;
SET @line=(SELECT Id FROM sales.SaleLines WHERE SaleId=@sale AND LineNumber=1);

DECLARE @ret sales.ReturnLineRequest;
INSERT INTO @ret(SaleLineId,Quantity,RestockPool) VALUES(@line,3,'store');
BEGIN TRY
  EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,
    @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
    @Reason=N'intento de devolver de mas',@OriginNodeId=@node,@Lines=@ret;
  THROW 59002,'ASSERT FAIL: se devolvieron 3 unidades de una venta de 2',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51532 THROW; END CATCH;

SET @n=(SELECT ReturnedQuantity FROM sales.SaleLines WHERE Id=@line);
EXEC test.AssertEq N'unidades devueltas',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleReversals WHERE SaleId=@sale);
EXEC test.AssertEq N'devoluciones guardadas',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleReversalLines WHERE SaleLineId=@line);
EXEC test.AssertEq N'lineas devueltas',0,@n;
SET @n=(SELECT COUNT(*) FROM credits.Credits WHERE Id=@credit);
EXEC test.AssertEq N'anticipos emitidos',0,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock intacto tras el rechazo',8,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE Kind='return');
EXEC test.AssertEq N'movimientos de devolucion',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.Sales WHERE Id=@sale AND Status='recorded');
EXEC test.AssertEq N'la venta sigue registrada',1,@n;
PRINT 'PASS';

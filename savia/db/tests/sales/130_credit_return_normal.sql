-- TEST: usp_PostCreditReturn emite un anticipo igual al total de la linea devuelta, devuelve el stock al pool elegido y deja la venta parcialmente devuelta.
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

-- Devolucion de 1 de 3 unidades: credito 120000.
DECLARE @ret sales.ReturnLineRequest;
INSERT INTO @ret(SaleLineId,Quantity,RestockPool) VALUES(@line,1,'store');
EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,
  @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
  @Reason=N'no le quedo la talla',@OriginNodeId=@node,@Lines=@ret;

SET @n=(SELECT COUNT(*) FROM sales.SaleReversals WHERE Id=@rev AND SaleId=@sale AND Kind='return'
        AND SettlementKind='credit' AND Status='approved' AND CreditMinor=120000
        AND ApprovedBy=@super AND LocationId=@loc AND TillId=@till);
EXEC test.AssertEq N'devolucion aprobada por 120000',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleReversalLines WHERE ReversalId=@rev AND SaleLineId=@line
        AND Quantity=1 AND CreditMinor=120000 AND COGSReversedMinor=60000 AND RestockPool='store');
EXEC test.AssertEq N'linea devuelta con costo revertido',1,@n;
SET @n=(SELECT ReturnedQuantity FROM sales.SaleLines WHERE Id=@line);
EXEC test.AssertEq N'unidades devueltas en la linea',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.Sales WHERE Id=@sale AND Status='partially_returned');
EXEC test.AssertEq N'venta parcialmente devuelta',1,@n;
SET @n=(SELECT COUNT(*) FROM credits.Credits WHERE Id=@credit AND SourceReversalId=@rev
        AND OriginalMinor=120000 AND CustomerId=@customer AND CurrencyCode='NIO' AND Status='active');
EXEC test.AssertEq N'anticipo emitido por 120000',1,@n;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branch);
EXEC test.AssertEq N'saldo disponible del anticipo en la sucursal',120000,@n;
SET @n=(SELECT COUNT(*) FROM credits.CreditMovements WHERE CreditId=@credit AND Kind='issue'
        AND AvailableDeltaMinor=120000 AND SourceId=@rev);
EXEC test.AssertEq N'movimiento de emision',1,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock tras devolver 1 de 3 de 10',8,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE SourceId=@rev AND Kind='return'
        AND OnHandDelta=1 AND Pool='store');
EXEC test.AssertEq N'movimiento de devolucion a tienda',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@rev AND EventType='sales.credit_return_posted');
EXEC test.AssertEq N'evento de la devolucion',1,@n;
PRINT 'PASS';

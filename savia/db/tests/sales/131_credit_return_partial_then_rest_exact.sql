-- TEST: devolver en dos partes un total no divisible suma exactamente el total de la linea, sin perder ni ganar un centavo.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@super uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@register uniqueidentifier=test.Id('registerA'),
  @item2 uniqueidentifier=test.Id('item2'),@customer uniqueidentifier=test.Id('customer'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@rev1 uniqueidentifier=NEWID(),
  @rev2 uniqueidentifier=NEWID(),@credit1 uniqueidentifier=NEWID(),@credit2 uniqueidentifier=NEWID(),
  @line uniqueidentifier,@n bigint;
EXEC test.SeedStock @item2,@loc,10;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;
-- 3 unidades: base 254990, IVA 38249, total 293239 (no divisible por 3).
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item2,3,85000,10);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',293239,293239,0);
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
     @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders,
     @CustomerId=@customer,@DiscountApproverId='A0000000-0000-0000-0000-0000000000A5',@DiscountReason=N'Autorizado para prueba';
SET @line=(SELECT Id FROM sales.SaleLines WHERE SaleId=@sale AND LineNumber=1);

DECLARE @p1 sales.ReturnLineRequest;
INSERT INTO @p1(SaleLineId,Quantity,RestockPool) VALUES(@line,1,'store');
EXEC sales.usp_PostCreditReturn @ReversalId=@rev1,@CreditId=@credit1,@SaleId=@sale,@BranchId=@branch,
  @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
  @Reason=N'primera parte',@OriginNodeId=@node,@Lines=@p1;

DECLARE @p2 sales.ReturnLineRequest;
INSERT INTO @p2(SaleLineId,Quantity,RestockPool) VALUES(@line,2,'store');
EXEC sales.usp_PostCreditReturn @ReversalId=@rev2,@CreditId=@credit2,@SaleId=@sale,@BranchId=@branch,
  @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
  @Reason=N'el resto',@OriginNodeId=@node,@Lines=@p2;

SET @n=(SELECT CreditMinor FROM sales.SaleReversals WHERE Id=@rev1);
EXEC test.AssertEq N'credito de la primera parte',97746,@n;
SET @n=(SELECT CreditMinor FROM sales.SaleReversals WHERE Id=@rev2);
EXEC test.AssertEq N'credito del resto 293239-97746',195493,@n;
SET @n=(SELECT COALESCE(SUM(CreditMinor),0) FROM sales.SaleReversalLines WHERE SaleLineId=@line);
EXEC test.AssertEq N'suma de devoluciones igual al total de la linea',293239,@n;
SET @n=(SELECT COALESCE(SUM(OriginalMinor),0) FROM credits.Credits WHERE SourceReversalId IN (@rev1,@rev2));
EXEC test.AssertEq N'anticipos emitidos iguales al total',293239,@n;
SET @n=(SELECT ReturnedQuantity FROM sales.SaleLines WHERE Id=@line);
EXEC test.AssertEq N'unidades devueltas',3,@n;
SET @n=(SELECT COUNT(*) FROM sales.Sales WHERE Id=@sale AND Status='returned');
EXEC test.AssertEq N'venta totalmente devuelta',1,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item2 AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock de vuelta a 10',10,@n;
PRINT 'PASS';

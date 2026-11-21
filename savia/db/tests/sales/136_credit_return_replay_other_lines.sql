-- TEST: usp_PostCreditReturn rejects reusing a ReversalId with different returned lines instead of reporting success.
-- FIXED (V007): D-B-03 usp_PostCreditReturn aceptaba el mismo ReversalId con otras cantidades y responde exito, asi que la cajera cree haber devuelto 3 unidades cuando solo se devolvio 1.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@super uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@register uniqueidentifier=test.Id('registerA'),
  @item uniqueidentifier=test.Id('item'),@customer uniqueidentifier=test.Id('customer'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@rev uniqueidentifier=NEWID(),
  @credit uniqueidentifier=NEWID(),@line uniqueidentifier,@rejected bit=0,@n bigint;
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

DECLARE @one sales.ReturnLineRequest;
INSERT INTO @one(SaleLineId,Quantity,RestockPool) VALUES(@line,1,'store');
EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,
  @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
  @Reason=N'devolucion',@OriginNodeId=@node,@Lines=@one;

-- El mismo comprobante con otras cantidades: es otra instruccion y debe rechazarse.
DECLARE @rest sales.ReturnLineRequest;
INSERT INTO @rest(SaleLineId,Quantity,RestockPool) VALUES(@line,2,'store');
BEGIN TRY
  EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,
    @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
    @Reason=N'devolucion',@OriginNodeId=@node,@Lines=@rest;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()=51538 SET @rejected=1; ELSE THROW;
END CATCH;
IF @rejected=0
  THROW 59002,'ASSERT FAIL: se acepto el mismo ReversalId devolviendo 2 unidades mas',1;

-- Con el producto corregido o no, una devolucion sigue teniendo una sola linea y una sola unidad.
SET @n=(SELECT COUNT(*) FROM sales.SaleReversalLines WHERE ReversalId=@rev);
EXEC test.AssertEq N'lineas de la devolucion',1,@n;
SET @n=(SELECT ReturnedQuantity FROM sales.SaleLines WHERE Id=@line);
EXEC test.AssertEq N'unidades devueltas',1,@n;
SET @n=(SELECT COUNT(*) FROM credits.Credits WHERE SourceReversalId=@rev);
EXEC test.AssertEq N'anticipos de la devolucion',1,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock de tienda: 10 sembradas - 3 vendidas + 1 devuelta',8,@n;
PRINT 'PASS';

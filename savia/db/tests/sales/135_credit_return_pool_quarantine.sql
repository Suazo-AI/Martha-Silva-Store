-- TEST: la prenda devuelta entra al pool elegido (cuarentena) y no al pool de tienda.
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
INSERT INTO @ret(SaleLineId,Quantity,RestockPool) VALUES(@line,1,'quarantine');
EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,
  @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
  @Reason=N'manchada',@OriginNodeId=@node,@Lines=@ret;

SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='quarantine');
EXEC test.AssertEq N'unidades en cuarentena',1,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'el pool de tienda no sube',8,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE SourceId=@rev AND Pool='quarantine' AND OnHandDelta=1);
EXEC test.AssertEq N'movimiento a cuarentena',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleReversalLines WHERE ReversalId=@rev AND RestockPool='quarantine');
EXEC test.AssertEq N'pool guardado en la linea devuelta',1,@n;
SET @n=(SELECT CreditMinor FROM sales.SaleReversals WHERE Id=@rev);
EXEC test.AssertEq N'credito de la unidad devuelta',120000,@n;
PRINT 'PASS';

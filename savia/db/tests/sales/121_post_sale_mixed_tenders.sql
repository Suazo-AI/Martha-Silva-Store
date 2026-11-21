-- TEST: el pago mixto (efectivo + tarjeta) cuadra con el total, la tarjeta guarda referencia y solo el efectivo entra a la caja.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@item uniqueidentifier=test.Id('item'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@n bigint;
EXEC test.SeedStock @item,@loc,5;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;

DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor,Reference)
  VALUES(1,'cash',100000,100000,0,NULL),(2,'card',20000,NULL,NULL,N'AUTH-0001');
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
     @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;

SET @n=(SELECT COUNT(*) FROM sales.SaleTenders WHERE SaleId=@sale);
EXEC test.AssertEq N'pagos guardados',2,@n;
SET @n=(SELECT COALESCE(SUM(AmountMinor),0) FROM sales.SaleTenders WHERE SaleId=@sale);
EXEC test.AssertEq N'pagos igual al total',120000,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleTenders WHERE SaleId=@sale AND TenderKind='card'
        AND Reference=N'AUTH-0001' AND AmountMinor=20000 AND Status='captured');
EXEC test.AssertEq N'pago con tarjeta y referencia',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE TillId=@till AND Kind='sale');
EXEC test.AssertEq N'un solo movimiento de efectivo',1,@n;
SET @n=(SELECT COALESCE(SUM(DeltaMinor),0) FROM sales.CashEntries WHERE TillId=@till);
EXEC test.AssertEq N'efectivo esperado solo por la parte en efectivo',100000,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries c JOIN sales.SaleTenders t ON t.Id=c.SaleTenderId
        WHERE c.TillId=@till AND t.TenderKind='card');
EXEC test.AssertEq N'movimientos de caja de tarjeta',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleTenders WHERE SaleId=@sale AND TenderKind='card' AND SaleId IS NOT NULL);
EXEC test.AssertEq N'la tarjeta no desaparece del recibo',1,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock final',4,@n;
PRINT 'PASS';

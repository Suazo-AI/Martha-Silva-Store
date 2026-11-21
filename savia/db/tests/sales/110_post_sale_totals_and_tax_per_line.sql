-- TEST: el total de la venta es la suma por linea de (precio x cantidad - descuento + IVA), con el IVA redondeado por linea.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@item uniqueidentifier=test.Id('item'),
  @item2 uniqueidentifier=test.Id('item2'),@till uniqueidentifier=NEWID(),
  @sale1 uniqueidentifier=NEWID(),@sale2 uniqueidentifier=NEWID(),@n bigint;
EXEC test.SeedStock @item,@loc,10;
EXEC test.SeedStock @item2,@loc,10;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;

-- Venta 1: 2 blusas sin IVA (240000) + 3 blusas con IVA 15% y descuento 10.
-- Linea 2: base 3x85000-10 = 254990, IVA ROUND(254990*0.15) = 38249, total 293239.
DECLARE @l1 sales.SaleLineRequest,@t1 sales.SaleTenderRequest;
INSERT INTO @l1(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor)
  VALUES(1,@item,2,120000,0),(2,@item2,3,85000,10);
INSERT INTO @t1(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor)
  VALUES(1,'cash',533239,600000,66761);
EXEC sales.usp_PostSale @SaleId=@sale1,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
     @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@l1,@Tenders=@t1,@DiscountApproverId='A0000000-0000-0000-0000-0000000000A5',@DiscountReason=N'Autorizado para prueba';

SET @n=(SELECT SubtotalMinor FROM sales.Sales WHERE Id=@sale1);
EXEC test.AssertEq N'subtotal 2x120000 + 3x85000',495000,@n;
SET @n=(SELECT DiscountMinor FROM sales.Sales WHERE Id=@sale1);
EXEC test.AssertEq N'descuento de la venta',10,@n;
SET @n=(SELECT TaxMinor FROM sales.Sales WHERE Id=@sale1);
EXEC test.AssertEq N'IVA de la venta',38249,@n;
SET @n=(SELECT TotalMinor FROM sales.Sales WHERE Id=@sale1);
EXEC test.AssertEq N'total 240000 + 293239',533239,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleLines WHERE SaleId=@sale1);
EXEC test.AssertEq N'lineas guardadas',2,@n;
SET @n=(SELECT TaxMinor FROM sales.SaleLines WHERE SaleId=@sale1 AND LineNumber=1);
EXEC test.AssertEq N'IVA de la linea sin impuesto',0,@n;
SET @n=(SELECT TotalMinor FROM sales.SaleLines WHERE SaleId=@sale1 AND LineNumber=1);
EXEC test.AssertEq N'total de la linea sin impuesto',240000,@n;
SET @n=(SELECT TaxMinor FROM sales.SaleLines WHERE SaleId=@sale1 AND LineNumber=2);
EXEC test.AssertEq N'IVA por linea',38249,@n;
SET @n=(SELECT TotalMinor FROM sales.SaleLines WHERE SaleId=@sale1 AND LineNumber=2);
EXEC test.AssertEq N'total de la linea con IVA',293239,@n;
DECLARE @sum1 bigint=(SELECT SUM(TotalMinor) FROM sales.SaleLines WHERE SaleId=@sale1),
        @total1 bigint=(SELECT TotalMinor FROM sales.Sales WHERE Id=@sale1);
EXEC test.AssertEq N'suma de lineas igual al total',@total1,@sum1;
SET @n=(SELECT COALESCE(SUM(AmountMinor),0) FROM sales.SaleTenders WHERE SaleId=@sale1);
EXEC test.AssertEq N'pagos igual al total',533239,@n;

-- Venta 2: dos lineas iguales, cada una con IVA 12749. Redondear sobre la suma daria 25497: se exige 25498.
DECLARE @l2 sales.SaleLineRequest,@t2 sales.SaleTenderRequest;
INSERT INTO @l2(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor)
  VALUES(1,@item2,1,85000,10),(2,@item2,1,85000,10);
INSERT INTO @t2(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor)
  VALUES(1,'cash',195478,195478,0);
EXEC sales.usp_PostSale @SaleId=@sale2,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
     @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@l2,@Tenders=@t2,@DiscountApproverId='A0000000-0000-0000-0000-0000000000A5',@DiscountReason=N'Autorizado para prueba';
SET @n=(SELECT TaxMinor FROM sales.Sales WHERE Id=@sale2);
EXEC test.AssertEq N'IVA redondeado por linea 12749+12749',25498,@n;
SET @n=(SELECT TotalMinor FROM sales.Sales WHERE Id=@sale2);
EXEC test.AssertEq N'total de dos lineas de 97739',195478,@n;
DECLARE @tax2lines bigint=(SELECT SUM(TaxMinor) FROM sales.SaleLines WHERE SaleId=@sale2),
        @tax2sale bigint=(SELECT TaxMinor FROM sales.Sales WHERE Id=@sale2);
EXEC test.AssertEq N'IVA de cada linea igual a la venta',@tax2sale,@tax2lines;
PRINT 'PASS';

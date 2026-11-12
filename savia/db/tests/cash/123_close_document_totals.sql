-- TEST: el cierre deja un solo documento contable y un solo trabajo de exportacion, con ventas brutas, devoluciones, neto, IVA y costo exactos.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@super uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@register uniqueidentifier=test.Id('registerA'),
  @item uniqueidentifier=test.Id('item'),@item2 uniqueidentifier=test.Id('item2'),
  @customer uniqueidentifier=test.Id('customer'),@till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),
  @rev uniqueidentifier=NEWID(),@credit uniqueidentifier=NEWID(),@count uniqueidentifier=NEWID(),
  @close uniqueidentifier=NEWID(),@doc uniqueidentifier,@line2 uniqueidentifier,@n bigint;
EXEC test.SeedStock @item,@loc,10;
EXEC test.SeedStock @item2,@loc,10;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@node;

-- Venta: 240000 sin IVA + 293239 con IVA (38249) = 533239; efectivo 500000 y tarjeta 33239.
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor)
  VALUES(1,@item,2,120000,0),(2,@item2,3,85000,10);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor,Reference)
  VALUES(1,'cash',500000,500000,0,NULL),(2,'card',33239,NULL,NULL,N'AUTH-77');
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
     @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders,
     @CustomerId=@customer;
SET @line2=(SELECT Id FROM sales.SaleLines WHERE SaleId=@sale AND LineNumber=2);

-- Devolucion completa de la linea con IVA: 293239.
DECLARE @ret sales.ReturnLineRequest;
INSERT INTO @ret(SaleLineId,Quantity,RestockPool) VALUES(@line2,3,'store');
EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,
  @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
  @Reason=N'devolucion completa',@OriginNodeId=@node,@Lines=@ret;

-- Esperado 100000+500000 = 600000; contado 6x100000.
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@count,@till,@cashier,'draft',@cashier);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity) VALUES(@count,100000,6);
EXEC sales.usp_SubmitCashCount @CashCountId=@count,@ActorId=@cashier;
EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@till,@CashCountId=@count,@ActorId=@super,@OriginNodeId=@node;

SET @doc=(SELECT Id FROM accounting.CloseDocuments WHERE ClosureId=@close);
SET @n=(SELECT COUNT(*) FROM accounting.CloseDocuments WHERE Id=@doc AND DocumentKind='accounting_summary'
        AND Status='prepared' AND CurrencyCode='NIO' AND DocumentNumber=CONCAT(N'CIERRE-',CONVERT(nvarchar(36),@close)));
EXEC test.AssertEq N'documento contable unico del cierre',1,@n;
SET @n=(SELECT SaleGrossMinor FROM accounting.CloseDocuments WHERE Id=@doc);
EXEC test.AssertEq N'ventas brutas del turno',533239,@n;
SET @n=(SELECT SaleTaxMinor FROM accounting.CloseDocuments WHERE Id=@doc);
EXEC test.AssertEq N'IVA de las ventas',38249,@n;
SET @n=(SELECT SaleDiscountMinor FROM accounting.CloseDocuments WHERE Id=@doc);
EXEC test.AssertEq N'descuentos del turno',10,@n;
SET @n=(SELECT SaleCount FROM accounting.CloseDocuments WHERE Id=@doc);
EXEC test.AssertEq N'cantidad de ventas',1,@n;
SET @n=(SELECT ReturnGrossMinor FROM accounting.CloseDocuments WHERE Id=@doc);
EXEC test.AssertEq N'devoluciones del turno',293239,@n;
SET @n=(SELECT NetSalesMinor FROM accounting.CloseDocuments WHERE Id=@doc);
EXEC test.AssertEq N'venta neta 533239-293239',240000,@n;
SET @n=(SELECT SaleCOGSMinor FROM accounting.CloseDocuments WHERE Id=@doc);
EXEC test.AssertEq N'costo bruto 2x60000+3x40000',240000,@n;
SET @n=(SELECT ReturnedCOGSMinor FROM accounting.CloseDocuments WHERE Id=@doc);
EXEC test.AssertEq N'costo devuelto 3x40000',120000,@n;
SET @n=(SELECT NetCOGSMinor FROM accounting.CloseDocuments WHERE Id=@doc);
EXEC test.AssertEq N'costo neto',120000,@n;
SET @n=(SELECT CardCapturedMinor FROM accounting.CloseDocuments WHERE Id=@doc);
EXEC test.AssertEq N'tarjeta capturada',33239,@n;
SET @n=(SELECT CreditRedeemedMinor FROM accounting.CloseDocuments WHERE Id=@doc);
EXEC test.AssertEq N'anticipos canjeados',0,@n;
SET @n=(SELECT CashDifferenceMinor FROM accounting.CloseDocuments WHERE Id=@doc);
EXEC test.AssertEq N'diferencia de caja',0,@n;

SET @n=(SELECT COUNT(*) FROM accounting.CloseDocumentLines WHERE CloseDocumentId=@doc);
EXEC test.AssertEq N'lineas del documento',11,@n;
SET @n=(SELECT AmountMinor FROM accounting.CloseDocumentLines WHERE CloseDocumentId=@doc AND ConceptCode='EXPECTED_CASH');
EXEC test.AssertEq N'linea de efectivo esperado',600000,@n;
SET @n=(SELECT AmountMinor FROM accounting.CloseDocumentLines WHERE CloseDocumentId=@doc AND ConceptCode='SALE_GROSS');
EXEC test.AssertEq N'linea de ventas brutas',533239,@n;
SET @n=(SELECT AmountMinor FROM accounting.CloseDocumentLines WHERE CloseDocumentId=@doc AND ConceptCode='RETURN_GROSS');
EXEC test.AssertEq N'linea de devoluciones con signo negativo',-293239,@n;
SET @n=(SELECT AmountMinor FROM accounting.CloseDocumentLines WHERE CloseDocumentId=@doc AND ConceptCode='NET_SALES');
EXEC test.AssertEq N'linea de venta neta',240000,@n;
SET @n=(SELECT AmountMinor FROM accounting.CloseDocumentLines WHERE CloseDocumentId=@doc AND ConceptCode='CARD_TENDERS');
EXEC test.AssertEq N'linea de tarjetas',33239,@n;
SET @n=(SELECT AmountMinor FROM accounting.CloseDocumentLines WHERE CloseDocumentId=@doc AND ConceptCode='COGS_RETURNED');
EXEC test.AssertEq N'linea de costo devuelto con signo negativo',-120000,@n;

SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE CloseDocumentId=@doc);
EXEC test.AssertEq N'un solo trabajo de exportacion',1,@n;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE CloseDocumentId=@doc
        AND RecipientCode=N'ACCOUNTANT' AND Format='PDF' AND Status='pending');
EXEC test.AssertEq N'trabajo pendiente para el contador en PDF',1,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item2 AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock del articulo devuelto',10,@n;
PRINT 'PASS';

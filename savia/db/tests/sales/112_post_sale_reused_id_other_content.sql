-- TEST: usp_PostSale rechaza el mismo SaleId con otro contenido (51510) y deja intacta la venta original.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@item uniqueidentifier=test.Id('item'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@n bigint;
EXEC test.SeedStock @item,@loc,5;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;

DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,2,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',240000,240000,0);
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
     @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;

DECLARE @lines2 sales.SaleLineRequest,@tenders2 sales.SaleTenderRequest;
INSERT INTO @lines2(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
INSERT INTO @tenders2(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',120000,120000,0);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines2,@Tenders=@tenders2;
  THROW 59002,'ASSERT FAIL: SaleId reutilizado con otra cantidad fue aceptado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51510 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM sales.Sales WHERE Id=@sale);
EXEC test.AssertEq N'ventas guardadas',1,@n;
SET @n=(SELECT TotalMinor FROM sales.Sales WHERE Id=@sale);
EXEC test.AssertEq N'el total original no cambio',240000,@n;
SET @n=(SELECT Quantity FROM sales.SaleLines WHERE SaleId=@sale);
EXEC test.AssertEq N'la cantidad original no cambio',2,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleTenders WHERE SaleId=@sale);
EXEC test.AssertEq N'pagos guardados',1,@n;
SET @n=(SELECT COALESCE(SUM(DeltaMinor),0) FROM sales.CashEntries WHERE TillId=@till AND Kind='sale');
EXEC test.AssertEq N'efectivo de caja',240000,@n;
PRINT 'PASS';

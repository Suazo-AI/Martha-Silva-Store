-- TEST: usp_PostSale rejects a price that does not match the catalog, a variant without approved cost and another currency (51513).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@item uniqueidentifier=test.Id('item'),
  @draft uniqueidentifier=test.Id('itemDraft'),@till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),
  @n bigint;
EXEC test.SeedStock @item,@loc,10;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;
DECLARE @tenders sales.SaleTenderRequest;
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',110000,110000,0);

-- 51513 precio 110000 cuando el catalogo dice 120000
DECLARE @cheap sales.SaleLineRequest;
INSERT INTO @cheap(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,110000,0);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@cheap,@Tenders=@tenders;
  THROW 59002,'ASSERT FAIL: venta con precio distinto al catalogo aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51513 THROW; END CATCH;

-- 51513 variante en borrador (sin costo aprobado)
DECLARE @draftLine sales.SaleLineRequest,@draftTender sales.SaleTenderRequest;
INSERT INTO @draftLine(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@draft,1,90000,0);
INSERT INTO @draftTender(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',90000,90000,0);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@draftLine,@Tenders=@draftTender;
  THROW 59002,'ASSERT FAIL: venta de una variante sin costo aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51513 THROW; END CATCH;

-- 51513 moneda de la venta distinta a la del producto
DECLARE @samePrice sales.SaleLineRequest;
INSERT INTO @samePrice(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='USD',@TillId=@till,@OriginNodeId=@node,@Lines=@samePrice,@Tenders=@tenders;
  THROW 59002,'ASSERT FAIL: venta en otra moneda que la del producto aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51513 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM sales.Sales);
EXEC test.AssertEq N'ventas guardadas',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleLines);
EXEC test.AssertEq N'lineas guardadas',0,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock intacto',10,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE Kind='sale');
EXEC test.AssertEq N'cobros en caja',0,@n;
PRINT 'PASS';

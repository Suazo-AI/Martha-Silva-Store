-- TEST: usp_PostSale rejects tenders that do not add up to the total (51517) and a sale above the 9e12 ceiling (51516); nothing is stored in either case.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@item uniqueidentifier=test.Id('item'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@n bigint;
EXEC test.SeedStock @item,@loc,10;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;
DECLARE @lines sales.SaleLineRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,2,120000,0);

-- Un centavo de menos.
DECLARE @under sales.SaleTenderRequest;
INSERT INTO @under(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',239999,239999,0);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@under;
  THROW 59002,'ASSERT FAIL: venta con pago menor al total aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51517 THROW; END CATCH;

-- Un centavo de mas.
DECLARE @over sales.SaleTenderRequest;
INSERT INTO @over(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',240001,240001,0);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@over;
  THROW 59002,'ASSERT FAIL: venta con pago mayor al total aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51517 THROW; END CATCH;

-- 51516 un total mayor a 9e12 se rechaza: precio 10000000 x 1000000 unidades.
DECLARE @manager uniqueidentifier=test.Id('manager'),@product uniqueidentifier=test.Id('product'),
  @size uniqueidentifier=test.Id('sizeM'),@color uniqueidentifier=test.Id('colorWhite'),
  @supplier uniqueidentifier=test.Id('supplier'),@bigItem uniqueidentifier=NEWID(),
  @evt uniqueidentifier=NEWID(),@bigSale uniqueidentifier=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-SKU-BIG',@VariantName=N'Blusa cara',
  @CurrencyCode='NIO',@UnitPriceMinor=10000000,@UnitCostMinor=1000000,@Barcode=N'0000999000111',
  @SizeId=@size,@ColorId=@color,@SupplierId=@supplier,@ActorId=@manager,@ItemId=@bigItem,
  @OriginNodeId=@node,@EventId=@evt;
DECLARE @bigLines sales.SaleLineRequest,@bigTenders sales.SaleTenderRequest;
INSERT INTO @bigLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor)
  VALUES(1,@bigItem,1000000,10000000,0);
INSERT INTO @bigTenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor)
  VALUES(1,'cash',10000000000000,10000000000000,0);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@bigSale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@bigLines,@Tenders=@bigTenders;
  THROW 59002,'ASSERT FAIL: venta con total mayor a 9e12 aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51516 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM sales.Sales WHERE Id=@bigSale);
EXEC test.AssertEq N'la venta enorme no se guardo',0,@n;

SET @n=(SELECT COUNT(*) FROM sales.Sales);
EXEC test.AssertEq N'ventas guardadas',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleLines);
EXEC test.AssertEq N'lineas guardadas',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleTenders);
EXEC test.AssertEq N'pagos guardados',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE TillId=@till AND Kind='sale');
EXEC test.AssertEq N'cobros en caja',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE Kind='sale');
EXEC test.AssertEq N'movimientos de inventario',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventType='sales.sale_posted');
EXEC test.AssertEq N'eventos de venta',0,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock intacto',10,@n;
PRINT 'PASS';

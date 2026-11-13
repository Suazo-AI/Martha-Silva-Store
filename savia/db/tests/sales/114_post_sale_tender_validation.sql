-- TEST: usp_PostSale rejects invalid tenders (51509): zero amount, cash change that does not match, card without reference and credit without credit id.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@item uniqueidentifier=test.Id('item'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@n bigint;
EXEC test.SeedStock @item,@loc,10;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;
DECLARE @lines sales.SaleLineRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);

-- Importe cero.
DECLARE @a sales.SaleTenderRequest;
INSERT INTO @a(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',0,0,0);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@a;
  THROW 59002,'ASSERT FAIL: pago de importe cero aceptado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51509 THROW; END CATCH;

-- Efectivo: recibido - cambio <> importe.
DECLARE @b sales.SaleTenderRequest;
INSERT INTO @b(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',120000,130000,5000);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@b;
  THROW 59002,'ASSERT FAIL: efectivo que no cuadra aceptado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51509 THROW; END CATCH;

-- Efectivo sin recibido ni cambio declarados.
DECLARE @c sales.SaleTenderRequest;
INSERT INTO @c(TenderNumber,TenderKind,AmountMinor) VALUES(1,'cash',120000);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@c;
  THROW 59002,'ASSERT FAIL: efectivo sin recibido/cambio aceptado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51509 THROW; END CATCH;

-- Transferencia sin referencia.
DECLARE @e sales.SaleTenderRequest;
INSERT INTO @e(TenderNumber,TenderKind,AmountMinor) VALUES(1,'transfer',120000);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@e;
  THROW 59002,'ASSERT FAIL: transferencia sin referencia aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51509 THROW; END CATCH;

-- Anticipo sin CreditId ni clienta.
DECLARE @f sales.SaleTenderRequest;
INSERT INTO @f(TenderNumber,TenderKind,AmountMinor) VALUES(1,'credit',120000);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@f;
  THROW 59002,'ASSERT FAIL: anticipo sin CreditId aceptado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51509 THROW; END CATCH;

-- Tarjeta con recibido/cambio de efectivo.
DECLARE @g sales.SaleTenderRequest;
INSERT INTO @g(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor,Reference)
  VALUES(1,'card',120000,120000,0,N'AUTH-1');
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@g;
  THROW 59002,'ASSERT FAIL: tarjeta con recibido/cambio aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51509 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM sales.Sales);
EXEC test.AssertEq N'ventas guardadas',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleTenders);
EXEC test.AssertEq N'pagos guardados',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE TillId=@till AND Kind='sale');
EXEC test.AssertEq N'cobros en caja',0,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock intacto',10,@n;
PRINT 'PASS';

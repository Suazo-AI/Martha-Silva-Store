-- TEST: usp_PostSale rejects a missing till (51514), a till from another cashier, another branch or already closed (51515); a foreign currency is rejected earlier by the item check (51513).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@super uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@register uniqueidentifier=test.Id('registerA'),
  @registerB uniqueidentifier=test.Id('registerB'),@item uniqueidentifier=test.Id('item'),
  @cashierB uniqueidentifier=test.Id('cashierB'),@nodeB uniqueidentifier=test.Id('nodeB'),
  @till uniqueidentifier=NEWID(),@tillB uniqueidentifier=NEWID(),@closedTill uniqueidentifier=NEWID(),
  @sale uniqueidentifier=NEWID(),@n bigint;
EXEC test.SeedStock @item,@loc,10;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;
-- Turno de la sucursal B y turno cerrado sembrado directamente.
EXEC sales.usp_OpenTill @TillId=@tillB,@RegisterId=@registerB,@CashierId=@cashierB,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@nodeB;
INSERT INTO sales.CashTills(Id,RegisterId,CashierId,CurrencyCode,Status,ClosedAt)
  VALUES(@closedTill,@register,@cashier,'NIO','closed',SYSUTCDATETIME());

DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',120000,120000,0);

-- 51514 venta POS sin turno
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;
  THROW 59002,'ASSERT FAIL: venta POS sin turno aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51514 THROW; END CATCH;

-- 51515 el turno pertenece a otra cajera (la supervisora si tiene acceso a la sucursal)
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@super,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;
  THROW 59002,'ASSERT FAIL: venta con el turno de otra cajera aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51515 THROW; END CATCH;

-- 51515 el turno pertenece a otra sucursal
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@tillB,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;
  THROW 59002,'ASSERT FAIL: venta con un turno de otra sucursal aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51515 THROW; END CATCH;

-- 51515 el turno esta cerrado
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@closedTill,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;
  THROW 59002,'ASSERT FAIL: venta sobre un turno cerrado aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51515 THROW; END CATCH;

-- 51513 una moneda distinta choca primero con la moneda del articulo, asi que el
-- predicado de moneda del turno (51515) no es alcanzable por esta via.
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='USD',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;
  THROW 59002,'ASSERT FAIL: venta con moneda distinta a la del articulo aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51513 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM sales.Sales);
EXEC test.AssertEq N'ventas guardadas',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE Kind='sale');
EXEC test.AssertEq N'cobros en caja',0,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock intacto',10,@n;
PRINT 'PASS';

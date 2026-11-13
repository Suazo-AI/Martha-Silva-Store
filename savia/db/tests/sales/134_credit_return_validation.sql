-- TEST: usp_PostCreditReturn rejects empty return, empty reason, wrong location, closed till, approver without permission, other customer, bad quantity or pool, and zero value (51525-51531, 51534).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @locB uniqueidentifier=test.Id('locB'),@cashier uniqueidentifier=test.Id('cashierA'),
  @super uniqueidentifier=test.Id('supervisorA'),@node uniqueidentifier=test.Id('nodeA'),
  @nodeB uniqueidentifier=test.Id('nodeB'),@register uniqueidentifier=test.Id('registerA'),
  @registerB uniqueidentifier=test.Id('registerB'),@item uniqueidentifier=test.Id('item'),
  @customer uniqueidentifier=test.Id('customer'),@customer2 uniqueidentifier=test.Id('customer2'),
  @cashierB uniqueidentifier=test.Id('cashierB'),
  @till uniqueidentifier=NEWID(),@tillB uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),
  @zeroSale uniqueidentifier=NEWID(),@line uniqueidentifier,@zeroLine uniqueidentifier,
  @rev uniqueidentifier=NEWID(),@credit uniqueidentifier=NEWID(),
  @rev2 uniqueidentifier=NEWID(),@credit2 uniqueidentifier=NEWID(),@n bigint;
EXEC test.SeedStock @item,@loc,10;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;
EXEC sales.usp_OpenTill @TillId=@tillB,@RegisterId=@registerB,@CashierId=@cashierB,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@nodeB;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,3,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',360000,360000,0);
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
     @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders,
     @CustomerId=@customer,@DiscountApproverId='A0000000-0000-0000-0000-0000000000A5',@DiscountReason=N'Autorizado para prueba';
SET @line=(SELECT Id FROM sales.SaleLines WHERE SaleId=@sale AND LineNumber=1);

-- 51525 devolucion sin prendas
DECLARE @none sales.ReturnLineRequest;
BEGIN TRY
  EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,
    @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
    @Reason=N'sin prendas',@OriginNodeId=@node,@Lines=@none;
  THROW 59002,'ASSERT FAIL: devolucion sin prendas aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51525 THROW; END CATCH;

-- 51525 devolucion sin motivo
DECLARE @one sales.ReturnLineRequest;
INSERT INTO @one(SaleLineId,Quantity,RestockPool) VALUES(@line,1,'store');
BEGIN TRY
  EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,
    @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
    @Reason=N'   ',@OriginNodeId=@node,@Lines=@one;
  THROW 59002,'ASSERT FAIL: devolucion sin motivo aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51525 THROW; END CATCH;

-- 51527 ubicacion de otra sucursal
BEGIN TRY
  EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,
    @ReturnLocationId=@locB,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
    @Reason=N'ubicacion ajena',@OriginNodeId=@node,@Lines=@one;
  THROW 59002,'ASSERT FAIL: ubicacion de otra sucursal aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51527 THROW; END CATCH;

-- 51528 turno de otra sucursal
BEGIN TRY
  EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,
    @ReturnLocationId=@loc,@TillId=@tillB,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
    @Reason=N'turno ajeno',@OriginNodeId=@node,@Lines=@one;
  THROW 59002,'ASSERT FAIL: turno de otra sucursal aceptado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51528 THROW; END CATCH;

-- 51529 quien aprueba no puede aprobar devoluciones
BEGIN TRY
  EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,
    @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@cashier,@CustomerId=@customer,
    @Reason=N'sin permiso',@OriginNodeId=@node,@Lines=@one;
  THROW 59002,'ASSERT FAIL: devolucion aprobada por quien no puede aprobar',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51529 THROW; END CATCH;

-- 51530 la venta es de otra clienta
BEGIN TRY
  EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,
    @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer2,
    @Reason=N'otra clienta',@OriginNodeId=@node,@Lines=@one;
  THROW 59002,'ASSERT FAIL: devolucion a otra clienta aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51530 THROW; END CATCH;

-- 51531 pool de destino invalido
DECLARE @web sales.ReturnLineRequest;
INSERT INTO @web(SaleLineId,Quantity,RestockPool) VALUES(@line,1,'web');
BEGIN TRY
  EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,
    @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
    @Reason=N'pool invalido',@OriginNodeId=@node,@Lines=@web;
  THROW 59002,'ASSERT FAIL: pool web aceptado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51531 THROW; END CATCH;

-- 51531 cantidad cero
DECLARE @zero sales.ReturnLineRequest;
INSERT INTO @zero(SaleLineId,Quantity,RestockPool) VALUES(@line,0,'store');
BEGIN TRY
  EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,
    @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
    @Reason=N'cantidad cero',@OriginNodeId=@node,@Lines=@zero;
  THROW 59002,'ASSERT FAIL: devolucion con cantidad cero aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51531 THROW; END CATCH;

-- 51534 una venta de valor cero no genera anticipo
DECLARE @zlines sales.SaleLineRequest,@ztenders sales.SaleTenderRequest;
INSERT INTO @zlines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,120000);
EXEC sales.usp_PostSale @SaleId=@zeroSale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
     @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@zlines,@Tenders=@ztenders,
     @CustomerId=@customer,@DiscountApproverId=@super,@DiscountReason=N'Autorizado para prueba';
SET @zeroLine=(SELECT Id FROM sales.SaleLines WHERE SaleId=@zeroSale AND LineNumber=1);
DECLARE @zeroRet sales.ReturnLineRequest;
INSERT INTO @zeroRet(SaleLineId,Quantity,RestockPool) VALUES(@zeroLine,1,'store');
BEGIN TRY
  EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@zeroSale,@BranchId=@branch,
    @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
    @Reason=N'valor cero',@OriginNodeId=@node,@Lines=@zeroRet;
  THROW 59002,'ASSERT FAIL: devolucion de valor cero genero anticipo',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51534 THROW; END CATCH;

-- 51526 la devolucion ya existe con otro anticipo
EXEC sales.usp_PostCreditReturn @ReversalId=@rev2,@CreditId=@credit2,@SaleId=@sale,@BranchId=@branch,
  @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
  @Reason=N'devolucion valida',@OriginNodeId=@node,@Lines=@one;
DECLARE @otherCredit uniqueidentifier=NEWID();
BEGIN TRY
  EXEC sales.usp_PostCreditReturn @ReversalId=@rev2,@CreditId=@otherCredit,@SaleId=@sale,@BranchId=@branch,
    @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@super,@CustomerId=@customer,
    @Reason=N'otro anticipo',@OriginNodeId=@node,@Lines=@one;
  THROW 59002,'ASSERT FAIL: se emitio otro anticipo para la misma devolucion',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51526 THROW; END CATCH;

-- Solo la devolucion valida quedo guardada.
SET @n=(SELECT COUNT(*) FROM sales.SaleReversals);
EXEC test.AssertEq N'devoluciones guardadas',1,@n;
SET @n=(SELECT COUNT(*) FROM credits.Credits);
EXEC test.AssertEq N'anticipos emitidos',1,@n;
SET @n=(SELECT ReturnedQuantity FROM sales.SaleLines WHERE Id=@line);
EXEC test.AssertEq N'unidades devueltas de la linea de la venta valida',1,@n;
SET @n=(SELECT ReturnedQuantity FROM sales.SaleLines WHERE Id=@zeroLine);
EXEC test.AssertEq N'unidades devueltas de la linea de valor cero',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.SaleReversals WHERE Id=@rev);
EXEC test.AssertEq N'la devolucion rechazada no existe',0,@n;
PRINT 'PASS';

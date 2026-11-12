-- TEST: branch B cannot return a sale made at branch A; the sale, its lines, stock and credits stay untouched (ADR-001 D7, critique F3).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@locA uniqueidentifier=test.Id('locA'),
  @branchB uniqueidentifier=test.Id('branchB'),@locB uniqueidentifier=test.Id('locB'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@cashierB uniqueidentifier=test.Id('cashierB'),
  @supervisorB uniqueidentifier=test.Id('supervisorB'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),
  @registerA uniqueidentifier=test.Id('registerA'),@registerB uniqueidentifier=test.Id('registerB'),
  @item uniqueidentifier=test.Id('item'),@customer uniqueidentifier=test.Id('customer'),
  @tillA uniqueidentifier=NEWID(),@tillB uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),
  @return uniqueidentifier=NEWID(),@credit uniqueidentifier=NEWID(),@n bigint;

-- Branch A sells 2 units to a known customer.
EXEC test.SeedStock @item,@locA,5;
EXEC sales.usp_OpenTill @TillId=@tillA,@RegisterId=@registerA,@CashierId=@cashierA,@CurrencyCode='NIO',@OpeningMinor=50000,@OriginNodeId=@nodeA;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest,@ret sales.ReturnLineRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,2,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',240000,240000,0);
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branchA,@LocationId=@locA,@CashierId=@cashierA,@CurrencyCode='NIO',
     @CustomerId=@customer,@TillId=@tillA,@OriginNodeId=@nodeA,@Lines=@lines,@Tenders=@tenders;

-- Branch B, with its own open till and its own supervisor, tries to return that sale.
EXEC sales.usp_OpenTill @TillId=@tillB,@RegisterId=@registerB,@CashierId=@cashierB,@CurrencyCode='NIO',@OpeningMinor=50000,@OriginNodeId=@nodeB;
INSERT INTO @ret(SaleLineId,Quantity,RestockPool) SELECT Id,2,'store' FROM sales.SaleLines WHERE SaleId=@sale;
BEGIN TRY
  EXEC sales.usp_PostCreditReturn @ReversalId=@return,@CreditId=@credit,@SaleId=@sale,@BranchId=@branchB,
       @ReturnLocationId=@locB,@TillId=@tillB,@ActorId=@cashierB,@ApprovedBy=@supervisorB,@CustomerId=@customer,
       @Reason=N'Devolucion en otra sucursal',@OriginNodeId=@nodeB,@Lines=@ret;
  THROW 59002,'ASSERT FAIL: branch B returned a sale of branch A',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()<>51535 THROW;
END CATCH;

SET @n=(SELECT SUM(ReturnedQuantity) FROM sales.SaleLines WHERE SaleId=@sale);
EXEC test.AssertEq N'returned units on the sale of A',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.Sales WHERE Id=@sale AND Status='recorded');
EXEC test.AssertEq N'the sale of A keeps its status',1,@n;
SET @n=(SELECT COUNT(*) FROM credits.Credits);
EXEC test.AssertEq N'credits issued',0,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances WHERE LocationId=@locB);
EXEC test.AssertEq N'stock at branch B',0,@n;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';

-- TEST: transfer requests are rejected with their exact error for same-branch, non-positive amount, blank reason, duplicated id with other content, inactive credit, and an origin branch without allocation; a retry with the same ids creates only one row.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @flag bigint; DECLARE @tmp uniqueidentifier=NEWID();
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),
  @locA uniqueidentifier=test.Id('locA'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@registerA uniqueidentifier=test.Id('registerA'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @item uniqueidentifier=test.Id('item'),@nodeA uniqueidentifier=test.Id('nodeA'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@rev uniqueidentifier=NEWID(),
  @credit uniqueidentifier=NEWID(),@t1 uniqueidentifier=NEWID(),@t2 uniqueidentifier=NEWID(),
  @requestEvent uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),
  @n bigint,@lineId uniqueidentifier;

EXEC test.SeedStock @item,@locA,5;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@registerA,@CashierId=@cashierA,
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@nodeA;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',120000,120000,0);
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branchA,@LocationId=@locA,@CashierId=@cashierA,
     @CurrencyCode='NIO',@CustomerId=@customer,@TillId=@till,@OriginNodeId=@nodeA,@Lines=@lines,@Tenders=@tenders;
SET @lineId=(SELECT Id FROM sales.SaleLines WHERE SaleId=@sale AND LineNumber=1);
DECLARE @ret sales.ReturnLineRequest;
INSERT INTO @ret(SaleLineId,Quantity,RestockPool) VALUES(@lineId,1,'quarantine');
EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branchA,
     @ReturnLocationId=@locA,@TillId=@till,@ActorId=@cashierA,@ApprovedBy=@manager,@CustomerId=@customer,
     @Reason=N'Talla equivocada',@OriginNodeId=@nodeA,@Lines=@ret;

-- Same origin and destination.
BEGIN TRY
  EXEC credits.usp_RequestTransfer @TransferId=@tmp,@CreditId=@credit,
    @FromBranchId=@branchA,@ToBranchId=@branchA,@AmountMinor=50000,
    @RequestedBy=@cashierA,@Reason=N'mismo lugar',@OriginNodeId=@nodeA,@EventId=@e2;
  THROW 59002,'ASSERT FAIL: same-branch request was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51608 THROW; END CATCH;

-- Non-positive amount.
BEGIN TRY
  EXEC credits.usp_RequestTransfer @TransferId=@tmp,@CreditId=@credit,
    @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=0,
    @RequestedBy=@cashierA,@Reason=N'cero',@OriginNodeId=@nodeA,@EventId=@e2;
  THROW 59002,'ASSERT FAIL: zero-amount request was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51608 THROW; END CATCH;

-- Blank reason.
BEGIN TRY
  EXEC credits.usp_RequestTransfer @TransferId=@tmp,@CreditId=@credit,
    @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,
    @RequestedBy=@cashierA,@Reason=N'   ',@OriginNodeId=@nodeA,@EventId=@e2;
  THROW 59002,'ASSERT FAIL: blank-reason request was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51608 THROW; END CATCH;

-- Inactive / unknown credit.
BEGIN TRY
  EXEC credits.usp_RequestTransfer @TransferId=@tmp,@CreditId=@tmp,
    @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,
    @RequestedBy=@cashierA,@Reason=N'anticipo falso',@OriginNodeId=@nodeA,@EventId=@e2;
  THROW 59002,'ASSERT FAIL: request for an unknown credit was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51610 THROW; END CATCH;

-- Origin branch without an allocation of this credit.
BEGIN TRY
  EXEC credits.usp_RequestTransfer @TransferId=@tmp,@CreditId=@credit,
    @FromBranchId=@branchB,@ToBranchId=@branchA,@AmountMinor=50000,
    @RequestedBy=@cashierA,@Reason=N'no hay saldo aca',@OriginNodeId=@nodeA,@EventId=@e2;
  THROW 59002,'ASSERT FAIL: request from a branch without allocation was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51611 THROW; END CATCH;

-- Normal request, then a retry with the same ids and content: one row only.
EXEC credits.usp_RequestTransfer @TransferId=@t1,@CreditId=@credit,
  @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,
  @RequestedBy=@cashierA,@Reason=N'Canje en otra sucursal',@OriginNodeId=@nodeA,@EventId=@requestEvent;
EXEC credits.usp_RequestTransfer @TransferId=@t1,@CreditId=@credit,
  @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,
  @RequestedBy=@cashierA,@Reason=N'Canje en otra sucursal',@OriginNodeId=@nodeA,@EventId=@requestEvent;
SET @n=(SELECT COUNT(*) FROM credits.CreditTransfers WHERE Id=@t1);
EXEC test.AssertEq N'one transfer row after retry',1,@n;

-- Duplicated transfer id with different content.
BEGIN TRY
  EXEC credits.usp_RequestTransfer @TransferId=@t1,@CreditId=@credit,
    @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=60000,
    @RequestedBy=@cashierA,@Reason=N'Canje en otra sucursal',@OriginNodeId=@nodeA,@EventId=@e2;
  THROW 59002,'ASSERT FAIL: transfer id reused with another amount was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51609 THROW; END CATCH;

-- The request itself moves no money.
SET @n=(SELECT COUNT(*) FROM credits.CreditTransfers WHERE Id=@t2);
EXEC test.AssertEq N'no phantom transfer rows',0,@n;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'available unchanged by request',120000,@n;
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'credit conservation after requests',0,@n;
PRINT 'PASS';

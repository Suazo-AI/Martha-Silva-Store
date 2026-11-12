-- TEST: while 50000 is held by a transfer, the origin branch cannot redeem more than its 70000 available; the held amount is not spendable.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),
  @locA uniqueidentifier=test.Id('locA'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@registerA uniqueidentifier=test.Id('registerA'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @item uniqueidentifier=test.Id('item'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@rev uniqueidentifier=NEWID(),
  @credit uniqueidentifier=NEWID(),@transfer uniqueidentifier=NEWID(),@lockEvent uniqueidentifier=NEWID(),
  @requestEvent uniqueidentifier=NEWID(),@approveEvent uniqueidentifier=NEWID(),
  @r1 uniqueidentifier=NEWID(),@r2 uniqueidentifier=NEWID(),@n bigint,@lineId uniqueidentifier;

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

EXEC credits.usp_RequestTransfer @TransferId=@transfer,@CreditId=@credit,
  @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,
  @RequestedBy=@cashierA,@Reason=N'Canje en otra sucursal',
  @OriginNodeId=@nodeA,@EventId=@requestEvent;
EXEC credits.usp_ApproveTransfer @TransferId=@transfer,@ApproverId=@manager,
  @OriginNodeId=@nodeA,@EventId=@approveEvent;
EXEC credits.usp_LockTransferAtOrigin @TransferId=@transfer,
  @OriginLockEventId=@lockEvent,@OriginNodeId=@nodeA,@ActorId=@cashierA;

SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'available after locking 50000',70000,@n;
SET @n=(SELECT HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'held after locking 50000',50000,@n;
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'credit conservation after lock',0,@n;

-- A redemption above the free balance is rejected while 50000 is held.
BEGIN TRY
  EXEC credits.usp_RedeemCredit @RedemptionId=@r1,@CreditId=@credit,@BranchId=@branchA,
       @SaleId=@sale,@AmountMinor=80000,@ActorId=@cashierA;
  THROW 59002,'ASSERT FAIL: redemption that touches the held amount was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51607 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM credits.CreditRedemptions WHERE CreditId=@credit);
EXEC test.AssertEq N'no redemption row for rejected hold-touching redeem',0,@n;

-- The free 70000 can still be redeemed while the rest is held.
EXEC credits.usp_RedeemCredit @RedemptionId=@r2,@CreditId=@credit,@BranchId=@branchA,
     @SaleId=@sale,@AmountMinor=70000,@ActorId=@cashierA;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'available after redeeming the free part',0,@n;
SET @n=(SELECT HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'held unchanged by redemption',50000,@n;
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'credit conservation after redeeming free part',0,@n;
PRINT 'PASS';

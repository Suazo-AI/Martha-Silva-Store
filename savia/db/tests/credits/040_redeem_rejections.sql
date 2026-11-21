-- TEST: a redemption is rejected with its exact error for a non-positive amount, a duplicated id with other content, a sale of another branch or customer, an amount above the branch balance, and a branch without allocation.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @flag bigint; DECLARE @tmp uniqueidentifier=NEWID();
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),
  @locA uniqueidentifier=test.Id('locA'),@locB uniqueidentifier=test.Id('locB'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@cashierB uniqueidentifier=test.Id('cashierB'),
  @registerA uniqueidentifier=test.Id('registerA'),@registerB uniqueidentifier=test.Id('registerB'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @customer2 uniqueidentifier=test.Id('customer2'),
  @item uniqueidentifier=test.Id('item'),@nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),
  @tillA uniqueidentifier=NEWID(),@tillB uniqueidentifier=NEWID(),
  @saleA uniqueidentifier=NEWID(),@saleB uniqueidentifier=NEWID(),@saleC uniqueidentifier=NEWID(),
  @rev uniqueidentifier=NEWID(),@credit uniqueidentifier=NEWID(),
  @r1 uniqueidentifier=NEWID(),@r2 uniqueidentifier=NEWID(),@r3 uniqueidentifier=NEWID(),
  @r4 uniqueidentifier=NEWID(),@r5 uniqueidentifier=NEWID(),
  @n bigint,@lineIdA uniqueidentifier,@lineIdB uniqueidentifier,@lineIdC uniqueidentifier;

EXEC test.SeedStock @item,@locA,5;
EXEC test.SeedStock @item,@locB,5;
EXEC sales.usp_OpenTill @TillId=@tillA,@RegisterId=@registerA,@CashierId=@cashierA,
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@nodeA;
EXEC sales.usp_OpenTill @TillId=@tillB,@RegisterId=@registerB,@CashierId=@cashierB,
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@nodeB;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',120000,120000,0);
EXEC sales.usp_PostSale @SaleId=@saleA,@BranchId=@branchA,@LocationId=@locA,@CashierId=@cashierA,
     @CurrencyCode='NIO',@CustomerId=@customer,@TillId=@tillA,@OriginNodeId=@nodeA,@Lines=@lines,@Tenders=@tenders;
EXEC sales.usp_PostSale @SaleId=@saleB,@BranchId=@branchA,@LocationId=@locA,@CashierId=@cashierA,
     @CurrencyCode='NIO',@CustomerId=@customer2,@TillId=@tillA,@OriginNodeId=@nodeA,@Lines=@lines,@Tenders=@tenders;
EXEC sales.usp_PostSale @SaleId=@saleC,@BranchId=@branchB,@LocationId=@locB,@CashierId=@cashierB,
     @CurrencyCode='NIO',@CustomerId=@customer,@TillId=@tillB,@OriginNodeId=@nodeB,@Lines=@lines,@Tenders=@tenders;
SET @lineIdA=(SELECT Id FROM sales.SaleLines WHERE SaleId=@saleA AND LineNumber=1);
SET @lineIdB=(SELECT Id FROM sales.SaleLines WHERE SaleId=@saleB AND LineNumber=1);
SET @lineIdC=(SELECT Id FROM sales.SaleLines WHERE SaleId=@saleC AND LineNumber=1);
DECLARE @ret sales.ReturnLineRequest;
INSERT INTO @ret(SaleLineId,Quantity,RestockPool) VALUES(@lineIdA,1,'quarantine');
EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@saleA,@BranchId=@branchA,
     @ReturnLocationId=@locA,@TillId=@tillA,@ActorId=@cashierA,@ApprovedBy=@manager,@CustomerId=@customer,
     @Reason=N'Talla equivocada',@OriginNodeId=@nodeA,@Lines=@ret;

-- Non-positive amount.
BEGIN TRY
  EXEC credits.usp_RedeemCredit @RedemptionId=@tmp,@CreditId=@credit,@BranchId=@branchA,
       @SaleId=@saleA,@AmountMinor=0,@ActorId=@cashierA;
  THROW 59002,'ASSERT FAIL: zero-amount redemption was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51604 THROW; END CATCH;

-- Sale of another branch (a branchA redemption against a branchB sale).
BEGIN TRY
  EXEC credits.usp_RedeemCredit @RedemptionId=@r3,@CreditId=@credit,@BranchId=@branchA,
       @SaleId=@saleC,@AmountMinor=50000,@ActorId=@cashierA;
  THROW 59002,'ASSERT FAIL: redemption against a sale of another branch was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51606 THROW; END CATCH;

-- Sale of another customer.
BEGIN TRY
  EXEC credits.usp_RedeemCredit @RedemptionId=@tmp,@CreditId=@credit,@BranchId=@branchA,
       @SaleId=@saleB,@AmountMinor=50000,@ActorId=@cashierA;
  THROW 59002,'ASSERT FAIL: redemption against another customer''s sale was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51606 THROW; END CATCH;

-- One real redemption of 80000, then the same id with a different amount is rejected.
EXEC credits.usp_RedeemCredit @RedemptionId=@r1,@CreditId=@credit,@BranchId=@branchA,
     @SaleId=@saleA,@AmountMinor=80000,@ActorId=@cashierA;
BEGIN TRY
  EXEC credits.usp_RedeemCredit @RedemptionId=@r1,@CreditId=@credit,@BranchId=@branchA,
       @SaleId=@saleA,@AmountMinor=60000,@ActorId=@cashierA;
  THROW 59002,'ASSERT FAIL: duplicated redemption id with other amount was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51605 THROW; END CATCH;

-- Amount above the remaining balance (two redemptions that together exceed it: the second is rejected).
BEGIN TRY
  EXEC credits.usp_RedeemCredit @RedemptionId=@r4,@CreditId=@credit,@BranchId=@branchA,
       @SaleId=@saleA,@AmountMinor=50000,@ActorId=@cashierA;
  THROW 59002,'ASSERT FAIL: redemption above the remaining balance was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51607 THROW; END CATCH;

-- Branch without allocation for this credit.
BEGIN TRY
  EXEC credits.usp_RedeemCredit @RedemptionId=@r5,@CreditId=@credit,@BranchId=@branchB,
       @SaleId=@saleC,@AmountMinor=1000,@ActorId=@cashierB;
  THROW 59002,'ASSERT FAIL: redemption in a branch without allocation was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51607 THROW; END CATCH;

-- Only the first redemption stands; conservation holds.
SET @n=(SELECT COUNT(*) FROM credits.CreditRedemptions WHERE CreditId=@credit);
EXEC test.AssertEq N'one redemption row after rejections',1,@n;
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'credit conservation after rejections',0,@n;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'available after rejected over-redemption',40000,@n;
PRINT 'PASS';

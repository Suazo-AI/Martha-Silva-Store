-- TEST: redeeming 50000 of a 120000 credit leaves 70000 and a retry of the same redemption changes nothing; draining the balance marks the credit exhausted.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @flag bigint; DECLARE @tmp uniqueidentifier=NEWID();
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@locA uniqueidentifier=test.Id('locA'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@registerA uniqueidentifier=test.Id('registerA'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @item uniqueidentifier=test.Id('item'),@nodeA uniqueidentifier=test.Id('nodeA'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@rev uniqueidentifier=NEWID(),
  @credit uniqueidentifier=NEWID(),@r1 uniqueidentifier=NEWID(),@r2 uniqueidentifier=NEWID(),
  @n bigint,@lineId uniqueidentifier,@status varchar(16);

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

EXEC credits.usp_RedeemCredit @RedemptionId=@r1,@CreditId=@credit,@BranchId=@branchA,
     @SaleId=@sale,@AmountMinor=50000,@ActorId=@cashierA;

SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'available after redeeming 50000',70000,@n;
SET @n=(SELECT COUNT(*) FROM credits.CreditRedemptions WHERE Id=@r1 AND CreditId=@credit AND BranchId=@branchA AND AmountMinor=50000 AND Status='posted');
EXEC test.AssertEq N'redemption row posted once',1,@n;
SET @n=(SELECT COUNT(*) FROM credits.CreditMovements WHERE CreditId=@credit AND Kind='redeem' AND AvailableDeltaMinor=-50000);
EXEC test.AssertEq N'redeem movement',1,@n;
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'credit conservation after redeem',0,@n;

-- Retry with the same redemption id (lost reply): nothing changes.
EXEC credits.usp_RedeemCredit @RedemptionId=@r1,@CreditId=@credit,@BranchId=@branchA,
     @SaleId=@sale,@AmountMinor=50000,@ActorId=@cashierA;
SET @n=(SELECT COUNT(*) FROM credits.CreditRedemptions WHERE CreditId=@credit);
EXEC test.AssertEq N'no duplicate redemption after retry',1,@n;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'balance unchanged after retry',70000,@n;

-- Redeem the remaining 70000 exactly: credit becomes exhausted.
EXEC credits.usp_RedeemCredit @RedemptionId=@r2,@CreditId=@credit,@BranchId=@branchA,
     @SaleId=@sale,@AmountMinor=70000,@ActorId=@cashierA;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'available after full drain',0,@n;
SET @status=(SELECT Status FROM credits.Credits WHERE Id=@credit);
SET @flag=CASE WHEN @status='exhausted' THEN 1 ELSE 0 END;
EXEC test.AssertEq N'credit exhausted after full drain',1,@flag;
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'credit conservation after full drain',0,@n;
PRINT 'PASS';

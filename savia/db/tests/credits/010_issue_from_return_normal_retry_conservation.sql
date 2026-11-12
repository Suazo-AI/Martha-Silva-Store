-- TEST: a return issues a credit of exactly the returned value once; a retry with the same ids changes nothing and a retry with another CreditId is rejected.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @flag bigint; DECLARE @tmp uniqueidentifier=NEWID();
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@locA uniqueidentifier=test.Id('locA'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@registerA uniqueidentifier=test.Id('registerA'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @item uniqueidentifier=test.Id('item'),@nodeA uniqueidentifier=test.Id('nodeA'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@rev uniqueidentifier=NEWID(),
  @credit uniqueidentifier=NEWID(),@n bigint,@lineId uniqueidentifier,@status varchar(16);

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

SET @n=(SELECT OriginalMinor FROM credits.Credits WHERE Id=@credit);
EXEC test.AssertEq N'credit original amount',120000,@n;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'branch A available after issue',120000,@n;
SET @n=(SELECT HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'branch A held after issue',0,@n;
SET @n=(SELECT COUNT(*) FROM credits.CreditMovements WHERE CreditId=@credit AND Kind='issue' AND AvailableDeltaMinor=120000);
EXEC test.AssertEq N'issue movement',1,@n;
SET @status=(SELECT Status FROM credits.Credits WHERE Id=@credit);
SET @flag=CASE WHEN @status='active' THEN 1 ELSE 0 END;
EXEC test.AssertEq N'credit active after issue',1,@flag;
-- Conservation: Original = SUM(available+held) + posted redemptions.
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'credit conservation after issue',0,@n;

-- Retry with the same CreditId and ReversalId: the client did not get the reply. Nothing changes.
EXEC credits.usp_IssueFromReturn @CreditId=@credit,@ReversalId=@rev,@ActorId=@manager;
SET @n=(SELECT COUNT(*) FROM credits.Credits WHERE SourceReversalId=@rev);
EXEC test.AssertEq N'no duplicate credit after retry',1,@n;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'balance unchanged after retry',120000,@n;

-- Retry with a different CreditId for an already-used reversal must be rejected.
DECLARE @other uniqueidentifier=NEWID();
BEGIN TRY
  EXEC credits.usp_IssueFromReturn @CreditId=@other,@ReversalId=@rev,@ActorId=@manager;
  THROW 59002,'ASSERT FAIL: reversal reused for a second credit was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51601 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM credits.Credits WHERE SourceReversalId=@rev);
EXEC test.AssertEq N'still one credit after rejected retry',1,@n;
PRINT 'PASS';

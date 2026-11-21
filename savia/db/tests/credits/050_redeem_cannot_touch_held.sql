-- TEST: a dispatched amount leaves the origin at once: the origin can redeem only what it still has.
-- FIXED (V009): rewritten for the transition procedures; the legacy procedure now throws 51719.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @flag bigint,@n bigint;
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),
  @branchC uniqueidentifier=test.Id('branchC'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@cashierB uniqueidentifier=test.Id('cashierB'),
  @supervisorA uniqueidentifier=test.Id('supervisorA'),@supervisorB uniqueidentifier=test.Id('supervisorB'),
  @manager uniqueidentifier=test.Id('manager'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),
  @nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @credit uniqueidentifier=NEWID(),@t1 uniqueidentifier=NEWID(),@t2 uniqueidentifier=NEWID(),@t3 uniqueidentifier=NEWID();
EXEC test.SeedCredit @credit;  -- 120000 available at A

DECLARE @saleA uniqueidentifier=NEWID(),@r1 uniqueidentifier=NEWID(),@r2 uniqueidentifier=NEWID();
EXEC test.SeedSale @saleA,'A';
EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
EXEC credits.usp_TransferApprove @TransferId=@t1,@ApproverId=@manager,@NodeId=@nodeCloud;
EXEC credits.usp_TransferDispatch @TransferId=@t1,@ActorId=@cashierA,@NodeId=@nodeA;
BEGIN TRY
  EXEC credits.usp_RedeemCredit @RedemptionId=@r1,@CreditId=@credit,@BranchId=@branchA,@SaleId=@saleA,@AmountMinor=70001,@ActorId=@cashierA;
  THROW 59002,'ASSERT FAIL: origin redeemed part of the dispatched amount',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51607 THROW; END CATCH;
EXEC credits.usp_RedeemCredit @RedemptionId=@r2,@CreditId=@credit,@BranchId=@branchA,@SaleId=@saleA,@AmountMinor=70000,@ActorId=@cashierA;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'A available after spending its free part',0,@n;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';

-- TEST: an amount in transit is spendable nowhere: A keeps only its free part, B cannot redeem before receipt; the credit stays active while money is in transit even if A spends all it has, and after receipt B spends it and the credit is exhausted.
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
DECLARE @saleA uniqueidentifier=NEWID(),@saleB uniqueidentifier=NEWID(),
  @r1 uniqueidentifier=NEWID(),@r2 uniqueidentifier=NEWID(),@r3 uniqueidentifier=NEWID(),@r4 uniqueidentifier=NEWID(),
  @status varchar(16);
EXEC test.SeedSale @saleA,'A';
EXEC test.SeedSale @saleB,'B';
EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
EXEC credits.usp_TransferApprove @TransferId=@t1,@ApproverId=@manager,@NodeId=@nodeCloud;
EXEC credits.usp_TransferDispatch @TransferId=@t1,@ActorId=@cashierA,@NodeId=@nodeA;
BEGIN TRY
  EXEC credits.usp_RedeemCredit @RedemptionId=@r1,@CreditId=@credit,@BranchId=@branchA,@SaleId=@saleA,@AmountMinor=80000,@ActorId=@cashierA;
  THROW 59002,'ASSERT FAIL: origin redeemed the in-transit amount',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51607 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_RedeemCredit @RedemptionId=@r2,@CreditId=@credit,@BranchId=@branchB,@SaleId=@saleB,@AmountMinor=1000,@ActorId=@cashierB;
  THROW 59002,'ASSERT FAIL: destination redeemed an in-transit amount',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51607 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM credits.CreditRedemptions WHERE CreditId=@credit);
EXEC test.AssertEq N'no redemption while in transit',0,@n;
EXEC credits.usp_RedeemCredit @RedemptionId=@r3,@CreditId=@credit,@BranchId=@branchA,@SaleId=@saleA,@AmountMinor=70000,@ActorId=@cashierA;
EXEC audit.usp_CheckConservation @Throw=1;
SET @status=(SELECT Status FROM credits.Credits WHERE Id=@credit);
SET @flag=CASE WHEN @status='active' THEN 1 ELSE 0 END;
EXEC test.AssertEq N'credit stays active while 50000 is in transit',1,@flag;
EXEC credits.usp_TransferReceive @TransferId=@t1,@ActorId=@cashierB,@NodeId=@nodeB;
EXEC credits.usp_RedeemCredit @RedemptionId=@r4,@CreditId=@credit,@BranchId=@branchB,@SaleId=@saleB,@AmountMinor=50000,@ActorId=@cashierB;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchB);
EXEC test.AssertEq N'B spent the received amount',0,@n;
SET @status=(SELECT Status FROM credits.Credits WHERE Id=@credit);
SET @flag=CASE WHEN @status='exhausted' THEN 1 ELSE 0 END;
EXEC test.AssertEq N'credit exhausted once nothing is left anywhere',1,@flag;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';

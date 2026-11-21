-- TEST: the full transfer A->B (request B, approve cloud, dispatch A, receive B) keeps the conservation oracle green at every step, including while the amount is in transit; receiving twice is a no-op and a foreign node, foreign actor or other content is rejected.
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

EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
EXEC audit.usp_CheckConservation @Throw=1;
EXEC credits.usp_TransferApprove @TransferId=@t1,@ApproverId=@manager,@NodeId=@nodeCloud;
EXEC audit.usp_CheckConservation @Throw=1;
EXEC credits.usp_TransferDispatch @TransferId=@t1,@ActorId=@cashierA,@NodeId=@nodeA;
-- In transit: 50000 is in no balance; the oracle counts it as dispatched-not-received.
EXEC audit.usp_CheckConservation @Throw=1;
SET @n=(SELECT COUNT(*) FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchB);
EXEC test.AssertEq N'B has no balance row before receipt',0,@n;
BEGIN TRY
  EXEC credits.usp_TransferReceive @TransferId=@t1,@ActorId=@cashierA,@NodeId=@nodeA;
  THROW 59002,'ASSERT FAIL: receipt from the origin node accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51723 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_TransferReceive @TransferId=@t1,@ActorId=@manager,@NodeId=@nodeCloud;
  THROW 59002,'ASSERT FAIL: receipt from the cloud accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51723 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_TransferReceive @TransferId=@t1,@ActorId=@cashierA,@NodeId=@nodeB;
  THROW 59002,'ASSERT FAIL: receipt by an actor without destination access accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51724 THROW; END CATCH;
EXEC credits.usp_TransferReceive @TransferId=@t1,@ActorId=@cashierB,@NodeId=@nodeB;
EXEC audit.usp_CheckConservation @Throw=1;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'A available after receipt',70000,@n;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchB);
EXEC test.AssertEq N'B available after receipt',50000,@n;
EXEC credits.usp_TransferReceive @TransferId=@t1,@ActorId=@cashierB,@NodeId=@nodeB;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchB);
EXEC test.AssertEq N'B unchanged after receipt retry',50000,@n;
SET @n=(SELECT COUNT(*) FROM credits.CreditMovements WHERE SourceId=@t1 AND Kind='transfer_in');
EXEC test.AssertEq N'one transfer_in after retry',1,@n;
SET @n=(SELECT COUNT(*) FROM credits.TransferReceipts WHERE TransferId=@t1);
EXEC test.AssertEq N'one receipt row after retry',1,@n;
BEGIN TRY
  EXEC credits.usp_TransferReceive @TransferId=@t1,@ActorId=@supervisorB,@NodeId=@nodeB;
  THROW 59002,'ASSERT FAIL: second receipt by another actor accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51721 THROW; END CATCH;
-- A second transfer into an existing B balance row adds to it.
EXEC credits.usp_TransferRequest @TransferId=@t2,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=20000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
EXEC credits.usp_TransferApprove @TransferId=@t2,@ApproverId=@manager,@NodeId=@nodeCloud;
EXEC credits.usp_TransferDispatch @TransferId=@t2,@ActorId=@cashierA,@NodeId=@nodeA;
EXEC credits.usp_TransferReceive @TransferId=@t2,@ActorId=@cashierB,@NodeId=@nodeB;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'A after second transfer',50000,@n;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchB);
EXEC test.AssertEq N'B after second transfer',70000,@n;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';

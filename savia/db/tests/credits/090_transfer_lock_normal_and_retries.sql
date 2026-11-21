-- TEST: dispatch is written by the origin node: -amount from A once, one transfer_out movement; a retry is a no-op, another actor is rejected, a foreign node, an actor without origin access and an amount above the balance are rejected.
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
EXEC credits.usp_TransferApprove @TransferId=@t1,@ApproverId=@manager,@NodeId=@nodeCloud;
EXEC credits.usp_TransferRequest @TransferId=@t2,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=120001,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
EXEC credits.usp_TransferApprove @TransferId=@t2,@ApproverId=@manager,@NodeId=@nodeCloud;
BEGIN TRY
  EXEC credits.usp_TransferDispatch @TransferId=@t1,@ActorId=@cashierB,@NodeId=@nodeB;
  THROW 59002,'ASSERT FAIL: dispatch from the destination node accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51723 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_TransferDispatch @TransferId=@t1,@ActorId=@manager,@NodeId=@nodeCloud;
  THROW 59002,'ASSERT FAIL: dispatch from the cloud accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51723 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_TransferDispatch @TransferId=@t1,@ActorId=@cashierB,@NodeId=@nodeA;
  THROW 59002,'ASSERT FAIL: dispatch by an actor without origin access accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51724 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_TransferDispatch @TransferId=@t2,@ActorId=@cashierA,@NodeId=@nodeA;
  THROW 59002,'ASSERT FAIL: dispatch above the balance accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51729 THROW; END CATCH;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'A untouched by rejected dispatches',120000,@n;
EXEC credits.usp_TransferDispatch @TransferId=@t1,@ActorId=@cashierA,@NodeId=@nodeA;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'A available after dispatch',70000,@n;
SET @n=(SELECT COUNT(*) FROM credits.CreditMovements WHERE SourceId=@t1 AND Kind='transfer_out' AND BranchId=@branchA AND AvailableDeltaMinor=-50000 AND HeldDeltaMinor=0);
EXEC test.AssertEq N'one transfer_out movement',1,@n;
EXEC credits.usp_TransferDispatch @TransferId=@t1,@ActorId=@cashierA,@NodeId=@nodeA;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'A unchanged after retry',70000,@n;
SET @n=(SELECT COUNT(*) FROM credits.CreditMovements WHERE SourceId=@t1);
EXEC test.AssertEq N'no duplicate movement after retry',1,@n;
BEGIN TRY
  EXEC credits.usp_TransferDispatch @TransferId=@t1,@ActorId=@supervisorA,@NodeId=@nodeA;
  THROW 59002,'ASSERT FAIL: second dispatch by another actor accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51721 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM credits.CreditAllocations WHERE CreditId=@credit AND HeldMinor<>0);
EXEC test.AssertEq N'dispatch holds nothing',0,@n;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';

-- TEST: an approval is written by the cloud for an existing, uncancelled request, by an approver who is not the requester and holds CanApproveTransfers in the origin branch; a retry is a no-op and another approver is rejected.
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

BEGIN TRY
  EXEC credits.usp_TransferApprove @TransferId=@t1,@ApproverId=@manager,@NodeId=@nodeCloud;
  THROW 59002,'ASSERT FAIL: approval of an unknown transfer accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51725 THROW; END CATCH;
EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@supervisorB,@Reason=N'Canje en B',@NodeId=@nodeB;
BEGIN TRY
  EXEC credits.usp_TransferApprove @TransferId=@t1,@ApproverId=@manager,@NodeId=@nodeA;
  THROW 59002,'ASSERT FAIL: approval from a branch node accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51723 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_TransferApprove @TransferId=@t1,@ApproverId=@supervisorB,@NodeId=@nodeCloud;
  THROW 59002,'ASSERT FAIL: approver without permission in origin accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51727 THROW; END CATCH;
EXEC credits.usp_TransferRequest @TransferId=@t2,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@manager,@Reason=N'Canje en B',@NodeId=@nodeB;
BEGIN TRY
  EXEC credits.usp_TransferApprove @TransferId=@t2,@ApproverId=@manager,@NodeId=@nodeCloud;
  THROW 59002,'ASSERT FAIL: requester approved their own request',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51727 THROW; END CATCH;
EXEC credits.usp_TransferApprove @TransferId=@t1,@ApproverId=@manager,@NodeId=@nodeCloud;
EXEC credits.usp_TransferApprove @TransferId=@t1,@ApproverId=@manager,@NodeId=@nodeCloud;
SET @n=(SELECT COUNT(*) FROM credits.TransferApprovals WHERE TransferId=@t1);
EXEC test.AssertEq N'one approval row after retry',1,@n;
BEGIN TRY
  EXEC credits.usp_TransferApprove @TransferId=@t1,@ApproverId=@supervisorA,@NodeId=@nodeCloud;
  THROW 59002,'ASSERT FAIL: second approval with another approver accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51721 THROW; END CATCH;
EXEC credits.usp_TransferRequest @TransferId=@t3,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
EXEC credits.usp_TransferCancel @TransferId=@t3,@ActorId=@manager,@Reason=N'Ya no se necesita',@NodeId=@nodeCloud;
BEGIN TRY
  EXEC credits.usp_TransferApprove @TransferId=@t3,@ApproverId=@manager,@NodeId=@nodeCloud;
  THROW 59002,'ASSERT FAIL: approval of a cancelled transfer accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51726 THROW; END CATCH;
PRINT 'PASS';

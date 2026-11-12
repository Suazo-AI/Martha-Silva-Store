-- TEST: transition order is strict: dispatch before approval, receipt before dispatch, dispatch after cancel and cancel after dispatch are rejected; unknown transfers are rejected at every step.
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
  EXEC credits.usp_TransferDispatch @TransferId=@t1,@ActorId=@cashierA,@NodeId=@nodeA;
  THROW 59002,'ASSERT FAIL: dispatch of an unknown transfer accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51725 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_TransferReceive @TransferId=@t1,@ActorId=@cashierB,@NodeId=@nodeB;
  THROW 59002,'ASSERT FAIL: receipt of an unknown transfer accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51725 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_TransferCancel @TransferId=@t1,@ActorId=@manager,@Reason=N'Ya no se necesita',@NodeId=@nodeCloud;
  THROW 59002,'ASSERT FAIL: cancel of an unknown transfer accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51725 THROW; END CATCH;
EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
BEGIN TRY
  EXEC credits.usp_TransferDispatch @TransferId=@t1,@ActorId=@cashierA,@NodeId=@nodeA;
  THROW 59002,'ASSERT FAIL: dispatch without approval accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51728 THROW; END CATCH;
EXEC credits.usp_TransferApprove @TransferId=@t1,@ApproverId=@manager,@NodeId=@nodeCloud;
BEGIN TRY
  EXEC credits.usp_TransferReceive @TransferId=@t1,@ActorId=@cashierB,@NodeId=@nodeB;
  THROW 59002,'ASSERT FAIL: receipt without dispatch accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51730 THROW; END CATCH;
EXEC credits.usp_TransferDispatch @TransferId=@t1,@ActorId=@cashierA,@NodeId=@nodeA;
BEGIN TRY
  EXEC credits.usp_TransferCancel @TransferId=@t1,@ActorId=@manager,@Reason=N'Ya no se necesita',@NodeId=@nodeCloud;
  THROW 59002,'ASSERT FAIL: cancel after dispatch accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51731 THROW; END CATCH;
EXEC credits.usp_TransferRequest @TransferId=@t2,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=10000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
EXEC credits.usp_TransferApprove @TransferId=@t2,@ApproverId=@manager,@NodeId=@nodeCloud;
EXEC credits.usp_TransferCancel @TransferId=@t2,@ActorId=@manager,@Reason=N'Ya no se necesita',@NodeId=@nodeCloud;
BEGIN TRY
  EXEC credits.usp_TransferDispatch @TransferId=@t2,@ActorId=@cashierA,@NodeId=@nodeA;
  THROW 59002,'ASSERT FAIL: dispatch after cancel accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51726 THROW; END CATCH;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'A available: only the first dispatch left',70000,@n;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';

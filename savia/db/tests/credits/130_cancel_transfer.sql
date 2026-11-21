-- TEST: the cloud cancels a requested or approved transfer before dispatch; a retry is a no-op, other content, a branch node, an actor without approval rights and an unknown transfer are rejected; a cancelled transfer cannot be dispatched and balances never move.
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
EXEC credits.usp_TransferRequest @TransferId=@t2,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=10000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
EXEC credits.usp_TransferApprove @TransferId=@t2,@ApproverId=@manager,@NodeId=@nodeCloud;
BEGIN TRY
  EXEC credits.usp_TransferCancel @TransferId=@t1,@ActorId=@supervisorB,@Reason=N'Ya no se necesita',@NodeId=@nodeB;
  THROW 59002,'ASSERT FAIL: cancel from a branch node accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51723 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_TransferCancel @TransferId=@t1,@ActorId=@cashierB,@Reason=N'Ya no se necesita',@NodeId=@nodeCloud;
  THROW 59002,'ASSERT FAIL: cancel by an actor without approval rights accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51727 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_TransferCancel @TransferId=@t1,@ActorId=@manager,@Reason=N'',@NodeId=@nodeCloud;
  THROW 59002,'ASSERT FAIL: cancel without reason accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51720 THROW; END CATCH;
EXEC credits.usp_TransferCancel @TransferId=@t1,@ActorId=@manager,@Reason=N'Ya no se necesita',@NodeId=@nodeCloud;
EXEC credits.usp_TransferCancel @TransferId=@t1,@ActorId=@manager,@Reason=N'Ya no se necesita',@NodeId=@nodeCloud;
SET @n=(SELECT COUNT(*) FROM credits.TransferCancellations WHERE TransferId=@t1);
EXEC test.AssertEq N'one cancellation row after retry',1,@n;
BEGIN TRY
  EXEC credits.usp_TransferCancel @TransferId=@t1,@ActorId=@manager,@Reason=N'Otro',@NodeId=@nodeCloud;
  THROW 59002,'ASSERT FAIL: second cancel with other content accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51721 THROW; END CATCH;
EXEC credits.usp_TransferCancel @TransferId=@t2,@ActorId=@manager,@Reason=N'Ya no se necesita',@NodeId=@nodeCloud;
BEGIN TRY
  EXEC credits.usp_TransferDispatch @TransferId=@t2,@ActorId=@cashierA,@NodeId=@nodeA;
  THROW 59002,'ASSERT FAIL: dispatch of a cancelled approved transfer accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51726 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_TransferDispatch @TransferId=@t1,@ActorId=@cashierA,@NodeId=@nodeA;
  THROW 59002,'ASSERT FAIL: dispatch of a cancelled request accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51726 THROW; END CATCH;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'A untouched by cancelled transfers',120000,@n;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';

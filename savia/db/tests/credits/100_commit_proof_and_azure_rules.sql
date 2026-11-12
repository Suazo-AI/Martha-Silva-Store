-- TEST: the six legacy transfer procedures are retired: each throws 51719 and writes nothing.
-- FIXED (V009): usp_CommitTransfer moved A's and B's balances in one cloud transaction (F2); the legacy set is retired.
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
DECLARE @e uniqueidentifier=NEWID();
BEGIN TRY
  EXEC credits.usp_RequestTransfer @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@cashierA,@Reason=N'x',@OriginNodeId=@nodeA,@EventId=@e;
  THROW 59002,'ASSERT FAIL: legacy request ran',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51719 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_ApproveTransfer @TransferId=@t1,@ApproverId=@manager,@OriginNodeId=@nodeCloud,@EventId=@e;
  THROW 59002,'ASSERT FAIL: legacy approve ran',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51719 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_LockTransferAtOrigin @TransferId=@t1,@OriginLockEventId=@e,@OriginNodeId=@nodeA,@ActorId=@cashierA;
  THROW 59002,'ASSERT FAIL: legacy lock ran',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51719 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_CommitTransfer @TransferId=@t1,@ActorId=@manager,@OriginNodeId=@nodeCloud,@EventId=@e;
  THROW 59002,'ASSERT FAIL: legacy commit ran',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51719 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_AcceptTransfer @TransferId=@t1,@ActorId=@cashierB,@OriginNodeId=@nodeB,@EventId=@e;
  THROW 59002,'ASSERT FAIL: legacy accept ran',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51719 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_CancelUnblockedTransfer @TransferId=@t1,@ActorId=@manager;
  THROW 59002,'ASSERT FAIL: legacy cancel ran',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51719 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM credits.CreditTransfers);
EXEC test.AssertEq N'no legacy transfer rows',0,@n;
SET @n=(SELECT COUNT(*) FROM credits.CreditMovements WHERE CreditId=@credit);
EXEC test.AssertEq N'only the issue movement',1,@n;
PRINT 'PASS';

-- TEST: one writer per row (ADR-001 D5, F2): no credit-transfer call changes the balance of two branches; each transition changes at most the balance of the branch whose node runs it, and no transition rewrites a row written by an earlier one.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @flag bigint,@n bigint,@changedBranch uniqueidentifier,@retired bit=0;
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@cashierB uniqueidentifier=test.Id('cashierB'),
  @manager uniqueidentifier=test.Id('manager'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),
  @nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @credit uniqueidentifier=NEWID(),@legacy uniqueidentifier=NEWID(),@transfer uniqueidentifier=NEWID(),
  @e1 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),@lockEvent uniqueidentifier=NEWID(),
  @e4 uniqueidentifier=NEWID(),@lockPayload nvarchar(max);
DECLARE @before test.AllocationSnapshot;
EXEC test.SeedCredit @credit;

-- Part 1. The legacy commit. Before V009 it moved A's and B's balances in one cloud transaction.
BEGIN TRY
  EXEC credits.usp_RequestTransfer @TransferId=@legacy,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,
    @AmountMinor=50000,@RequestedBy=@cashierA,@Reason=N'Canje en B',@OriginNodeId=@nodeA,@EventId=@e1;
  EXEC credits.usp_ApproveTransfer @TransferId=@legacy,@ApproverId=@manager,@OriginNodeId=@nodeA,@EventId=@e2;
  EXEC credits.usp_LockTransferAtOrigin @TransferId=@legacy,@OriginLockEventId=@lockEvent,@OriginNodeId=@nodeA,@ActorId=@cashierA;
  BEGIN TRANSACTION;
  SET @lockPayload=(SELECT PayloadJson FROM sync.Outbox WHERE EventId=@lockEvent);
  EXEC sync.usp_RecordAppliedInbox @EventId=@lockEvent,@OriginNodeId=@nodeA,
    @AggregateType='credit_transfer',@AggregateId=@legacy,@PayloadJson=@lockPayload;
  COMMIT;
  INSERT INTO @before SELECT BranchId,AvailableMinor,HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit;
  EXEC credits.usp_CommitTransfer @TransferId=@legacy,@ActorId=@manager,@OriginNodeId=@nodeCloud,@EventId=@e4;
  EXEC test.ChangedBranches @credit,@before,@n OUTPUT,@changedBranch OUTPUT;
  EXEC test.AssertEq N'branches whose balance one usp_CommitTransfer call changed',1,@n;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51719 THROW; SET @retired=1; END CATCH;
SET @flag=@retired;
EXEC test.AssertEq N'legacy two-branch commit retired',1,@flag;

-- Part 2. The transition procedures: request (B), approve (cloud), dispatch (A), receive (B).
DECLARE @rvRequest binary(8),@rvApproval binary(8),@rvDispatch binary(8);
DELETE FROM @before; INSERT INTO @before SELECT BranchId,AvailableMinor,HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit;
EXEC credits.usp_TransferRequest @TransferId=@transfer,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,
  @AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
EXEC test.ChangedBranches @credit,@before,@n OUTPUT,@changedBranch OUTPUT;
EXEC test.AssertEq N'branches changed by request',0,@n;
SET @rvRequest=(SELECT RowVersion FROM credits.TransferRequests WHERE Id=@transfer);

DELETE FROM @before; INSERT INTO @before SELECT BranchId,AvailableMinor,HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit;
EXEC credits.usp_TransferApprove @TransferId=@transfer,@ApproverId=@manager,@NodeId=@nodeCloud;
EXEC test.ChangedBranches @credit,@before,@n OUTPUT,@changedBranch OUTPUT;
EXEC test.AssertEq N'branches changed by approval',0,@n;
SET @rvApproval=(SELECT RowVersion FROM credits.TransferApprovals WHERE TransferId=@transfer);

DELETE FROM @before; INSERT INTO @before SELECT BranchId,AvailableMinor,HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit;
EXEC credits.usp_TransferDispatch @TransferId=@transfer,@ActorId=@cashierA,@NodeId=@nodeA;
EXEC test.ChangedBranches @credit,@before,@n OUTPUT,@changedBranch OUTPUT;
EXEC test.AssertEq N'branches changed by dispatch',1,@n;
SET @flag=CASE WHEN @changedBranch=@branchA THEN 1 ELSE 0 END;
EXEC test.AssertEq N'dispatch changed only A',1,@flag;
SET @rvDispatch=(SELECT RowVersion FROM credits.TransferDispatches WHERE TransferId=@transfer);

DELETE FROM @before; INSERT INTO @before SELECT BranchId,AvailableMinor,HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit;
EXEC credits.usp_TransferReceive @TransferId=@transfer,@ActorId=@cashierB,@NodeId=@nodeB;
EXEC test.ChangedBranches @credit,@before,@n OUTPUT,@changedBranch OUTPUT;
EXEC test.AssertEq N'branches changed by receipt',1,@n;
SET @flag=CASE WHEN @changedBranch=@branchB THEN 1 ELSE 0 END;
EXEC test.AssertEq N'receipt changed only B',1,@flag;

-- Earlier transition rows were never rewritten.
SET @flag=CASE WHEN @rvRequest=(SELECT RowVersion FROM credits.TransferRequests WHERE Id=@transfer) THEN 1 ELSE 0 END;
EXEC test.AssertEq N'request row untouched after later transitions',1,@flag;
SET @flag=CASE WHEN @rvApproval=(SELECT RowVersion FROM credits.TransferApprovals WHERE TransferId=@transfer) THEN 1 ELSE 0 END;
EXEC test.AssertEq N'approval row untouched after later transitions',1,@flag;
SET @flag=CASE WHEN @rvDispatch=(SELECT RowVersion FROM credits.TransferDispatches WHERE TransferId=@transfer) THEN 1 ELSE 0 END;
EXEC test.AssertEq N'dispatch row untouched after receipt',1,@flag;
-- Each balance movement sits in the branch of the node that wrote it.
SET @n=(SELECT COUNT(*) FROM credits.CreditMovements WHERE SourceId=@transfer AND
  ((Kind='transfer_out' AND BranchId=@branchA AND AvailableDeltaMinor=-50000) OR (Kind='transfer_in' AND BranchId=@branchB AND AvailableDeltaMinor=50000)));
EXEC test.AssertEq N'one -50000 movement in A and one +50000 in B',2,@n;
SET @n=(SELECT COUNT(*) FROM credits.CreditMovements WHERE SourceId=@transfer);
EXEC test.AssertEq N'no other movements for the transfer',2,@n;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';

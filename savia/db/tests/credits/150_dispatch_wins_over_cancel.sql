-- TEST: dispatch wins over a cancel it never saw (Jason, 2026-11-12). The cloud cancels while branch A, offline, dispatches.
-- When A's dispatch rows arrive, the money still reaches B: B can receive, the status says received, the cancel is overridden
-- and the conservation oracle stays clean.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @n bigint,@ok int,@status varchar(20);
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@cashierB uniqueidentifier=test.Id('cashierB'),
  @supervisorA uniqueidentifier=test.Id('supervisorA'),@manager uniqueidentifier=test.Id('manager'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),@nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @credit uniqueidentifier=NEWID(),@t uniqueidentifier=NEWID();
EXEC test.SeedCredit @credit;  -- 120000 available at A
EXEC credits.usp_TransferRequest @TransferId=@t,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
EXEC credits.usp_TransferApprove @TransferId=@t,@ApproverId=@supervisorA,@NodeId=@nodeCloud;
-- Cloud: cancels before it has seen any dispatch.
EXEC credits.usp_TransferCancel @TransferId=@t,@ActorId=@manager,@Reason=N'Clienta cambio de idea',@NodeId=@nodeCloud;
-- Branch A, offline, saw the approval and not the cancel. Its dispatch rows arrive by sync (the applier copies rows, F4).
UPDATE credits.CreditAllocations SET AvailableMinor=AvailableMinor-50000,ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@cashierA
 WHERE CreditId=@credit AND BranchId=@branchA;
INSERT INTO credits.CreditMovements(Id,CreditId,BranchId,Kind,AvailableDeltaMinor,SourceType,SourceId,ActorId,CreatedBy)
 VALUES(NEWID(),@credit,@branchA,'transfer_out',-50000,'credit_transfer',@t,@cashierA,@cashierA);
INSERT INTO credits.TransferDispatches(TransferId,ActorId,NodeId) VALUES(@t,@cashierA,@nodeA);

SELECT @status=[Status] FROM credits.vw_TransferStatus WHERE TransferId=@t;
SET @ok=CASE WHEN @status='in_transit' THEN 1 ELSE 0 END; EXEC test.AssertEq N'dispatched after a cancel is in transit',1,@ok;
SET @n=(SELECT CAST(CancelOverridden AS bigint) FROM credits.vw_TransferStatus WHERE TransferId=@t);
EXEC test.AssertEq N'the cancel is marked overridden',1,@n;
-- Branch B receives normally.
EXEC credits.usp_TransferReceive @TransferId=@t,@ActorId=@cashierB,@NodeId=@nodeB;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchB);
EXEC test.AssertEq N'B has the money',50000,@n;
SELECT @status=[Status] FROM credits.vw_TransferStatus WHERE TransferId=@t;
SET @ok=CASE WHEN @status='received' THEN 1 ELSE 0 END; EXEC test.AssertEq N'status received',1,@ok;
-- A cancel the cloud has not seen dispatched stays a plain cancel.
DECLARE @t2 uniqueidentifier=NEWID();
EXEC credits.usp_TransferRequest @TransferId=@t2,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=10000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
EXEC credits.usp_TransferCancel @TransferId=@t2,@ActorId=@manager,@Reason=N'Duplicada',@NodeId=@nodeCloud;
SELECT @status=[Status] FROM credits.vw_TransferStatus WHERE TransferId=@t2;
SET @ok=CASE WHEN @status='cancelled' THEN 1 ELSE 0 END; EXEC test.AssertEq N'cancel without dispatch is cancelled',1,@ok;
SET @n=(SELECT COUNT(*) FROM credits.CreditAllocations WHERE CreditId=@credit AND AvailableMinor<0);
EXEC test.AssertEq N'no negative balance',0,@n;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';

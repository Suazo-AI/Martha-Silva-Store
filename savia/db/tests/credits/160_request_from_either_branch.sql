-- TEST: the customer may ask at either branch (Jason, 2026-11-12). Staff of the origin or the destination branch can request,
-- on their own branch node. A third branch, the cloud and staff without access to the node's branch are rejected.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @n bigint,@err int;
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@cashierB uniqueidentifier=test.Id('cashierB'),@cashierC uniqueidentifier=test.Id('cashierC'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),@nodeC uniqueidentifier=test.Id('nodeC'),
  @nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @credit uniqueidentifier=NEWID(),@t1 uniqueidentifier=NEWID(),@t2 uniqueidentifier=NEWID(),@t3 uniqueidentifier=NEWID();
EXEC test.SeedCredit @credit;  -- 120000 available at A
-- At the origin branch A.
EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=30000,@RequestedBy=@cashierA,@Reason=N'Clienta pide enviar a B',@NodeId=@nodeA;
SET @n=(SELECT COUNT(*) FROM credits.TransferRequests WHERE Id=@t1 AND NodeId=@nodeA AND RequestedBy=@cashierA);
EXEC test.AssertEq N'origin branch staff can request on the origin node',1,@n;
-- At the destination branch B.
EXEC credits.usp_TransferRequest @TransferId=@t2,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=20000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
SET @n=(SELECT COUNT(*) FROM credits.TransferRequests WHERE Id=@t2 AND NodeId=@nodeB);
EXEC test.AssertEq N'destination branch staff can request on the destination node',1,@n;
-- Staff of B on A's node: no access to A.
SET @err=0;
BEGIN TRY EXEC credits.usp_TransferRequest @TransferId=@t3,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=1000,@RequestedBy=@cashierB,@Reason=N'x',@NodeId=@nodeA; END TRY
BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'requester without access to the node branch',51724,@err;
-- A third branch is not part of the transfer.
SET @err=0;
BEGIN TRY EXEC credits.usp_TransferRequest @TransferId=@t3,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=1000,@RequestedBy=@cashierC,@Reason=N'x',@NodeId=@nodeC; END TRY
BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'third branch node rejected',51723,@err;
SET @err=0;
BEGIN TRY EXEC credits.usp_TransferRequest @TransferId=@t3,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=1000,@RequestedBy=@cashierB,@Reason=N'x',@NodeId=@nodeCloud; END TRY
BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'cloud node rejected',51723,@err;
SET @n=(SELECT COUNT(*) FROM credits.TransferRequests WHERE Id=@t3);
EXEC test.AssertEq N'no row for the rejected requests',0,@n;
PRINT 'PASS';

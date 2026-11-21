-- TEST: a request is written by the origin or destination node (V010): same branch, non-positive amount, blank reason, reused id with other content, inactive credit or no balance at origin, foreign node and requester without access to the destination are rejected with their exact error; a retry creates one row.
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
  EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchA,@AmountMinor=50000,@RequestedBy=@cashierA,@Reason=N'Canje en B',@NodeId=@nodeA;
  THROW 59002,'ASSERT FAIL: same-branch request accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51720 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=0,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
  THROW 59002,'ASSERT FAIL: zero amount accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51720 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'   ',@NodeId=@nodeB;
  THROW 59002,'ASSERT FAIL: blank reason accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51720 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeA;
  THROW 59002,'ASSERT FAIL: destination staff on the origin node accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51724 THROW; END CATCH;  -- CHANGED (V010): either branch may request; cashier B has no access to A.
BEGIN TRY
  EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeCloud;
  THROW 59002,'ASSERT FAIL: request from the cloud accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51723 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@cashierA,@Reason=N'Canje en B',@NodeId=@nodeB;
  THROW 59002,'ASSERT FAIL: requester without access to the destination accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51724 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchC,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
  THROW 59002,'ASSERT FAIL: request from a branch without balance accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51722 THROW; END CATCH;
DECLARE @ghost uniqueidentifier=NEWID();
BEGIN TRY
  EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@ghost,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
  THROW 59002,'ASSERT FAIL: request for an unknown credit accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51722 THROW; END CATCH;
EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
SET @n=(SELECT COUNT(*) FROM credits.TransferRequests WHERE Id=@t1);
EXEC test.AssertEq N'one request row after retry',1,@n;
BEGIN TRY
  EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=40000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
  THROW 59002,'ASSERT FAIL: same id with another amount accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51721 THROW; END CATCH;
BEGIN TRY
  EXEC credits.usp_TransferRequest @TransferId=@t1,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'Otro motivo',@NodeId=@nodeB;
  THROW 59002,'ASSERT FAIL: same id with another reason accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51721 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM credits.CreditTransfers);
EXEC test.AssertEq N'no legacy transfer row written',0,@n;
PRINT 'PASS';

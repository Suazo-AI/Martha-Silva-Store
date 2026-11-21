-- TEST: the conservation oracle counts money dispatched and not yet received (V009) and reports a transfer leg changed by hand.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@cashierB uniqueidentifier=test.Id('cashierB'),
  @manager uniqueidentifier=test.Id('manager'),@nodeA uniqueidentifier=test.Id('nodeA'),
  @nodeB uniqueidentifier=test.Id('nodeB'),@nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @credit uniqueidentifier=NEWID(),@t uniqueidentifier=NEWID(),@n bigint;
DECLARE @found TABLE(CheckName varchar(60),KeyText nvarchar(200),Expected bigint,Actual bigint);
EXEC test.SeedCredit @credit;
EXEC credits.usp_TransferRequest @TransferId=@t,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,
  @AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
EXEC credits.usp_TransferApprove @TransferId=@t,@ApproverId=@manager,@NodeId=@nodeCloud;
EXEC credits.usp_TransferDispatch @TransferId=@t,@ActorId=@cashierA,@NodeId=@nodeA;

-- In transit: clean.
INSERT INTO @found EXEC audit.usp_CheckConservation;
SET @n=(SELECT COUNT(*) FROM @found);
EXEC test.AssertEq N'violations with 50000 in transit',0,@n;

-- Corruption: the dispatch leg says -40000 instead of -50000.
UPDATE credits.CreditMovements SET AvailableDeltaMinor=-40000 WHERE SourceId=@t AND Kind='transfer_out';
DELETE FROM @found; INSERT INTO @found EXEC audit.usp_CheckConservation;
SET @n=(SELECT COUNT(*) FROM @found WHERE CheckName='credit.transfer_leg' AND Expected=1 AND Actual=0);
EXEC test.AssertEq N'detects a dispatch leg with the wrong amount',1,@n;
SET @n=(SELECT COUNT(*) FROM @found WHERE CheckName='credit.available_vs_movements');
EXEC test.AssertEq N'and the balance no longer matches its movements',1,@n;
UPDATE credits.CreditMovements SET AvailableDeltaMinor=-50000 WHERE SourceId=@t AND Kind='transfer_out';

-- Corruption: a receipt row without its +amount leg (inserted by hand).
INSERT INTO credits.TransferReceipts(TransferId,ActorId,NodeId) VALUES(@t,@cashierB,@nodeB);
DELETE FROM @found; INSERT INTO @found EXEC audit.usp_CheckConservation;
SET @n=(SELECT COUNT(*) FROM @found WHERE CheckName='credit.transfer_leg' AND Expected=1 AND Actual=0);
EXEC test.AssertEq N'detects a receipt without its transfer_in leg',1,@n;
SET @n=(SELECT COUNT(*) FROM @found WHERE CheckName='credit.conservation' AND Expected=120000 AND Actual=70000);
EXEC test.AssertEq N'and 50000 vanished from conservation',1,@n;
PRINT 'PASS';

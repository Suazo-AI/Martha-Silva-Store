-- TEST: staff find a customer's credit fast by name, phone (any format), email or customer code (Jason, 2026-11-12).
-- One row per branch balance. Customers without credit, wildcards and too-short queries return nothing; unknown staff is rejected.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @n bigint,@err int;
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@cashierB uniqueidentifier=test.Id('cashierB'),
  @supervisorA uniqueidentifier=test.Id('supervisorA'),@customer uniqueidentifier=test.Id('customer'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),@nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @credit uniqueidentifier=NEWID(),@t uniqueidentifier=NEWID();
UPDATE crm.Customers SET Phone=N'+505 8888-1234',CustomerCode=N'CLI-0042' WHERE Id=@customer;
EXEC test.SeedCredit @credit;  -- 120000 available at A
DECLARE @r TABLE(CustomerId uniqueidentifier,DisplayName nvarchar(200),Phone nvarchar(40),Email nvarchar(254),
  CreditId uniqueidentifier,CurrencyCode varchar(3),BranchId uniqueidentifier,BranchName nvarchar(150),AvailableMinor bigint);

INSERT @r EXEC credits.usp_FindCustomerCredits @Query=N'clienta',@ActorId=@cashierB;
SET @n=(SELECT COUNT(*) FROM @r WHERE CustomerId=@customer AND CreditId=@credit AND BranchId=@branchA AND AvailableMinor=120000);
EXEC test.AssertEq N'name finds the credit at A from branch B',1,@n;
SET @n=(SELECT COUNT(DISTINCT CustomerId) FROM @r); EXEC test.AssertEq N'customer without credit not listed',1,@n;
DELETE @r; INSERT @r EXEC credits.usp_FindCustomerCredits @Query=N'88881234',@ActorId=@cashierB;
SET @n=(SELECT COUNT(*) FROM @r WHERE CreditId=@credit); EXEC test.AssertEq N'phone digits',1,@n;
DELETE @r; INSERT @r EXEC credits.usp_FindCustomerCredits @Query=N'8888-1234',@ActorId=@cashierB;
SET @n=(SELECT COUNT(*) FROM @r WHERE CreditId=@credit); EXEC test.AssertEq N'phone with dash',1,@n;
DELETE @r; INSERT @r EXEC credits.usp_FindCustomerCredits @Query=N'clienta@example.test',@ActorId=@cashierB;
SET @n=(SELECT COUNT(*) FROM @r WHERE CreditId=@credit); EXEC test.AssertEq N'email',1,@n;
DELETE @r; INSERT @r EXEC credits.usp_FindCustomerCredits @Query=N'cli-0042',@ActorId=@cashierB;
SET @n=(SELECT COUNT(*) FROM @r WHERE CreditId=@credit); EXEC test.AssertEq N'customer code',1,@n;
DELETE @r; INSERT @r EXEC credits.usp_FindCustomerCredits @Query=N'nadie',@ActorId=@cashierB;
SET @n=(SELECT COUNT(*) FROM @r); EXEC test.AssertEq N'no match',0,@n;
DELETE @r; INSERT @r EXEC credits.usp_FindCustomerCredits @Query=N'%%',@ActorId=@cashierB;
SET @n=(SELECT COUNT(*) FROM @r); EXEC test.AssertEq N'wildcards are literal',0,@n;
SET @err=0;
BEGIN TRY INSERT @r EXEC credits.usp_FindCustomerCredits @Query=N' a ',@ActorId=@cashierB; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'query shorter than 2 characters',51733,@err;
SET @err=0;
BEGIN TRY DECLARE @ghost uniqueidentifier=NEWID(); INSERT @r EXEC credits.usp_FindCustomerCredits @Query=N'clienta',@ActorId=@ghost; END TRY
BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'unknown staff rejected',51724,@err;
-- After a full transfer of 50000 the search shows both branch balances.
EXEC credits.usp_TransferRequest @TransferId=@t,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@nodeB;
EXEC credits.usp_TransferApprove @TransferId=@t,@ApproverId=@supervisorA,@NodeId=@nodeCloud;
EXEC credits.usp_TransferDispatch @TransferId=@t,@ActorId=@cashierA,@NodeId=@nodeA;
EXEC credits.usp_TransferReceive @TransferId=@t,@ActorId=@cashierB,@NodeId=@nodeB;
DELETE @r; INSERT @r EXEC credits.usp_FindCustomerCredits @Query=N'clienta',@ActorId=@cashierB;
SET @n=(SELECT SUM(AvailableMinor) FROM @r WHERE BranchId=@branchA); EXEC test.AssertEq N'A after transfer',70000,@n;
SET @n=(SELECT SUM(AvailableMinor) FROM @r WHERE BranchId=@branchB); EXEC test.AssertEq N'B after transfer',50000,@n;
PRINT 'PASS';

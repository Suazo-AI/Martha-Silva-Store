-- TEST: D-038 issuer procedures for a credit's status (V052). Only the issuing branch's node blocks or expires a credit; a retry changes nothing; expiry needs a due date in the past; a blocked or expired credit is not redeemable; a restored branch cannot change a status.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@b uniqueidentifier=test.Id('nodeB'),
  @branchA uniqueidentifier=test.Id('branchA'),@supervisorA uniqueidentifier=test.Id('supervisorA'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@supervisorB uniqueidentifier=test.Id('supervisorB'),
  @fork uniqueidentifier=(SELECT recovery_fork_guid FROM sys.database_recovery_status WHERE database_id=DB_ID()),
  @credit uniqueidentifier=NEWID(),@due uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),
  @x uniqueidentifier=NEWID(),@rv binary(8),@n bigint,@err int,@status varchar(16);
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedCredit @credit;
EXEC test.SeedCredit @due;
EXEC test.SeedSale @sale,'A';

EXEC credits.usp_BlockCredit @CreditId=@credit,@ActorId=@supervisorA;
SET @status=(SELECT Status FROM credits.vw_CreditStatus WHERE CreditId=@credit);
SET @n=IIF(@status='blocked',1,0); EXEC test.AssertEq N'the issuer blocks a credit',1,@n;
SET @n=(SELECT COUNT(*) FROM credits.Credits WHERE Id=@credit AND ModifiedBy=@supervisorA); EXEC test.AssertEq N'the block records who',1,@n;
SET @rv=(SELECT CONVERT(binary(8),RowVersion) FROM credits.Credits WHERE Id=@credit);
EXEC credits.usp_BlockCredit @CreditId=@credit,@ActorId=@supervisorA;
SET @n=(SELECT COUNT(*) FROM credits.Credits WHERE Id=@credit AND CONVERT(binary(8),RowVersion)=@rv); EXEC test.AssertEq N'a retried block writes nothing',1,@n;
SET @err=0;
BEGIN TRY EXEC credits.usp_RedeemCredit @RedemptionId=@x,@CreditId=@credit,@BranchId=@branchA,@SaleId=@sale,@AmountMinor=1000,@ActorId=@cashierA;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a blocked credit is not redeemable',51606,@err;

SET @err=0;
BEGIN TRY EXEC credits.usp_BlockCredit @CreditId=@due,@ActorId=@cashierA; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a cashier cannot block',51633,@err;
SET @err=0;
BEGIN TRY EXEC credits.usp_ExpireCredit @CreditId=@due,@ActorId=@supervisorA; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a credit without a past due date does not expire',51632,@err;
-- The due date is set at issue; this test moves it into the past.
UPDATE credits.Credits SET ExpiresAt=DATEADD(day,-1,SYSUTCDATETIME()) WHERE Id=@due;

-- Another branch's node never writes the issuer's row.
UPDATE sync.LocalNode SET NodeId=@b;
SET @err=0;
BEGIN TRY EXEC credits.usp_ExpireCredit @CreditId=@due,@ActorId=@supervisorB; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'another branch cannot expire the credit',51631,@err;
UPDATE sync.LocalNode SET NodeId=@a,ForkGuid=NEWID();
SET @err=0;
BEGIN TRY EXEC credits.usp_ExpireCredit @CreditId=@due,@ActorId=@supervisorA; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a recovering issuer cannot expire',51864,@err;
UPDATE sync.LocalNode SET ForkGuid=@fork;

EXEC credits.usp_ExpireCredit @CreditId=@due,@ActorId=@supervisorA;
EXEC credits.usp_ExpireCredit @CreditId=@due,@ActorId=@supervisorA;
SET @status=(SELECT Status FROM credits.vw_CreditStatus WHERE CreditId=@due);
SET @n=IIF(@status='expired',1,0); EXEC test.AssertEq N'the issuer expires a due credit, retry included',1,@n;
SET @err=0;
BEGIN TRY EXEC credits.usp_BlockCredit @CreditId=@due,@ActorId=@supervisorA; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'an expired credit cannot be blocked',51634,@err;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';

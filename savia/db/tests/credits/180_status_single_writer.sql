-- TEST: D-038 one writer for a credit's status. Redeeming never writes the issuer's credit row; the derived status (credits.vw_CreditStatus) is exhausted once every branch's money is spent; a status the issuer sets wins and stops redemptions.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@cashierA uniqueidentifier=test.Id('cashierA'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@supervisorA uniqueidentifier=test.Id('supervisorA'),
  @credit uniqueidentifier=NEWID(),@blocked uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),
  @r uniqueidentifier=NEWID(),@before binary(8),@n bigint,@status varchar(16),@err int;
EXEC test.SeedCredit @credit;  -- 120000 available at A
EXEC test.SeedSale @sale,'A';
SET @before=(SELECT CONVERT(binary(8),RowVersion) FROM credits.Credits WHERE Id=@credit);
EXEC credits.usp_RedeemCredit @RedemptionId=@r,@CreditId=@credit,@BranchId=@branchA,@SaleId=@sale,@AmountMinor=120000,@ActorId=@cashierA;
SET @n=(SELECT COUNT(*) FROM credits.Credits WHERE Id=@credit AND CONVERT(binary(8),RowVersion)=@before AND Status='active');
EXEC test.AssertEq N'the redemption left the credit row untouched',1,@n;
SET @status=(SELECT Status FROM credits.vw_CreditStatus WHERE CreditId=@credit);
SET @n=IIF(@status='exhausted',1,0); EXEC test.AssertEq N'derived status exhausted',1,@n;

-- The issuer blocks a credit (credits.usp_BlockCredit, V052).
EXEC test.SeedCredit @blocked;
EXEC sync.usp_SetLocalNode @NodeId=@nodeA;
EXEC credits.usp_BlockCredit @CreditId=@blocked,@ActorId=@supervisorA;
SET @status=(SELECT Status FROM credits.vw_CreditStatus WHERE CreditId=@blocked);
SET @n=IIF(@status='blocked',1,0); EXEC test.AssertEq N'issuer status wins',1,@n;
SET @err=0; SET @r=NEWID();
BEGIN TRY EXEC credits.usp_RedeemCredit @RedemptionId=@r,@CreditId=@blocked,@BranchId=@branchA,@SaleId=@sale,@AmountMinor=1000,@ActorId=@cashierA;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a blocked credit is not redeemable',51606,@err;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';

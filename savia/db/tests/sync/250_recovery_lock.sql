-- TEST: D-036 recovery lock. A branch on another recovery fork than the one it was bound on refuses sale, till opening and receiving (51864) and reports recovering; a retry of usp_SetLocalNode keeps the lock; the hub never locks; a rebuild from the hub lifts the lock.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @register uniqueidentifier=test.Id('registerA'),@cashier uniqueidentifier=test.Id('cashierA'),
  @item uniqueidentifier=test.Id('item'),@loc uniqueidentifier=test.Id('locA'),
  @fork uniqueidentifier=(SELECT recovery_fork_guid FROM sys.database_recovery_status WHERE database_id=DB_ID()),
  @state nvarchar(max),@plan nvarchar(max),@rb nvarchar(max),@r nvarchar(max),@n bigint,@err int,
  @sale uniqueidentifier=NEWID(),@till uniqueidentifier=NEWID();
EXEC sync.usp_SetLocalNode @NodeId=@a;
SET @n=(SELECT COUNT(*) FROM sync.LocalNode WHERE ForkGuid=@fork); EXEC test.AssertEq N'bound on the current fork',1,@n;
SET @n=sync.fn_Recovering(); EXEC test.AssertEq N'a bound branch is not recovering',0,@n;

-- A database cannot restore itself inside a test, so the bound fork is moved: the same state a restore leaves.
UPDATE sync.LocalNode SET ForkGuid=NEWID();
SET @n=sync.fn_Recovering(); EXEC test.AssertEq N'a restored branch is recovering',1,@n;
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
SET @n=IIF(JSON_VALUE(@state,'$.recovering')='true',1,0); EXEC test.AssertEq N'source state reports recovering',1,@n;
EXEC sync.usp_SetLocalNode @NodeId=@a;
SET @n=sync.fn_Recovering(); EXEC test.AssertEq N'a retry of usp_SetLocalNode keeps the lock',1,@n;

SET @err=0;
BEGIN TRY EXEC test.SeedSale @sale,'A'; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'sale refused while recovering',51864,@err;
SET @err=0;
BEGIN TRY EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
  @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@a; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'till opening refused while recovering',51864,@err;
SET @err=0;
BEGIN TRY EXEC sales.usp_OpenTillCounted @TillId=@till,@RegisterId=@register,@CashierId=@cashier,@CurrencyCode='NIO',
  @OpeningMinor=100000,@OriginNodeId=@a,@LinesJson=N'[{"denominationMinor":100000,"quantity":1}]';
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'counted till opening refused while recovering',51864,@err;
SET @err=0;
BEGIN TRY EXEC test.SeedStock @item,@loc,1; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'receiving refused while recovering',51864,@err;
SET @n=(SELECT COUNT(*) FROM sales.Sales)+(SELECT COUNT(*) FROM sales.CashTills); EXEC test.AssertEq N'nothing was written',0,@n;

-- The hub never locks, whatever its bound fork says.
UPDATE sync.LocalNode SET NodeId=@cloud;
SET @n=sync.fn_Recovering(); EXEC test.AssertEq N'the hub is never recovering',0,@n;

-- The hub serves A a rebuild and A applies it: the lock lifts in the same transaction as the rows.
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_PlanJson @PeerNodeId=@cloud,@StateJson=@state,@Mode='rebuild',@Json=@plan OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_ReadBatch @TargetNodeId=@a,@PlanJson=@plan,@TargetForkGuid=@fork,@Json=@rb OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_ApplyBatch @PeerNodeId=@cloud,@BatchJson=@rb,@Json=@r OUTPUT;
SET @n=sync.fn_Recovering(); EXEC test.AssertEq N'rebuild lifts the lock',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.LocalNode WHERE ForkGuid=@fork); EXEC test.AssertEq N'bound to the rebuilt fork',1,@n;
EXEC test.SeedSale @sale,'A';
SET @n=(SELECT COUNT(*) FROM sales.Sales WHERE Id=@sale); EXEC test.AssertEq N'sale accepted after the rebuild',1,@n;
PRINT 'PASS';

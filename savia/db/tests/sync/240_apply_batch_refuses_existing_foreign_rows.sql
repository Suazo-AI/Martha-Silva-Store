-- TEST: ownership of the existing row. A row whose key already exists keeps its owner:
-- the hub refuses a push that reuses another branch's key with the sender's own owner value,
-- and a branch refuses a normal pull that would rewrite a row it owns under another owner (V034).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @state nvarchar(max),@plan nvarchar(max),@p nvarchar(max),@bad nvarchar(max),@r nvarchar(max),@n bigint,@err int,
  @mine uniqueidentifier=NEWID(),@theirs uniqueidentifier=NEWID();
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedSale @mine,'A';
EXEC test.SeedSale @theirs,'B';   -- B's sale, already on the hub and relayed to A

-- Push: A's batch with its own sale row relabelled to B's sale id (owner column still A).
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_PlanJson @PeerNodeId=@a,@StateJson=@state,@Json=@plan OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@Json=@p OUTPUT;
SET @bad=(SELECT JSON_MODIFY(@p,'$.tables',JSON_QUERY(N'['+value+N']')) FROM OPENJSON(@p,'$.tables')
          WHERE JSON_VALUE(value,'$.t')=N'[sales].[Sales]');
SET @bad=REPLACE(@bad,CONVERT(nvarchar(36),@mine),CONVERT(nvarchar(36),@theirs));
UPDATE sync.LocalNode SET NodeId=@cloud;
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@bad,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'hub refuses a push that reuses the key of a row owned by another branch',51851,@err;
SET @n=(SELECT COUNT(*) FROM sales.Sales WHERE Id=@theirs AND BranchId=test.Id('branchB'));
EXEC test.AssertEq N'the sale of B keeps its owner',1,@n;

-- Pull: the hub's batch for A with B's sale relabelled to A's own sale id (owner column still B).
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_PlanJson @PeerNodeId=@cloud,@StateJson=@state,@Json=@plan OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_ReadBatch @TargetNodeId=@a,@PlanJson=@plan,@Json=@p OUTPUT;
SET @bad=(SELECT JSON_MODIFY(@p,'$.tables',JSON_QUERY(N'['+value+N']')) FROM OPENJSON(@p,'$.tables')
          WHERE JSON_VALUE(value,'$.t')=N'[sales].[Sales]');
SET @n=(SELECT COUNT(*) FROM OPENJSON(@bad,'$.tables[0].rows')); EXEC test.AssertEq N'hub sends the sale of B to A',1,@n;
SET @bad=REPLACE(@bad,CONVERT(nvarchar(36),@theirs),CONVERT(nvarchar(36),@mine));
UPDATE sync.LocalNode SET NodeId=@a;
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@cloud,@BatchJson=@bad,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'branch refuses a pull that rewrites its own row under another owner',51851,@err;
SET @n=(SELECT COUNT(*) FROM sales.Sales WHERE Id=@mine AND BranchId=test.Id('branchA'));
EXEC test.AssertEq N'the sale of A keeps its owner',1,@n;
PRINT 'PASS';

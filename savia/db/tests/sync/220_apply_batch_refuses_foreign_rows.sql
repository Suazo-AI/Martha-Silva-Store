-- TEST: ownership. The hub refuses a push row owned by another branch; a branch refuses a normal pull row it owns itself.
-- Also: wrong peer, a node pair that may not sync, and a schema mismatch are refused before any write.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@b uniqueidentifier=test.Id('nodeB'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @state nvarchar(max),@plan nvarchar(max),@p nvarchar(max),@bad nvarchar(max),@r nvarchar(max),@n bigint,@err int,
  @id uniqueidentifier=NEWID();
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedSale @id,'A';
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_PlanJson @PeerNodeId=@a,@StateJson=@state,@Json=@plan OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@Json=@p OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
-- A's stock balance relabelled to B's location: A claims a row that B owns.
SET @bad=(SELECT JSON_MODIFY(@p,'$.tables',JSON_QUERY(N'['+value+N']')) FROM OPENJSON(@p,'$.tables')
          WHERE JSON_VALUE(value,'$.t')=N'[inventory].[StockBalances]');
SET @bad=REPLACE(@bad,CONVERT(nvarchar(36),test.Id('locA')),CONVERT(nvarchar(36),test.Id('locB')));
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@bad,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'hub refuses a row owned by another branch',51851,@err;
SET @n=(SELECT COUNT(*) FROM sync.PeerCursors WHERE PeerNodeId=@a); EXEC test.AssertEq N'no cursor moved',0,@n;
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@b,@BatchJson=@p,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'batch of A presented as B refused',51850,@err;
SET @bad=JSON_MODIFY(@p,'$.schema','V000');
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@bad,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'schema mismatch refused',51856,@err;
-- Branch to branch is not a sync pair.
UPDATE sync.LocalNode SET NodeId=@b;
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@p,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'branch to branch refused',51850,@err;
-- The hub's normal batch for B carries A's sale. Delivered to A as if from the hub, A refuses its own row.
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@b;
EXEC sync.usp_PlanJson @PeerNodeId=@cloud,@StateJson=@state,@Json=@plan OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_ReadBatch @TargetNodeId=@b,@PlanJson=@plan,@Json=@p OUTPUT;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@p,'$.tables[1].rows')); EXEC test.AssertEq N'hub relays the sale of A to B',1,@n;
UPDATE sync.LocalNode SET NodeId=@a;
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@cloud,@BatchJson=@p,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'branch refuses its own row in a normal pull',51851,@err;
PRINT 'PASS';

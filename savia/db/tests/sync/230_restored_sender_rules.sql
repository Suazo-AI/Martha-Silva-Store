-- TEST: restore. A batch from a new fork is refused until the hub served that fork a rebuild (51854);
-- after the rebuild, a batch from the old fork (read before the restore) is refused forever (51853).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @state nvarchar(max),@plan nvarchar(max),@p0 nvarchar(max),@p1 nvarchar(max),@rb nvarchar(max),@r nvarchar(max),
  @n bigint,@err int,@id uniqueidentifier=NEWID(),@newFork uniqueidentifier=NEWID();
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedSale @id,'A';
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_PlanJson @PeerNodeId=@a,@StateJson=@state,@Json=@plan OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@Json=@p0 OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@p0,@Json=@r OUTPUT;
-- A full-state batch from a new fork stands for A after a restore ('initial' tables, as a recover plan sends).
SET @p1=JSON_MODIFY(JSON_MODIFY(@p0,'$.fork',CONVERT(nvarchar(36),@newFork)),'$.to',CONVERT(bigint,JSON_VALUE(@p0,'$.to'))+1);
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@p1,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'restored node may not push before a rebuild',51854,@err;
-- The hub serves A a rebuild for its new fork.
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_PlanJson @PeerNodeId=@cloud,@StateJson=@state,@Mode='rebuild',@Json=@plan OUTPUT;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@plan,'$.tables') WITH (a varchar(20)) WHERE a='rebuild');
EXEC test.AssertEq N'rebuild plan covers every table',23,@n;
-- A branch may not serve a rebuild.
SET @err=0;
BEGIN TRY EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@TargetForkGuid=@newFork,@Json=@rb OUTPUT; END TRY
BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'branch cannot serve a rebuild',51850,@err;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_ReadBatch @TargetNodeId=@a,@PlanJson=@plan,@TargetForkGuid=@newFork,@Json=@rb OUTPUT;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@rb,'$.tables[1].rows')); EXEC test.AssertEq N'rebuild carries the own sale of A',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.PeerRebuilds WHERE PeerNodeId=@a AND ForkGuid=@newFork); EXEC test.AssertEq N'rebuild recorded',1,@n;
-- The pre-restore batch arrives late: refused, even though its data looks new.
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@p0,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'batch from the retired fork refused',51853,@err;
-- V033: serving the rebuild is not enough; the push must carry the token of the rebuild the branch applied.
SET @n=IIF(TRY_CONVERT(uniqueidentifier,JSON_VALUE(@rb,'$.rebuild')) IS NULL,0,1); EXEC test.AssertEq N'rebuild carries a token',1,@n;
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@p1,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'new fork without the applied rebuild token refused',51854,@err;
SET @p1=JSON_MODIFY(@p1,'$.rebuild',CONVERT(nvarchar(36),NEWID()));
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@p1,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'new fork with a wrong token refused',51854,@err;
-- The recovery push from the new fork, with the token, is accepted and moves every cursor to it.
SET @p1=JSON_MODIFY(@p1,'$.rebuild',JSON_VALUE(@rb,'$.rebuild'));
EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@p1,@Json=@r OUTPUT;
SET @n=(SELECT COUNT(*) FROM sync.PeerCursors WHERE PeerNodeId=@a AND ForkGuid=@newFork); EXEC test.AssertEq N'cursors on the new fork',23,@n;
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@p0,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'old fork still refused after recovery',51853,@err;
PRINT 'PASS';

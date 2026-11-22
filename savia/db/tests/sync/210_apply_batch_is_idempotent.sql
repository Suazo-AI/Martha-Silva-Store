-- TEST: A-04. A duplicate or late batch changes nothing and raises no error; a gap in an incremental batch is refused.
-- One database plays both nodes: sync.LocalNode is switched between A (sender) and the cloud (receiver).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @state nvarchar(max),@plan nvarchar(max),@p1 nvarchar(max),@p2 nvarchar(max),@p3 nvarchar(max),@r nvarchar(max),
  @n bigint,@err int,@id uniqueidentifier=NEWID();
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedSale @id,'A';
-- A reads its first batch for the cloud.
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_PlanJson @PeerNodeId=@a,@StateJson=@state,@Json=@plan OUTPUT;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@plan,'$.tables') WITH (a varchar(20)) WHERE a='initial');
EXEC test.AssertEq N'first plan is initial for every table',23,@n;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@Json=@p1 OUTPUT;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@p1,'$.tables[1].rows')); EXEC test.AssertEq N'the sale travels',1,@n;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@p1,@Json=@r OUTPUT;
SET @n=JSON_VALUE(@r,'$.applied'); EXEC test.AssertEq N'first batch applies every table',23,@n;
SET @n=(SELECT COUNT(*) FROM sync.PeerCursors WHERE PeerNodeId=@a AND [Version]=JSON_VALUE(@p1,'$.to'));
EXEC test.AssertEq N'every cursor at the batch version',23,@n;
-- Duplicate delivery.
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@p1,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'duplicate: no error',0,@err;
SET @n=JSON_VALUE(@r,'$.skipped'); EXEC test.AssertEq N'duplicate: every table skipped',23,@n;
SET @n=JSON_VALUE(@r,'$.changed'); EXEC test.AssertEq N'duplicate: 0 changes',0,@n;
-- A newer batch, then the old one arrives late.
UPDATE sync.LocalNode SET NodeId=@a;
SET @id=NEWID(); EXEC test.SeedSale @id,'A';
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_PlanJson @PeerNodeId=@a,@StateJson=@state,@Json=@plan OUTPUT;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@plan,'$.tables') WITH (a varchar(20)) WHERE a='incremental');
EXEC test.AssertEq N'second plan is incremental',23,@n;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@Json=@p2 OUTPUT;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@p2,'$.tables[1].rows')); EXEC test.AssertEq N'only the new sale travels',1,@n;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@p2,@Json=@r OUTPUT;
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@p1,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'late batch: no error',0,@err;
SET @n=JSON_VALUE(@r,'$.skipped'); EXEC test.AssertEq N'late batch: every table skipped',23,@n;
SET @n=(SELECT COUNT(*) FROM sync.PeerCursors WHERE PeerNodeId=@a AND [Version]=JSON_VALUE(@p2,'$.to'));
EXEC test.AssertEq N'late batch: cursors stay at the newer version',23,@n;
-- Gap: the receiver's cursor is older than the batch's start, so an incremental batch would skip changes.
UPDATE sync.LocalNode SET NodeId=@a;
SET @id=NEWID(); EXEC test.SeedSale @id,'A';
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_PlanJson @PeerNodeId=@a,@StateJson=@state,@Json=@plan OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@Json=@p3 OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
UPDATE sync.PeerCursors SET [Version]=[Version]-1 WHERE PeerNodeId=@a;
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@p3,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'gap refused',51852,@err;
-- The read needs its own SNAPSHOT transaction.
UPDATE sync.LocalNode SET NodeId=@a;
SET @err=0;
BEGIN TRY
  BEGIN TRANSACTION; EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@Json=@p3 OUTPUT; COMMIT;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); IF @@TRANCOUNT>0 ROLLBACK; END CATCH;
EXEC test.AssertEq N'read inside a transaction refused',51857,@err;
PRINT 'PASS';

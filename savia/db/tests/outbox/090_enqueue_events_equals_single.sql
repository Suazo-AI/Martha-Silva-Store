-- TEST: sync.usp_EnqueueEvents (V061, P1) leaves the outbox and deliveries that one sync.usp_EnqueueEvent call per event
-- leaves, in the same order, and refuses what the single call refuses with the same error.
-- Cases: a branch origin (one delivery to the hub each), a hub origin (no delivery) and an explicit destination; each with
-- the same event twice in one set, and the first with a replay of a stored event.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),@hub uniqueidentifier=test.Id('nodeCloud'),
  @old uniqueidentifier=NEWID(),@n bigint,@diff int,@origin uniqueidentifier,@dest uniqueidentifier;
DECLARE @cases TABLE(CaseNo int,Origin uniqueidentifier,Dest uniqueidentifier NULL);
INSERT @cases VALUES(1,@nodeA,NULL),(2,@hub,NULL),(3,@hub,@nodeB);
-- One stored event: the set replays it unchanged.
BEGIN TRAN; EXEC sync.usp_EnqueueEvent @old,@nodeA,'sale',@old,'sales.sale_posted',N'{"n":0}'; COMMIT;
-- Ords 3 and 5 replay the stored event; Ord 7 repeats Ord 1 inside the set. The stored event has a branch origin, so only
-- case 1 may replay it: under another origin the single call refuses it (51005), as tested below.
DECLARE @all TABLE(Ord int PRIMARY KEY,EventId uniqueidentifier,AggregateType varchar(50),AggregateId uniqueidentifier,EventType varchar(80),PayloadJson nvarchar(max));
INSERT @all SELECT v.n,NEWID(),'item',NEWID(),'catalog.item_registered',CONCAT(N'{"n":',v.n,N'}') FROM (VALUES(1),(2),(4),(6)) v(n);
INSERT @all VALUES(3,@old,'sale',@old,'sales.sale_posted',N'{"n":0}'),(5,@old,'sale',@old,'sales.sale_posted',N'{"n":0}');
INSERT @all SELECT 7,EventId,AggregateType,AggregateId,EventType,PayloadJson FROM @all WHERE Ord=1;
DECLARE @events sync.EventInput;
DECLARE @single TABLE(CaseNo int,Rank bigint,EventId uniqueidentifier,Origin uniqueidentifier,AggType varchar(50),Agg uniqueidentifier,
  EvType varchar(80),Payload nvarchar(max),Dest uniqueidentifier NULL);
DECLARE @set TABLE(CaseNo int,Rank bigint,EventId uniqueidentifier,Origin uniqueidentifier,AggType varchar(50),Agg uniqueidentifier,
  EvType varchar(80),Payload nvarchar(max),Dest uniqueidentifier NULL);
DECLARE @case int=1,@ord int,@e uniqueidentifier,@at varchar(50),@a uniqueidentifier,@et varchar(80),@p nvarchar(max),@since bigint;
WHILE @case<=3
BEGIN
  SELECT @origin=Origin,@dest=Dest FROM @cases WHERE CaseNo=@case;
  DELETE @events; INSERT @events SELECT * FROM @all WHERE @case=1 OR Ord NOT IN (3,5);
  SET @since=(SELECT MAX(SequenceNo) FROM sync.Outbox);
  BEGIN TRAN;
  SET @ord=(SELECT MIN(Ord) FROM @events);
  WHILE @ord IS NOT NULL
  BEGIN
    SELECT @e=EventId,@at=AggregateType,@a=AggregateId,@et=EventType,@p=PayloadJson FROM @events WHERE Ord=@ord;
    EXEC sync.usp_EnqueueEvent @e,@origin,@at,@a,@et,@p,@dest;
    SET @ord=(SELECT MIN(Ord) FROM @events WHERE Ord>@ord);
  END;
  INSERT @single SELECT @case,ROW_NUMBER() OVER(ORDER BY o.SequenceNo),o.EventId,o.OriginNodeId,o.AggregateType,o.AggregateId,o.EventType,
    o.PayloadJson,d.DestinationNodeId FROM sync.Outbox o LEFT JOIN sync.EventDeliveries d ON d.EventId=o.EventId WHERE o.SequenceNo>@since;
  ROLLBACK;
  BEGIN TRAN;
  EXEC sync.usp_EnqueueEvents @OriginNodeId=@origin,@Events=@events,@DestinationNodeId=@dest;
  INSERT @set SELECT @case,ROW_NUMBER() OVER(ORDER BY o.SequenceNo),o.EventId,o.OriginNodeId,o.AggregateType,o.AggregateId,o.EventType,
    o.PayloadJson,d.DestinationNodeId FROM sync.Outbox o LEFT JOIN sync.EventDeliveries d ON d.EventId=o.EventId WHERE o.SequenceNo>@since;
  ROLLBACK;
  SET @case+=1;
END;
SET @n=(SELECT COUNT(*) FROM @single); EXEC test.AssertEq N'single calls: four new events in three cases',12,@n;
SET @n=(SELECT COUNT(*) FROM @single WHERE CaseNo=1 AND Dest=@hub); EXEC test.AssertEq N'branch origin: every event goes to the hub',4,@n;
SET @n=(SELECT COUNT(*) FROM @single WHERE CaseNo=2 AND Dest IS NULL); EXEC test.AssertEq N'hub origin: no delivery',4,@n;
SET @diff=(SELECT COUNT(*) FROM (SELECT * FROM @single EXCEPT SELECT * FROM @set UNION ALL SELECT * FROM @set EXCEPT SELECT * FROM @single) x);
EXEC test.AssertEq N'the set leaves the rows, order and deliveries of single calls',0,@diff;
SET @n=(SELECT COUNT(*) FROM @set); EXEC test.AssertEq N'set: same row count',12,@n;

-- Refusals: the same error number as the single call, and nothing written.
DECLARE @bad sync.EventInput; DECLARE @err int;
SET @since=(SELECT MAX(SequenceNo) FROM sync.Outbox);
INSERT @bad VALUES(1,NEWID(),'item',NEWID(),'catalog.item_registered',N'{}');
BEGIN TRY EXEC sync.usp_EnqueueEvents @OriginNodeId=@nodeA,@Events=@bad; SET @err=0; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'outside a transaction: 51000',51000,@err;
BEGIN TRY BEGIN TRAN; EXEC sync.usp_EnqueueEvents @OriginNodeId=@old,@Events=@bad; SET @err=0; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
IF @@TRANCOUNT>0 ROLLBACK; EXEC test.AssertEq N'unknown origin: 51002',51002,@err;
UPDATE @bad SET PayloadJson=N'not json';
BEGIN TRY BEGIN TRAN; EXEC sync.usp_EnqueueEvents @OriginNodeId=@nodeA,@Events=@bad; SET @err=0; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
IF @@TRANCOUNT>0 ROLLBACK; EXEC test.AssertEq N'invalid payload: 51001',51001,@err;
UPDATE @bad SET EventId=@old,PayloadJson=N'{"n":1}';
BEGIN TRY BEGIN TRAN; EXEC sync.usp_EnqueueEvents @OriginNodeId=@nodeA,@Events=@bad; SET @err=0; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
IF @@TRANCOUNT>0 ROLLBACK; EXEC test.AssertEq N'stored event with other content: 51005',51005,@err;
DELETE @bad; INSERT @bad VALUES(1,@old,'sale',@old,'sales.sale_posted',N'{"n":0}'),(2,NEWID(),'item',NEWID(),'catalog.item_registered',N'{}');
BEGIN TRY BEGIN TRAN; EXEC sync.usp_EnqueueEvents @OriginNodeId=@nodeA,@Events=@bad,@DestinationNodeId=@nodeA; SET @err=0; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
IF @@TRANCOUNT>0 ROLLBACK; EXEC test.AssertEq N'destination equal to origin: 51004',51004,@err;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE SequenceNo>@since); EXEC test.AssertEq N'refusals write nothing',0,@n;
PRINT 'PASS';

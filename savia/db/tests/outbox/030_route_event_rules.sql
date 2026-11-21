-- TEST: routing adds a delivery once per node, is idempotent, rejects unknown events, unauthorized destinations and late routes after the node cursor passed the event.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),
  @nodeCloud uniqueidentifier=test.Id('nodeCloud'),@ghost uniqueidentifier=NEWID(),
  @agg uniqueidentifier=NEWID(),@e1 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),@e3 uniqueidentifier=NEWID(),
  @seq1 bigint,@seq2 bigint,@n bigint,@payload nvarchar(max)=N'{}';

BEGIN TRANSACTION;
EXEC sync.usp_EnqueueEvent @e1,@nodeA,'test',@agg,'test.event',@payload;
EXEC sync.usp_EnqueueEvent @e2,@nodeA,'test',@agg,'test.event',@payload;
COMMIT;
SET @seq1=(SELECT SequenceNo FROM sync.Outbox WHERE EventId=@e1);
SET @seq2=(SELECT SequenceNo FROM sync.Outbox WHERE EventId=@e2);

-- Route e1 to node A.
EXEC sync.usp_RouteEvent @EventId=@e1,@DestinationNodeId=@nodeA;
SET @n=(SELECT COUNT(*) FROM sync.EventDeliveries WHERE EventId=@e1 AND DestinationNodeId=@nodeA AND Status='pending');
EXEC test.AssertEq N'delivery created for node A',1,@n;

-- Routing again does not duplicate.
EXEC sync.usp_RouteEvent @EventId=@e1,@DestinationNodeId=@nodeA;
SET @n=(SELECT COUNT(*) FROM sync.EventDeliveries WHERE EventId=@e1 AND DestinationNodeId=@nodeA);
EXEC test.AssertEq N'no duplicate delivery after re-route',1,@n;

-- Unknown event.
BEGIN TRY
  EXEC sync.usp_RouteEvent @EventId=@e3,@DestinationNodeId=@nodeA;
  THROW 59002,'ASSERT FAIL: routing an unknown event was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51006 THROW; END CATCH;

-- Destination not configured.
BEGIN TRY
  EXEC sync.usp_RouteEvent @EventId=@e1,@DestinationNodeId=@ghost;
  THROW 59002,'ASSERT FAIL: routing to an unknown node was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51007 THROW; END CATCH;

-- Late route: once node A's cursor passed the event sequence, routing is rejected.
EXEC sync.usp_AdvanceCursor @NodeId=@nodeA,@StreamName='outbox',@LastSequence=@seq1;
BEGIN TRY
  EXEC sync.usp_RouteEvent @EventId=@e1,@DestinationNodeId=@nodeA;
  THROW 59002,'ASSERT FAIL: late route after the cursor was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51008 THROW; END CATCH;
-- An event with a higher sequence can still be routed.
EXEC sync.usp_RouteEvent @EventId=@e2,@DestinationNodeId=@nodeA;
SET @n=(SELECT COUNT(*) FROM sync.EventDeliveries WHERE EventId=@e2 AND DestinationNodeId=@nodeA);
EXEC test.AssertEq N'event above the cursor still routable',1,@n;

-- Routing to another node works independently.
EXEC sync.usp_RouteEvent @EventId=@e1,@DestinationNodeId=@nodeB;
SET @n=(SELECT COUNT(*) FROM sync.EventDeliveries WHERE EventId=@e1 AND DestinationNodeId=@nodeB);
EXEC test.AssertEq N'event delivered to node B too',1,@n;
PRINT 'PASS';

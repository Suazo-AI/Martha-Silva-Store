-- TEST: acknowledging marks the delivery once and never twice; the outbox event is acked only when every destination acknowledged; an unknown delivery is rejected.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),
  @nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @agg uniqueidentifier=NEWID(),@e1 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),
  @n bigint,@ack1 datetime2(3),@same bigint,@payload nvarchar(max)=N'{}';

BEGIN TRANSACTION;
EXEC sync.usp_EnqueueEvent @e1,@nodeA,'test',@agg,'test.event',@payload;
EXEC sync.usp_EnqueueEvent @e2,@nodeA,'test',@agg,'test.event',@payload;
COMMIT;
EXEC sync.usp_RouteEvent @EventId=@e1,@DestinationNodeId=@nodeA;
EXEC sync.usp_RouteEvent @EventId=@e1,@DestinationNodeId=@nodeB;
EXEC sync.usp_RouteEvent @EventId=@e2,@DestinationNodeId=@nodeA;

-- Acknowledge one of the two deliveries of e1: the outbox is still pending.
EXEC sync.usp_AcknowledgeDelivery @EventId=@e1,@DestinationNodeId=@nodeA;
SET @n=(SELECT COUNT(*) FROM sync.EventDeliveries WHERE EventId=@e1 AND DestinationNodeId=@nodeA AND Status='acked' AND AcknowledgedAt IS NOT NULL);
EXEC test.AssertEq N'delivery marked acked',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@e1 AND Status='acked');
EXEC test.AssertEq N'outbox still pending with one delivery left',0,@n;

-- A second acknowledgement of the same delivery changes nothing.
SET @ack1=(SELECT AcknowledgedAt FROM sync.EventDeliveries WHERE EventId=@e1 AND DestinationNodeId=@nodeA);
EXEC sync.usp_AcknowledgeDelivery @EventId=@e1,@DestinationNodeId=@nodeA;
SET @same=(SELECT CASE WHEN AcknowledgedAt=@ack1 THEN 1 ELSE 0 END FROM sync.EventDeliveries WHERE EventId=@e1 AND DestinationNodeId=@nodeA);
EXEC test.AssertEq N'repeated ack keeps the first timestamp',1,@same;

-- Acknowledge the remaining deliveries (branch B and the automatic Azure delivery): the outbox event becomes acked.
EXEC sync.usp_AcknowledgeDelivery @EventId=@e1,@DestinationNodeId=@nodeB;
EXEC sync.usp_AcknowledgeDelivery @EventId=@e1,@DestinationNodeId=@nodeCloud;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@e1 AND Status='acked' AND AckedAt IS NOT NULL);
EXEC test.AssertEq N'outbox acked after all deliveries',1,@n;

-- Unknown delivery.
BEGIN TRY
  EXEC sync.usp_AcknowledgeDelivery @EventId=@e2,@DestinationNodeId=@nodeB;
  THROW 59002,'ASSERT FAIL: acknowledgement of an undelivered event was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51011 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM sync.EventDeliveries WHERE EventId=@e2 AND Status='acked');
EXEC test.AssertEq N'no phantom ack after rejection',0,@n;
PRINT 'PASS';

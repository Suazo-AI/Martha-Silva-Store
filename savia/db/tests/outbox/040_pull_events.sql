-- TEST: usp_PullEvents returns only the events routed to the node, after the given sequence, in order and at most the batch size; invalid cursor or batch are rejected.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),@nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @agg uniqueidentifier=NEWID(),@e1 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),@e3 uniqueidentifier=NEWID(),@e4 uniqueidentifier=NEWID(),
  @seq1 bigint,@seq2 bigint,@seq3 bigint,@seq4 bigint,@n bigint,@payload nvarchar(max)=N'{}';
DECLARE @pull TABLE(SequenceNo bigint,EventId uniqueidentifier,OriginNodeId uniqueidentifier,
  AggregateType varchar(50),AggregateId uniqueidentifier,EventType varchar(80),PayloadJson nvarchar(max));

BEGIN TRANSACTION;
EXEC sync.usp_EnqueueEvent @e1,@nodeA,'test',@agg,'test.event',@payload;
EXEC sync.usp_EnqueueEvent @e2,@nodeA,'test',@agg,'test.event',@payload;
EXEC sync.usp_EnqueueEvent @e3,@nodeA,'test',@agg,'test.event',@payload;
COMMIT;
-- e4 is only delivered to the Azure node, never to A.
BEGIN TRANSACTION;
EXEC sync.usp_EnqueueEvent @e4,@nodeA,'test',@agg,'test.event',@payload;
COMMIT;
SET @seq1=(SELECT SequenceNo FROM sync.Outbox WHERE EventId=@e1);
SET @seq2=(SELECT SequenceNo FROM sync.Outbox WHERE EventId=@e2);
SET @seq3=(SELECT SequenceNo FROM sync.Outbox WHERE EventId=@e3);
SET @seq4=(SELECT SequenceNo FROM sync.Outbox WHERE EventId=@e4);

EXEC sync.usp_RouteEvent @EventId=@e1,@DestinationNodeId=@nodeA;
EXEC sync.usp_RouteEvent @EventId=@e2,@DestinationNodeId=@nodeA;
EXEC sync.usp_RouteEvent @EventId=@e3,@DestinationNodeId=@nodeA;
EXEC sync.usp_RouteEvent @EventId=@e4,@DestinationNodeId=@nodeB;

-- Pull for node A: exactly the three routed events, in order.
DELETE FROM @pull;
INSERT INTO @pull EXEC sync.usp_PullEvents @DestinationNodeId=@nodeA,@AfterSequence=0,@BatchSize=200;
SET @n=(SELECT COUNT(*) FROM @pull);
EXEC test.AssertEq N'node A receives its three events',3,@n;
SET @n=(SELECT COUNT(*) FROM @pull WHERE EventId IN (@e1,@e2,@e3));
EXEC test.AssertEq N'node A receives only its events',3,@n;
SET @n=(SELECT COUNT(*) FROM @pull WHERE EventId=@e4);
EXEC test.AssertEq N'node A does not receive B''s event',0,@n;
-- Pull is ordered by sequence: with batch 1 the first pull returns e1, the next returns e2, the next e3.
DELETE FROM @pull;
INSERT INTO @pull EXEC sync.usp_PullEvents @DestinationNodeId=@nodeA,@AfterSequence=0,@BatchSize=1;
SET @n=(SELECT COUNT(*) FROM @pull WHERE EventId=@e1);
EXEC test.AssertEq N'pull with batch 1 returns the first event',1,@n;
DELETE FROM @pull;
INSERT INTO @pull EXEC sync.usp_PullEvents @DestinationNodeId=@nodeA,@AfterSequence=@seq1,@BatchSize=1;
SET @n=(SELECT COUNT(*) FROM @pull WHERE EventId=@e2);
EXEC test.AssertEq N'pull after seq1 returns the second event',1,@n;
DELETE FROM @pull;
INSERT INTO @pull EXEC sync.usp_PullEvents @DestinationNodeId=@nodeA,@AfterSequence=@seq2,@BatchSize=1;
SET @n=(SELECT COUNT(*) FROM @pull WHERE EventId=@e3);
EXEC test.AssertEq N'pull after seq2 returns the third event',1,@n;

-- After the first sequence only the rest arrives.
DELETE FROM @pull;
INSERT INTO @pull EXEC sync.usp_PullEvents @DestinationNodeId=@nodeA,@AfterSequence=@seq1,@BatchSize=200;
SET @n=(SELECT COUNT(*) FROM @pull);
EXEC test.AssertEq N'pull after the first sequence',2,@n;

-- Batch size limits the page.
DELETE FROM @pull;
INSERT INTO @pull EXEC sync.usp_PullEvents @DestinationNodeId=@nodeA,@AfterSequence=0,@BatchSize=2;
SET @n=(SELECT COUNT(*) FROM @pull);
EXEC test.AssertEq N'pull respects the batch size',2,@n;

-- Batch out of range.
BEGIN TRY
  DELETE FROM @pull;
  INSERT INTO @pull EXEC sync.usp_PullEvents @DestinationNodeId=@nodeA,@AfterSequence=0,@BatchSize=0;
  THROW 59002,'ASSERT FAIL: pull with batch 0 was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51009 THROW; END CATCH;
BEGIN TRY
  DELETE FROM @pull;
  INSERT INTO @pull EXEC sync.usp_PullEvents @DestinationNodeId=@nodeA,@AfterSequence=0,@BatchSize=501;
  THROW 59002,'ASSERT FAIL: pull with batch 501 was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51009 THROW; END CATCH;

-- Negative cursor.
BEGIN TRY
  DELETE FROM @pull;
  INSERT INTO @pull EXEC sync.usp_PullEvents @DestinationNodeId=@nodeA,@AfterSequence=-1,@BatchSize=10;
  THROW 59002,'ASSERT FAIL: pull with a negative cursor was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51010 THROW; END CATCH;
PRINT 'PASS';

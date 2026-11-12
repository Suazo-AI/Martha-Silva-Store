-- TEST: an event is enqueued inside the business transaction, delivered to the Azure node by default, retried safely, and the same EventId with different content is rejected; the sequence always grows.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @flag bigint; DECLARE @tmp uniqueidentifier=NEWID();
DECLARE @nodeA uniqueidentifier=test.Id('nodeA'),@nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @agg uniqueidentifier=NEWID(),@agg2 uniqueidentifier=NEWID(),
  @e1 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),@e3 uniqueidentifier=NEWID(),
  @n bigint,@seq1 bigint,@seq2 bigint,@payload nvarchar(max)=N'{"qty":1}';

-- Normal enqueue from a branch node: delivery to the Azure node is created automatically.
BEGIN TRANSACTION;
EXEC sync.usp_EnqueueEvent @e1,@nodeA,'test',@agg,'test.event',@payload;
COMMIT;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@e1 AND OriginNodeId=@nodeA
        AND AggregateType='test' AND AggregateId=@agg AND EventType='test.event' AND Status='pending');
EXEC test.AssertEq N'event stored once',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.EventDeliveries WHERE EventId=@e1 AND DestinationNodeId=@nodeCloud AND Status='pending');
EXEC test.AssertEq N'delivery to Azure created',1,@n;
SET @seq1=(SELECT SequenceNo FROM sync.Outbox WHERE EventId=@e1);
SET @flag=CASE WHEN @seq1>0 THEN 1 ELSE 0 END;
EXEC test.AssertEq N'sequence assigned',1,@flag;

-- Retry with the same ids and content (the reply was lost): nothing changes.
BEGIN TRANSACTION;
EXEC sync.usp_EnqueueEvent @e1,@nodeA,'test',@agg,'test.event',@payload;
COMMIT;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@e1);
EXEC test.AssertEq N'no duplicate event after retry',1,@n;

-- Same EventId with a different payload is rejected.
BEGIN TRY
  BEGIN TRANSACTION;
  EXEC sync.usp_EnqueueEvent @e1,@nodeA,'test',@agg,'test.event',N'{"qty":2}';
  ROLLBACK;
  THROW 59002,'ASSERT FAIL: reused EventId with a different payload was accepted',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()<>51005 THROW;
  IF @@TRANCOUNT>0 ROLLBACK;
END CATCH;

-- Same EventId with a different aggregate is rejected.
BEGIN TRY
  BEGIN TRANSACTION;
  EXEC sync.usp_EnqueueEvent @e1,@nodeA,'test',@agg2,'test.event',@payload;
  ROLLBACK;
  THROW 59002,'ASSERT FAIL: reused EventId with a different aggregate was accepted',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()<>51005 THROW;
  IF @@TRANCOUNT>0 ROLLBACK;
END CATCH;

-- Same EventId with a different event type is rejected.
BEGIN TRY
  BEGIN TRANSACTION;
  EXEC sync.usp_EnqueueEvent @e1,@nodeA,'test',@agg,'test.other',@payload;
  ROLLBACK;
  THROW 59002,'ASSERT FAIL: reused EventId with a different type was accepted',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()<>51005 THROW;
  IF @@TRANCOUNT>0 ROLLBACK;
END CATCH;

-- Sequence always grows: a second event gets a higher number.
BEGIN TRANSACTION;
EXEC sync.usp_EnqueueEvent @e2,@nodeA,'test',@agg,'test.event',@payload;
EXEC sync.usp_EnqueueEvent @e3,@nodeA,'test',@agg,'test.event',@payload;
COMMIT;
SET @seq1=(SELECT SequenceNo FROM sync.Outbox WHERE EventId=@e2);
SET @seq2=(SELECT SequenceNo FROM sync.Outbox WHERE EventId=@e3);
SET @flag=CASE WHEN @seq2>@seq1 THEN 1 ELSE 0 END;
EXEC test.AssertEq N'sequence grows between events',1,@flag;
PRINT 'PASS';

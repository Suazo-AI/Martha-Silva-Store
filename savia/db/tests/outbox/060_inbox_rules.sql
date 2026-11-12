-- TEST: recording an applied inbox entry needs the handler transaction and valid JSON, is idempotent for the same payload and rejects the same EventId with a different payload or origin.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),
  @agg uniqueidentifier=NEWID(),@e1 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),
  @payload nvarchar(max)=N'{"amount":50000}',@n bigint;

-- Outside the handler transaction.
BEGIN TRY
  EXEC sync.usp_RecordAppliedInbox @EventId=@e1,@OriginNodeId=@nodeA,
    @AggregateType='test',@AggregateId=@agg,@PayloadJson=@payload;
  THROW 59002,'ASSERT FAIL: inbox record outside a transaction was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51012 THROW; END CATCH;

-- Invalid JSON.
BEGIN TRY
  BEGIN TRANSACTION;
  EXEC sync.usp_RecordAppliedInbox @EventId=@e1,@OriginNodeId=@nodeA,
    @AggregateType='test',@AggregateId=@agg,@PayloadJson=N'not json';
  ROLLBACK;
  THROW 59002,'ASSERT FAIL: invalid inbox payload was accepted',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()<>51013 THROW;
  IF @@TRANCOUNT>0 ROLLBACK;
END CATCH;

-- Normal record.
BEGIN TRANSACTION;
EXEC sync.usp_RecordAppliedInbox @EventId=@e1,@OriginNodeId=@nodeA,
  @AggregateType='test',@AggregateId=@agg,@PayloadJson=@payload;
COMMIT;
SET @n=(SELECT COUNT(*) FROM sync.Inbox WHERE EventId=@e1 AND OriginNodeId=@nodeA AND Status='applied' AND AppliedAt IS NOT NULL);
EXEC test.AssertEq N'inbox entry applied once',1,@n;

-- Redelivery of the same event with the same payload: idempotent.
BEGIN TRANSACTION;
EXEC sync.usp_RecordAppliedInbox @EventId=@e1,@OriginNodeId=@nodeA,
  @AggregateType='test',@AggregateId=@agg,@PayloadJson=@payload;
COMMIT;
SET @n=(SELECT COUNT(*) FROM sync.Inbox WHERE EventId=@e1);
EXEC test.AssertEq N'no duplicate inbox entry after redelivery',1,@n;

-- Same EventId with a different payload.
BEGIN TRY
  BEGIN TRANSACTION;
  EXEC sync.usp_RecordAppliedInbox @EventId=@e1,@OriginNodeId=@nodeA,
    @AggregateType='test',@AggregateId=@agg,@PayloadJson=N'{"amount":99000}';
  ROLLBACK;
  THROW 59002,'ASSERT FAIL: same event with a different payload was accepted',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()<>51014 THROW;
  IF @@TRANCOUNT>0 ROLLBACK;
END CATCH;

-- Same EventId from a different origin node.
BEGIN TRY
  BEGIN TRANSACTION;
  EXEC sync.usp_RecordAppliedInbox @EventId=@e1,@OriginNodeId=@nodeB,
    @AggregateType='test',@AggregateId=@agg,@PayloadJson=@payload;
  ROLLBACK;
  THROW 59002,'ASSERT FAIL: same event from another origin was accepted',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()<>51014 THROW;
  IF @@TRANCOUNT>0 ROLLBACK;
END CATCH;

SET @n=(SELECT COUNT(*) FROM sync.Inbox);
EXEC test.AssertEq N'only valid inbox entries stored',1,@n;
PRINT 'PASS';

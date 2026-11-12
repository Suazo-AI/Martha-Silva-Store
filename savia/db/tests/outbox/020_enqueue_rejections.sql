-- TEST: enqueueing is rejected with its exact error outside a business transaction, with invalid JSON, an unauthorized origin, a disabled Azure node, and an invalid destination.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),
  @nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @agg uniqueidentifier=NEWID(),@e1 uniqueidentifier=NEWID(),@ghost uniqueidentifier=NEWID(),@n bigint;

-- No transaction: the event would be committed without the business change.
BEGIN TRY
  EXEC sync.usp_EnqueueEvent @e1,@nodeA,'test',@agg,'test.event',N'{}';
  THROW 59002,'ASSERT FAIL: enqueue outside a transaction was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51000 THROW; END CATCH;

-- Invalid JSON payload.
BEGIN TRY
  BEGIN TRANSACTION;
  EXEC sync.usp_EnqueueEvent @e1,@nodeA,'test',@agg,'test.event',N'no json';
  ROLLBACK;
  THROW 59002,'ASSERT FAIL: invalid JSON was accepted',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()<>51001 THROW;
  IF @@TRANCOUNT>0 ROLLBACK;
END CATCH;

-- Origin node not configured.
BEGIN TRY
  BEGIN TRANSACTION;
  EXEC sync.usp_EnqueueEvent @e1,@ghost,'test',@agg,'test.event',N'{}';
  ROLLBACK;
  THROW 59002,'ASSERT FAIL: unknown origin node was accepted',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()<>51002 THROW;
  IF @@TRANCOUNT>0 ROLLBACK;
END CATCH;

-- Disabled Azure node: a branch event cannot skip the cloud.
BEGIN TRY
  BEGIN TRANSACTION;
  UPDATE sync.Nodes SET IsEnabled=0 WHERE Id=@nodeCloud;
  EXEC sync.usp_EnqueueEvent @e1,@nodeA,'test',@agg,'test.event',N'{}';
  ROLLBACK;
  THROW 59002,'ASSERT FAIL: enqueue with a disabled Azure node was accepted',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()<>51003 THROW;
  IF @@TRANCOUNT>0 ROLLBACK;
END CATCH;

-- Invalid destination node.
BEGIN TRY
  BEGIN TRANSACTION;
  EXEC sync.usp_EnqueueEvent @e1,@nodeA,'test',@agg,'test.event',N'{}',@ghost;
  ROLLBACK;
  THROW 59002,'ASSERT FAIL: invalid destination was accepted',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()<>51004 THROW;
  IF @@TRANCOUNT>0 ROLLBACK;
END CATCH;

-- An event from the Azure node with an explicit valid destination is stored with that delivery only.
BEGIN TRANSACTION;
EXEC sync.usp_EnqueueEvent @e1,@nodeCloud,'test',@agg,'test.event',N'{}',@nodeB;
COMMIT;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@e1 AND OriginNodeId=@nodeCloud);
EXEC test.AssertEq N'azure-origin event stored',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.EventDeliveries WHERE EventId=@e1 AND DestinationNodeId=@nodeB);
EXEC test.AssertEq N'azure-origin event delivered to branch B',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.EventDeliveries WHERE EventId=@e1 AND DestinationNodeId<>@nodeB);
EXEC test.AssertEq N'azure-origin event has no other delivery',0,@n;
PRINT 'PASS';

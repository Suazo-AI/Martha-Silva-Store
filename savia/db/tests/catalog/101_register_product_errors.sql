-- TEST: usp_RegisterProduct rejects an empty name (51200) and a reused id with another name (51210) without writing rows.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @p1 uniqueidentifier=NEWID(),@p2 uniqueidentifier=NEWID(),@p3 uniqueidentifier=NEWID(),
  @actor uniqueidentifier=test.Id('manager'),@node uniqueidentifier=test.Id('nodeA'),
  @event uniqueidentifier=NEWID(),@event2 uniqueidentifier=NEWID(),@n bigint;

-- Empty name is rejected before anything is written.
BEGIN TRY
  EXEC catalog.usp_RegisterProduct @ProductId=@p1,@Name=N'   ',@ActorId=@actor,
    @OriginNodeId=@node,@EventId=@event;
  THROW 59002,'ASSERT FAIL: an empty product name was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51200 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM catalog.Products WHERE Id=@p1);
EXEC test.AssertEq N'products created by the rejected empty name',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@event);
EXEC test.AssertEq N'outbox events for the rejected empty name',0,@n;

-- A product id reused with another name is rejected.
EXEC catalog.usp_RegisterProduct @ProductId=@p2,@Name=N'Nombre Original',@ActorId=@actor,
  @OriginNodeId=@node,@EventId=@event2;
BEGIN TRY
  EXEC catalog.usp_RegisterProduct @ProductId=@p2,@Name=N'Otro Nombre',@ActorId=@actor,
    @OriginNodeId=@node,@EventId=@event2;
  THROW 59002,'ASSERT FAIL: a product id was reused with another name',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51210 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM catalog.Products WHERE Id=@p2 AND Name=N'Nombre Original');
EXEC test.AssertEq N'the original product name survived',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@p2);
EXEC test.AssertEq N'outbox events for the reused product id',1,@n;

-- The id of the rejected registration was never used.
SET @n=(SELECT COUNT(*) FROM catalog.Products WHERE Id=@p3);
EXEC test.AssertEq N'products created by the rejected reuse',0,@n;
PRINT 'PASS';

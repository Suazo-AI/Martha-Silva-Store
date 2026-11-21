-- TEST: usp_AllocateToWeb rejects a quantity of zero or less (51104) and an allocation above the store stock (51102) without leaving rows behind.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@item uniqueidentifier=test.Id('item'),
  @actor uniqueidentifier=test.Id('manager'),@node uniqueidentifier=test.Id('nodeA'),
  @allocation1 uniqueidentifier=NEWID(),@allocation2 uniqueidentifier=NEWID(),
  @allocation3 uniqueidentifier=NEWID(),@n bigint;

EXEC test.SeedStock @item,@loc,5;

-- 51104: a quantity of zero.
BEGIN TRY
  EXEC inventory.usp_AllocateToWeb @AllocationId=@allocation1,@ItemId=@item,@LocationId=@loc,@Quantity=0,
    @ActorId=@actor,@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: an allocation of zero units was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51104 THROW; END CATCH;

-- 51104: a negative quantity.
BEGIN TRY
  EXEC inventory.usp_AllocateToWeb @AllocationId=@allocation2,@ItemId=@item,@LocationId=@loc,@Quantity=-1,
    @ActorId=@actor,@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: a negative allocation was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51104 THROW; END CATCH;

-- 51102: more units than the store pool holds.
BEGIN TRY
  EXEC inventory.usp_AllocateToWeb @AllocationId=@allocation3,@ItemId=@item,@LocationId=@loc,@Quantity=99,
    @ActorId=@actor,@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: an allocation above the store stock was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51102 THROW; END CATCH;

-- The rejected allocations left nothing behind.
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE SourceId IN
        (@allocation1,@allocation2,@allocation3));
EXEC test.AssertEq N'movements of the rejected allocations',0,@n;
SET @n=(SELECT COUNT(*) FROM audit.Operations WHERE Id IN (@allocation1,@allocation2,@allocation3));
EXEC test.AssertEq N'operations of the rejected allocations',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId IN (@allocation1,@allocation2,@allocation3));
EXEC test.AssertEq N'events of the rejected allocations',0,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'store stock after the rejections',5,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='web');
EXEC test.AssertEq N'web stock after the rejections',0,@n;
PRINT 'PASS';

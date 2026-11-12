-- TEST: usp_ApplyMovement rejects a repeated operation id with another instruction (51101), a movement that would leave the stock invalid (51102) and a frozen pool (51103) without leaving rows behind.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@item uniqueidentifier=test.Id('item'),
  @actor uniqueidentifier=test.Id('manager'),@operation uniqueidentifier=NEWID(),
  @operation2 uniqueidentifier=NEWID(),@operation3 uniqueidentifier=NEWID(),@operation4 uniqueidentifier=NEWID(),
  @operation5 uniqueidentifier=NEWID(),@operation6 uniqueidentifier=NEWID(),
  @source uniqueidentifier=NEWID(),@movement uniqueidentifier,@n bigint;

EXEC inventory.usp_ApplyMovement @OperationId=@operation,@ItemId=@item,@LocationId=@loc,@Pool='store',
  @Kind='receive',@OnHandDelta=5,@SourceType='test_receive',@SourceId=@source,@ActorId=@actor,
  @MovementId=@movement OUTPUT;

-- 51101: the same operation id with another instruction.
BEGIN TRY
  EXEC inventory.usp_ApplyMovement @OperationId=@operation,@ItemId=@item,@LocationId=@loc,@Pool='store',
    @Kind='receive',@OnHandDelta=7,@SourceType='test_receive',@SourceId=@source,@ActorId=@actor;
  THROW 59002,'ASSERT FAIL: a repeated operation id with another instruction was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51101 THROW; END CATCH;

-- 51102: the movement would leave the stock below zero.
BEGIN TRY
  EXEC inventory.usp_ApplyMovement @OperationId=@operation2,@ItemId=@item,@LocationId=@loc,@Pool='store',
    @Kind='adjust',@OnHandDelta=-99,@SourceType='test_adjust',@SourceId=@source,@ActorId=@actor;
  THROW 59002,'ASSERT FAIL: a movement below zero was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51102 THROW; END CATCH;

-- 51102: a movement without effect.
BEGIN TRY
  EXEC inventory.usp_ApplyMovement @OperationId=@operation3,@ItemId=@item,@LocationId=@loc,@Pool='store',
    @Kind='adjust',@OnHandDelta=0,@ReservedDelta=0,@SourceType='test_adjust',@SourceId=@source,@ActorId=@actor;
  THROW 59002,'ASSERT FAIL: a movement without effect was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51102 THROW; END CATCH;

-- 51102: more reserved than on hand.
BEGIN TRY
  EXEC inventory.usp_ApplyMovement @OperationId=@operation4,@ItemId=@item,@LocationId=@loc,@Pool='store',
    @Kind='adjust',@OnHandDelta=0,@ReservedDelta=99,@SourceType='test_adjust',@SourceId=@source,@ActorId=@actor;
  THROW 59002,'ASSERT FAIL: a reservation above the stock was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51102 THROW; END CATCH;

-- 51103: the pool is frozen.
UPDATE inventory.StockBalances SET Status='frozen'
  WHERE ItemId=@item AND LocationId=@loc AND Pool='store';
BEGIN TRY
  EXEC inventory.usp_ApplyMovement @OperationId=@operation5,@ItemId=@item,@LocationId=@loc,@Pool='store',
    @Kind='adjust',@OnHandDelta=1,@SourceType='test_adjust',@SourceId=@source,@ActorId=@actor;
  THROW 59002,'ASSERT FAIL: a movement into a frozen pool was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51103 THROW; END CATCH;
UPDATE inventory.StockBalances SET Status='active'
  WHERE ItemId=@item AND LocationId=@loc AND Pool='store';

-- A movement into a pool that does not exist yet creates its balance.
EXEC inventory.usp_ApplyMovement @OperationId=@operation6,@ItemId=@item,@LocationId=@loc,@Pool='web',
  @Kind='allocate',@OnHandDelta=2,@SourceType='test_allocate',@SourceId=@source,@ActorId=@actor;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='web');
EXEC test.AssertEq N'web stock created by the movement',2,@n;

-- The rejected movements left nothing behind.
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE OperationId IN
        (@operation2,@operation3,@operation4,@operation5));
EXEC test.AssertEq N'movements of the rejected operations',0,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'store stock after the rejections',5,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockBalances WHERE OnHand<0 OR Reserved<0 OR Reserved>OnHand);
EXEC test.AssertEq N'balances out of the allowed bounds',0,@n;
PRINT 'PASS';

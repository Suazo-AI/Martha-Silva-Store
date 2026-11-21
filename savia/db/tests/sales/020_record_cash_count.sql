-- TEST: a cash count is stored and submitted once, merges repeated denominations, and rejects bad lines, a reused id and a closed till.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @cashier uniqueidentifier=test.Id('cashierA'),@supervisor uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@register uniqueidentifier=test.Id('registerA'),
  @registerB uniqueidentifier=test.Id('registerB'),@cashierB uniqueidentifier=test.Id('cashierB'),
  @nodeB uniqueidentifier=test.Id('nodeB'),
  @till uniqueidentifier=NEWID(),@tillB uniqueidentifier=NEWID(),@count uniqueidentifier=NEWID(),
  @close uniqueidentifier=NEWID(),@n bigint;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,@CurrencyCode='NIO',
     @OpeningMinor=150000,@OriginNodeId=@node;
EXEC sales.usp_OpenTill @TillId=@tillB,@RegisterId=@registerB,@CashierId=@cashierB,@CurrencyCode='NIO',
     @OpeningMinor=0,@OriginNodeId=@nodeB;

DECLARE @json nvarchar(max)=N'[{"denominationMinor":100000,"quantity":1},{"denominationMinor":10000,"quantity":2},{"denominationMinor":10000,"quantity":3}]';
EXEC sales.usp_RecordCashCount @CashCountId=@count,@TillId=@till,@ActorId=@cashier,@LinesJson=@json;
EXEC sales.usp_RecordCashCount @CashCountId=@count,@TillId=@till,@ActorId=@cashier,@LinesJson=@json;
SET @n=(SELECT COUNT(*) FROM sales.CashCounts WHERE Id=@count AND Status='submitted');
EXEC test.AssertEq N'submitted counts',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashCountLines WHERE CashCountId=@count);
EXEC test.AssertEq N'count lines (10000 merged)',2,@n;
SET @n=(SELECT SUM(DenominationMinor*Quantity) FROM sales.CashCountLines WHERE CashCountId=@count);
EXEC test.AssertEq N'counted amount',150000,@n;

BEGIN TRY  -- same count id on another till
  EXEC sales.usp_RecordCashCount @CashCountId=@count,@TillId=@tillB,@ActorId=@cashierB,@LinesJson=@json;
  THROW 59002,'ASSERT FAIL: count id reused on another till was accepted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51542 THROW; END CATCH;

DECLARE @c2 uniqueidentifier=NEWID();
BEGIN TRY  -- not JSON
  EXEC sales.usp_RecordCashCount @CashCountId=@c2,@TillId=@till,@ActorId=@cashier,@LinesJson=N'not json';
  THROW 59002,'ASSERT FAIL: invalid JSON was accepted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51540 THROW; END CATCH;
BEGIN TRY  -- empty list
  EXEC sales.usp_RecordCashCount @CashCountId=@c2,@TillId=@till,@ActorId=@cashier,@LinesJson=N'[]';
  THROW 59002,'ASSERT FAIL: empty count was accepted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51541 THROW; END CATCH;
BEGIN TRY  -- negative quantity
  EXEC sales.usp_RecordCashCount @CashCountId=@c2,@TillId=@till,@ActorId=@cashier,
       @LinesJson=N'[{"denominationMinor":100000,"quantity":-1}]';
  THROW 59002,'ASSERT FAIL: negative quantity was accepted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51541 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM sales.CashCounts WHERE Id=@c2);
EXEC test.AssertEq N'rows left by rejected counts',0,@n;

-- The count closes the till with no difference; then a new count on the closed till is rejected.
EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@till,@CashCountId=@count,@ActorId=@supervisor,@OriginNodeId=@node;
SET @n=(SELECT DifferenceMinor FROM sales.CashClosures WHERE Id=@close);
EXEC test.AssertEq N'difference at close',0,@n;
BEGIN TRY
  EXEC sales.usp_RecordCashCount @CashCountId=@c2,@TillId=@till,@ActorId=@cashier,@LinesJson=@json;
  THROW 59002,'ASSERT FAIL: count on a closed till was accepted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51543 THROW; END CATCH;
PRINT 'PASS';

-- TEST: usp_RecordCashEntry rejects a cash entry posted by staff without access to the branch of the till.
-- FIXED (V007): D-B-02 usp_RecordCashEntry no verificaba que el actor tenga acceso a la sucursal del turno, asi que una cajera de la sucursal B puede sacar efectivo de la caja de la sucursal A.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @cashier uniqueidentifier=test.Id('cashierA'),@cashierB uniqueidentifier=test.Id('cashierB'),
  @node uniqueidentifier=test.Id('nodeA'),@register uniqueidentifier=test.Id('registerA'),
  @till uniqueidentifier=NEWID(),@entry uniqueidentifier=NEWID(),@rejected bit=0,@n bigint;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@node;

BEGIN TRY
  EXEC sales.usp_RecordCashEntry @EntryId=@entry,@TillId=@till,@ActorId=@cashierB,
       @Kind='payout',@DeltaMinor=-50000,@Reason=N'retiro de otra sucursal',@OriginNodeId=@node;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()=51537 SET @rejected=1; ELSE THROW;
END CATCH;
IF @rejected=0
  THROW 59002,'ASSERT FAIL: una cajera de otra sucursal retiro 50000 de esta caja',1;

SET @n=(SELECT DeltaMinor FROM sales.CashEntries WHERE TillId=@till AND Kind='opening');
EXEC test.AssertEq N'el fondo inicial no cambia',100000,@n;
PRINT 'PASS';

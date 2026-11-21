-- TEST: usp_RecordCashEntry rejects reusing an EntryId with a different kind or amount instead of reporting success.
-- FIXED (V007): D-B-05 usp_RecordCashEntry aceptaba el mismo EntryId con otro tipo e importe y responde exito, asi que un deposito de 90000 que nunca se registro queda como cobrado.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@till uniqueidentifier=NEWID(),
  @entry uniqueidentifier=NEWID(),@rejected bit=0,@n bigint;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@node;

EXEC sales.usp_RecordCashEntry @EntryId=@entry,@TillId=@till,@ActorId=@cashier,
     @Kind='payout',@DeltaMinor=-50000,@Reason=N'pago a proveedor',@OriginNodeId=@node;

-- El mismo comprobante con otro tipo e importe es otra instruccion de dinero: debe rechazarse.
BEGIN TRY
  EXEC sales.usp_RecordCashEntry @EntryId=@entry,@TillId=@till,@ActorId=@cashier,
       @Kind='deposit',@DeltaMinor=90000,@Reason=N'fondo extra',@OriginNodeId=@node;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()=51536 SET @rejected=1; ELSE THROW;
END CATCH;
IF @rejected=0
  THROW 59002,'ASSERT FAIL: el mismo EntryId se acepto como deposito de 90000',1;

-- Con el producto corregido o no, el movimiento sigue siendo uno y el mismo.
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE Id=@entry);
EXEC test.AssertEq N'un solo movimiento con ese Id',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE Id=@entry AND Kind='payout' AND DeltaMinor=-50000
        AND Reason=N'pago a proveedor');
EXEC test.AssertEq N'el movimiento original no cambio',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE TillId=@till AND Kind='deposit');
EXEC test.AssertEq N'ningun deposito guardado',0,@n;
SET @n=(SELECT COALESCE(SUM(DeltaMinor),0) FROM sales.CashEntries WHERE TillId=@till);
EXEC test.AssertEq N'efectivo esperado del turno',50000,@n;
PRINT 'PASS';

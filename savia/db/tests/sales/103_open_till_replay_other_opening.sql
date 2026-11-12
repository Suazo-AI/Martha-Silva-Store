-- TEST: usp_OpenTill rejects reusing a TillId with a different opening amount instead of reporting success.
-- FIXED (V007): D-B-01 usp_OpenTill aceptaba el mismo TillId con otro fondo inicial y responde exito, asi que el POS cree un fondo de 200000 mientras la caja registro 100000.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@till uniqueidentifier=NEWID(),@rejected bit=0,@n bigint;

EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@node;

-- El fondo inicial es el dato de dinero del turno: reutilizar el id con otro importe debe rechazarse.
BEGIN TRY
  EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
       @CurrencyCode='NIO',@OpeningMinor=200000,@OriginNodeId=@node;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()=51502 SET @rejected=1; ELSE THROW;
END CATCH;
IF @rejected=0
  THROW 59002,'ASSERT FAIL: se acepto el mismo TillId con fondo 200000 y solo quedo el fondo original',1;

-- Si el producto se corrige, el fondo sigue siendo uno y vale 100000.
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE TillId=@till);
EXEC test.AssertEq N'un solo fondo de caja',1,@n;
SET @n=(SELECT COALESCE(SUM(DeltaMinor),0) FROM sales.CashEntries WHERE TillId=@till);
EXEC test.AssertEq N'fondo de caja guardado',100000,@n;
PRINT 'PASS';

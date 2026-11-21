-- TEST: solo puede haber un turno abierto por caja registradora: el segundo turno choca con UX_OpenTill_Register y no deja rastro.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@till1 uniqueidentifier=NEWID(),@till2 uniqueidentifier=NEWID(),
  @n bigint;

EXEC sales.usp_OpenTill @TillId=@till1,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@node;

-- El indice unico filtrado es la ultima defensa: error 2601.
BEGIN TRY
  EXEC sales.usp_OpenTill @TillId=@till2,@RegisterId=@register,@CashierId=@cashier,
       @CurrencyCode='NIO',@OpeningMinor=50000,@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: se abrieron dos turnos en la misma caja registradora',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>2601 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM sales.CashTills WHERE Id=@till2);
EXEC test.AssertEq N'el segundo turno no existe',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE TillId=@till2);
EXEC test.AssertEq N'el segundo turno no dejo fondo de caja',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@till2);
EXEC test.AssertEq N'el segundo turno no dejo evento',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashTills WHERE RegisterId=@register AND Status='open');
EXEC test.AssertEq N'turnos abiertos en la caja registradora',1,@n;
SET @n=(SELECT COALESCE(SUM(DeltaMinor),0) FROM sales.CashEntries WHERE TillId=@till1);
EXEC test.AssertEq N'el fondo del primer turno no cambio',100000,@n;
PRINT 'PASS';

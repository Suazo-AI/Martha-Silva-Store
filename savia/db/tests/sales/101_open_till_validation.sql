-- TEST: usp_OpenTill rejects a negative opening, an unknown register, a cashier from another branch and a reused TillId with other data.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @cashier uniqueidentifier=test.Id('cashierA'),@cashierB uniqueidentifier=test.Id('cashierB'),
  @super uniqueidentifier=test.Id('supervisorA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@ghost uniqueidentifier=NEWID(),
  @till uniqueidentifier=NEWID(),@n bigint;

-- 51501 fondo negativo
BEGIN TRY
  EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
       @CurrencyCode='NIO',@OpeningMinor=-1,@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: se acepto un fondo inicial negativo',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51501 THROW; END CATCH;

-- 51503 caja registradora inexistente
BEGIN TRY
  EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@ghost,@CashierId=@cashier,
       @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: se acepto una caja registradora inexistente',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51503 THROW; END CATCH;

-- 51504 cajera de la sucursal B en la caja de la sucursal A
BEGIN TRY
  EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashierB,
       @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: se acepto una cajera sin acceso a la sucursal',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51504 THROW; END CATCH;

-- Nada de lo rechazado quedo guardado.
SET @n=(SELECT COUNT(*) FROM sales.CashTills WHERE Id=@till);
EXEC test.AssertEq N'turnos guardados de las peticiones rechazadas',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE TillId=@till);
EXEC test.AssertEq N'movimientos de caja de las peticiones rechazadas',0,@n;

-- 51502 TillId reutilizado con otra cajera o con otra moneda
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;
BEGIN TRY
  EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@super,
       @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: se reutilizo TillId con otra cajera',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51502 THROW; END CATCH;
BEGIN TRY
  EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
       @CurrencyCode='USD',@OpeningMinor=0,@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: se reutilizo TillId con otra moneda',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51502 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM sales.CashTills WHERE Id=@till AND CashierId=@cashier AND CurrencyCode='NIO');
EXEC test.AssertEq N'el turno original no cambio',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE TillId=@till);
EXEC test.AssertEq N'un solo fondo de caja',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashTills WHERE CashierId=@super);
EXEC test.AssertEq N'turnos de la supervisora',0,@n;
PRINT 'PASS';

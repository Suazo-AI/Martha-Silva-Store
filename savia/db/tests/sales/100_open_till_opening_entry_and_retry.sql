-- TEST: usp_OpenTill abre un turno con un solo fondo de caja y un evento; repetir la misma peticion no cambia nada.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@till uniqueidentifier=NEWID(),@n bigint;

EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=150000,@OriginNodeId=@node;

SET @n=(SELECT COUNT(*) FROM sales.CashTills WHERE Id=@till AND RegisterId=@register
        AND CashierId=@cashier AND CurrencyCode='NIO' AND Status='open' AND ClosedAt IS NULL);
EXEC test.AssertEq N'turno abierto',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE TillId=@till AND Kind='opening'
        AND DeltaMinor=150000 AND CurrencyCode='NIO');
EXEC test.AssertEq N'un fondo de caja de 150000',1,@n;
SET @n=(SELECT COALESCE(SUM(DeltaMinor),0) FROM sales.CashEntries WHERE TillId=@till);
EXEC test.AssertEq N'efectivo esperado tras abrir',150000,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@till AND EventType='cash.till_opened'
        AND OriginNodeId=@node AND AggregateType='cash_till');
EXEC test.AssertEq N'evento cash.till_opened',1,@n;

-- Reintento identico (el POS no recibio la respuesta).
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=150000,@OriginNodeId=@node;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE TillId=@till);
EXEC test.AssertEq N'movimientos de caja tras reintento',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@till);
EXEC test.AssertEq N'eventos tras reintento',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashTills WHERE RegisterId=@register);
EXEC test.AssertEq N'turnos en la caja registradora',1,@n;
PRINT 'PASS';

-- TEST: usp_RecordCashEntry registra entradas y salidas manuales con motivo, copia la moneda del turno y no duplica al reintentar.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@till uniqueidentifier=NEWID(),
  @deposit uniqueidentifier=NEWID(),@payout uniqueidentifier=NEWID(),@n bigint;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@node;

EXEC sales.usp_RecordCashEntry @EntryId=@deposit,@TillId=@till,@ActorId=@cashier,
     @Kind='deposit',@DeltaMinor=30000,@Reason=N'cambio de billetes',@OriginNodeId=@node;
EXEC sales.usp_RecordCashEntry @EntryId=@payout,@TillId=@till,@ActorId=@cashier,
     @Kind='payout',@DeltaMinor=-20000,@Reason=N'compra de bolsas',@OriginNodeId=@node;

SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE TillId=@till);
EXEC test.AssertEq N'movimientos de caja',3,@n;
SET @n=(SELECT DeltaMinor FROM sales.CashEntries WHERE Id=@deposit);
EXEC test.AssertEq N'importe del deposito',30000,@n;
SET @n=(SELECT DeltaMinor FROM sales.CashEntries WHERE Id=@payout);
EXEC test.AssertEq N'importe del retiro',-20000,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE Id IN (@deposit,@payout)
        AND CurrencyCode='NIO' AND Reason IS NOT NULL AND ActorId=@cashier);
EXEC test.AssertEq N'moneda, motivo y actor copiados',2,@n;
SET @n=(SELECT COALESCE(SUM(DeltaMinor),0) FROM sales.CashEntries WHERE TillId=@till);
EXEC test.AssertEq N'efectivo esperado 100000+30000-20000',110000,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventType='cash.manual_entry' AND AggregateId IN (@deposit,@payout));
EXEC test.AssertEq N'eventos de movimiento manual',2,@n;

-- Reintento identico del deposito.
EXEC sales.usp_RecordCashEntry @EntryId=@deposit,@TillId=@till,@ActorId=@cashier,
     @Kind='deposit',@DeltaMinor=30000,@Reason=N'cambio de billetes',@OriginNodeId=@node;
SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE TillId=@till);
EXEC test.AssertEq N'movimientos tras el reintento',3,@n;
SET @n=(SELECT COALESCE(SUM(DeltaMinor),0) FROM sales.CashEntries WHERE TillId=@till);
EXEC test.AssertEq N'efectivo esperado tras el reintento',110000,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@deposit);
EXEC test.AssertEq N'eventos del deposito',1,@n;
PRINT 'PASS';

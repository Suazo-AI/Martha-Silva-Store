-- TEST: usp_RecordCashEntry rejects a kind other than payout/deposit/adjustment, a missing reason (51505) and a closed or unknown till (51506).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@till uniqueidentifier=NEWID(),
  @closedTill uniqueidentifier=NEWID(),@ghost uniqueidentifier=NEWID(),@entry uniqueidentifier=NEWID(),
  @n bigint;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@node;
DECLARE @closedAt datetime2(3)=SYSUTCDATETIME();
INSERT INTO sales.CashTills(Id,RegisterId,CashierId,CurrencyCode,Status,OpenedAt,ClosedAt)
  VALUES(@closedTill,@register,@cashier,'NIO','closed',@closedAt,@closedAt);

-- 51505 tipo de operacion no manual
BEGIN TRY
  EXEC sales.usp_RecordCashEntry @EntryId=@entry,@TillId=@till,@ActorId=@cashier,
       @Kind='sale',@DeltaMinor=1000,@Reason=N'venta disfrazada',@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: se acepto un movimiento manual de tipo sale',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51505 THROW; END CATCH;

-- 51505 sin motivo
BEGIN TRY
  EXEC sales.usp_RecordCashEntry @EntryId=@entry,@TillId=@till,@ActorId=@cashier,
       @Kind='payout',@DeltaMinor=-1000,@Reason=N'  ',@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: se acepto un movimiento manual sin motivo',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51505 THROW; END CATCH;

-- 51506 turno cerrado
BEGIN TRY
  EXEC sales.usp_RecordCashEntry @EntryId=@entry,@TillId=@closedTill,@ActorId=@cashier,
       @Kind='payout',@DeltaMinor=-1000,@Reason=N'turno cerrado',@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: se acepto un movimiento en un turno cerrado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51506 THROW; END CATCH;

-- 51506 turno inexistente
BEGIN TRY
  EXEC sales.usp_RecordCashEntry @EntryId=@entry,@TillId=@ghost,@ActorId=@cashier,
       @Kind='deposit',@DeltaMinor=1000,@Reason=N'turno inexistente',@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: se acepto un movimiento en un turno inexistente',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51506 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM sales.CashEntries WHERE Id=@entry);
EXEC test.AssertEq N'movimientos guardados de las peticiones rechazadas',0,@n;
SET @n=(SELECT COALESCE(SUM(DeltaMinor),0) FROM sales.CashEntries WHERE TillId=@till);
EXEC test.AssertEq N'efectivo esperado sin cambios',100000,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@entry);
EXEC test.AssertEq N'eventos de las peticiones rechazadas',0,@n;
PRINT 'PASS';

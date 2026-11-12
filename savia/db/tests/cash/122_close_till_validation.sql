-- TEST: usp_CloseTill rejects an unknown or closed till (51522), a count that is not submitted or belongs to another till (51523) and a negative expected cash (51524).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @cashier uniqueidentifier=test.Id('cashierA'),@cashierB uniqueidentifier=test.Id('cashierB'),
  @super uniqueidentifier=test.Id('supervisorA'),@node uniqueidentifier=test.Id('nodeA'),
  @nodeB uniqueidentifier=test.Id('nodeB'),@register uniqueidentifier=test.Id('registerA'),
  @registerB uniqueidentifier=test.Id('registerB'),@till uniqueidentifier=NEWID(),
  @tillB uniqueidentifier=NEWID(),@closedTill uniqueidentifier=NEWID(),@ghostTill uniqueidentifier=NEWID(),
  @ghostCount uniqueidentifier=NEWID(),@draftCount uniqueidentifier=NEWID(),
  @countB uniqueidentifier=NEWID(),@countA uniqueidentifier=NEWID(),@payout uniqueidentifier=NEWID(),
  @close uniqueidentifier=NEWID(),@n bigint;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;
EXEC sales.usp_OpenTill @TillId=@tillB,@RegisterId=@registerB,@CashierId=@cashierB,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@nodeB;
INSERT INTO sales.CashTills(Id,RegisterId,CashierId,CurrencyCode,Status,ClosedAt)
  VALUES(@closedTill,@register,@cashier,'NIO','closed',SYSUTCDATETIME());
-- Arqueo presentado del turno B, para probar que no sirve para el turno A.
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@countB,@tillB,@cashierB,'draft',@cashierB);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity) VALUES(@countB,10000,1);
EXEC sales.usp_SubmitCashCount @CashCountId=@countB,@ActorId=@cashierB;

-- 51522 turno inexistente
BEGIN TRY
  EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@ghostTill,@CashCountId=@ghostCount,@ActorId=@super,@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: se cerro un turno inexistente',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51522 THROW; END CATCH;

-- 51522 turno ya cerrado sin comprobante de cierre
BEGIN TRY
  EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@closedTill,@CashCountId=@ghostCount,@ActorId=@super,@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: se cerro un turno ya cerrado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51522 THROW; END CATCH;

-- 51523 arqueo en borrador
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@draftCount,@till,@cashier,'draft',@cashier);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity) VALUES(@draftCount,10000,1);
BEGIN TRY
  EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@till,@CashCountId=@draftCount,@ActorId=@super,@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: se cerro con un arqueo sin presentar',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51523 THROW; END CATCH;

-- 51523 arqueo de otro turno
BEGIN TRY
  EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@till,@CashCountId=@countB,@ActorId=@super,@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: se cerro con el arqueo de otro turno',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51523 THROW; END CATCH;

-- 51524 el esperado queda negativo con un retiro mayor que el fondo
EXEC sales.usp_RecordCashEntry @EntryId=@payout,@TillId=@till,@ActorId=@cashier,
     @Kind='payout',@DeltaMinor=-1000,@Reason=N'retiro sin fondo',@OriginNodeId=@node;
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@countA,@till,@cashier,'draft',@cashier);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity) VALUES(@countA,10000,1);
EXEC sales.usp_SubmitCashCount @CashCountId=@countA,@ActorId=@cashier;
BEGIN TRY
  EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@till,@CashCountId=@countA,@ActorId=@super,@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: se cerro un turno con efectivo esperado negativo',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51524 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM sales.CashClosures);
EXEC test.AssertEq N'cierres guardados',0,@n;
SET @n=(SELECT COUNT(*) FROM accounting.CloseDocuments);
EXEC test.AssertEq N'documentos contables',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashTills WHERE Id IN (@till,@tillB) AND Status='open');
EXEC test.AssertEq N'turnos que siguen abiertos',2,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventType='cash.till_closed');
EXEC test.AssertEq N'eventos de cierre',0,@n;
PRINT 'PASS';

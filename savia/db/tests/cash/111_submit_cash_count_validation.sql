-- TEST: usp_SubmitCashCount rejects an unknown or already submitted count (51518), a count without denominations (51519), a closed till (51520) and a second submitted count (2601).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@till uniqueidentifier=NEWID(),
  @closedTill uniqueidentifier=NEWID(),@ghost uniqueidentifier=NEWID(),
  @c1 uniqueidentifier=NEWID(),@c2 uniqueidentifier=NEWID(),@c3 uniqueidentifier=NEWID(),
  @c4 uniqueidentifier=NEWID(),@n bigint;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=20000,@OriginNodeId=@node;
INSERT INTO sales.CashTills(Id,RegisterId,CashierId,CurrencyCode,Status,ClosedAt)
  VALUES(@closedTill,@register,@cashier,'NIO','closed',SYSUTCDATETIME());

-- 51518 arqueo inexistente
BEGIN TRY
  EXEC sales.usp_SubmitCashCount @CashCountId=@ghost,@ActorId=@cashier;
  THROW 59002,'ASSERT FAIL: se presento un arqueo inexistente',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51518 THROW; END CATCH;

-- 51519 arqueo sin denominaciones
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@c1,@till,@cashier,'draft',@cashier);
BEGIN TRY
  EXEC sales.usp_SubmitCashCount @CashCountId=@c1,@ActorId=@cashier;
  THROW 59002,'ASSERT FAIL: se presento un arqueo sin denominaciones',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51519 THROW; END CATCH;

-- 51520 turno cerrado
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@c2,@closedTill,@cashier,'draft',@cashier);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity) VALUES(@c2,10000,2);
BEGIN TRY
  EXEC sales.usp_SubmitCashCount @CashCountId=@c2,@ActorId=@cashier;
  THROW 59002,'ASSERT FAIL: se presento un arqueo de un turno cerrado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51520 THROW; END CATCH;

-- Un arqueo valido si se presenta.
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@c3,@till,@cashier,'draft',@cashier);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity) VALUES(@c3,10000,2);
EXEC sales.usp_SubmitCashCount @CashCountId=@c3,@ActorId=@cashier;

-- 2601 un turno no puede tener dos arqueos presentados (UX_CashCounts_TillSubmitted).
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@c4,@till,@cashier,'draft',@cashier);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity) VALUES(@c4,10000,2);
BEGIN TRY
  EXEC sales.usp_SubmitCashCount @CashCountId=@c4,@ActorId=@cashier;
  THROW 59002,'ASSERT FAIL: se presentaron dos arqueos para el mismo turno',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>2601 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM sales.CashCounts WHERE TillId=@till AND Status='submitted');
EXEC test.AssertEq N'arqueos presentados del turno',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashCounts WHERE Id IN (@c1,@c2,@c4) AND Status='draft');
EXEC test.AssertEq N'arqueos que siguen en borrador',3,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashCounts WHERE Id=@ghost);
EXEC test.AssertEq N'arqueos inexistentes guardados',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashCountLines WHERE CashCountId=@c2);
EXEC test.AssertEq N'las denominaciones rechazadas no se pierden',1,@n;
PRINT 'PASS';

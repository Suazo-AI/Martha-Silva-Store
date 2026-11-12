-- TEST: usp_SubmitCashCount marca el arqueo como presentado una sola vez; el reintento con los mismos ids falla con 51518 y no cambia nada.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@till uniqueidentifier=NEWID(),
  @count uniqueidentifier=NEWID(),@stamp datetime2(3),@n bigint;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=20000,@OriginNodeId=@node;
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@count,@till,@cashier,'draft',@cashier);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity) VALUES(@count,10000,2);

EXEC sales.usp_SubmitCashCount @CashCountId=@count,@ActorId=@cashier;
SET @n=(SELECT COUNT(*) FROM sales.CashCounts WHERE Id=@count AND Status='submitted' AND SubmittedAt IS NOT NULL);
EXEC test.AssertEq N'arqueo presentado con fecha',1,@n;
SET @stamp=(SELECT SubmittedAt FROM sales.CashCounts WHERE Id=@count);
SET @n=(SELECT COALESCE(SUM(CONVERT(bigint,DenominationMinor)*Quantity),0) FROM sales.CashCountLines WHERE CashCountId=@count);
EXEC test.AssertEq N'efectivo contado 2x10000',20000,@n;

-- Reintento: un arqueo presentado no se vuelve a presentar y la fecha no cambia.
BEGIN TRY
  EXEC sales.usp_SubmitCashCount @CashCountId=@count,@ActorId=@cashier;
  THROW 59002,'ASSERT FAIL: se presento dos veces el mismo arqueo',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51518 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM sales.CashCounts WHERE Id=@count AND Status='submitted' AND SubmittedAt=@stamp);
EXEC test.AssertEq N'el arqueo sigue presentado en la misma fecha',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashCounts WHERE TillId=@till);
EXEC test.AssertEq N'arqueos del turno',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashCountLines WHERE CashCountId=@count);
EXEC test.AssertEq N'denominaciones del arqueo',1,@n;
PRINT 'PASS';

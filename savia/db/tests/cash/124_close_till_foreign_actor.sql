-- TEST: usp_CloseTill rejects a closer without access to the branch of the till.
-- FIXED (V007): D-B-04 usp_CloseTill no verificaba al actor, asi que una cajera de la sucursal C puede cerrar y firmar la caja de la sucursal A.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @cashier uniqueidentifier=test.Id('cashierA'),@cashierC uniqueidentifier=test.Id('cashierC'),
  @node uniqueidentifier=test.Id('nodeA'),@register uniqueidentifier=test.Id('registerA'),
  @till uniqueidentifier=NEWID(),@count uniqueidentifier=NEWID(),@close uniqueidentifier=NEWID(),
  @rejected bit=0,@n bigint;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=50000,@OriginNodeId=@node;
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@count,@till,@cashier,'draft',@cashier);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity) VALUES(@count,50000,1);
EXEC sales.usp_SubmitCashCount @CashCountId=@count,@ActorId=@cashier;

BEGIN TRY
  EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@till,@CashCountId=@count,@ActorId=@cashierC,@OriginNodeId=@node;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()=51537 SET @rejected=1; ELSE THROW;
END CATCH;
IF @rejected=0
  THROW 59002,'ASSERT FAIL: una cajera de la sucursal C cerro la caja de la sucursal A',1;

-- The rejected close leaves no closure, no accounting document and an open till.
SET @n=(SELECT COUNT(*) FROM sales.CashClosures WHERE TillId=@till);
EXEC test.AssertEq N'cierres del turno',0,@n;
SET @n=(SELECT COUNT(*) FROM accounting.CloseDocuments d JOIN sales.CashClosures c ON c.Id=d.ClosureId
        WHERE c.TillId=@till);
EXEC test.AssertEq N'documentos contables del turno',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashTills WHERE Id=@till AND Status='open');
EXEC test.AssertEq N'el turno sigue abierto',1,@n;
PRINT 'PASS';

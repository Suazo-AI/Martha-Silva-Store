-- TEST: cerrar dos veces con los mismos ids no cambia nada y un ClosureId distinto para un turno ya cerrado se rechaza con 51521.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @cashier uniqueidentifier=test.Id('cashierA'),@super uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@register uniqueidentifier=test.Id('registerA'),
  @till uniqueidentifier=NEWID(),@count uniqueidentifier=NEWID(),@close uniqueidentifier=NEWID(),
  @other uniqueidentifier=NEWID(),@n bigint;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=50000,@OriginNodeId=@node;
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@count,@till,@cashier,'draft',@cashier);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity) VALUES(@count,50000,1);
EXEC sales.usp_SubmitCashCount @CashCountId=@count,@ActorId=@cashier;
EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@till,@CashCountId=@count,@ActorId=@super,@OriginNodeId=@node;

-- Reintento identico del cierre.
EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@till,@CashCountId=@count,@ActorId=@super,@OriginNodeId=@node;
SET @n=(SELECT COUNT(*) FROM sales.CashClosures WHERE TillId=@till);
EXEC test.AssertEq N'cierres del turno',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashClosures WHERE Id=@close AND ExpectedMinor=50000
        AND CountedMinor=50000 AND DifferenceMinor=0);
EXEC test.AssertEq N'el cierre original no cambio',1,@n;
SET @n=(SELECT COUNT(*) FROM accounting.CloseDocuments WHERE ClosureId=@close);
EXEC test.AssertEq N'documentos contables',1,@n;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs e JOIN accounting.CloseDocuments d ON d.Id=e.CloseDocumentId
        WHERE d.ClosureId=@close);
EXEC test.AssertEq N'trabajos de exportacion',1,@n;
SET @n=(SELECT COUNT(*) FROM accounting.CloseDocumentLines WHERE CloseDocumentId=
        (SELECT Id FROM accounting.CloseDocuments WHERE ClosureId=@close));
EXEC test.AssertEq N'lineas del documento contable',12,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@close AND EventType='cash.till_closed');
EXEC test.AssertEq N'eventos de cierre',1,@n;

-- Otro comprobante para el mismo turno.
BEGIN TRY
  EXEC sales.usp_CloseTill @ClosureId=@other,@TillId=@till,@CashCountId=@count,@ActorId=@super,@OriginNodeId=@node;
  THROW 59002,'ASSERT FAIL: se cerro el turno con otro comprobante',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51521 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM sales.CashClosures WHERE Id=@other);
EXEC test.AssertEq N'el segundo cierre no existe',0,@n;
SET @n=(SELECT COUNT(*) FROM accounting.CloseDocuments WHERE ClosureId=@other);
EXEC test.AssertEq N'el segundo documento no existe',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashClosures);
EXEC test.AssertEq N'cierres guardados',1,@n;
SET @n=(SELECT COUNT(*) FROM accounting.CloseDocumentLines l JOIN accounting.CloseDocuments d ON d.Id=l.CloseDocumentId
        WHERE d.ClosureId=@close AND l.ConceptCode='CASH_ROUNDING' AND l.AmountMinor=0);
EXEC test.AssertEq N'redondeo NIO sin pagos USD',1,@n;
PRINT 'PASS';

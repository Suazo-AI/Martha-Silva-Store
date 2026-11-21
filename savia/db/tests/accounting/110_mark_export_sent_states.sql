-- TEST: usp_MarkExportSent lleva un trabajo pendiente a ready con @Delivered=0 y a sent con @Delivered=1, sella la bitacora y no permite volver de sent a ready.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@super uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@register uniqueidentifier=test.Id('registerA'),
  @till uniqueidentifier=NEWID(),@count uniqueidentifier=NEWID(),@close uniqueidentifier=NEWID(),
  @doc uniqueidentifier,@job uniqueidentifier=NEWID(),@n bigint,@sentAt datetime2(3);
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=20000,@OriginNodeId=@node;
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@count,@till,@cashier,'draft',@cashier);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity) VALUES(@count,10000,2);
EXEC sales.usp_SubmitCashCount @CashCountId=@count,@ActorId=@cashier;
EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@till,@CashCountId=@count,@ActorId=@super,@OriginNodeId=@node;
SET @doc=(SELECT Id FROM accounting.CloseDocuments WHERE ClosureId=@close);
EXEC accounting.usp_QueueExport @ExportId=@job,@CloseDocumentId=@doc,@RecipientCode=N'T-AUDITOR',
     @Format='CSV',@ActorId=@cashier;

-- Archivo generado pero todavia sin entregar: ready, con blob y sin SentAt.
EXEC accounting.usp_MarkExportSent @ExportId=@job,@BlobKey=N'exports/2026/cierre.csv',@Delivered=0;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE Id=@job AND Status='ready'
        AND BlobKey=N'exports/2026/cierre.csv' AND SentAt IS NULL AND ModifiedAt IS NOT NULL);
EXEC test.AssertEq N'trabajo en ready con blob y sin hora de envio',1,@n;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE Id=@job AND Status='ready' AND CreatedBy=@cashier);
EXEC test.AssertEq N'el creador no cambia al marcar',1,@n;

-- Repetir el marcado de ready no duplica ni retrocede el estado.
EXEC accounting.usp_MarkExportSent @ExportId=@job,@BlobKey=N'exports/2026/cierre.csv',@Delivered=0;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE Id=@job AND Status='ready'
        AND BlobKey=N'exports/2026/cierre.csv' AND SentAt IS NULL);
EXEC test.AssertEq N'ready repetido sin cambios',1,@n;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE CloseDocumentId=@doc);
EXEC test.AssertEq N'sin trabajos duplicados',2,@n;

-- Entrega confirmada: sent con hora de envio.
EXEC accounting.usp_MarkExportSent @ExportId=@job,@BlobKey=N'exports/2026/cierre.csv',@Delivered=1;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE Id=@job AND Status='sent'
        AND BlobKey=N'exports/2026/cierre.csv' AND SentAt IS NOT NULL);
EXEC test.AssertEq N'trabajo enviado con hora',1,@n;
SET @sentAt=(SELECT SentAt FROM accounting.ExportJobs WHERE Id=@job);

-- Volver a ready desde sent no esta permitido.
BEGIN TRY
  EXEC accounting.usp_MarkExportSent @ExportId=@job,@BlobKey=N'exports/2026/otro.csv',@Delivered=0;
  THROW 59002,'ASSERT FAIL: un trabajo enviado volvio a ready',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51802 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE Id=@job AND Status='sent'
        AND BlobKey=N'exports/2026/cierre.csv' AND SentAt=@sentAt);
EXEC test.AssertEq N'el trabajo enviado quedo intacto',1,@n;
-- Marcar la exportacion no aprueba ni exporta el documento contable por si solo.
SET @n=(SELECT COUNT(*) FROM accounting.CloseDocuments WHERE Id=@doc AND Status='prepared');
EXEC test.AssertEq N'el documento sigue en prepared',1,@n;
PRINT 'PASS';

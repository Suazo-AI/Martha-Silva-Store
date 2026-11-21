-- TEST: usp_MarkExportSent solo acepta trabajos en pending, generating o ready (y sent para reenvio); un Id inexistente o un trabajo confirmed/failed devuelve 51802 y no cambia nada.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@super uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@register uniqueidentifier=test.Id('registerA'),
  @till uniqueidentifier=NEWID(),@count uniqueidentifier=NEWID(),@close uniqueidentifier=NEWID(),
  @doc uniqueidentifier,@ghost uniqueidentifier=NEWID(),@gen uniqueidentifier=NEWID(),
  @conf uniqueidentifier=NEWID(),@fail uniqueidentifier=NEWID(),@n bigint;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=20000,@OriginNodeId=@node;
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@count,@till,@cashier,'draft',@cashier);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity) VALUES(@count,10000,2);
EXEC sales.usp_SubmitCashCount @CashCountId=@count,@ActorId=@cashier;
EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@till,@CashCountId=@count,@ActorId=@super,@OriginNodeId=@node;
SET @doc=(SELECT Id FROM accounting.CloseDocuments WHERE ClosureId=@close);

-- Id que no existe.
BEGIN TRY
  EXEC accounting.usp_MarkExportSent @ExportId=@ghost,@BlobKey=N'x.csv',@Delivered=1;
  THROW 59002,'ASSERT FAIL: exportacion inexistente aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51802 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE Id=@ghost);
EXEC test.AssertEq N'no se creo el trabajo inexistente',0,@n;

INSERT INTO accounting.ExportJobs(Id,CloseDocumentId,RecipientCode,Format,BlobKey,Status,CreatedBy)
  VALUES(@gen,@doc,N'BANK','XML',N'gen.xml','generating',@cashier),
        (@conf,@doc,N'LEGAL','XML',N'conf.xml','confirmed',@cashier),
        (@fail,@doc,N'T-AUDITOR','JSON',NULL,'failed',@cashier);

-- generating avanza a ready y despues a sent.
EXEC accounting.usp_MarkExportSent @ExportId=@gen,@BlobKey=N'gen.xml',@Delivered=0;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE Id=@gen AND Status='ready' AND BlobKey=N'gen.xml');
EXEC test.AssertEq N'generating pasa a ready',1,@n;
EXEC accounting.usp_MarkExportSent @ExportId=@gen,@BlobKey=N'gen.xml',@Delivered=1;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE Id=@gen AND Status='sent' AND SentAt IS NOT NULL);
EXEC test.AssertEq N'generating termina en sent',1,@n;

-- confirmed y failed quedan fuera del flujo, en ambos sentidos.
BEGIN TRY
  EXEC accounting.usp_MarkExportSent @ExportId=@conf,@BlobKey=N'otro.xml',@Delivered=1;
  THROW 59002,'ASSERT FAIL: exportacion confirmada aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51802 THROW; END CATCH;
BEGIN TRY
  EXEC accounting.usp_MarkExportSent @ExportId=@conf,@BlobKey=N'otro.xml',@Delivered=0;
  THROW 59002,'ASSERT FAIL: exportacion confirmada aceptada como ready',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51802 THROW; END CATCH;
BEGIN TRY
  EXEC accounting.usp_MarkExportSent @ExportId=@fail,@BlobKey=N'otro.json',@Delivered=0;
  THROW 59002,'ASSERT FAIL: exportacion fallida aceptada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51802 THROW; END CATCH;
BEGIN TRY
  EXEC accounting.usp_MarkExportSent @ExportId=@fail,@BlobKey=N'otro.json',@Delivered=1;
  THROW 59002,'ASSERT FAIL: exportacion fallida enviada',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51802 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE Id=@conf AND Status='confirmed'
        AND BlobKey=N'conf.xml' AND SentAt IS NULL AND ModifiedAt IS NULL);
EXEC test.AssertEq N'el trabajo confirmado quedo intacto',1,@n;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE Id=@fail AND Status='failed'
        AND BlobKey IS NULL AND SentAt IS NULL AND ModifiedAt IS NULL);
EXEC test.AssertEq N'el trabajo fallido quedo intacto',1,@n;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE CloseDocumentId=@doc);
EXEC test.AssertEq N'sin trabajos nuevos por los rechazos',4,@n;
PRINT 'PASS';

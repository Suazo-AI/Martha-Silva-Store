-- TEST: usp_QueueExport encola un trabajo pendiente para un documento cerrado y repetir la misma peticion (mismo Id o mismo documento+destinatario+formato) no crea filas nuevas ni toca la fila existente.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@super uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@register uniqueidentifier=test.Id('registerA'),
  @till uniqueidentifier=NEWID(),@count uniqueidentifier=NEWID(),@close uniqueidentifier=NEWID(),
  @doc uniqueidentifier,@job uniqueidentifier=NEWID(),@job2 uniqueidentifier=NEWID(),@n bigint;

-- Cierre sin ventas: esperado 20000, contado 2 x 10000. Deja un trabajo ACCOUNTANT/PDF pendiente.
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=20000,@OriginNodeId=@node;
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@count,@till,@cashier,'draft',@cashier);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity) VALUES(@count,10000,2);
EXEC sales.usp_SubmitCashCount @CashCountId=@count,@ActorId=@cashier;
EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@till,@CashCountId=@count,@ActorId=@super,@OriginNodeId=@node;
SET @doc=(SELECT Id FROM accounting.CloseDocuments WHERE ClosureId=@close);
SET @n=(SELECT COUNT(*) FROM accounting.CloseDocuments WHERE Id=@doc);
EXEC test.AssertEq N'documento contable del cierre',1,@n;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE CloseDocumentId=@doc);
EXEC test.AssertEq N'trabajo automatico del cierre',1,@n;

EXEC accounting.usp_QueueExport @ExportId=@job,@CloseDocumentId=@doc,@RecipientCode=N'T-AUDITOR',
     @Format='CSV',@ActorId=@cashier;

SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE Id=@job AND CloseDocumentId=@doc
        AND RecipientCode=N'T-AUDITOR' AND Format='CSV' AND Status='pending'
        AND BlobKey IS NULL AND SentAt IS NULL AND ModifiedAt IS NULL AND CreatedBy=@cashier);
EXEC test.AssertEq N'trabajo CSV pendiente y sin marca de envio',1,@n;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE CloseDocumentId=@doc);
EXEC test.AssertEq N'trabajos del documento tras encolar',2,@n;

-- Misma peticion otra vez (el cliente no recibio la respuesta).
EXEC accounting.usp_QueueExport @ExportId=@job,@CloseDocumentId=@doc,@RecipientCode=N'T-AUDITOR',
     @Format='CSV',@ActorId=@cashier;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE CloseDocumentId=@doc);
EXEC test.AssertEq N'trabajos tras repetir la misma peticion',2,@n;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE Id=@job AND Status='pending'
        AND BlobKey IS NULL AND SentAt IS NULL AND ModifiedAt IS NULL);
EXEC test.AssertEq N'la repeticion no modifico el trabajo',1,@n;

-- Mismo documento+destinatario+formato con Id distinto: no hay duplicado ni se usa el Id nuevo.
EXEC accounting.usp_QueueExport @ExportId=@job2,@CloseDocumentId=@doc,@RecipientCode=N'T-AUDITOR',
     @Format='CSV',@ActorId=@super;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE CloseDocumentId=@doc
        AND RecipientCode=N'T-AUDITOR' AND Format='CSV');
EXEC test.AssertEq N'un solo trabajo por documento, destinatario y formato',1,@n;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE Id=@job2);
EXEC test.AssertEq N'el Id nuevo no se persistio',0,@n;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE Id=@job AND CreatedBy=@cashier);
EXEC test.AssertEq N'el trabajo original conserva su creador',1,@n;

-- Encolar el PDF del contador ya creado por el cierre tampoco duplica.
EXEC accounting.usp_QueueExport @ExportId=@job2,@CloseDocumentId=@doc,@RecipientCode=N'ACCOUNTANT',
     @Format='PDF',@ActorId=@super;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE CloseDocumentId=@doc
        AND RecipientCode=N'ACCOUNTANT' AND Format='PDF');
EXEC test.AssertEq N'un solo PDF del contador',1,@n;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE CloseDocumentId=@doc AND Id=@job2);
EXEC test.AssertEq N'ningun trabajo uso el segundo Id',0,@n;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE CloseDocumentId=@doc);
EXEC test.AssertEq N'trabajos finales del documento',2,@n;
PRINT 'PASS';

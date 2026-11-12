-- TEST: usp_QueueExport rechaza con 51801 todo formato fuera de la lista (PDF, CSV, JSON, XML) y no deja filas a medias; un formato nulo es rechazado por la restriccion NOT NULL del esquema.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@super uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@register uniqueidentifier=test.Id('registerA'),
  @till uniqueidentifier=NEWID(),@count uniqueidentifier=NEWID(),@close uniqueidentifier=NEWID(),
  @doc uniqueidentifier,@j1 uniqueidentifier=NEWID(),@j2 uniqueidentifier=NEWID(),
  @j3 uniqueidentifier=NEWID(),@j4 uniqueidentifier=NEWID(),@j5 uniqueidentifier=NEWID(),
  @n bigint,@nullFormat varchar(16)=NULL;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=20000,@OriginNodeId=@node;
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@count,@till,@cashier,'draft',@cashier);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity) VALUES(@count,10000,2);
EXEC sales.usp_SubmitCashCount @CashCountId=@count,@ActorId=@cashier;
EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@till,@CashCountId=@count,@ActorId=@super,@OriginNodeId=@node;
SET @doc=(SELECT Id FROM accounting.CloseDocuments WHERE ClosureId=@close);

BEGIN TRY
  EXEC accounting.usp_QueueExport @ExportId=@j1,@CloseDocumentId=@doc,@RecipientCode=N'T-AUDITOR',
       @Format='TXT',@ActorId=@cashier;
  THROW 59002,'ASSERT FAIL: formato TXT aceptado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51801 THROW; END CATCH;

BEGIN TRY
  EXEC accounting.usp_QueueExport @ExportId=@j2,@CloseDocumentId=@doc,@RecipientCode=N'T-AUDITOR',
       @Format='excel',@ActorId=@cashier;
  THROW 59002,'ASSERT FAIL: formato excel aceptado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51801 THROW; END CATCH;

BEGIN TRY
  EXEC accounting.usp_QueueExport @ExportId=@j3,@CloseDocumentId=@doc,@RecipientCode=N'T-AUDITOR',
       @Format='',@ActorId=@cashier;
  THROW 59002,'ASSERT FAIL: formato vacio aceptado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51801 THROW; END CATCH;

-- Un formato nulo no se convierte en 51801: el INSERT choca con NOT NULL (515). Igual no se guarda nada.
BEGIN TRY
  EXEC accounting.usp_QueueExport @ExportId=@j4,@CloseDocumentId=@doc,@RecipientCode=N'T-AUDITOR',
       @Format=@nullFormat,@ActorId=@cashier;
  THROW 59002,'ASSERT FAIL: formato nulo aceptado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>515 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE CloseDocumentId=@doc AND RecipientCode=N'T-AUDITOR');
EXEC test.AssertEq N'ningun trabajo tras los formatos invalidos',0,@n;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE Id IN (@j1,@j2,@j3,@j4));
EXEC test.AssertEq N'ningun Id invalido persistido',0,@n;

-- El procedimiento sigue usable tras los rechazos.
EXEC accounting.usp_QueueExport @ExportId=@j5,@CloseDocumentId=@doc,@RecipientCode=N'T-AUDITOR',
     @Format='JSON',@ActorId=@cashier;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs WHERE Id=@j5 AND Format='JSON' AND Status='pending');
EXEC test.AssertEq N'trabajo JSON encolado tras los rechazos',1,@n;
PRINT 'PASS';

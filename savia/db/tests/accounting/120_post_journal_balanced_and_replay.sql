-- TEST: usp_PostJournal publica un asiento borrador balanceado con sus marcas de auditoria y una repeticion del mismo Id devuelve 51803 sin tocar el asiento ya publicado.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @cashier uniqueidentifier=test.Id('cashierA'),@asset uniqueidentifier=NEWID(),
  @revenue uniqueidentifier=NEWID(),@entry uniqueidentifier=NEWID(),@n bigint,
  @postedAt datetime2(3),@rv varbinary(8);
INSERT INTO accounting.Accounts(Id,Code,Name,Kind) VALUES
  (@asset,'1101',N'Caja general','asset'),(@revenue,'4101',N'Ingresos por ventas','revenue');
INSERT INTO accounting.JournalEntries(Id,ExternalRef,DocumentDate,Description,Status,CurrencyCode,
  SourceType,SourceId,CreatedBy)
  VALUES(@entry,N'T-JE-100',CAST(SYSUTCDATETIME() AS date),N'Cierre de caja del dia','draft','NIO',
  'cash_closure',NEWID(),@cashier);
INSERT INTO accounting.JournalLines(JournalEntryId,[LineNo],AccountId,DebitMinor,CreditMinor,Description) VALUES
  (@entry,1,@asset,50000,0,N'Entrada de efectivo'),
  (@entry,2,@revenue,0,50000,N'Venta del turno');

EXEC accounting.usp_PostJournal @EntryId=@entry,@PosterId=@cashier;

SET @n=(SELECT COUNT(*) FROM accounting.JournalEntries WHERE Id=@entry AND Status='posted'
        AND PostedAt IS NOT NULL AND PostedBy=@cashier AND ModifiedBy=@cashier AND ModifiedAt IS NOT NULL);
EXEC test.AssertEq N'asiento publicado con marcas de auditoria',1,@n;
SET @n=(SELECT DATEDIFF(second,ModifiedAt,PostedAt) FROM accounting.JournalEntries WHERE Id=@entry);
EXEC test.AssertEq N'hora de publicacion y de modificacion iguales',0,@n;
SET @n=(SELECT COUNT(*) FROM accounting.JournalLines WHERE JournalEntryId=@entry);
EXEC test.AssertEq N'lineas del asiento intactas',2,@n;
SET @n=(SELECT SUM(DebitMinor)-SUM(CreditMinor) FROM accounting.JournalLines WHERE JournalEntryId=@entry);
EXEC test.AssertEq N'asiento sigue balanceado',0,@n;
SET @n=(SELECT COUNT(*) FROM accounting.JournalEntries);
EXEC test.AssertEq N'no se creo otro asiento',1,@n;

SET @postedAt=(SELECT PostedAt FROM accounting.JournalEntries WHERE Id=@entry);
SET @rv=(SELECT RowVersion FROM accounting.JournalEntries WHERE Id=@entry);

-- Repeticion de la misma peticion: el contrato es rechazar, no volver a publicar.
BEGIN TRY
  EXEC accounting.usp_PostJournal @EntryId=@entry,@PosterId=@cashier;
  THROW 59002,'ASSERT FAIL: un asiento ya publicado se volvio a publicar',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51803 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM accounting.JournalEntries WHERE Id=@entry AND Status='posted'
        AND PostedAt=@postedAt AND RowVersion=@rv);
EXEC test.AssertEq N'el asiento no cambio tras la repeticion',1,@n;
SET @n=(SELECT COUNT(*) FROM accounting.JournalLines WHERE JournalEntryId=@entry);
EXEC test.AssertEq N'las lineas no cambiaron tras la repeticion',2,@n;
PRINT 'PASS';

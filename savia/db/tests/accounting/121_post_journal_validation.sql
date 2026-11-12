-- TEST: usp_PostJournal rechaza con 51803 un Id inexistente, con 51804 un asiento no balanceado, sin lineas o de una sola linea, y con 51805 una cuenta inactiva; en todos los casos el asiento sigue en borrador.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @cashier uniqueidentifier=test.Id('cashierA'),@asset uniqueidentifier=NEWID(),
  @revenue uniqueidentifier=NEWID(),@inactive uniqueidentifier=NEWID(),
  @ghost uniqueidentifier=NEWID(),@unbalanced uniqueidentifier=NEWID(),
  @empty uniqueidentifier=NEWID(),@single uniqueidentifier=NEWID(),
  @inactiveEntry uniqueidentifier=NEWID(),@good uniqueidentifier=NEWID(),@n bigint;
INSERT INTO accounting.Accounts(Id,Code,Name,Kind) VALUES
  (@asset,'1101',N'Caja general','asset'),(@revenue,'4101',N'Ingresos por ventas','revenue'),
  (@inactive,'1102',N'Caja dada de baja','asset');
UPDATE accounting.Accounts SET IsActive=0 WHERE Id=@inactive;
INSERT INTO accounting.JournalEntries(Id,ExternalRef,DocumentDate,Description,Status,CurrencyCode,
  SourceType,SourceId,CreatedBy) VALUES
  (@unbalanced,N'T-JE-201',CAST(SYSUTCDATETIME() AS date),N'No balanceado','draft','NIO','test',NEWID(),@cashier),
  (@empty,N'T-JE-202',CAST(SYSUTCDATETIME() AS date),N'Sin lineas','draft','NIO','test',NEWID(),@cashier),
  (@single,N'T-JE-203',CAST(SYSUTCDATETIME() AS date),N'Una sola linea','draft','NIO','test',NEWID(),@cashier),
  (@inactiveEntry,N'T-JE-204',CAST(SYSUTCDATETIME() AS date),N'Cuenta inactiva','draft','NIO','test',NEWID(),@cashier),
  (@good,N'T-JE-205',CAST(SYSUTCDATETIME() AS date),N'Valido','draft','NIO','test',NEWID(),@cashier);
INSERT INTO accounting.JournalLines(JournalEntryId,[LineNo],AccountId,DebitMinor,CreditMinor) VALUES
  (@unbalanced,1,@asset,100,0),(@unbalanced,2,@revenue,0,99),
  (@single,1,@asset,1000,0),
  (@inactiveEntry,1,@inactive,7000,0),(@inactiveEntry,2,@revenue,0,7000),
  (@good,1,@asset,2500,0),(@good,2,@revenue,0,2500);

BEGIN TRY
  EXEC accounting.usp_PostJournal @EntryId=@ghost,@PosterId=@cashier;
  THROW 59002,'ASSERT FAIL: asiento inexistente publicado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51803 THROW; END CATCH;

BEGIN TRY
  EXEC accounting.usp_PostJournal @EntryId=@unbalanced,@PosterId=@cashier;
  THROW 59002,'ASSERT FAIL: asiento no balanceado publicado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51804 THROW; END CATCH;

BEGIN TRY
  EXEC accounting.usp_PostJournal @EntryId=@empty,@PosterId=@cashier;
  THROW 59002,'ASSERT FAIL: asiento sin lineas publicado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51804 THROW; END CATCH;

BEGIN TRY
  EXEC accounting.usp_PostJournal @EntryId=@single,@PosterId=@cashier;
  THROW 59002,'ASSERT FAIL: asiento de una linea publicado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51804 THROW; END CATCH;

BEGIN TRY
  EXEC accounting.usp_PostJournal @EntryId=@inactiveEntry,@PosterId=@cashier;
  THROW 59002,'ASSERT FAIL: asiento con cuenta inactiva publicado',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51805 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM accounting.JournalEntries WHERE Id IN (@unbalanced,@empty,@single,@inactiveEntry)
        AND Status='draft' AND PostedAt IS NULL AND PostedBy IS NULL AND ModifiedAt IS NULL);
EXEC test.AssertEq N'los cuatro asientos rechazados siguen en borrador',4,@n;
SET @n=(SELECT COUNT(*) FROM accounting.JournalEntries WHERE Status='posted');
EXEC test.AssertEq N'ningun asiento publicado por los rechazos',0,@n;
SET @n=(SELECT COUNT(*) FROM accounting.JournalEntries WHERE Id=@ghost);
EXEC test.AssertEq N'no se creo el asiento inexistente',0,@n;

-- El procedimiento sigue publicando correctamente despues de los rechazos.
EXEC accounting.usp_PostJournal @EntryId=@good,@PosterId=@cashier;
SET @n=(SELECT COUNT(*) FROM accounting.JournalEntries WHERE Id=@good AND Status='posted' AND PostedAt IS NOT NULL);
EXEC test.AssertEq N'asiento valido publicado tras los rechazos',1,@n;
PRINT 'PASS';

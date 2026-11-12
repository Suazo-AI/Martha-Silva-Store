/* SAVIA — post-instalacion: comprobaciones de metadatos, no altera datos.
   Estas pruebas NO garantizan logica financiera ni comportamientos concurrentes. */
SET NOCOUNT ON;
GO
DECLARE @schemas int, @tables int, @fks int, @checks int, @indexes int,
        @procs int, @views int, @types int, @roles int;
SELECT @schemas = COUNT(*) FROM sys.schemas
 WHERE name IN ('core','security','crm','sourcing','catalog','inventory',
 'purchasing','receiving','sales','credits','webstore','labels','accounting','sync','audit');
SELECT @tables=COUNT(*) FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
 WHERE s.name IN ('core','security','crm','sourcing','catalog','inventory',
 'purchasing','receiving','sales','credits','webstore','labels','accounting','sync','audit');
SELECT @fks=COUNT(*) FROM sys.foreign_keys f JOIN sys.tables t ON t.object_id=f.parent_object_id
 JOIN sys.schemas s ON s.schema_id=t.schema_id
 WHERE s.name IN ('core','security','crm','sourcing','catalog','inventory',
 'purchasing','receiving','sales','credits','webstore','labels','accounting','sync','audit');
SELECT @checks=COUNT(*) FROM sys.check_constraints c JOIN sys.tables t ON t.object_id=c.parent_object_id
 JOIN sys.schemas s ON s.schema_id=t.schema_id
 WHERE s.name IN ('core','security','crm','sourcing','catalog','inventory',
 'purchasing','receiving','sales','credits','webstore','labels','accounting','sync','audit');
SELECT @indexes=COUNT(*) FROM sys.indexes i JOIN sys.tables t ON t.object_id=i.object_id
 JOIN sys.schemas s ON s.schema_id=t.schema_id WHERE i.name LIKE 'IX[_]%' OR i.name LIKE 'UX[_]%';
SELECT @procs=COUNT(*) FROM sys.procedures p JOIN sys.schemas s ON s.schema_id=p.schema_id
 WHERE s.name IN ('core','security','crm','sourcing','catalog','inventory',
 'purchasing','receiving','sales','credits','webstore','labels','accounting','sync','audit');
SELECT @views=COUNT(*) FROM sys.views v JOIN sys.schemas s ON s.schema_id=v.schema_id
 WHERE s.name IN ('core','security','crm','sourcing','catalog','inventory',
 'purchasing','receiving','sales','credits','webstore','labels','accounting','sync','audit');
SELECT @types=COUNT(*) FROM sys.table_types x JOIN sys.schemas s ON s.schema_id=x.schema_id
 WHERE s.name IN ('sales','webstore');
SELECT @roles=COUNT(*) FROM sys.database_principals WHERE name IN
 ('savia_pos_app','savia_inventory_app','savia_manager_app','savia_web_checkout',
 'savia_payment_worker','savia_fulfillment_worker','savia_sync_worker',
 'savia_label_worker','savia_accounting_worker');
SELECT @schemas AS Schemas, @tables AS Tables, @fks AS ForeignKeys,
       @checks AS CheckConstraints, @indexes AS AdditionalIndexes,
       @procs AS StoredProcedures,@views AS Views,@types AS TableTypes,@roles AS AppRoles;
IF @schemas<>15 OR @tables<>77 OR @fks<>150 OR @checks<>151 OR @indexes<>68
 OR @procs<>41 OR @views<>5 OR @types<>4 OR @roles<>9
  THROW 53000,'SAVIA: objetos faltantes o recuento distinto al baseline; revisar mensajes anteriores.',1;
IF NOT EXISTS(SELECT 1 FROM core.Currencies WHERE Code='NIO')
 OR NOT EXISTS(SELECT 1 FROM core.Currencies WHERE Code='USD')
  THROW 53001,'SAVIA: semillas de monedas faltantes.',1;
PRINT 'SAVIA: metadata baseline correcta; falta ejecutar smoke test y QA integral de la aplicacion.';
GO

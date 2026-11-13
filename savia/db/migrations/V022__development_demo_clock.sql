-- Development-only business clock. No HTTP route exposes it. Security/session clocks stay real UTC.
CREATE OR ALTER FUNCTION core.ufn_BusinessNow() RETURNS datetime2(3)
AS
BEGIN
 RETURN CASE WHEN DB_NAME() LIKE N'SAVIA_DEV[_]%' THEN COALESCE(TRY_CONVERT(datetime2(3),SESSION_CONTEXT(N'savia.demoAt')),SYSUTCDATETIME()) ELSE SYSUTCDATETIME() END;
END;
GO
CREATE OR ALTER PROCEDURE core.usp_SetDemoDate @At datetime2(3)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 IF DB_NAME()<>N'SAVIA_DEV_pilot' THROW 52008,'La historia de muestra solo se permite en SAVIA_DEV_pilot.',1;
 IF @At IS NOT NULL AND (@At<DATEADD(day,-370,SYSUTCDATETIME()) OR @At>SYSUTCDATETIME()) THROW 52008,'Fecha de muestra fuera de rango.',1;
 EXEC sys.sp_set_session_context @key=N'savia.demoAt',@value=@At;
END;
GO
DECLARE @defaults TABLE(SchemaName sysname,TableName sysname,ColumnName sysname);
INSERT @defaults VALUES
 ('sales','Sales','CreatedAt'),('sales','SaleLines','CreatedAt'),('sales','SaleTenders','CreatedAt'),
 ('sales','SaleReversals','CreatedAt'),('sales','SaleReversalLines','CreatedAt'),('sales','CashTills','OpenedAt'),
 ('sales','CashTills','CreatedAt'),('sales','CashCounts','CreatedAt'),('sales','CashClosures','CreatedAt'),
 ('sales','CashEntries','CreatedAt'),('sales','StockExceptions','CreatedAt'),
 ('purchasing','GoodsReceipts','CreatedAt'),('purchasing','GoodsReceiptLines','CreatedAt'),
 ('receiving','ImportContainers','CreatedAt'),('receiving','ScanSessions','CreatedAt'),('receiving','ScanEvents','CreatedAt'),('receiving','QualityChecks','CreatedAt'),
 ('inventory','StockMovements','CreatedAt');
DECLARE @schema sysname,@table sysname,@column sysname,@constraint sysname,@command nvarchar(max);
DECLARE d CURSOR LOCAL FAST_FORWARD FOR SELECT SchemaName,TableName,ColumnName FROM @defaults;
OPEN d;FETCH NEXT FROM d INTO @schema,@table,@column;
WHILE @@FETCH_STATUS=0
BEGIN
 SET @constraint=NULL;
 SELECT @constraint=dc.name FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id=dc.parent_object_id AND c.column_id=dc.parent_column_id WHERE dc.parent_object_id=OBJECT_ID(QUOTENAME(@schema)+N'.'+QUOTENAME(@table)) AND c.name=@column;
 IF @constraint IS NOT NULL
 BEGIN
  SET @command=N'ALTER TABLE '+QUOTENAME(@schema)+N'.'+QUOTENAME(@table)+N' DROP CONSTRAINT '+QUOTENAME(@constraint)+N'; ALTER TABLE '+QUOTENAME(@schema)+N'.'+QUOTENAME(@table)+N' ADD CONSTRAINT '+QUOTENAME(@constraint)+N' DEFAULT(core.ufn_BusinessNow()) FOR '+QUOTENAME(@column)+N';';
  EXEC sys.sp_executesql @command;
 END;
 FETCH NEXT FROM d INTO @schema,@table,@column;
END;
CLOSE d;DEALLOCATE d;
GO
DECLARE @definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'sales.usp_OpenTill'));
IF @definition IS NULL THROW 52008,'Procedimiento requerido no encontrado.',1;
SET @definition=REPLACE(REPLACE(@definition,N'CREATE   PROCEDURE',N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE',N'CREATE OR ALTER PROCEDURE');
SET @definition=REPLACE(@definition,N'SYSUTCDATETIME()',N'core.ufn_BusinessNow()');
EXEC sys.sp_executesql @definition;
GO
DECLARE @definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'sales.usp_CloseTill'));
IF @definition IS NULL THROW 52008,'Procedimiento requerido no encontrado.',1;
SET @definition=REPLACE(REPLACE(@definition,N'CREATE   PROCEDURE',N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE',N'CREATE OR ALTER PROCEDURE');
SET @definition=REPLACE(@definition,N'SYSUTCDATETIME()',N'core.ufn_BusinessNow()');
EXEC sys.sp_executesql @definition;
GO
DECLARE @definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'sales.usp_RecordCashCount'));
IF @definition IS NULL THROW 52008,'Procedimiento requerido no encontrado.',1;
SET @definition=REPLACE(REPLACE(@definition,N'CREATE   PROCEDURE',N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE',N'CREATE OR ALTER PROCEDURE');
SET @definition=REPLACE(@definition,N'SYSUTCDATETIME()',N'core.ufn_BusinessNow()');
EXEC sys.sp_executesql @definition;
GO
DECLARE @definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'sales.usp_SubmitCashCount'));
IF @definition IS NULL THROW 52008,'Procedimiento requerido no encontrado.',1;
SET @definition=REPLACE(REPLACE(@definition,N'CREATE   PROCEDURE',N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE',N'CREATE OR ALTER PROCEDURE');
SET @definition=REPLACE(@definition,N'SYSUTCDATETIME()',N'core.ufn_BusinessNow()');
EXEC sys.sp_executesql @definition;
GO
DECLARE @definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'sales.usp_PostCreditReturn'));
IF @definition IS NULL THROW 52008,'Procedimiento requerido no encontrado.',1;
SET @definition=REPLACE(REPLACE(@definition,N'CREATE   PROCEDURE',N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE',N'CREATE OR ALTER PROCEDURE');
SET @definition=REPLACE(@definition,N'SYSUTCDATETIME()',N'core.ufn_BusinessNow()');
EXEC sys.sp_executesql @definition;
GO
DECLARE @definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'sales.usp_ReviewStockException'));
IF @definition IS NULL THROW 52008,'Procedimiento requerido no encontrado.',1;
SET @definition=REPLACE(REPLACE(@definition,N'CREATE   PROCEDURE',N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE',N'CREATE OR ALTER PROCEDURE');
SET @definition=REPLACE(@definition,N'SYSUTCDATETIME()',N'core.ufn_BusinessNow()');
EXEC sys.sp_executesql @definition;
GO

-- TEST: catalog import previews row errors, imports all rows in one batch, and replays the same batch.
SET NOCOUNT ON;SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),@node uniqueidentifier=test.Id('nodeA'),
 @owner uniqueidentifier=test.Id('manager'),@manager uniqueidentifier=test.Id('supervisorA'),@batch uniqueidentifier=NEWID(),@n bigint,@json nvarchar(max);
DECLARE @bad nvarchar(max)=N'[
 {"row":2,"code":"7501234567893","sku":"","name":"Blusa lino","type":"Blusa","size":"M","color":"Azul","cost":"200","price":"C$ 450.00","stock":"3"},
 {"row":3,"code":"7501234567890","name":"Blusa lino","type":"Blusa","size":"L","color":"Azul","cost":"200","price":"450","stock":"2"},
 {"row":4,"code":"7501234567893","name":"Falda","type":"Falda","size":"S","color":"Negro","cost":"150","price":"","stock":"1"},
 {"row":5,"code":"0000555000111","name":"Copia","price":"10","stock":"x"}]';
DECLARE @out TABLE(Json nvarchar(max));
BEGIN TRY INSERT @out EXEC catalog.usp_ImportCatalog @batch,@branch,@loc,@manager,N'pcg.csv',@bad,@node,0;THROW 59002,'ASSERT FAIL: manager imported',1;END TRY BEGIN CATCH IF ERROR_NUMBER()<>52001 THROW;END CATCH;
INSERT @out EXEC catalog.usp_ImportCatalog @batch,@branch,@loc,@owner,N'pcg.csv',@bad,@node,0;
SET @json=(SELECT Json FROM @out);
SET @n=TRY_CONVERT(bigint,JSON_VALUE(@json,'$.errorCount'));EXEC test.AssertEq N'four rows with errors',4,@n;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@json,'$.errors') WHERE JSON_VALUE(value,'$.message')=N'Digito verificador EAN incorrecto.');EXEC test.AssertEq N'bad check digit',1,@n;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@json,'$.errors') WHERE JSON_VALUE(value,'$.message')=N'Codigo repetido en el archivo.');EXEC test.AssertEq N'duplicate code twice',2,@n;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@json,'$.errors') WHERE JSON_VALUE(value,'$.message')=N'Falta el precio.');EXEC test.AssertEq N'missing price',1,@n;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@json,'$.errors') WHERE JSON_VALUE(value,'$.message')=N'Codigo ya registrado.');EXEC test.AssertEq N'existing code',1,@n;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@json,'$.errors') WHERE JSON_VALUE(value,'$.message')=N'Existencia invalida.');EXEC test.AssertEq N'bad stock',1,@n;
BEGIN TRY EXEC catalog.usp_ImportCatalog @batch,@branch,@loc,@owner,N'pcg.csv',@bad,@node,1;THROW 59002,'ASSERT FAIL: imported with errors',1;END TRY BEGIN CATCH IF ERROR_NUMBER()<>52031 THROW;END CATCH;
SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Sku=N'7501234567893');EXEC test.AssertEq N'nothing written',0,@n;
DECLARE @good nvarchar(max)=N'[
 {"row":2,"code":"7501234567893","sku":"","name":"Blusa lino","type":"Blusa","size":"M","color":"Azul","cost":"200","price":"C$ 450.00","stock":"3"},
 {"row":3,"code":"7501234567886","name":"Blusa lino","type":"Blusa","size":"L","color":"Azul","cost":"200","price":"450","stock":"2"},
 {"row":4,"code":"PCG-0001","sku":"FAL-S-NEG","name":"Falda","type":"Falda","size":"S","color":"Negro","cost":"150.50","price":"1,250.00","stock":"0"}]';
DELETE @out;INSERT @out EXEC catalog.usp_ImportCatalog @batch,@branch,@loc,@owner,N'pcg.csv',@good,@node,1;
SET @n=TRY_CONVERT(bigint,(SELECT JSON_VALUE(Json,'$.itemsCreated') FROM @out));EXEC test.AssertEq N'three items',3,@n;
SET @n=(SELECT COUNT(DISTINCT ProductId) FROM catalog.Items i JOIN catalog.ImportBatchItems b ON b.ItemId=i.Id WHERE b.BatchId=@batch);EXEC test.AssertEq N'two products',2,@n;
SET @n=(SELECT SUM(OnHandDelta) FROM inventory.StockMovements WHERE SourceType='catalog_import' AND SourceId=@batch AND Kind='adjust');EXEC test.AssertEq N'opening stock tied to batch',5,@n;
SET @n=(SELECT UnitPriceMinor FROM catalog.Items WHERE Sku=N'FAL-S-NEG');EXEC test.AssertEq N'price parsed with thousands',125000,@n;
SET @n=(SELECT UnitCostMinor FROM catalog.Items WHERE Sku=N'FAL-S-NEG');EXEC test.AssertEq N'cost parsed',15050,@n;
SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Sku=N'7501234567893' AND Status='active');EXEC test.AssertEq N'sku defaults to code; item active',1,@n;
DELETE @out;INSERT @out EXEC catalog.usp_ImportCatalog @batch,@branch,@loc,@owner,N'pcg.csv',@good,@node,1;
SET @n=(SELECT COUNT(*) FROM catalog.ImportBatchItems WHERE BatchId=@batch);EXEC test.AssertEq N'replay writes nothing',3,@n;
BEGIN TRY EXEC catalog.usp_ImportCatalog @batch,@branch,@loc,@owner,N'otro.csv',@good,@node,1;THROW 59002,'ASSERT FAIL: batch id reused',1;END TRY BEGIN CATCH IF ERROR_NUMBER()<>52004 THROW;END CATCH;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';
